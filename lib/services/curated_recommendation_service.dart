import '../../../../models/user_model.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/helpers/dealbreaker_matcher.dart';
import '../../../../shared/helpers/profile_visibility_helper.dart';

class CuratedRecommendation {
  final UserModel user;
  final int score;
  final List<String> reasons;

  const CuratedRecommendation({
    required this.user,
    required this.score,
    required this.reasons,
  });
}

/// Picks 3–5 highly compatible marriage recommendations from Discover candidates.
class CuratedRecommendationService {
  CuratedRecommendationService._();
  static final CuratedRecommendationService instance =
      CuratedRecommendationService._();

  static const double _minProfileCompletion = 0.6;

  List<CuratedRecommendation> buildToday({
    required UserModel me,
    required List<UserModel> candidates,
    int limit = 5,
    Set<String> excludeUserIds = const {},
  }) {
    final scored = <CuratedRecommendation>[];
    final targetGenders = _targetGenders(me);

    for (final other in candidates) {
      if (other.uid == me.uid) continue;
      if (excludeUserIds.contains(other.uid)) continue;

      final map = other.toMap();

      // Same Discover gates: admin-approved + intro video approved + public + not paused.
      if (!ProfileVisibilityHelper.isDiscoverVisible(map)) continue;

      final completion =
          UserService.instance.calculateProfileCompletion(map);
      if (completion < _minProfileCompletion) continue;

      // Never recommend same-gender when looking for the opposite gender.
      final theirGender = _normalizeGender(other.gender);
      if (targetGenders.isNotEmpty && !targetGenders.contains(theirGender)) {
        continue;
      }

      final intent = (map['intentStatus'] ?? '').toString();
      if (intent == 'taking_break' || intent == 'pause_matching') continue;

      if (me.dealbreakers.isNotEmpty &&
          !DealbreakerMatcher.satisfies(
            myDealbreakers: me.dealbreakers,
            candidate: map,
            myProfile: me.toMap(),
          )) {
        continue;
      }

      final score = _score(me, other);
      if (score < 45) continue;
      scored.add(
        CuratedRecommendation(
          user: other,
          score: score,
          reasons: _reasons(me, other),
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final takeCount = limit < 1 ? 3 : limit;
    return scored.take(takeCount).toList();
  }

  String _normalizeGender(String raw) {
    final g = raw.trim().toLowerCase();
    if (g == 'male' || g == 'man' || g == 'm') return 'male';
    if (g == 'female' || g == 'woman' || g == 'f') return 'female';
    return g;
  }

  /// Preferred partner genders for [me], from partnerPreference or own gender.
  Set<String> _targetGenders(UserModel me) {
    final pref = me.partnerPreference.trim().toLowerCase();
    if (pref.contains('woman') || pref.contains('female')) {
      return {'female'};
    }
    if (pref.contains('man') || pref.contains('male')) {
      return {'male'};
    }

    final myGender = _normalizeGender(me.gender);
    if (myGender == 'male') return {'female'};
    if (myGender == 'female') return {'male'};
    return const {};
  }

  int _score(UserModel me, UserModel other) {
    String n(String s) => s.trim().toLowerCase();
    double score = 0;

    if (me.lookingFor.isNotEmpty && other.lookingFor.isNotEmpty) {
      score += n(me.lookingFor) == n(other.lookingFor) ? 22 : 8;
    }
    if (me.religion.isNotEmpty && other.religion.isNotEmpty) {
      score += n(me.religion) == n(other.religion) ? 16 : 4;
    }
    final age = other.age;
    if (age > 0 &&
        age >= me.minAgePreference &&
        age <= me.maxAgePreference) {
      score += 16;
    }
    final mine = me.interests.map(n).toSet();
    final theirs = other.interests.map(n).toSet();
    if (mine.isNotEmpty && theirs.isNotEmpty) {
      final overlap = mine.intersection(theirs).length;
      score += (overlap / mine.length * 18).clamp(0, 18);
    }
    if (me.lifestyleTags.isNotEmpty && other.lifestyleTags.isNotEmpty) {
      final a = me.lifestyleTags.map(n).toSet();
      final b = other.lifestyleTags.map(n).toSet();
      score += (a.intersection(b).length / a.length * 14).clamp(0, 14);
    }
    final mpA = me.marriageProfile ?? {};
    final mpB = other.marriageProfile ?? {};
    final intentA = mpA['intent'] is Map ? mpA['intent'] as Map : {};
    final intentB = mpB['intent'] is Map ? mpB['intent'] as Map : {};
    final tA = (intentA['marriageTimeline'] ?? me.toMap()['marriageTimeline'] ?? '')
        .toString();
    final tB = (intentB['marriageTimeline'] ?? other.toMap()['marriageTimeline'] ?? '')
        .toString();
    if (tA.isNotEmpty && tB.isNotEmpty) {
      score += n(tA) == n(tB) ? 14 : 6;
    }
    return score.round().clamp(0, 100);
  }

  List<String> _reasons(UserModel me, UserModel other) {
    String n(String s) => s.trim().toLowerCase();
    final reasons = <String>[];

    if (me.lookingFor.isNotEmpty &&
        n(me.lookingFor) == n(other.lookingFor)) {
      reasons.add('Shared long-term goals');
    }

    final mpA = me.marriageProfile ?? {};
    final mpB = other.marriageProfile ?? {};
    final intentA = mpA['intent'] is Map ? mpA['intent'] as Map : {};
    final intentB = mpB['intent'] is Map ? mpB['intent'] as Map : {};
    final tA = (intentA['marriageTimeline'] ?? '').toString();
    final tB = (intentB['marriageTimeline'] ?? '').toString();
    if (tA.isNotEmpty && n(tA) == n(tB)) {
      reasons.add('Same marriage timeline');
    }

    if (me.religion.isNotEmpty && n(me.religion) == n(other.religion)) {
      reasons.add('Aligned cultural / faith values');
    }

    if ((me.familyValuesImportance) >= 4 &&
        (other.familyValuesImportance) >= 4) {
      reasons.add('Similar family values');
    }

    final a = me.lifestyleTags.map(n).toSet();
    final b = other.lifestyleTags.map(n).toSet();
    if (a.isNotEmpty && a.intersection(b).isNotEmpty) {
      reasons.add('Compatible lifestyle');
    }

    if (reasons.isEmpty) {
      reasons.add('Strong overall marriage compatibility');
    }
    return reasons.take(4).toList();
  }
}
