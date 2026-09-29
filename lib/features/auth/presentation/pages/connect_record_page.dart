import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;

import '../../../../core/constants/colors.dart';
import '../../../../services/connection_service.dart';
import '../../../../shared/helpers/topic_suggestions.dart';
import '../../../../shared/widgets/linear_message.dart';
import 'set_my_topic_dialog.dart';

/// Connect flow: record a topic-based video response addressed to
/// [receiverId], preview/retake it (up to [_maxAttempts] takes), then submit
/// via `ConnectionService.sendConnectionRequest`. Camera setup / permission
/// handling / record-preview transition mirrors
/// `onboarding_step_intro_video.dart` — the differences are the 15s/5MB hard
/// caps (vs. onboarding's 30s/8MB), the topic banner, and the attempt
/// counter.
class ConnectRecordPage extends StatefulWidget {
  final String receiverId;
  final String? receiverName;
  final String? receiverPhotoUrl;

  const ConnectRecordPage({
    super.key,
    required this.receiverId,
    this.receiverName,
    this.receiverPhotoUrl,
  });

  @override
  State<ConnectRecordPage> createState() => _ConnectRecordPageState();
}

enum _Stage {
  loadingTopic,
  loadingCamera,
  permissionDenied,
  cameraError,
  ready,
  recording,
  // Between "stop" and the preview: the camera is being released, so the
  // camera preview must no longer be built.
  stopping,
  preview,
  sending,
}

class _ConnectRecordPageState extends State<ConnectRecordPage>
    with WidgetsBindingObserver {
  // Hard cap for a connection video response — deliberately shorter than
  // onboarding's 30s intro video, since this is a quick topic answer.
  static const int _maxSeconds = 15;
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const int _maxAttempts = 3;

  _Stage _stage = _Stage.loadingTopic;
  String _topic = '';

  CameraController? _cameraController;
  VideoPlayerController? _previewController;
  String? _recordedPath;
  String? _thumbnailPath;
  bool _fileTooLarge = false;
  int _recordedSeconds = 0;
  int _attemptsUsed = 0;
  Timer? _timer;
  bool _submitting = false;
  double _uploadProgress = 0;
  /// True only after permanent denial — Settings link allowed only then (5.1.1iv).
  bool _permissionPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOwnTopicThenLoad());
  }

  /// Requires the CONNECTING user (not the receiver) to have set their own
  /// topic before they can send a connect request — since that topic is what
  /// they'll be asking others to answer whenever someone connects with THEM,
  /// it wouldn't be fair for them to ask others to answer a topic before
  /// they've committed to one themselves. Blocks entry into the record flow
  /// entirely (pops back out) if they skip the prompt.
  Future<void> _checkOwnTopicThenLoad() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null) {
      try {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(myUid).get();
        final myTopic = (doc.data()?['myTopic'] ?? '').toString().trim();
        if (myTopic.isEmpty) {
          if (!mounted) return;
          showLinearMessage(
            context,
            'Set your own topic first — that\'s what others will answer when they connect with you.',
          );
          final saved = await SetMyTopicDialog.show(context);
          if (!saved) {
            if (!mounted) return;
            Navigator.of(context).pop(false);
            return;
          }
        }
      } catch (e) {
        debugPrint('ConnectRecordPage: own-topic check failed: $e');
        // Non-fatal — don't block the whole flow over a read error.
      }
    }
    if (!mounted) return;
    await _loadTopic();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (controller == null || !controller.value.isInitialized) return;
      controller.dispose();
      _cameraController = null;
      // Backgrounded mid-recording: the recording is lost with the camera.
      // Drop back to "ready" so resuming re-opens the camera instead of
      // leaving the page on an endless spinner.
      if (_stage == _Stage.recording) {
        _timer?.cancel();
        if (mounted) setState(() => _stage = _Stage.ready);
      }
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

  Future<void> _loadTopic() async {
    setState(() => _stage = _Stage.loadingTopic);
    var topic = '';

    // The receiver's own topic (set via the "Set My Topic" popup/Settings)
    // takes priority — connecting to someone should answer THEIR question,
    // not a random global one. Only fall back to the shared random pool if
    // they haven't set one yet.
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.receiverId)
          .get();
      topic = (doc.data()?['myTopic'] ?? '').toString().trim();
    } catch (e) {
      debugPrint('ConnectRecordPage: receiver topic fetch failed: $e');
    }

    if (topic.isEmpty) {
      try {
        final texts = await fetchActiveTopics();
        topic = texts[Random().nextInt(texts.length)];
      } catch (e) {
        debugPrint('ConnectRecordPage: topic fetch failed, using fallback: $e');
        topic = kFallbackTopics[Random().nextInt(kFallbackTopics.length)];
      }
    }

    if (!mounted) return;
    setState(() => _topic = topic);
    await _initCamera();
  }

  Future<void> _initCamera() async {
    if (mounted) setState(() => _stage = _Stage.loadingCamera);

    // Always request the system permission dialog first (Guideline 5.1.1iv).
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
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await controller.initialize();
      try {
        await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      } catch (e) {
        debugPrint('lockCaptureOrientation failed: $e');
      }
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
      debugPrint('ConnectRecordPage: camera init error: $e');
      if (mounted) setState(() => _stage = _Stage.cameraError);
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
      debugPrint('ConnectRecordPage: start recording error: $e');
    }
  }

  Future<void> _stopRecording() async {
    final controller = _cameraController;
    if (controller == null ||
        _stage != _Stage.recording ||
        !controller.value.isRecordingVideo) {
      return;
    }
    _timer?.cancel();
    // Leave the camera view BEFORE the controller is disposed. Previously the
    // page stayed on the recording stage while `await controller.dispose()`
    // ran, so a rebuild in between built CameraPreview on a disposed
    // controller — the red error screen flashed until the preview loaded.
    // Same pattern as IntroVideoRecorder._stopRecording.
    if (mounted) setState(() => _stage = _Stage.stopping);
    try {
      // Some vendor camera stacks can hang on stopVideoRecording() with no
      // exception — bound it so the user always gets a way forward.
      final file = await controller
          .stopVideoRecording()
          .timeout(const Duration(seconds: 15));
      _recordedPath = file.path;
      _fileTooLarge = await _isOverSizeLimit(file.path);
      _attemptsUsed++;
      _cameraController = null;
      // The preview UI shows a spinner until the player is ready, so advance
      // now; camera teardown and player setup are best-effort from here.
      if (mounted) setState(() => _stage = _Stage.preview);
      unawaited(
        controller.dispose().catchError(
          (e) => debugPrint('ConnectRecordPage: camera dispose error: $e'),
        ),
      );
      unawaited(_initPreviewPlayer(file.path));
      unawaited(_generateThumbnail(file.path));
    } catch (e) {
      debugPrint('ConnectRecordPage: stop recording error: $e');
      _cameraController = null;
      unawaited(controller.dispose().catchError((_) {}));
      if (mounted) setState(() => _stage = _Stage.cameraError);
    }
  }

  /// Extracts a JPEG frame from the recorded video for use as an instant
  /// preview image while the (much larger) response video itself
  /// buffers/loads for the recipient. Best-effort only: failures are
  /// swallowed and simply leave `_thumbnailPath` null — Submit must never be
  /// blocked by this.
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
      debugPrint('ConnectRecordPage: thumbnail generation error: $e');
    }
  }

  Future<void> _initPreviewPlayer(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
    } catch (e) {
      // Preview playback is best-effort (called unawaited): the recorded file
      // can still be submitted; the preview area keeps its spinner.
      debugPrint('ConnectRecordPage: preview player error: $e');
      await controller.dispose();
      return;
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() => _previewController = controller);
  }

  /// Checks a video file against the 5 MB topic-response size cap. Failure
  /// to stat the file (e.g. transient IO error) is treated as "not over"
  /// rather than blocking submission over an unrelated glitch.
  Future<bool> _isOverSizeLimit(String path) async {
    try {
      final bytes = await File(path).length();
      return bytes > _maxFileSizeBytes;
    } catch (_) {
      return false;
    }
  }

  bool get _canRetake => _attemptsUsed < _maxAttempts;

  bool get _canSubmit => _recordedPath != null && !_fileTooLarge;

  Future<void> _retake() async {
    if (!_canRetake) return;
    await _previewController?.dispose();
    _previewController = null;
    _recordedPath = null;
    _thumbnailPath = null;
    _recordedSeconds = 0;
    _fileTooLarge = false;
    await _initCamera();
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() {
      _submitting = true;
      _stage = _Stage.sending;
      _uploadProgress = 0;
    });

    final thumbnailPath = _thumbnailPath;
    final thumbnailFile = thumbnailPath != null && File(thumbnailPath).existsSync()
        ? File(thumbnailPath)
        : null;

    final outcome = await ConnectionService.instance.sendConnectionRequest(
      receiverId: widget.receiverId,
      topic: _topic,
      videoFile: File(_recordedPath!),
      thumbnailFile: thumbnailFile,
      onProgress: (progress) {
        if (mounted) setState(() => _uploadProgress = progress);
      },
    );

    if (!mounted) return;

    if (outcome.result == ConnectionSendResult.sent) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _submitting = false;
      _stage = _Stage.preview;
    });
    showLinearMessage(context, _errorMessageFor(outcome), isError: true);
  }

  String _errorMessageFor(ConnectionSendOutcome outcome) {
    switch (outcome.result) {
      case ConnectionSendResult.dailyLimitReached:
        return "You've reached your daily connection limit. Try again tomorrow.";
      case ConnectionSendResult.alreadyPending:
        return 'You already have a pending request with this person.';
      case ConnectionSendResult.alreadyConnected:
        return "You're already connected with this person.";
      case ConnectionSendResult.receiverNotEligible:
        return "This person isn't available to connect with right now.";
      case ConnectionSendResult.sent:
      case ConnectionSendResult.failed:
        return outcome.message?.isNotEmpty == true
            ? outcome.message!
            : 'Could not send your connection request. Please try again.';
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildStage(),
            if (_stage != _Stage.sending)
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                ),
              ),
            if (_stage == _Stage.sending) _buildSendingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case _Stage.loadingTopic:
      case _Stage.loadingCamera:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.goldMedium),
        );
      case _Stage.permissionDenied:
        return _buildFallback(
          icon: Icons.videocam_off_rounded,
          title: 'Camera & microphone access needed',
          message: _permissionPermanentlyDenied
              ? 'Camera and microphone access is required to record your response. Enable them in Settings, then return here.'
              : 'Swan Match needs camera and microphone access to record your response. Tap Try Again to allow access.',
          primaryLabel: 'Try Again',
          onPrimary: _initCamera,
          secondaryLabel:
              _permissionPermanentlyDenied ? 'Open Settings' : 'Cancel',
          onSecondary: _permissionPermanentlyDenied
              ? openAppSettings
              : () => Navigator.of(context).pop(false),
        );
      case _Stage.cameraError:
        return _buildFallback(
          icon: Icons.error_outline_rounded,
          title: 'Camera unavailable',
          message:
              "We couldn't access a camera on this device. Please check your device and try again.",
          primaryLabel: 'Try Again',
          onPrimary: _initCamera,
        );
      case _Stage.ready:
      case _Stage.recording:
        return _buildCameraView();
      case _Stage.stopping:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.goldMedium),
        );
      case _Stage.preview:
      case _Stage.sending:
        return _buildPreviewView();
    }
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
          Icon(icon, color: AppColors.goldMedium, size: 56),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          _GoldButton(label: primaryLabel, onPressed: onPrimary),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel,
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopicBanner() {
    return Positioned(
      top: 56,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.goldMedium.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.forum_rounded, color: AppColors.goldMedium, size: 16),
                const SizedBox(width: 6),
                Text(
                  widget.receiverName != null && widget.receiverName!.isNotEmpty
                      ? 'Your topic for ${widget.receiverName}'
                      : 'Your topic',
                  style: const TextStyle(
                    color: AppColors.goldMedium,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _topic,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttemptBadge() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Attempt ${min(_attemptsUsed + 1, _maxAttempts)} of $_maxAttempts',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.goldMedium),
      );
    }
    final isRecording = _stage == _Stage.recording;

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 1,
            height: controller.value.previewSize?.width ?? 1,
            child: CameraPreview(controller),
          ),
        ),
        _buildTopicBanner(),
        _buildAttemptBadge(),

        // Countdown / progress ring + duration readout.
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
                    'Tap to record your answer (max 15s)',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  )
                else
                  Text(
                    '${_formatDuration(_recordedSeconds)} / ${_formatDuration(_maxSeconds)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: isRecording ? _stopRecording : _startRecording,
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 76,
                          height: 76,
                          child: CircularProgressIndicator(
                            value: isRecording
                                ? (_recordedSeconds / _maxSeconds).clamp(0.0, 1.0)
                                : 0,
                            strokeWidth: 4,
                            backgroundColor: Colors.white.withOpacity(0.25),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.redAccent,
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isRecording ? 30 : 60,
                          height: isRecording ? 30 : 60,
                          // Always a rectangle; only the corner radius animates
                          // (fully round = circle). Animating BoxShape.circle ⇄
                          // rectangle interpolates a borderRadius onto a circle,
                          // which throws ("borderRadius can only be given for
                          // rectangular boxes") — the red flash on record/stop.
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(isRecording ? 6 : 100),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewView() {
    final controller = _previewController;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.black,
          child: controller != null && controller.value.isInitialized
              ? Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(color: AppColors.goldMedium),
                ),
        ),
        _buildTopicBanner(),
        _buildAttemptBadge(),
        if (_fileTooLarge)
          Positioned(
            left: 20,
            right: 20,
            bottom: 96,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'This video is too large (max ${_maxFileSizeBytes ~/ (1024 * 1024)}MB). Please retake.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 32,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  // Once all attempts are used the label switches to
                  // "Cancel" — it must actually close the screen then
                  // (mirrors the top-left X), not just go dead/disabled.
                  onPressed: _submitting
                      ? null
                      : (_canRetake
                          ? _retake
                          : () => Navigator.of(context).pop(false)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: _canRetake
                          ? AppColors.goldMedium
                          : Colors.white.withOpacity(0.25),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: Text(
                    _canRetake ? 'Retake' : 'Cancel',
                    style: TextStyle(
                      color: _canRetake ? AppColors.goldMedium : Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _GoldButton(
                  label: 'Submit',
                  onPressed: _canSubmit && !_submitting ? _submit : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSendingOverlay() {
    final percent = (_uploadProgress.clamp(0.0, 1.0) * 100).round();
    final label = _uploadProgress > 0
        ? 'Sending your connection request… $percent%'
        : 'Sending your connection request...';
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: AbsorbPointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.black.withOpacity(0.85)),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: AppColors.goldMedium,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
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
}

/// Small gold-gradient CTA button, matching the visual language already used
/// elsewhere in Discover (e.g. the "Add My Photos" CTA) without pulling in
/// the onboarding-only `NextButton`/`OnboardingColors`.
class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _GoldButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: enabled
            ? const LinearGradient(
                colors: [Color(0xFFC8960C), AppColors.goldMedium],
              )
            : null,
        color: enabled ? null : Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.black : Colors.white38,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
