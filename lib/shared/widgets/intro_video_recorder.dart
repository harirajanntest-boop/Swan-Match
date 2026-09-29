import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;

import 'onboarding_widgets.dart';

/// Shared record → preview → retake → submit intro-video flow.
///
/// Extracted from onboarding's intro-video step so it can be reused by the
/// Profile tab's "Replace intro video" action without duplicating the
/// camera/permission/timer logic. Front camera by default, live 0-30s
/// duration timer, hard-stop at 30s, Submit disabled under 10s. A user may
/// instead choose an existing video from their gallery — that path enforces
/// the same 10-30s duration window (verified for real, not just relying on
/// the picker's `maxDuration` hint) before accepting it.
/// Camera/mic permissions are requested via `permission_handler` before the
/// camera is initialized. If denied, the UI offers "Try Again" (re-request).
/// "Open Settings" is shown only after a permanent denial (Guideline 5.1.1iv).
///
/// This widget has no opinion on what happens after Submit — onboarding just
/// stashes the file path and advances its `PageView`, while the profile flow
/// uploads immediately and writes Firestore. That's entirely up to
/// [onSubmit]; this widget only owns the record/preview/retake mechanics.
class IntroVideoRecorder extends StatefulWidget {
  /// Path to an already-recorded take to resume straight onto the preview
  /// stage with (e.g. onboarding coming back via "Retake" from Review).
  /// Null, empty, or a missing file starts straight into the camera.
  final String? initialLocalPath;

  /// Called with the recorded file (and, best-effort, a locally-generated
  /// JPEG thumbnail file — null if thumbnail generation failed, which is
  /// never fatal) once the user taps Submit. The recorder shows its own
  /// submit spinner while this future is pending. Rethrow from here to keep
  /// the user on the preview stage (e.g. after showing an error snackbar) so
  /// they can retry Submit or Retake.
  final Future<void> Function(File videoFile, File? thumbnailFile) onSubmit;

  final String submitLabel;

  const IntroVideoRecorder({
    super.key,
    this.initialLocalPath,
    required this.onSubmit,
    this.submitLabel = 'Submit',
  });

  @override
  State<IntroVideoRecorder> createState() => _IntroVideoRecorderState();
}

enum _Stage {
  intro,
  loading,
  permissionDenied,
  cameraError,
  ready,
  recording,
  stopping,
  preview,
}

class _IntroVideoRecorderState extends State<IntroVideoRecorder>
    with WidgetsBindingObserver {
  static const int _maxSeconds = 30;
  static const int _minSeconds = 10;
  static const int _maxFileSizeBytes = 8 * 1024 * 1024; // 8 MB

  CameraController? _cameraController;
  VideoPlayerController? _previewController;
  _Stage _stage = _Stage.intro;
  String? _recordedPath;
  String? _thumbnailPath;
  bool _fileTooLarge = false;
  int _recordedSeconds = 0;
  Timer? _timer;
  bool _isSubmitting = false;
  bool _pickingGalleryVideo = false;
  CameraLensDirection _currentLensDirection = CameraLensDirection.front;
  /// True only after the OS permission dialog was shown and the user denied
  /// permanently — Settings link is allowed only in that case (Apple 5.1.1iv).
  bool _permissionPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final existingPath = widget.initialLocalPath;
    if (existingPath != null &&
        existingPath.isNotEmpty &&
        File(existingPath).existsSync()) {
      // Resuming onto this step with an already-recorded take (e.g. came back
      // via "Retake" from Review) — jump straight to the preview state,
      // skipping the intro instructions screen entirely.
      _recordedPath = existingPath;
      _recordedSeconds = _minSeconds; // already-submitted take passed validation
      _stage = _Stage.preview;
      _initPreviewPlayer(existingPath);
      unawaited(_generateThumbnail(existingPath));
    }
    // Otherwise this is a genuinely fresh start: stay on `_Stage.intro` (its
    // default value above) and wait for the user to tap "Start Recording"
    // before requesting permissions / touching the camera at all.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (controller == null || !controller.value.isInitialized) return;
      // A stop is already finishing the take and disposes the camera itself;
      // disposing it here would throw away the finished recording.
      if (_stage == _Stage.stopping) return;
      controller.dispose();
      _cameraController = null;
      // Backgrounded mid-recording (call, Control Center, app switch): the
      // recording is lost with the camera. Drop back to "ready" so resuming
      // re-opens the camera instead of leaving a timer running with no
      // camera and no way to stop or retake.
      if (_stage == _Stage.recording) {
        _timer?.cancel();
        _recordedSeconds = 0;
        _stage = _Stage.ready;
      }
      // Rebuild so the disposed controller is no longer in the preview.
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed &&
        _stage == _Stage.ready &&
        controller == null) {
      // The camera was released when the app went to the background.
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _cameraController?.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  /// Builds and initializes a [CameraController] for the given lens,
  /// applying the same resolution preset and portrait orientation lock used
  /// everywhere this widget creates a controller (initial setup, retake, and
  /// front/back flip) so those call sites never drift out of sync.
  Future<CameraController> _createController(
    CameraDescription description,
  ) async {
    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: true,
    );
    await controller.initialize();
    try {
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } catch (e) {
      debugPrint('lockCaptureOrientation failed: $e');
    }
    return controller;
  }

  Future<void> _initCamera() async {
    if (mounted) setState(() => _stage = _Stage.loading);

    // Always request the system permission dialog first (Guideline 5.1.1iv).
    // Never open Settings before the OS prompt has been shown.
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (!cameraStatus.isGranted || !micStatus.isGranted) {
      final permanentlyDenied = cameraStatus.isPermanentlyDenied ||
          micStatus.isPermanentlyDenied;
      if (mounted) {
        setState(() {
          _permissionPermanentlyDenied = permanentlyDenied;
          _stage = _Stage.permissionDenied;
        });
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _stage = _Stage.cameraError);
        return;
      }
      final description = cameras.firstWhere(
        (c) => c.lensDirection == _currentLensDirection,
        orElse: () => cameras.first,
      );

      final controller = await _createController(description);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _permissionPermanentlyDenied = false;
        _cameraController = controller;
        _stage = _Stage.ready;
      });
    } catch (e) {
      debugPrint('Intro video camera init error: $e');
      if (mounted) setState(() => _stage = _Stage.cameraError);
    }
  }

  /// Switches between the front and back lens. Only ever called while
  /// `_stage == _Stage.ready` (the flip control is hidden/disabled during
  /// `recording`) — swapping the active `CameraController` mid-recording
  /// would tear down the in-progress capture on most device camera stacks,
  /// so that path is intentionally not supported here.
  Future<void> _flipCamera() async {
    if (_stage != _Stage.ready) return;
    final previousController = _cameraController;
    final newDirection = _currentLensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    try {
      final cameras = await availableCameras();
      final description = cameras.firstWhere(
        (c) => c.lensDirection == newDirection,
        orElse: () => cameras.first,
      );
      final controller = await _createController(description);
      await previousController?.dispose();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _currentLensDirection = newDirection;
        _stage = _Stage.ready;
      });
    } catch (e) {
      debugPrint('Flip camera error: $e');
      // Non-fatal: keep whatever camera was already active rather than
      // dropping the user out of the ready stage over a failed flip.
    }
  }

  Future<void> _startRecording() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _stage = _Stage.recording;
        _recordedSeconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _recordedSeconds++);
        if (_recordedSeconds >= _maxSeconds) {
          timer.cancel();
          await _stopRecording();
        }
      });
    } catch (e) {
      debugPrint('Start recording error: $e');
    }
  }

  Future<void> _stopRecording() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isRecordingVideo) return;
    _timer?.cancel();
    if (mounted) setState(() => _stage = _Stage.stopping);
    try {
      // Some device camera stacks (observed on vendor-customized Android
      // builds) can hang indefinitely on stopVideoRecording() with no
      // exception thrown — a bare `await` here previously left the user
      // stuck on the recording screen forever with no error and no way
      // forward. Bound it with a timeout so that failure mode always
      // resolves into a visible, actionable error instead.
      final file = await controller
          .stopVideoRecording()
          .timeout(const Duration(seconds: 15));
      _recordedPath = file.path;
      _fileTooLarge = await _isOverSizeLimit(file.path);
      _cameraController = null;
      // Advance to preview immediately — getting the recorded file is the
      // only thing that actually needs to succeed for Submit to work.
      // Camera teardown and preview playback are both best-effort from here
      // and must never block reaching this stage: the preview UI already
      // renders a spinner in place of the player when it isn't ready yet.
      if (mounted) setState(() => _stage = _Stage.preview);

      unawaited(
        controller.dispose().catchError(
          (e) => debugPrint('Camera dispose after stop error: $e'),
        ),
      );
      unawaited(_initPreviewPlayer(file.path));
      unawaited(_generateThumbnail(file.path));
    } catch (e) {
      debugPrint('Stop recording error: $e');
      unawaited(controller.dispose().catchError((_) {}));
      _cameraController = null;
      if (mounted) {
        setState(() => _stage = _Stage.cameraError);
      }
    }
  }

  /// Checks a video file against the 8 MB intro-video size cap. Failure to
  /// stat the file (e.g. transient IO error) is treated as "not over" rather
  /// than blocking submission over an unrelated glitch.
  Future<bool> _isOverSizeLimit(String path) async {
    try {
      final bytes = await File(path).length();
      return bytes > _maxFileSizeBytes;
    } catch (_) {
      return false;
    }
  }

  /// Lets the user pick an already-recorded video from their gallery instead
  /// of recording live, subject to the exact same 10-30s duration window as
  /// live recording (`_minSeconds`/`_maxSeconds`). `image_picker`'s
  /// `maxDuration` is only a hint some gallery pickers ignore, so the real
  /// duration is re-verified here via a throwaway `VideoPlayerController`
  /// before the pick is accepted.
  Future<void> _pickFromGallery() async {
    if (_pickingGalleryVideo) return;
    setState(() => _pickingGalleryVideo = true);
    VideoPlayerController? probeController;
    try {
      final picker = ImagePicker();
      final file = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: _maxSeconds),
      );
      if (file == null) return;

      probeController = VideoPlayerController.file(File(file.path));
      await probeController.initialize().timeout(const Duration(seconds: 15));
      final duration = probeController.value.duration.inSeconds;
      await probeController.dispose();
      probeController = null;

      if (duration < _minSeconds) {
        _showGalleryError(
          'That video is too short — please choose one that\'s at least $_minSeconds seconds.',
        );
        return;
      }
      if (duration > _maxSeconds) {
        _showGalleryError(
          'That video is too long — please choose one that\'s under $_maxSeconds seconds.',
        );
        return;
      }
      if (await _isOverSizeLimit(file.path)) {
        final maxMb = _maxFileSizeBytes ~/ (1024 * 1024);
        _showGalleryError(
          'That video is too large — please choose one under ${maxMb}MB.',
        );
        return;
      }

      _recordedPath = file.path;
      _recordedSeconds = duration;
      _fileTooLarge = false;
      if (mounted) setState(() => _stage = _Stage.preview);
      unawaited(_initPreviewPlayer(file.path));
      unawaited(_generateThumbnail(file.path));
    } catch (e) {
      debugPrint('Gallery video pick error: $e');
      _showGalleryError('Could not load that video. Please try another.');
    } finally {
      await probeController?.dispose();
      if (mounted) setState(() => _pickingGalleryVideo = false);
    }
  }

  void _showGalleryError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
    );
  }

  Future<void> _initPreviewPlayer(String path) async {
    try {
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize().timeout(const Duration(seconds: 15));
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _previewController = controller);
    } catch (e) {
      // Non-fatal: the recorded file still exists and can still be
      // submitted even if the inline preview player never loads — the
      // preview UI shows a spinner in its place rather than blocking Submit.
      debugPrint('Preview player init error: $e');
    }
  }

  /// Extracts a JPEG frame from the recorded video for use as an instant
  /// preview image while the (much larger) video itself buffers/loads
  /// elsewhere in the app. Best-effort only: failures are swallowed and
  /// simply leave `_thumbnailPath` null — Submit must never be blocked by
  /// this, same philosophy as `_initPreviewPlayer` above.
  Future<void> _generateThumbnail(String videoPath) async {
    try {
      final dir = await getTemporaryDirectory();
      final thumbPath = await video_thumbnail.VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: dir.path,
        imageFormat: video_thumbnail.ImageFormat.JPEG,
        maxWidth: 480,
        quality: 75,
      );
      if (thumbPath == null) return;
      if (mounted) {
        setState(() => _thumbnailPath = thumbPath);
      } else {
        _thumbnailPath = thumbPath;
      }
    } catch (e) {
      // Non-fatal: the video itself is unaffected and Submit still works
      // without a thumbnail — the caller simply won't have one to upload.
      debugPrint('Intro video thumbnail generation error: $e');
    }
  }

  Future<void> _retake() async {
    if (_isSubmitting) return;
    await _previewController?.dispose();
    _previewController = null;
    _recordedPath = null;
    _thumbnailPath = null;
    _recordedSeconds = 0;
    _fileTooLarge = false;
    await _initCamera();
  }

  bool get _canSubmit =>
      _recordedPath != null &&
      _recordedSeconds >= _minSeconds &&
      !_fileTooLarge;

  Future<void> _submit() async {
    if (!_canSubmit || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final thumbnailPath = _thumbnailPath;
      final thumbnailFile = thumbnailPath != null && File(thumbnailPath).existsSync()
          ? File(thumbnailPath)
          : null;
      await widget.onSubmit(File(_recordedPath!), thumbnailFile);
    } catch (_) {
      // Caller is expected to surface its own error UI; swallow here so the
      // recorder simply stays on the preview stage for a retry.
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.intro:
        return _buildIntroScreen();
      case _Stage.loading:
        return const Center(
          child: CircularProgressIndicator(color: OnboardingColors.primaryGold),
        );
      case _Stage.permissionDenied:
        // Primary action is always "Try Again" (re-triggers the system dialog
        // when still possible). "Open Settings" is only offered after a
        // permanent denial — never before the OS permission prompt.
        return _buildFallback(
          icon: Icons.videocam_off_rounded,
          title: 'Camera & microphone access needed',
          message: _permissionPermanentlyDenied
              ? 'Camera and microphone access is required to record your intro video. Enable them in Settings, then return here.'
              : 'Swan Match needs camera and microphone access to record your intro video. Tap Try Again to allow access.',
          primaryLabel: 'Try Again',
          onPrimary: _initCamera,
          secondaryLabel:
              _permissionPermanentlyDenied ? 'Open Settings' : null,
          onSecondary:
              _permissionPermanentlyDenied ? openAppSettings : null,
        );
      case _Stage.cameraError:
        return _buildFallback(
          icon: Icons.error_outline_rounded,
          title: 'Camera unavailable',
          message:
              'We couldn\'t access a camera on this device. Please check your device and try again.',
          primaryLabel: 'Try Again',
          onPrimary: _initCamera,
        );
      case _Stage.ready:
      case _Stage.recording:
        return _buildCameraView();
      case _Stage.stopping:
        return const Center(
          child: CircularProgressIndicator(color: OnboardingColors.primaryGold),
        );
      case _Stage.preview:
        return _buildPreviewView();
    }
  }

  /// The very first thing a user sees on this step, before any camera or
  /// microphone permission is requested — explains what to record and warns
  /// against inappropriate content. Only shown on a genuinely fresh start;
  /// `initState` skips straight to `_Stage.preview` when resuming an
  /// already-recorded take.
  Widget _buildIntroScreen() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  OnboardingColors.primaryGold.withOpacity(0.3),
                  OnboardingColors.goldDark.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: OnboardingColors.primaryGold.withOpacity(0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: OnboardingColors.primaryGold.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.videocam_rounded,
                size: 42,
                color: OnboardingColors.primaryGold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Record Your Intro Video',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: OnboardingColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Text(
              'This is your first impression — introduce yourself! Share who '
              'you are, what you enjoy, and what you\'re looking for in a '
              'match. Feel free to show off a talent too — singing, dancing, '
              'whatever makes you, you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: OnboardingColors.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Do not upload violent, explicit, or otherwise '
                    'inappropriate content. Doing so may result in your '
                    'account being permanently banned from Swan Match.',
                    style: TextStyle(
                      color: Colors.redAccent.shade100,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          NextButton(
            label: 'Start Recording',
            onPressed: _initCamera,
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: _pickingGalleryVideo ? null : _pickFromGallery,
            icon: _pickingGalleryVideo
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: OnboardingColors.primaryGold,
                    ),
                  )
                : const Icon(Icons.photo_library_outlined,
                    color: OnboardingColors.primaryGold, size: 18),
            label: Text(
              _pickingGalleryVideo
                  ? 'Loading video…'
                  : 'Choose from Gallery ($_minSeconds-$_maxSeconds seconds)',
              style: const TextStyle(
                color: OnboardingColors.primaryGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFallback({
    required IconData icon,
    required String title,
    required String message,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: OnboardingColors.primaryGold, size: 56),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OnboardingColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          NextButton(label: primaryLabel, onPressed: onPrimary),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel,
                style: const TextStyle(color: OnboardingColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: OnboardingColors.primaryGold),
      );
    }
    final isRecording = _stage == _Stage.recording;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed camera preview, cropped to cover the available area.
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.previewSize?.height ?? 1,
              height: controller.value.previewSize?.width ?? 1,
              child: CameraPreview(controller),
            ),
          ),

          // Front/back camera flip — only offered while `ready`. Switching
          // the active CameraController mid-recording isn't safe with this
          // plugin, so the button is hidden once recording starts.
          if (!isRecording)
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: _flipCamera,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.55),
                  ),
                  child: const Icon(
                    Icons.flip_camera_ios_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),

          // Top duration readout.
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: isRecording
                      ? Border.all(color: Colors.redAccent, width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isRecording) ...[
                      const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 12),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      '${_formatDuration(_recordedSeconds)} / ${_formatDuration(_maxSeconds)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom gradient + record control.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 60, bottom: 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isRecording)
                    const Text(
                      'Tap to record your 10-30s intro',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: isRecording ? _stopRecording : _startRecording,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        // Always a rectangle; only the corner radius animates
                        // (fully round = circle). Animating BoxShape.circle ⇄
                        // rectangle interpolates a borderRadius onto a circle,
                        // which throws — a red error flash on record/stop.
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(isRecording ? 6 : 100),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewView() {
    final controller = _previewController;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview Your Intro',
            style: TextStyle(
              color: OnboardingColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'This is what others will see first. Happy with it?',
            style: TextStyle(
              color: OnboardingColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Colors.black,
                child: controller != null && controller.value.isInitialized
                    ? Center(
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                          color: OnboardingColors.primaryGold,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!_canSubmit)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _fileTooLarge
                    ? 'This video is too large (max ${_maxFileSizeBytes ~/ (1024 * 1024)}MB). Please retake or choose another.'
                    : 'Record at least $_minSeconds seconds to continue.',
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : _retake,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: OnboardingColors.primaryGold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: const Text(
                    'Retake',
                    style: TextStyle(
                      color: OnboardingColors.primaryGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: NextButton(
                  label: widget.submitLabel,
                  enabled: _canSubmit,
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
