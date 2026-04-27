import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which chat conversation is currently open on screen.
/// Used by notification handlers to suppress push notifications
/// when the user is already viewing the chat with the sender.
class ChatPresenceService {
  ChatPresenceService._();
  static final ChatPresenceService instance = ChatPresenceService._();

  /// The otherUserId of the currently open chat, or null if no chat is open.
  String? _currentChatUserId;

  /// Set when entering a chat screen.
  void enterChat(String otherUserId) {
    _currentChatUserId = otherUserId;
    // Persist for background FCM handler
    SharedPreferences.getInstance()
        .then((p) => p.setString('active_chat_uid', otherUserId));
  }

  /// Clear when leaving a chat screen.
  void leaveChat() {
    _currentChatUserId = null;
    // Clear persisted presence so background handler knows chat is closed
    SharedPreferences.getInstance()
        .then((p) => p.remove('active_chat_uid'));
  }

  /// Returns true if the user is currently in a chat with the given userId.
  bool isInChatWith(String userId) {
    return _currentChatUserId != null && _currentChatUserId == userId;
  }

  /// Returns true if any chat screen is currently open.
  bool get isInChat => _currentChatUserId != null;

  /// The currently open chat userId, or null.
  String? get currentChatUserId => _currentChatUserId;
}
