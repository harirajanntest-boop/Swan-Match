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
    if (userData['status']?.toString() == 'deleted') return true;
    return false;
  }

  /// Returns 'Deleted Account' for deleted users, otherwise the firstName.
  static String getDisplayName(Map<String, dynamic>? userData) {
    if (isDeleted(userData)) return 'Deleted Account';
    return (userData?['firstName'] ?? userData?['name'] ?? 'Unknown').toString();
  }

  /// Returns null for deleted users so no photo is shown.
  static String? getAvatarUrl(Map<String, dynamic>? userData) {
    if (isDeleted(userData)) return null;
    final url = (userData?['profilePhotoUrl'] ??
            userData?['photoUrl'] ??
            '')
        .toString();
    return url.isEmpty ? null : url;
  }

  /// Returns false for deleted users — prevents sending messages.
  static bool canSendMessage(Map<String, dynamic>? userData) {
    return !isDeleted(userData);
  }

  /// Returns a contextual subtitle string.
  static String getSubtitle(Map<String, dynamic>? userData) {
    if (isDeleted(userData)) return 'This account no longer exists';
    return (userData?['profession'] ?? userData?['occupation'] ?? '').toString();
  }
}
