import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/day_summary.dart';
import 'package:dayline/src/model/event.dart';
import 'package:dayline/src/model/occurrence.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:test/test.dart';

void main() {
  const date = CalendarDate(2026, 9, 11);
  final now = DateTime(2026, 9, 11, 8, 42);

  var nextId = 1;
  Occurrence occurrence(
    String title,
    int timeOfDay, {
    CompletionStatus? status,
  }) {
    final id = nextId++;
    return Occurrence(
      event: Event(
        id: id,
        title: title,
        colorValue: 0xFF3B82F6,
        rule: EventRule(
          recurrence: Recurrence.daily,
          timeOfDay: timeOfDay,
          startDate: date.addDays(-10),
        ),
      ),
      date: date,
      effectiveTimeOfDay: timeOfDay,
      status: status,
    );
  }

  setUp(() => nextId = 1);

  DaySummary summarise(List<Occurrence> list, {bool isToday = true}) =>
      DaySummary.from(occurrences: list, now: now, isToday: isToday);

  group('sectioning today', () {
    test('splits around now, with exactly one next up', () {
      final summary = summarise([
        occurrence('Gym', 7 * 60),
        occurrence('Water plants', 8 * 60),
        occurrence('Standup', 9 * 60 + 30),
        occurrence('Physio', 13 * 60),
        occurrence('Medication', 21 * 60),
      ]);

      expect(summary.overdue.map((o) => o.event.title),
          ['Gym', 'Water plants']);
      expect(summary.nextUp?.event.title, 'Standup');
      expect(summary.later.map((o) => o.event.title), ['Physio', 'Medication']);
      expect(summary.done, isEmpty);
    });

    test('anything dealt with leaves the timeline entirely', () {
      final summary = summarise([
        occurrence('Gym', 7 * 60, status: CompletionStatus.done),
        occurrence('Water plants', 8 * 60),
        occurrence('Standup', 9 * 60 + 30, status: CompletionStatus.skipped),
        occurrence('Physio', 13 * 60),
      ]);

      expect(summary.overdue.map((o) => o.event.title), ['Water plants']);
      expect(summary.nextUp?.event.title, 'Physio',
          reason: 'a skipped occurrence cannot be next up');
      expect(summary.done.map((o) => o.event.title), ['Gym', 'Standup']);
    });

    test('a finished day has no next up and no overdue', () {
      final summary = summarise([
        occurrence('Gym', 7 * 60, status: CompletionStatus.done),
        occurrence('Standup', 9 * 60, status: CompletionStatus.done),
      ]);

      expect(summary.nextUp, isNull);
      expect(summary.overdue, isEmpty);
      expect(summary.isComplete, isTrue);
    });

    test('an entirely untouched past day is all overdue', () {
      final summary = summarise([
        occurrence('Gym', 7 * 60),
        occurrence('Water plants', 8 * 60),
      ]);

      expect(summary.overdue, hasLength(2));
      expect(summary.nextUp, isNull);
    });
  });

  group('sectioning any other day', () {
    test('nothing is overdue, because there is no now to be late against', () {
      final summary = summarise([
        occurrence('Gym', 7 * 60),
        occurrence('Standup', 9 * 60 + 30),
      ], isToday: false);

      expect(summary.overdue, isEmpty);
      expect(summary.nextUp, isNull);
      expect(summary.later, hasLength(2));
      expect(summary.showsNowDivider, isFalse);
    });

    test('the now line needs something behind it', () {
      // Nothing overdue means the boundary is the top of the list.
      final summary = summarise([occurrence('Physio', 13 * 60)]);
      expect(summary.showsNowDivider, isFalse);

      final withPast = summarise([
        occurrence('Gym', 7 * 60),
        occurrence('Physio', 13 * 60),
      ]);
      expect(withPast.showsNowDivider, isTrue);
    });

    test('but a marked occurrence is still shown as done', () {
      final summary = summarise([
        occurrence('Gym', 7 * 60, status: CompletionStatus.done),
      ], isToday: false);

      expect(summary.done, hasLength(1));
      expect(summary.later, isEmpty);
    });
  });

  group('progress', () {
    test('counts what was done against what was expected', () {
      final summary = summarise([
        occurrence('A', 6 * 60, status: CompletionStatus.done),
        occurrence('B', 7 * 60, status: CompletionStatus.done),
        occurrence('C', 8 * 60, status: CompletionStatus.done),
        occurrence('D', 13 * 60),
        occurrence('E', 14 * 60),
        occurrence('F', 15 * 60),
      ]);

      expect(summary.progressLabel, '3 of 6 done');
      expect(summary.progress, closeTo(0.5, 0.001));
      expect(summary.isComplete, isFalse);
    });

    test('a skipped occurrence leaves the denominator', () {
      // Deciding something is not happening today should not read as failure.
      final summary = summarise([
        occurrence('A', 6 * 60, status: CompletionStatus.done),
        occurrence('B', 7 * 60, status: CompletionStatus.skipped),
        occurrence('C', 8 * 60),
      ]);

      expect(summary.progressLabel, '1 of 2 done');
      expect(summary.total, 3);
      expect(summary.expected, 2);
    });

    test('a day that is entirely skipped says so rather than reading 0 of 0',
        () {
      final summary = summarise([
        occurrence('A', 7 * 60, status: CompletionStatus.skipped),
      ]);

      expect(summary.progressLabel, 'All skipped');
      expect(summary.progress, 0);
      expect(summary.isComplete, isFalse);
    });

    test('an empty day', () {
      final summary = summarise([]);
      expect(summary.isEmpty, isTrue);
      expect(summary.progressLabel, 'Nothing scheduled');
      expect(summary.showsNowDivider, isFalse);
    });

    test('everything done, including alongside a skip', () {
      final summary = summarise([
        occurrence('A', 6 * 60, status: CompletionStatus.done),
        occurrence('B', 7 * 60, status: CompletionStatus.skipped),
      ]);

      expect(summary.isComplete, isTrue);
      expect(summary.progressLabel, '1 of 1 done');
    });
  });
}
