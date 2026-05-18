/// Helper for checking and displaying data for soft-deleted user accounts.
///
/// All methods are safe to call with null userData (e.g., when the Firestore
/// fetch is still pending or the document no longer exists).
class DeletedUserHelper {
  DeletedUserHelper._();

  /// Returns true if the user document is marked as deleted.
  static bool isDeleted(Map<String, dynamic>? userData) {
    if (userData == null) return true;
    if (userData['isDeleted'] == true) return true;
    if (userData['status']?.toString().toLowerCase() == 'deleted') return true;
    if (userData['deletedAt'] != null) return true;
    if (userData['scheduledHardDeleteAt'] != null) return true;

    final name = (userData['name'] ?? userData['displayName'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (name == 'deleted account') return true;

    final firstName = (userData['firstName'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final lastName = (userData['lastName'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (firstName == 'deleted' && lastName == 'account') return true;
    return false;
  }

  /// Returns 'Deleted Account' for deleted users, otherwise the firstName.
  static String getDisplayName(Map<String, dynamic>? userData) {
    if (isDeleted(userData)) return 'Deleted Account';
    return (userData?['firstName'] ?? userData?['name'] ?? 'Unknown')
        .toString();
  }

  /// True when the user has hidden their photos from public view.
  static bool arePhotosHidden(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    return userData['showPhotosToEveryone'] == false;
  }

  /// Returns null for deleted users or when photos are hidden.
  static String? getAvatarUrl(Map<String, dynamic>? userData) {
    if (isDeleted(userData)) return null;
    if (arePhotosHidden(userData)) return null;
    // Check dedicated photo fields first, then fall back to photos array
    final url =
        (userData?['profilePhotoUrl'] ??
                userData?['photoUrl'] ??
                userData?['profilePicture'] ??
                '')
            .toString();
    if (url.isNotEmpty) return url;
    // Fall back to first item in photos array
    final photos = userData?['photos'];
    if (photos is List && photos.isNotEmpty) {
      final first = photos.first?.toString() ?? '';
      if (first.isNotEmpty) return first;
    }
    return null;
  }

  /// Returns false for deleted users — prevents sending messages.
  static bool canSendMessage(Map<String, dynamic>? userData) {
    return !isDeleted(userData);
  }

  /// Returns a contextual subtitle string.
  static String getSubtitle(Map<String, dynamic>? userData) {
    if (isDeleted(userData)) return 'This account no longer exists';
    return (userData?['profession'] ?? userData?['occupation'] ?? '')
        .toString();
  }
}
