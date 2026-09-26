import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/colors.dart';
import '../../../../services/user_service.dart';
import 'replace_intro_video_page.dart';

/// Full-size intro video viewer, reached from the Profile screen's
/// "My Intro Video" menu row. Shows the video at its native aspect ratio
/// (via `AspectRatio`, matching `intro_video_recorder.dart`'s preview) rather
/// than the old cropped `FittedBox(BoxFit.cover)` treatment that used to live
/// inline on the Profile screen. Streams the profile itself (rather than
/// taking a static snapshot) so the status/rejection reason stay live if the
/// user replaces the video and comes back.
class IntroVideoDetailPage extends StatelessWidget {
  const IntroVideoDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'My Intro Video',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: UserService.instance.watchCurrentUserProfile(),
          builder: (context, snapshot) {
            if (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.goldMedium),
              );
            }
            final profile = snapshot.data ?? const <String, dynamic>{};
            return _IntroVideoDetailBody(profile: profile);
          },
        ),
      ),
    );
  }
}

class _IntroVideoDetailBody extends StatelessWidget {
  final Map<String, dynamic> profile;

  const _IntroVideoDetailBody({required this.profile});

  String get _url => (profile['introVideoUrl'] ?? '').toString().trim();
  String get _status =>
      (profile['introVideoStatus'] ?? '').toString().trim().toLowerCase();
  String get _rejectionReason =>
      (profile['introVideoRejectionReason'] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.videocam_rounded, color: AppColors.goldMedium, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Intro Video',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _buildStatusPill(),
            ],
          ),
          const SizedBox(height: 16),
          if (_url.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _FullIntroVideoPlayer(url: _url),
            )
          else
            _buildEmptyState(),
          if (_status == 'rejected' && _rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warningRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _rejectionReason,
                      style: const TextStyle(
                        color: AppColors.warningRed,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReplaceIntroVideoPage()),
              ),
              icon: const Icon(Icons.videocam_outlined, size: 16, color: AppColors.goldMedium),
              label: Text(
                _url.isEmpty ? 'Record Intro Video' : 'Replace Intro Video',
                style: const TextStyle(
                  color: AppColors.goldMedium,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.goldMedium),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Add a short intro video so others can see the real you.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    switch (_status) {
      case 'pending':
        return _pill('Under review', Colors.orangeAccent);
      case 'rejected':
        return _pill('Rejected', Colors.redAccent);
      case 'approved':
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: Colors.greenAccent, size: 8),
            SizedBox(width: 4),
            Text(
              'Live',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Plays the network intro video at its native aspect ratio — no cropping,
/// unlike the old Profile-screen inline thumbnail which forced a fixed
/// 220px-tall `FittedBox(BoxFit.cover)` box (see `intro_video_recorder.dart`'s
/// `_buildPreviewView` for the pattern this mirrors).
class _FullIntroVideoPlayer extends StatefulWidget {
  final String url;

  const _FullIntroVideoPlayer({required this.url});

  @override
  State<_FullIntroVideoPlayer> createState() => _FullIntroVideoPlayerState();
}

class _FullIntroVideoPlayerState extends State<_FullIntroVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      if (_isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 220,
        color: const Color(0xFF1A1A1A),
        child: const Center(
          child: Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 36),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        height: 220,
        color: const Color(0xFF1A1A1A),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.goldMedium, strokeWidth: 2),
        ),
      );
    }
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
            AnimatedOpacity(
              opacity: _isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
