/// Canonical marriage dealbreaker IDs and display labels.
class DealbreakerCatalog {
  DealbreakerCatalog._();

  static const wantsChildren = 'wants_children';
  static const noChildren = 'no_children';
  static const sameReligion = 'same_religion';
  static const nonSmoker = 'non_smoker';
  static const nonDrinker = 'non_drinker';
  static const marriageWithin2Years = 'marriage_within_2_years';
  static const willingRelocate = 'willing_relocate';
  static const familyOriented = 'family_oriented';
  static const financiallyStable = 'financially_stable';
  static const activeLifestyle = 'active_lifestyle';

  static const List<String> allIds = [
    wantsChildren,
    noChildren,
    sameReligion,
    nonSmoker,
    nonDrinker,
    marriageWithin2Years,
    willingRelocate,
    familyOriented,
    financiallyStable,
    activeLifestyle,
  ];

  static const Map<String, String> labels = {
    wantsChildren: 'Wants children',
    noChildren: "Doesn't want children",
    sameReligion: 'Same religion only',
    nonSmoker: 'Non-smoker',
    nonDrinker: 'Non-drinker',
    marriageWithin2Years: 'Marriage within 2 years',
    willingRelocate: 'Willing to relocate',
    familyOriented: 'Family-oriented',
    financiallyStable: 'Financially stable',
    activeLifestyle: 'Active lifestyle',
  };

  static String labelFor(String id) => labels[id] ?? id;
}

/// Hard-constraint matching: every selected dealbreaker on [myDealbreakers]
/// must be satisfied by [candidate] (and optionally [myProfile] for religion).
class DealbreakerMatcher {
  DealbreakerMatcher._();

  static bool satisfies({
    required List<String> myDealbreakers,
    required Map<String, dynamic> candidate,
    Map<String, dynamic>? myProfile,
  }) {
    if (myDealbreakers.isEmpty) return true;

    for (final id in myDealbreakers) {
      if (!_satisfiesOne(id, candidate, myProfile)) return false;
    }
    return true;
  }

  static bool _satisfiesOne(
    String id,
    Map<String, dynamic> candidate,
    Map<String, dynamic>? myProfile,
  ) {
    final mp = candidate['marriageProfile'];
    final marriage = mp is Map ? Map<String, dynamic>.from(mp) : const <String, dynamic>{};
    final intent = marriage['intent'] is Map
        ? Map<String, dynamic>.from(marriage['intent'] as Map)
        : const <String, dynamic>{};
    final lifestyle = marriage['lifestyle'] is Map
        ? Map<String, dynamic>.from(marriage['lifestyle'] as Map)
        : const <String, dynamic>{};

    String str(dynamic v) => (v ?? '').toString().trim().toLowerCase();

    final children = str(
      candidate['childrenPreference'] ??
          lifestyle['childrenPreference'] ??
          intent['childrenPreference'],
    );
    final smoking = str(candidate['smoking'] ?? lifestyle['smoking']);
    final drinking = str(candidate['drinking'] ?? lifestyle['drinking']);
    final timeline = str(
      candidate['marriageTimeline'] ?? intent['marriageTimeline'],
    );
    final relocate = str(
      candidate['relocatePreference'] ??
          lifestyle['relocatePreference'] ??
          (candidate['willingToRelocate'] == true ? 'yes' : ''),
    );
    final religion = str(candidate['religion']);
    final myReligion = str(myProfile?['religion']);
    final familyValues = (candidate['familyValuesImportance'] as num?)?.toInt() ??
        (marriage['values'] is Map
            ? ((marriage['values'] as Map)['familyValuesImportance'] as num?)
                ?.toInt()
            : null) ??
        0;
    final income = str(candidate['incomeRange'] ?? lifestyle['incomeRange']);
    final tags = <String>[
      ...((candidate['lifestyleTags'] as List?) ?? const [])
          .map((e) => e.toString().toLowerCase()),
      ...((lifestyle['lifestyleTags'] as List?) ?? const [])
          .map((e) => e.toString().toLowerCase()),
      ...((candidate['interests'] as List?) ?? const [])
          .map((e) => e.toString().toLowerCase()),
    ];
    final workout = str(candidate['workout']);

    switch (id) {
      case DealbreakerCatalog.wantsChildren:
        return children.contains('yes') ||
            children.contains('want') ||
            children == 'undecided';
      case DealbreakerCatalog.noChildren:
        return children.contains('no') ||
            children.contains("doesn't") ||
            children.contains('do not');
      case DealbreakerCatalog.sameReligion:
        if (myReligion.isEmpty || religion.isEmpty) return true;
        return religion == myReligion;
      case DealbreakerCatalog.nonSmoker:
        return smoking.isEmpty ||
            smoking.contains('never') ||
            smoking.contains('no') ||
            smoking == 'non-smoker' ||
            smoking == 'nonsmoker';
      case DealbreakerCatalog.nonDrinker:
        return drinking.isEmpty ||
            drinking.contains('never') ||
            drinking.contains('no') ||
            drinking == 'non-drinker' ||
            drinking == 'nondrinker';
      case DealbreakerCatalog.marriageWithin2Years:
        return timeline.contains('1 year') ||
            timeline.contains('within 1') ||
            timeline.contains('1–2') ||
            timeline.contains('1-2') ||
            timeline.contains('2 year') ||
            timeline.contains('soon');
      case DealbreakerCatalog.willingRelocate:
        return relocate.contains('yes') ||
            relocate.contains('depend') ||
            candidate['willingToRelocate'] == true;
      case DealbreakerCatalog.familyOriented:
        return familyValues >= 4 ||
            tags.any((t) => t.contains('family'));
      case DealbreakerCatalog.financiallyStable:
        if (income.isEmpty) return true;
        return !income.contains('prefer not') && income != '0';
      case DealbreakerCatalog.activeLifestyle:
        return workout.contains('often') ||
            workout.contains('regular') ||
            workout.contains('active') ||
            workout.contains('daily') ||
            tags.any((t) =>
                t.contains('fitness') ||
                t.contains('sport') ||
                t.contains('active') ||
                t.contains('gym'));
      default:
        return true;
    }
  }
}
