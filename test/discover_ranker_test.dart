// ignore_for_file: avoid_print
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:swam_match_app/models/user_model.dart';
import 'package:swam_match_app/shared/helpers/discover_ranker.dart';

final now = DateTime(2026, 9, 28, 10);
DateTime daysAgo(int d) => now.subtract(Duration(days: d));

UserModel person(
  String name, {
  String gender = 'Woman',
  int age = 26,
  String lookingFor = 'Marriage',
  List<String> interests = const [],
  String religion = '',
  String city = '',
  String country = 'India',
  String language = '',
  int joinedDaysAgo = 60,
}) =>
    UserModel(
      uid: name.toLowerCase(),
      firstName: name,
      gender: gender,
      age: age,
      lookingFor: lookingFor,
      interests: interests,
      religion: religion,
      city: city,
      country: country,
      primaryLanguage: language,
      createdAt: daysAgo(joinedDaysAgo),
      updatedAt: daysAgo(joinedDaysAgo),
    );

final me = UserModel(
  uid: 'me',
  firstName: 'Arjun',
  gender: 'Man',
  age: 28,
  lookingFor: 'Marriage',
  minAgePreference: 24,
  maxAgePreference: 30,
  interests: const ['Travel', 'Music', 'Cooking'],
  religion: 'Hindu',
  city: 'Chennai',
  country: 'India',
  primaryLanguage: 'Tamil',
  createdAt: daysAgo(100),
  updatedAt: daysAgo(100),
);

// 12 candidates who already passed the hard filters (opposite gender,
// approved, age range…): a mix of strong / medium / weak, old and new.
final candidates = [
  person('Priya', interests: ['Travel', 'Music', 'Cooking'], religion: 'Hindu', city: 'Chennai', language: 'Tamil'),
  person('Divya', age: 25, interests: ['Travel', 'Music'], religion: 'Hindu', city: 'Bangalore', language: 'Tamil'),
  person('Meera', age: 27, interests: ['Music', 'Cooking'], religion: 'Hindu', city: 'Chennai', language: 'Tamil', joinedDaysAgo: 1),
  person('Lakshmi', age: 29, interests: ['Cooking'], religion: 'Hindu', city: 'Madurai', language: 'Tamil'),
  person('Anu', age: 29, interests: ['Dance'], religion: 'Christian', city: 'Mumbai', language: 'Hindi'),
  person('Riya', age: 24, interests: ['Travel'], religion: 'Sikh', city: 'Delhi', language: 'Hindi', joinedDaysAgo: 3),
  person('Nisha', age: 30, interests: ['Reading'], religion: 'Muslim', city: 'Hyderabad', language: 'Urdu'),
  person('Pooja', age: 26, interests: ['Yoga'], religion: 'Jain', city: 'Ahmedabad', language: 'Gujarati'),
  person('Sara', age: 31, lookingFor: 'Casual', interests: ['Gaming'], religion: 'Christian', city: 'London', country: 'UK', language: 'English', joinedDaysAgo: 2),
  person('Kavya', age: 33, lookingFor: 'Casual', interests: ['Gaming'], religion: 'Buddhist', city: 'Kathmandu', country: 'Nepal', language: 'Nepali'),
  person('Tara', age: 32, lookingFor: 'Casual', interests: ['Hiking'], city: 'Dubai', country: 'UAE', language: 'Arabic', joinedDaysAgo: 5),
  person('Zoya', age: 34, lookingFor: 'Friendship', interests: ['Gaming'], city: 'Paris', country: 'France', language: 'French'),
];

int score(UserModel u) => DiscoverRanker.compatibilityScore(me, u);

/// The OLD pipeline: rank by score → then shuffle new (≤7 days) profiles
/// first and everyone else after (random per app open) → free users keep 10.
List<UserModel> oldOrder(int sessionSeed, {bool free = false}) {
  final ranked = [...candidates]..sort((a, b) => score(b).compareTo(score(a)));
  final rng = Random(sessionSeed);
  final cutoff = now.subtract(const Duration(days: 7));
  final fresh = ranked.where((u) => u.createdAt.isAfter(cutoff)).toList()..shuffle(rng);
  final rest = ranked.where((u) => !u.createdAt.isAfter(cutoff)).toList()..shuffle(rng);
  final ordered = [...fresh, ...rest];
  return free ? ordered.take(10).toList() : ordered;
}

String line(List<UserModel> l, [int n = 6]) =>
    l.take(n).map((u) => '${u.firstName}(${score(u)})').join(' → ');

void main() {
  test('Discover order: BEFORE vs AFTER', () {
    print('\nCompatibility scores (0-100) for Arjun:');
    for (final u in [...candidates]..sort((a, b) => score(b).compareTo(score(a)))) {
      final isNew = u.createdAt.isAfter(now.subtract(const Duration(days: 7)));
      print('  ${u.firstName.padRight(8)} ${score(u).toString().padLeft(3)}${isNew ? '  (new)' : ''}');
    }

    print('\nBEFORE — first 6 cards on three different app opens:');
    for (final seed in [1, 2, 3]) {
      print('  open $seed: ${line(oldOrder(seed))}');
    }
    final after = DiscoverRanker.rank(candidates, me, now: now);
    print('\nAFTER — first 6 cards (same on every open today):');
    for (var i = 1; i <= 3; i++) {
      print('  open $i: ${line(DiscoverRanker.rank(candidates, me, now: now))}');
    }
    print('  tomorrow: ${line(DiscoverRanker.rank(candidates, me, now: now.add(const Duration(days: 1))))}');

    // Before: a weak new profile is always ahead of the best old match.
    expect(oldOrder(1).first.lookingFor == 'Marriage' && score(oldOrder(1).first) >= 70, isFalse,
        reason: 'old order puts new (possibly weak) profiles first');
    // After: best matches lead; stable within a day; weak ones sink.
    expect(after.take(3).map((u) => u.firstName).toSet(), {'Priya', 'Meera', 'Divya'});
    expect(DiscoverRanker.rank(candidates, me, now: now).map((u) => u.uid).toList(),
        after.map((u) => u.uid).toList());
    final weakNew = after.indexWhere((u) => u.firstName == 'Sara');
    expect(weakNew, greaterThan(7), reason: 'a weak new profile no longer jumps the queue');
  });

  test('Free user deck: BEFORE vs AFTER (skipped profiles hidden)', () {
    // The user skipped 6 profiles earlier this week (hidden for 7 days).
    final skipped = {'priya', 'divya', 'meera', 'lakshmi', 'anu', 'riya'};

    final beforeDeck = oldOrder(7, free: true).where((u) => !skipped.contains(u.uid)).toList();
    final afterDeck = DiscoverRanker.rank(candidates, me, now: now).where((u) => !skipped.contains(u.uid)).toList();
    final available = candidates.where((u) => !skipped.contains(u.uid)).length;

    print('\nFree user, 6 profiles skipped, $available still available:');
    print('  BEFORE: ${beforeDeck.length} cards (${line(beforeDeck, 10)})');
    print('  AFTER : ${afterDeck.length} cards (${line(afterDeck, 10)})');
    print('  (daily limit still enforced by the swipe counter: 3/day free, 5/day trial)');

    expect(afterDeck.length, available, reason: 'no profiles lost to the old 10-cut');
    expect(beforeDeck.length, lessThanOrEqualTo(available));
  });
}
