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

  /// A row the app wrote itself to record a stay, rather than one the user
  /// planned.
  Occurrence stay(String place, int arrivedAt) {
    final id = nextId++;
    return Occurrence(
      event: Event(
        id: id,
        title: place,
        colorValue: 0xFF10B981,
        rule: EventRule(
          recurrence: Recurrence.once,
          timeOfDay: arrivedAt,
          startDate: date,
        ),
        fromVisitId: id,
      ),
      date: date,
      effectiveTimeOfDay: arrivedAt,
      status: CompletionStatus.done,
      isAutomatic: true,
    );
  }

  setUp(() => nextId = 1);

  DaySummary summarise(List<Occurrence> list,
          {bool isToday = true, DateTime? at}) =>
      DaySummary.from(occurrences: list, now: at ?? now, isToday: isToday);

  // Looked at the evening before, so everything on [date] is still to come.
  final dayBefore = DateTime(2026, 9, 10, 20);

  group('the day in one line', () {
    test('splits around now, with exactly one next up', () {
      final summary = summarise([
        occurrence('Gym', 7 * 60),
        occurrence('Water plants', 8 * 60),
        occurrence('Standup', 9 * 60 + 30),
        occurrence('Physio', 13 * 60),
        occurrence('Medication', 21 * 60),
      ]);

      expect(summary.earlier.map((o) => o.event.title),
          ['Gym', 'Water plants']);
      expect(summary.nextUp?.event.title, 'Standup');
      expect(summary.later.map((o) => o.event.title), ['Physio', 'Medication']);
      expect(summary.done, isEmpty);
    });

    test('anything dealt with keeps its place in the day', () {
      // The whole point: a finished thing is still part of the day, in the
      // order it happened, rather than swept into a pile at the bottom.
      final summary = summarise([
        occurrence('Gym', 7 * 60, status: CompletionStatus.done),
        occurrence('Water plants', 8 * 60),
        occurrence('Standup', 9 * 60 + 30, status: CompletionStatus.skipped),
        occurrence('Physio', 13 * 60),
      ]);

      expect(summary.earlier.map((o) => o.event.title),
          ['Gym', 'Water plants']);
      expect(summary.later.map((o) => o.event.title), ['Standup']);
      expect(summary.nextUp?.event.title, 'Physio',
          reason: 'a skipped occurrence cannot be next up');
      expect(summary.done.map((o) => o.event.title), ['Gym', 'Standup'],
          reason: 'these are the ones the day list can be asked to hide');
    });

    test('only what is still pending counts as overdue', () {
      final summary = summarise([
        occurrence('Gym', 7 * 60, status: CompletionStatus.done),
        occurrence('Water plants', 8 * 60),
      ]);

      expect(summary.earlier, hasLength(2));
      expect(summary.overdue.map((o) => o.event.title), ['Water plants']);
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

  group('somewhere you went', () {
    test('is on the day, but is not a plan and is never hidden', () {
      final summary = summarise([
        occurrence('Gym', 7 * 60, status: CompletionStatus.done),
        stay('Office', 9 * 60),
      ]);

      expect(summary.visits.map((o) => o.event.title), ['Office']);
      expect(summary.earlier.map((o) => o.event.title), ['Gym', 'Office'],
          reason: 'in the order the day happened');
      expect(summary.done.map((o) => o.event.title), ['Gym'],
          reason: 'a stay is not something that was ticked off');
      expect(summary.total, 1, reason: 'the ring counts plans only');
    });

    test('has already happened, whatever the clock says', () {
      // Written at the time of arrival, so a stay is never "still to come"
      // and never next up.
      final summary = summarise([stay('Office', 21 * 60)]);

      expect(summary.earlier.map((o) => o.event.title), ['Office']);
      expect(summary.later, isEmpty);
      expect(summary.nextUp, isNull);
    });
  });

  group('any other day', () {
    test('nothing is overdue, because there is no now to be late against', () {
      final summary = summarise([
        occurrence('Gym', 7 * 60),
        occurrence('Standup', 9 * 60 + 30),
      ], isToday: false, at: dayBefore);

      expect(summary.overdue, isEmpty);
      expect(summary.nextUp, isNull);
      expect(summary.later, hasLength(2));
      expect(summary.showsNowDivider, isFalse);
    });

    test('the now line needs something behind it', () {
      // With nothing behind it the line is the top of the list.
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
      ], isToday: false, at: dayBefore);

      expect(summary.done, hasLength(1));
      expect(summary.later, hasLength(1),
          reason: 'still to come on a day that has not arrived');
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
