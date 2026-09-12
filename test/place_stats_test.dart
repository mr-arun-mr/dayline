import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/place.dart';
import 'package:dayline/src/model/place_stats.dart';
import 'package:test/test.dart';

void main() {
  const today = CalendarDate(2026, 9, 11);
  final now = DateTime(2026, 9, 11, 18, 0);

  var nextId = 1;
  Visit visit(int placeId, DateTime arrived, [DateTime? departed]) =>
      Visit(id: nextId++, placeId: placeId, arrivedAt: arrived, departedAt: departed);

  setUp(() => nextId = 1);

  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 9, day, hour, minute);

  group('time per place', () {
    test('adds up closed visits', () {
      final totals = timePerPlace(
        [
          visit(1, at(11, 9), at(11, 12)),
          visit(1, at(11, 14), at(11, 15, 30)),
          visit(2, at(11, 13), at(11, 13, 45)),
        ],
        from: at(11, 0),
        to: at(12, 0),
        now: now,
      );

      expect(totals[1], const Duration(hours: 4, minutes: 30));
      expect(totals[2], const Duration(minutes: 45));
    });

    test('clips a visit to the window rather than counting it whole', () {
      // Home from 22:00 last night until 08:00 — only the morning belongs to
      // a window that starts at midnight.
      final totals = timePerPlace(
        [visit(1, at(10, 22), at(11, 8))],
        from: at(11, 0),
        to: at(12, 0),
        now: now,
      );
      expect(totals[1], const Duration(hours: 8));
    });

    test('an open visit runs up to now, never past it', () {
      final totals = timePerPlace(
        [visit(1, at(11, 16))],
        from: at(11, 0),
        to: at(12, 0),
        now: now,
      );
      expect(totals[1], const Duration(hours: 2),
          reason: 'from 16:00 to the present 18:00, not to midnight');
    });

    test('a visit entirely outside the window counts for nothing', () {
      final totals = timePerPlace(
        [visit(1, at(9, 9), at(9, 17))],
        from: at(11, 0),
        to: at(12, 0),
        now: now,
      );
      expect(totals[1], isNull);
    });

    test('a zero-length visit is not a visit', () {
      final totals = timePerPlace(
        [visit(1, at(11, 9), at(11, 9))],
        from: at(11, 0),
        to: at(12, 0),
        now: now,
      );
      expect(totals[1], isNull);
    });
  });

  group('the day timeline', () {
    test('is ordered by arrival', () {
      final visits = visitsOnDay(
        [
          visit(2, at(11, 14), at(11, 15)),
          visit(1, at(11, 9), at(11, 12)),
        ],
        today,
        now: now,
      );
      expect(visits.map((v) => v.placeId), [1, 2]);
    });

    test('a stay spanning midnight shows on both days', () {
      // One stay, seen from two days — which is what a timeline should show.
      final overnight = visit(1, at(10, 22), at(11, 8));

      expect(visitsOnDay([overnight], today, now: now), hasLength(1));
      expect(
        visitsOnDay([overnight], today.addDays(-1), now: now),
        hasLength(1),
      );
      expect(
        visitsOnDay([overnight], today.addDays(-2), now: now),
        isEmpty,
      );
    });

    test('an open visit shows on today', () {
      expect(visitsOnDay([visit(1, at(11, 16))], today, now: now), hasLength(1));
    });
  });

  group('adherence', () {
    final gymDates = [
      today.addDays(-4),
      today.addDays(-3),
      today.addDays(-2),
      today.addDays(-1),
      today,
    ];

    test('counts an occurrence as kept when the device was there', () {
      final result = adherenceFor(
        occurrenceDates: gymDates,
        timeOfDay: 7 * 60,
        placeId: 1,
        now: now,
        visits: [
          visit(1, at(7, 6, 55), at(7, 8)),
          visit(1, at(8, 7, 10), at(8, 8)),
          visit(1, at(11, 7), at(11, 8)),
        ],
      );

      expect(result.expected, 5, reason: '07:00 today has already gone');
      expect(result.attended, 3);
      expect(result.missed, 2);
      expect(result.rate, closeTo(0.6, 0.001));
    });

    test('being there at the wrong time does not count', () {
      final result = adherenceFor(
        occurrenceDates: [today],
        timeOfDay: 7 * 60,
        placeId: 1,
        now: now,
        // Turned up at half four in the afternoon.
        visits: [visit(1, at(11, 16, 30), at(11, 17, 30))],
      );
      expect(result.attended, 0);
    });

    test('arriving late still counts, within the grace window', () {
      // Twenty minutes late is still going to the gym.
      final result = adherenceFor(
        occurrenceDates: [today],
        timeOfDay: 7 * 60,
        placeId: 1,
        now: now,
        visits: [visit(1, at(11, 7, 20), at(11, 8))],
      );
      expect(result.attended, 1);
    });

    test('an occurrence still ahead is neither kept nor missed', () {
      final result = adherenceFor(
        occurrenceDates: [today],
        timeOfDay: 21 * 60, // 21:00, and it is 18:00
        placeId: 1,
        now: now,
        visits: const [],
      );
      expect(result.expected, 0);
      expect(result.rate, 0);
    });

    test('visits to other places are ignored', () {
      final result = adherenceFor(
        occurrenceDates: [today],
        timeOfDay: 7 * 60,
        placeId: 1,
        now: now,
        visits: [visit(2, at(11, 7), at(11, 8))],
      );
      expect(result.attended, 0);
    });

    test('an open visit covering the time counts', () {
      final result = adherenceFor(
        occurrenceDates: [today],
        timeOfDay: 17 * 60,
        placeId: 1,
        now: now,
        visits: [visit(1, at(11, 16))],
      );
      expect(result.attended, 1);
    });
  });

  group('weekly trend', () {
    test('buckets by calendar week, Monday to Monday', () {
      // 2026-09-11 is a Friday, so this week began on Monday the 7th.
      final totals = weeklyTotals(
        [
          visit(1, at(8, 9), at(8, 11)), // Tuesday this week
          visit(1, at(2, 9), at(2, 12)), // Wednesday last week
        ],
        placeId: 1,
        today: today,
        now: now,
        weeks: 2,
      );

      expect(totals, hasLength(2));
      expect(totals.first.weekStart, const CalendarDate(2026, 8, 31));
      expect(totals.first.total, const Duration(hours: 3));
      expect(totals.last.weekStart, const CalendarDate(2026, 9, 7));
      expect(totals.last.total, const Duration(hours: 2));
    });

    test('a week with nothing in it is still a week', () {
      final totals = weeklyTotals(
        const [],
        placeId: 1,
        today: today,
        now: now,
        weeks: 4,
      );
      expect(totals, hasLength(4));
      expect(totals.every((t) => t.total == Duration.zero), isTrue);
    });

    test('other places do not leak in', () {
      final totals = weeklyTotals(
        [visit(2, at(8, 9), at(8, 11))],
        placeId: 1,
        today: today,
        now: now,
        weeks: 1,
      );
      expect(totals.single.total, Duration.zero);
    });
  });

  test('durations read the way people say them', () {
    expect(formatDuration(Duration.zero), '—');
    expect(formatDuration(const Duration(minutes: 45)), '45m');
    expect(formatDuration(const Duration(hours: 2)), '2h');
    expect(formatDuration(const Duration(hours: 3, minutes: 20)), '3h 20m');
  });
}
