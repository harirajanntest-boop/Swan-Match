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
