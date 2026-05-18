import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A CircleAvatar that gracefully shows a placeholder icon when a user
/// account has been deleted or no photo URL is available.
class DeletedUserAvatar extends StatelessWidget {
  final String? photoUrl;
  final double radius;
  final bool isDeleted;
  final bool photosHidden;

  const DeletedUserAvatar({
    super.key,
    this.photoUrl,
    this.radius = 24,
    this.isDeleted = false,
    this.photosHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final showPlaceholder = isDeleted ||
        photosHidden ||
        (photoUrl == null || photoUrl!.isEmpty);

    if (showPlaceholder) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white12,
        child: Icon(
          photosHidden
              ? Icons.admin_panel_settings_outlined
              : Icons.person_off_outlined,
          color: photosHidden
              ? Colors.white.withOpacity(0.35)
              : Colors.white30,
          size: radius * 0.8,
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white12,
      backgroundImage: CachedNetworkImageProvider(photoUrl!),
      onBackgroundImageError: (_, __) {},
      child: null,
    );
  }
}
