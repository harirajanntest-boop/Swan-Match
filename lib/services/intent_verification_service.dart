import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';

/// Periodic marriage-intent verification (monthly-ready architecture).
class IntentVerificationService {
  IntentVerificationService._();
  static final IntentVerificationService instance =
      IntentVerificationService._();

  static const marriage = 'marriage';
  static const longTerm = 'long_term';
  static const takingBreak = 'taking_break';
  static const pauseMatching = 'pause_matching';

  static const verificationIntervalDays = 30;
  static const _prefsKey = 'intent_verification_last_prompt';
  static const _prefsStatusKey = 'intent_status_cached';

  final _users = FirebaseFirestore.instance.collection('users');

  bool isPaused(String? intentStatus) {
    final s = (intentStatus ?? '').toLowerCase();
    return s == takingBreak || s == pauseMatching;
  }

  /// Map legacy lookingFor text → intentStatus id.
  String? intentFromLookingFor(String? lookingFor) {
    final l = (lookingFor ?? '').toLowerCase().trim();
    if (l.isEmpty || l == 'paused') return null;
    if (l.contains('marriage')) return marriage;
    if (l.contains('long')) return longTerm;
    return null;
  }

  Future<String?> currentIntentStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('$_prefsStatusKey:$uid');

    final snap = await _users.doc(uid).get();
    final data = snap.data();
    if (data == null) return cached;

    var status = (data['intentStatus'] ?? '').toString().trim();
    if (status.isEmpty) {
      status = intentFromLookingFor(data['lookingFor']?.toString()) ?? '';
    }
    if (status.isNotEmpty) {
      await prefs.setString('$_prefsStatusKey:$uid', status);
      return status;
    }
    return cached;
  }

  Future<bool> shouldPromptVerification() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final snap = await _users.doc(uid).get();
    final data = snap.data();
    if (data == null) return false;
    if (data['registrationCompleted'] != true) return false;

    var status = (data['intentStatus'] ?? '').toString().trim();
    if (status.isEmpty) {
      status = intentFromLookingFor(data['lookingFor']?.toString()) ?? '';
    }

    final verifiedAt = data['intentVerifiedAt'];
    DateTime? at;
    if (verifiedAt is Timestamp) at = verifiedAt.toDate();
    if (verifiedAt is String) at = DateTime.tryParse(verifiedAt);

    // Already confirmed and still within the verification window.
    if (status.isNotEmpty && at != null) {
      final age = DateTime.now().difference(at).inDays;
      if (age < verificationIntervalDays) return false;
    }

    // Has intentStatus but missing timestamp — treat as confirmed once,
    // backfill timestamp so Profile won't keep "asking".
    if (status.isNotEmpty && at == null) {
      await _users.doc(uid).set({
        'intentStatus': status,
        'intentVerifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefsStatusKey:$uid', status);
      return false;
    }

    // Legacy lookingFor only — backfill intentStatus without forcing a prompt
    // if they already set a marriage/long-term goal in onboarding.
    if (status.isNotEmpty) {
      await _users.doc(uid).set({
        'intentStatus': status,
        'intentVerifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastPrompt = prefs.getString('$_prefsKey:$uid');
    if (lastPrompt != null) {
      final last = DateTime.tryParse(lastPrompt);
      if (last != null && DateTime.now().difference(last).inHours < 12) {
        return false;
      }
    }

    return true;
  }

  Future<void> markPromptShown() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefsKey:$uid', DateTime.now().toIso8601String());
  }

  Future<void> submitIntent(String intentStatus) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    String lookingFor = '';
    switch (intentStatus) {
      case marriage:
        lookingFor = 'Marriage';
        break;
      case longTerm:
        lookingFor = 'Long-Term Relationship';
        break;
      case takingBreak:
      case pauseMatching:
        lookingFor = 'Paused';
        break;
    }

    // Use UserService so profile cache is invalidated after write.
    await UserService.instance.updateCurrentUserProfile({
      'intentStatus': intentStatus,
      'intentVerifiedAt': FieldValue.serverTimestamp(),
      if (lookingFor.isNotEmpty) 'lookingFor': lookingFor,
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefsStatusKey:$uid', intentStatus);
    await markPromptShown();
  }
}
