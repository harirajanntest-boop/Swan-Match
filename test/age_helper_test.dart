import 'package:flutter_test/flutter_test.dart';
import 'package:swam_match_app/shared/helpers/age_helper.dart';

int ageOn(DateTime dob, DateTime today) {
  var age = today.year - dob.year;
  if (today.month < dob.month ||
      (today.month == dob.month && today.day < dob.day)) {
    age--;
  }
  return age;
}

void main() {
  test('default DOB is always 18 or older (every day across leap years)', () {
    var day = DateTime(2027, 1, 1);
    final end = DateTime(2033, 1, 1);
    while (day.isBefore(end)) {
      final dob = defaultAdultDob(now: day);
      expect(ageOn(dob, day), 18, reason: 'on $day got $dob');
      day = day.add(const Duration(days: 1));
    }
  });

  test('Feb 29 today still gives an 18+ default', () {
    final today = DateTime(2028, 2, 29);
    expect(ageOn(defaultAdultDob(now: today), today), greaterThanOrEqualTo(18));
  });

  test('old "365 * 18 days" default was under 18 (the bug)', () {
    final today = DateTime(2026, 9, 29);
    final old = today.subtract(const Duration(days: 365 * 18));
    expect(ageOn(old, today), 17);
  });
}
