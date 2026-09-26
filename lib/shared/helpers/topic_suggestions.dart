import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared source of topic suggestions for both `ConnectRecordPage` (random
/// fallback topic when a receiver hasn't set their own) and the "Set My
/// Topic" popup (suggestions the user can pick from instead of typing their
/// own). Kept in one place so the two never drift out of sync.
const List<String> kFallbackTopics = [
  'What is one thing you value most in a relationship?',
  'What does a perfect weekend look like to you?',
  'What is something you are looking forward to in life right now?',
  'What does a meaningful partnership mean to you?',
  'What is a small thing that makes you really happy?',
  'What are you most grateful for these days?',
];

/// Fetches active topics from the `topics` collection (admin-curated), or
/// [kFallbackTopics] if that collection is empty/unreachable — mirrors the
/// existing fallback behavior in `ConnectRecordPage._loadTopic()`.
Future<List<String>> fetchActiveTopics({int limit = 30}) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('topics')
        .where('active', isEqualTo: true)
        .limit(limit)
        .get();
    final texts = snapshot.docs
        .map((doc) => (doc.data()['text'] ?? '').toString().trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (texts.isNotEmpty) return texts;
  } catch (_) {
    // Fall through to the local fallback list below.
  }
  return kFallbackTopics;
}
