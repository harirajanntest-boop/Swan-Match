import 'package:flutter/material.dart';

import '../../../../models/onboarding_data.dart';
import '../../../../shared/widgets/intro_video_recorder.dart';

/// Onboarding step: record → preview → retake → submit intro video.
///
/// Thin wrapper around the shared [IntroVideoRecorder] (which owns all the
/// camera/permission/timer mechanics) — this step's only job is to stash the
/// recorded file's local path onto [OnboardingData] and advance the
/// onboarding `PageView`. The actual Storage upload happens later, in bulk
/// alongside the photo uploads, at onboarding completion
/// (see `onboarding_flow.dart`'s `_completeOnboarding`).
///
/// The Profile tab's "Replace intro video" flow
/// (`replace_intro_video_page.dart`) reuses the same [IntroVideoRecorder]
/// but uploads immediately on submit instead.
class OnboardingStepIntroVideo extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingStepIntroVideo({
    super.key,
    required this.data,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return IntroVideoRecorder(
      initialLocalPath: data.introVideoLocalPath,
      onSubmit: (file, thumbnailFile) async {
        data.introVideoLocalPath = file.path;
        data.introVideoThumbnailLocalPath = thumbnailFile?.path;
        onNext();
      },
    );
  }
}
