import 'calendar_date.dart';
import 'event.dart';
import 'recurrence.dart';

/// How consistently a rule has actually been kept.
class Streak {
  const Streak({
    required this.current,
    required this.longest,
    required this.completedCount,
    required this.expectedCount,
  });

  static const none =
      Streak(current: 0, longest: 0, completedCount: 0, expectedCount: 0);

  /// Consecutive occurrences done, counting back from the most recent one that
  /// has already happened.
  final int current;

  /// The best run ever managed.
  final int longest;

  final int completedCount;

  /// Occurrences that have come and gone, skips excluded.
  final int expectedCount;

  double get rate => expectedCount == 0 ? 0 : completedCount / expectedCount;
}

/// Walks a rule's past occurrences and works out its streaks.
///
/// Only days that have already happened count. Today's gym is not a broken
/// streak at nine in the morning, and counting it as one would make every
/// streak read zero for most of the day.
///
/// A skipped occurrence is neutral: it neither extends a streak nor breaks it.
/// Skipping is the user saying "not today", and punishing that teaches them to
/// leave things pending instead, which loses the information entirely.
Streak calculateStreak({
  required Event event,
  required Map<CalendarDate, CompletionStatus> completions,
  required DateTime now,
  Set<CalendarDate> skippedDates = const {},
  int lookBackDays = 400,
}) {
  final today = CalendarDate.fromDateTime(now);
  final rule = event.rule;

  // The last occurrence whose time has passed. Everything at or before this is
  // fair game; everything after it is simply not due yet.
  final cutoff = _lastElapsedOccurrence(event, now, lookBackDays);
  if (cutoff == null) return Streak.none;

  final earliest = rule.startDate.isAfter(today.addDays(-lookBackDays))
      ? rule.startDate
      : today.addDays(-lookBackDays);

  var current = 0;
  var longest = 0;
  var run = 0;
  var completed = 0;
  var expected = 0;
  var currentRunOpen = true;

  for (var day = cutoff.epochDay; day >= earliest.epochDay; day--) {
    final date = CalendarDate.fromEpochDay(day);
    if (!rule.occursOn(date)) continue;
    if (skippedDates.contains(date)) continue;

    final status = completions[date];
    if (status == CompletionStatus.skipped) continue;

    expected++;
    if (status == CompletionStatus.done) {
      completed++;
      run++;
      if (run > longest) longest = run;
      if (currentRunOpen) current = run;
    } else {
      // A miss ends the run that reaches back from today.
      currentRunOpen = false;
      run = 0;
    }
  }

  return Streak(
    current: current,
    longest: longest,
    completedCount: completed,
    expectedCount: expected,
  );
}

/// The most recent occurrence whose wall-clock time is already behind us.
CalendarDate? _lastElapsedOccurrence(
  Event event,
  DateTime now,
  int lookBackDays,
) {
  final today = CalendarDate.fromDateTime(now);
  final rule = event.rule;
  final floor = today.addDays(-lookBackDays);

  for (var day = today.epochDay; day >= floor.epochDay; day--) {
    final date = CalendarDate.fromEpochDay(day);
    if (!rule.occursOn(date)) continue;
    if (date.localDateTimeAt(rule.timeOfDay).isAfter(now)) continue;
    return date;
  }
  return null;
}

/// Whether a streak is worth showing at all.
///
/// A one-off has no rhythm to keep, and a monthly rule needs years before a
/// streak means anything, so neither gets one.
bool supportsStreaks(Recurrence recurrence) => switch (recurrence) {
  Recurrence.daily || Recurrence.weekly || Recurrence.everyNDays => true,
  Recurrence.once || Recurrence.monthly => false,
};
