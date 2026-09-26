import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/storage_service.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/intro_video_recorder.dart';
import '../../../../shared/widgets/linear_message.dart';

/// Hosts the shared [IntroVideoRecorder] for (re)submitting an intro video
/// from the Profile tab — covers both "never submitted" and
/// "Replace intro video". Unlike onboarding (which just stashes the local
/// file path and uploads later at completion), this uploads immediately on
/// Submit and writes the resulting `pending` status straight to Firestore.
/// The Profile screen's `watchCurrentUserProfile()` stream picks up the
/// change automatically once this page pops — no manual refresh needed.
class ReplaceIntroVideoPage extends StatefulWidget {
  const ReplaceIntroVideoPage({super.key});

  @override
  State<ReplaceIntroVideoPage> createState() => _ReplaceIntroVideoPageState();
}

class _ReplaceIntroVideoPageState extends State<ReplaceIntroVideoPage> {
  bool _uploading = false;
  double _uploadProgress = 0;

  Future<void> _handleSubmit(File file, File? thumbnailFile) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      showLinearMessage(
        context,
        'Your session has expired. Please log in again.',
        isError: true,
      );
      return;
    }

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      final url = await StorageService.instance.uploadIntroVideo(
        uid: uid,
        file: file,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );

      // Thumbnail upload is best-effort — a nice-to-have preview image, not
      // required for the video submission to succeed. Never block or fail
      // the overall submit because of it.
      String? thumbnailUrl;
      if (thumbnailFile != null) {
        try {
          thumbnailUrl = await StorageService.instance.uploadIntroVideoThumbnail(
            uid: uid,
            file: thumbnailFile,
          );
        } catch (e) {
          debugPrint('Intro video thumbnail upload error: $e');
        }
      }

      await UserService.instance.updateCurrentUserProfile(<String, dynamic>{
        'introVideoUrl': url,
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
          'introVideoThumbnailUrl': thumbnailUrl,
        'introVideoStatus': 'pending',
        // introVideoRejectionReason is admin-only in Firestore rules — the
        // owner may never touch this key, not even to null it out. A stale
        // reason is harmless since the UI only shows it when status is
        // 'rejected', not 'pending'.
        'introVideoSubmittedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      showLinearMessage(context, 'Intro video submitted for review.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showLinearMessage(
        context,
        'Could not submit video. Please try again.',
        isError: true,
      );
      // Rethrow so IntroVideoRecorder knows the submit failed and keeps the
      // user on the preview stage (Retake/Submit) instead of assuming success.
      rethrow;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.goldMedium,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Replace Intro Video',
          style: TextStyle(color: Colors.white, letterSpacing: 1, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            IntroVideoRecorder(
              submitLabel: 'Submit for Review',
              onSubmit: _handleSubmit,
            ),
            if (_uploading) _buildUploadOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOverlay() {
    final percent = (_uploadProgress.clamp(0.0, 1.0) * 100).round();
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
                    'Uploading your intro video… $percent%',
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
