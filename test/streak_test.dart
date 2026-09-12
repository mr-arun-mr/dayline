import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/event.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/model/streak.dart';
import 'package:test/test.dart';

void main() {
  const today = CalendarDate(2026, 9, 11);
  // Mid-morning, so a 07:00 event has already been and a 21:00 one has not.
  final now = DateTime(2026, 9, 11, 9, 0);

  Event event({
    Recurrence recurrence = Recurrence.daily,
    int timeOfDay = 7 * 60,
    int daysOfWeek = Weekdays.none,
    int interval = 1,
    CalendarDate? startDate,
  }) =>
      Event(
        id: 1,
        title: 'Gym',
        colorValue: 0xFF3B82F6,
        rule: EventRule(
          recurrence: recurrence,
          timeOfDay: timeOfDay,
          startDate: startDate ?? today.addDays(-100),
          daysOfWeek: daysOfWeek,
          interval: interval,
        ),
      );

  /// Marks the given day-offsets from today as done.
  Map<CalendarDate, CompletionStatus> done(List<int> offsets) => {
        for (final offset in offsets)
          today.addDays(offset): CompletionStatus.done,
      };

  Streak streakOf(
    Event e,
    Map<CalendarDate, CompletionStatus> completions, {
    DateTime? at,
  }) =>
      calculateStreak(event: e, completions: completions, now: at ?? now);

  group('counting back from the last elapsed occurrence', () {
    test('an unbroken run', () {
      final streak = streakOf(event(), done([0, -1, -2, -3, -4]));
      expect(streak.current, 5);
      expect(streak.longest, 5);
    });

    test('a miss ends the current run but not the record', () {
      // Done today and yesterday; missed the day before; six before that.
      final streak = streakOf(
        event(),
        done([0, -1, -3, -4, -5, -6, -7, -8]),
      );
      expect(streak.current, 2);
      expect(streak.longest, 6);
    });

    test('nothing done at all', () {
      final streak = streakOf(event(), {});
      expect(streak.current, 0);
      expect(streak.longest, 0);
      expect(streak.rate, 0);
    });
  });

  group('what today counts as', () {
    test("an event that has not happened yet does not break the streak", () {
      // A 21:00 event, checked at 09:00: today is simply not due.
      final evening = event(timeOfDay: 21 * 60);
      final streak = streakOf(evening, done([-1, -2, -3]));
      expect(streak.current, 3,
          reason: 'counting today as missed would zero every streak all day');
    });

    test('an event that has happened and was not done breaks it', () {
      final streak = streakOf(event(), done([-1, -2, -3]));
      expect(streak.current, 0);
      expect(streak.longest, 3);
    });
  });

  group('skips', () {
    test('are neutral: they neither extend nor break a run', () {
      final completions = {
        ...done([0, -1, -3, -4]),
        today.addDays(-2): CompletionStatus.skipped,
      };
      final streak = streakOf(event(), completions);
      expect(streak.current, 4, reason: 'the skipped day is stepped over');
      expect(streak.expectedCount, isNot(contains(today.addDays(-2))));
    });

    test('leave the completion rate alone', () {
      final completions = {
        ...done([0, -1]),
        today.addDays(-2): CompletionStatus.skipped,
      };
      final streak = calculateStreak(
        event: event(startDate: today.addDays(-2)),
        completions: completions,
        now: now,
      );
      expect(streak.completedCount, 2);
      expect(streak.expectedCount, 2, reason: 'the skip is not expected of you');
      expect(streak.rate, 1.0);
    });
  });

  group('rules that are not daily', () {
    test('weekly counts occurrences, not days', () {
      // Fridays only; today is a Friday.
      final weekly = event(
        recurrence: Recurrence.weekly,
        daysOfWeek: Weekdays.friday,
      );
      final streak = streakOf(weekly, done([0, -7, -14]));
      expect(streak.current, 3);
      // The days in between are not occurrences, so they cannot be misses.
      expect(streak.expectedCount, greaterThanOrEqualTo(3));
    });

    test('every three days likewise', () {
      final everyThird = event(
        recurrence: Recurrence.everyNDays,
        interval: 3,
        startDate: today.addDays(-30),
      );
      final streak = streakOf(everyThird, done([0, -3, -6]));
      expect(streak.current, 3);
    });

    test('a rule that has not started yet has no streak', () {
      final future = event(startDate: today.addDays(5));
      expect(streakOf(future, {}), isA<Streak>()
          .having((s) => s.current, 'current', 0)
          .having((s) => s.expectedCount, 'expected', 0));
    });
  });

  group('which rules get a streak at all', () {
    test('rhythmic ones do', () {
      expect(supportsStreaks(Recurrence.daily), isTrue);
      expect(supportsStreaks(Recurrence.weekly), isTrue);
      expect(supportsStreaks(Recurrence.everyNDays), isTrue);
    });

    test('a one-off and a monthly do not', () {
      // Nothing to keep up, and years before a monthly streak means anything.
      expect(supportsStreaks(Recurrence.once), isFalse);
      expect(supportsStreaks(Recurrence.monthly), isFalse);
    });
  });

  test('completion rate', () {
    final streak = calculateStreak(
      event: event(startDate: today.addDays(-4)),
      completions: done([0, -1, -3]),
      now: now,
    );
    expect(streak.completedCount, 3);
    expect(streak.expectedCount, 5);
    expect(streak.rate, closeTo(0.6, 0.001));
  });
}
