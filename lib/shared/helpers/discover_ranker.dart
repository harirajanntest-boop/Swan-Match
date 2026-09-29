import '../../models/user_model.dart';

/// Orders the Discover feed best-match-first.
///
/// Order key = compatibility score (0–100)
///           + [newProfileBonus] for profiles that joined in the last 7 days
///           + a small jitter (0–[maxJitter]) so near-equal matches rotate.
///
/// The jitter is derived from (viewer, day, candidate), so the order is stable
/// for the whole day — reopening the app doesn't reshuffle the deck — but
/// changes from one day to the next and differs between viewers.
///
/// Replaces the previous ordering, which computed the score, then shuffled
/// every profile randomly (discarding it) and put all new profiles first.
class DiscoverRanker {
  DiscoverRanker._();

  static const double newProfileBonus = 8;
  static const Duration newProfileWindow = Duration(days: 7);
  static const double maxJitter = 5;

  static List<UserModel> rank(
    List<UserModel> candidates,
    UserModel me, {
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final day = '${t.year}-${t.month}-${t.day}';
    final cutoff = t.subtract(newProfileWindow);
    final keyed = [
      for (final u in candidates)
        (
          user: u,
          key: compatibilityScore(me, u) +
              (u.createdAt.isAfter(cutoff) ? newProfileBonus : 0) +
              _jitter('${me.uid}|$day|${u.uid}'),
        ),
    ]..sort((a, b) => b.key.compareTo(a.key));
    return [for (final k in keyed) k.user];
  }

  /// Weighted compatibility score (0–100) between the signed-in user (`me`)
  /// and `other`. Weights total 100 and reflect what matters for serious
  /// relationships.
  static int compatibilityScore(UserModel me, UserModel other) {
    String norm(String s) => s.trim().toLowerCase();
    double score = 0;

    // 1. Relationship goal — 25
    if (me.lookingFor.isNotEmpty && other.lookingFor.isNotEmpty) {
      score += norm(me.lookingFor) == norm(other.lookingFor) ? 25 : 25 * 0.4;
    }

    // 2. Age fit — 20 (full inside my preferred range, partial within 3 years)
    final otherAge = other.age > 0
        ? other.age
        : (other.dateOfBirth != null
            ? DateTime.now().year - other.dateOfBirth!.year
            : 0);
    if (otherAge > 0) {
      if (otherAge >= me.minAgePreference && otherAge <= me.maxAgePreference) {
        score += 20;
      } else {
        final gap = otherAge < me.minAgePreference
            ? me.minAgePreference - otherAge
            : otherAge - me.maxAgePreference;
        if (gap <= 3) score += 20 * (1 - gap / 3) * 0.7;
      }
    }

    // 3. Shared interests — 18 (overlap ratio)
    final mine = me.interests.map(norm).toSet();
    final theirs = other.interests.map(norm).toSet();
    if (mine.isNotEmpty && theirs.isNotEmpty) {
      final shared = mine.intersection(theirs).length;
      final union = mine.union(theirs).length;
      if (union > 0) score += 18 * (shared / union);
    }

    // 4. Religion / community — 12
    if (me.religion.isNotEmpty &&
        other.religion.isNotEmpty &&
        norm(me.religion) == norm(other.religion)) {
      score += 12;
    }

    // 5. Location — 10 (same city full, same country partial)
    if (me.city.isNotEmpty && norm(me.city) == norm(other.city)) {
      score += 10;
    } else if (me.country.isNotEmpty &&
        norm(me.country) == norm(other.country)) {
      score += 10 * 0.4;
    }

    // 6. Language — 8 (any shared primary/other language)
    final myLangs = {norm(me.primaryLanguage), ...me.otherLanguages.map(norm)}
      ..removeWhere((e) => e.isEmpty);
    final theirLangs = {
      norm(other.primaryLanguage),
      ...other.otherLanguages.map(norm),
    }..removeWhere((e) => e.isEmpty);
    if (myLangs.isNotEmpty &&
        theirLangs.isNotEmpty &&
        myLangs.intersection(theirLangs).isNotEmpty) {
      score += 8;
    }

    // 7. Lifestyle — 7 (smoking + drinking + workout + family-values closeness)
    double sub = 0;
    int parts = 0;
    for (final pair in [
      [me.smoking, other.smoking],
      [me.drinking, other.drinking],
      [me.workout, other.workout],
    ]) {
      if (pair[0].isNotEmpty && pair[1].isNotEmpty) {
        parts++;
        if (norm(pair[0]) == norm(pair[1])) sub += 1;
      }
    }
    parts++;
    sub += (1 -
            (me.familyValuesImportance - other.familyValuesImportance).abs() /
                5)
        .clamp(0.0, 1.0);
    if (parts > 0) score += 7 * (sub / parts);

    return score.clamp(0, 100).round();
  }

  /// Deterministic 0–[maxJitter] value (FNV-1a hash — String.hashCode is not
  /// guaranteed stable across app runs).
  static double _jitter(String key) {
    var h = 0x811c9dc5;
    for (final c in key.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h / 0xffffffff * maxJitter;
  }
}
