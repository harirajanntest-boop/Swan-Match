import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Client for Swan AI Cloud Functions (Groq in dev, OpenAI in prod).
class SwanAiService {
  SwanAiService._();
  static final SwanAiService instance = SwanAiService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<Map<String, dynamic>?> generateCompatibilityNarrative({
    required String journeyId,
    required String nameA,
    required String nameB,
    required int overallScore,
    required String ratingTier,
    required Map<String, int> categoryScores,
    required List<String> strengths,
    required List<String> discussionTopics,
    required Map<String, dynamic> profileA,
    required Map<String, dynamic> profileB,
  }) async {
    try {
      final result = await _functions
          .httpsCallable(
            'generateCompatibilityNarrative',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 55)),
          )
          .call(<String, dynamic>{
            'journeyId': journeyId,
            'nameA': nameA,
            'nameB': nameB,
            'overallScore': overallScore,
            'ratingTier': ratingTier,
            'categoryScores': categoryScores,
            'strengths': strengths,
            'discussionTopics': discussionTopics,
            'profileA': profileA,
            'profileB': profileB,
          });
      final data = result.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'SwanAiService.generateCompatibilityNarrative: ${e.code} ${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('SwanAiService.generateCompatibilityNarrative failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> generateJourneyStageInsight({
    required String journeyId,
    required int stage,
    required Map<String, dynamic> profileA,
    required Map<String, dynamic> profileB,
  }) async {
    try {
      final result = await _functions
          .httpsCallable(
            'generateJourneyStageInsight',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 55)),
          )
          .call(<String, dynamic>{
            'journeyId': journeyId,
            'stage': stage,
            'profileA': profileA,
            'profileB': profileB,
          });
      final data = result.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'SwanAiService.generateJourneyStageInsight: ${e.code} ${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('SwanAiService.generateJourneyStageInsight failed: $e');
      return null;
    }
  }
}
