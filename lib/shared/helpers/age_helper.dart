/// Default date shown in date-of-birth pickers: the day before the user's
/// 18th birthday cut-off, so the pre-filled value always passes the 18+ check
/// (a "365 * 18 days ago" default lands a few days short of 18 because of
/// leap years, and would reject a user who just taps Continue).
DateTime defaultAdultDob({DateTime? now}) {
  final DateTime today = now ?? DateTime.now();
  // Build from the calendar date (not a Duration), then step back one day so
  // Feb 29 and "birthday is today" edge cases are still 18+.
  return DateTime(today.year - 18, today.month, today.day)
      .subtract(const Duration(days: 1));
}
