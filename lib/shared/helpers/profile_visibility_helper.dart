import 'package:flutter/material.dart';

/// Shared helpers for profile visibility and photo privacy.
class ProfileVisibilityHelper {
  ProfileVisibilityHelper._();

  static bool isPrivateProfile(Map<String, dynamic> profile) {
    if (profile['showProfileToEveryone'] == false) return true;
    final visibility = (profile['profileVisibility'] ?? 'Public').toString();
    if (visibility == 'Private') return true;
    // Legacy onboarding value — treat as hidden from discovery.
    if (visibility == 'Curated Matches Only') return true;
    return false;
  }

  static bool shouldHidePhotos(Map<String, dynamic> profile) {
    return profile['showPhotosToEveryone'] == false;
  }

  /// Whether a profile may appear in Discover / match feeds.
  /// Requires admin profile approval + approved intro video, plus standard gates.
  /// Government ID is optional (Guideline 5.1.1v) and is not required here.
  static bool isDiscoverVisible(Map<String, dynamic> profile) {
    if (profile['isDeleted'] == true) return false;
    if (profile['status']?.toString().toLowerCase() == 'deleted') return false;
    if (profile['showProfileToEveryone'] == false) return false;

    final approvalStatus =
        (profile['profileApprovalStatus'] ?? 'pending').toString().toLowerCase();
    if (approvalStatus != 'approved') return false;

    // Video-first redesign: the intro video is the primary discovery
    // artifact, so it must be admin-approved too (separate from, and in
    // addition to, general profile approval above).
    final introVideoStatus =
        (profile['introVideoStatus'] ?? '').toString().toLowerCase();
    if (introVideoStatus != 'approved') return false;

    // Government ID is optional (Guideline 5.1.1v) — do not gate Discover on ID.

    final visibility = (profile['profileVisibility'] ?? 'Public').toString();
    if (visibility == 'Private') return false;
    if (visibility == 'Curated Matches Only') return false;

    final account = (profile['account'] ?? '').toString().toLowerCase();
    if (account == 'suspended') return false;

    final intent = (profile['intentStatus'] ?? '').toString().toLowerCase();
    if (intent == 'taking_break' || intent == 'pause_matching') return false;

    return true;
  }

  /// Admin-approved ID verification (set from admin panel).
  static bool isIdVerified(Map<String, dynamic> profile) {
    return profile['idVerified'] == true ||
        profile['isVerified'] == true ||
        profile['profileVerified'] == true ||
        profile['verificationStatus']?.toString().toLowerCase() == 'approved';
  }

  /// Whether the CURRENT user's own account has cleared admin review — the
  /// same approval gates [isDiscoverVisible] requires for a profile to
  /// be shown to others (profile approval + intro video approval), used
  /// instead to decide whether THIS user may browse Discover at all.
  /// Government ID is optional and is NOT required here (Guideline 5.1.1v).
  /// Deliberately excludes the privacy/pause/suspension
  /// checks in [isDiscoverVisible] — those are the user's own opt-out
  /// preferences, not admin-approval gates, and shouldn't stop someone from
  /// browsing just because they set their own profile to Private, for
  /// example.
  static bool isAccountApprovedForDiscover(Map<String, dynamic> profile) {
    final approvalStatus =
        (profile['profileApprovalStatus'] ?? 'pending').toString().toLowerCase();
    if (approvalStatus != 'approved') return false;

    final introVideoStatus =
        (profile['introVideoStatus'] ?? '').toString().toLowerCase();
    if (introVideoStatus != 'approved') return false;

    return true;
  }

  static Widget hiddenPhotoPlaceholder({double iconSize = 50}) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Icon(
          Icons.admin_panel_settings_outlined,
          color: Colors.white.withOpacity(0.35),
          size: iconSize,
        ),
      ),
    );
  }
}
