/// Rule-based Marriage Readiness Assessment (no external AI APIs).
class MarriageReadinessReport {
  final Map<String, int> categoryStars; // 1–5
  final int overallPercent;
  final List<String> strengths;
  final List<String> areasToImprove;
  final List<String> suggestions;
  final DateTime generatedAt;

  const MarriageReadinessReport({
    required this.categoryStars,
    required this.overallPercent,
    required this.strengths,
    required this.areasToImprove,
    required this.suggestions,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() => {
        'categoryStars': categoryStars,
        'overallPercent': overallPercent,
        'strengths': strengths,
        'areasToImprove': areasToImprove,
        'suggestions': suggestions,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory MarriageReadinessReport.fromMap(Map<String, dynamic> map) {
    final starsRaw = map['categoryStars'];
    final stars = <String, int>{};
    if (starsRaw is Map) {
      starsRaw.forEach((k, v) {
        stars[k.toString()] = (v as num?)?.toInt() ?? 3;
      });
    }
    return MarriageReadinessReport(
      categoryStars: stars,
      overallPercent: (map['overallPercent'] as num?)?.toInt() ?? 0,
      strengths: List<String>.from(map['strengths'] ?? const []),
      areasToImprove: List<String>.from(map['areasToImprove'] ?? const []),
      suggestions: List<String>.from(map['suggestions'] ?? const []),
      generatedAt: DateTime.tryParse(map['generatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class MarriageReadinessService {
  MarriageReadinessService._();
  static final MarriageReadinessService instance = MarriageReadinessService._();

  static const categoryOrder = [
    'Family Values',
    'Communication',
    'Lifestyle',
    'Financial Planning',
    'Marriage Timeline',
    'Children Planning',
    'Long-Term Goals',
  ];

  MarriageReadinessReport assess(Map<String, dynamic> profile) {
    final mp = profile['marriageProfile'];
    final marriage = mp is Map ? Map<String, dynamic>.from(mp) : <String, dynamic>{};
    final intent = marriage['intent'] is Map
        ? Map<String, dynamic>.from(marriage['intent'] as Map)
        : <String, dynamic>{};
    final lifestyle = marriage['lifestyle'] is Map
        ? Map<String, dynamic>.from(marriage['lifestyle'] as Map)
        : <String, dynamic>{};
    final values = marriage['values'] is Map
        ? Map<String, dynamic>.from(marriage['values'] as Map)
        : <String, dynamic>{};

    String s(dynamic v) => (v ?? '').toString().trim();
    int familyImportance = (profile['familyValuesImportance'] as num?)?.toInt() ??
        (values['familyValuesImportance'] as num?)?.toInt() ??
        3;

    final lookingFor = s(profile['lookingFor'] ?? intent['lookingFor']).toLowerCase();
    final timeline = s(profile['marriageTimeline'] ?? intent['marriageTimeline']);
    final children = s(profile['childrenPreference'] ?? lifestyle['childrenPreference']);
    final financial = s(profile['financialStyle'] ?? lifestyle['financialStyle']);
    final decision = s(profile['decisionMakingStyle'] ?? lifestyle['decisionMakingStyle']);
    final communication = s(profile['communicationStyle']);
    final bio = s(profile['bio']);
    final income = s(profile['incomeRange'] ?? lifestyle['incomeRange']);
    final smoking = s(profile['smoking']);
    final drinking = s(profile['drinking']);
    final workout = s(profile['workout']);
    final traits = ((profile['personalityTraits'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final priorities = ((profile['rankedPartnerPriorities'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();

    int clampStars(int v) => v.clamp(1, 5);

    final familyStars = clampStars(familyImportance);
    final communicationStars = clampStars(
      (communication.isNotEmpty ? 4 : 2) +
          (traits.any((t) => t.toLowerCase().contains('communicat')) ? 1 : 0) +
          (priorities.isNotEmpty &&
                  priorities.first.toLowerCase().contains('communication')
              ? 1
              : 0) -
          1,
    );
    final lifestyleStars = clampStars(
      2 +
          (smoking.toLowerCase().contains('never') ||
                  smoking.toLowerCase().contains('no')
              ? 1
              : 0) +
          (drinking.isNotEmpty ? 1 : 0) +
          (workout.isNotEmpty ? 1 : 0),
    );
    final financialStars = clampStars(
      2 +
          (financial.isNotEmpty ? 1 : 0) +
          (income.isNotEmpty ? 1 : 0) +
          (decision.isNotEmpty ? 1 : 0),
    );
    final timelineStars = clampStars(
      timeline.isEmpty
          ? 2
          : timeline.toLowerCase().contains('flexible')
              ? 3
              : timeline.toLowerCase().contains('1')
                  ? 5
                  : 4,
    );
    final childrenStars = clampStars(children.isEmpty ? 2 : 4);
    final goalsStars = clampStars(
      2 +
          (lookingFor.contains('marriage') ? 2 : lookingFor.isNotEmpty ? 1 : 0) +
          (bio.length > 40 ? 1 : 0),
    );

    final stars = {
      'Family Values': familyStars,
      'Communication': communicationStars,
      'Lifestyle': lifestyleStars,
      'Financial Planning': financialStars,
      'Marriage Timeline': timelineStars,
      'Children Planning': childrenStars,
      'Long-Term Goals': goalsStars,
    };

    final avg = stars.values.reduce((a, b) => a + b) / stars.length;
    final overall = ((avg / 5) * 100).round().clamp(0, 100);

    final strengths = <String>[];
    final improve = <String>[];
    final suggestions = <String>[];

    stars.forEach((name, value) {
      if (value >= 4) {
        strengths.add('Strong foundation in $name');
      } else if (value <= 2) {
        improve.add('$name needs more clarity');
      }
    });

    if (strengths.isEmpty) {
      strengths.add('You have started a serious marriage assessment');
    }
    if (improve.isEmpty) {
      improve.add('Keep refining your partner priorities over time');
    }

    if (familyStars < 4) {
      suggestions.add('Reflect on how family involvement shapes your marriage vision.');
    }
    if (timeline.isEmpty) {
      suggestions.add('Set a clear marriage timeline so Swan can match compatible partners.');
    }
    if (children.isEmpty) {
      suggestions.add('Clarify your children preferences — this is a common dealbreaker.');
    }
    if (financial.isEmpty) {
      suggestions.add('Share your financial style to improve long-term compatibility.');
    }
    if (suggestions.isEmpty) {
      suggestions.add('Complete your Guided Relationship Journey with high-compatibility matches.');
    }

    return MarriageReadinessReport(
      categoryStars: stars,
      overallPercent: overall,
      strengths: strengths.take(4).toList(),
      areasToImprove: improve.take(4).toList(),
      suggestions: suggestions.take(4).toList(),
      generatedAt: DateTime.now(),
    );
  }
}
