import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:test/test.dart';

/// Every date this rule produces in `[from, to]`, walked day by day.
List<CalendarDate> expand(
  EventRule rule,
  CalendarDate from,
  CalendarDate to,
) {
  final out = <CalendarDate>[];
  for (var day = from.epochDay; day <= to.epochDay; day++) {
    final date = CalendarDate.fromEpochDay(day);
    if (rule.occursOn(date)) out.add(date);
  }
  return out;
}

void main() {
  group('ONCE', () {
    final rule = EventRule(
      recurrence: Recurrence.once,
      startDate: const CalendarDate(2026, 9, 15),
      timeOfDay: 14 * 60 + 30,
    );

    test('fires on exactly its start date', () {
      expect(
        expand(rule, const CalendarDate(2026, 9, 1),
            const CalendarDate(2026, 10, 31)),
        [const CalendarDate(2026, 9, 15)],
      );
    });

    test('next occurrence is the date itself, then nothing', () {
      expect(rule.nextOccurrenceOnOrAfter(const CalendarDate(2026, 9, 1)),
          const CalendarDate(2026, 9, 15));
      expect(rule.nextOccurrenceOnOrAfter(const CalendarDate(2026, 9, 15)),
          const CalendarDate(2026, 9, 15));
      expect(rule.nextOccurrenceOnOrAfter(const CalendarDate(2026, 9, 16)),
          isNull);
    });
  });

  group('DAILY', () {
    // Starts well before every window below, so these tests are about the
    // daily cadence and not about start-date gating (covered separately).
    final gym = EventRule(
      recurrence: Recurrence.daily,
      startDate: const CalendarDate(2020, 1, 1),
      timeOfDay: 7 * 60,
    );

    test('every single day, leap day included', () {
      final dates = expand(gym, const CalendarDate(2024, 2, 26),
          const CalendarDate(2024, 3, 2));
      // 2024 is a leap year, so 29 February is a real day and must appear.
      expect(dates, hasLength(6));
      expect(dates, contains(const CalendarDate(2024, 2, 29)));
    });

    test('respects an inclusive end date', () {
      final bounded = EventRule(
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
        endDate: const CalendarDate(2026, 9, 3),
        timeOfDay: 7 * 60,
      );
      expect(
        expand(bounded, const CalendarDate(2026, 8, 28),
            const CalendarDate(2026, 9, 10)),
        [
          const CalendarDate(2026, 9, 1),
          const CalendarDate(2026, 9, 2),
          const CalendarDate(2026, 9, 3),
        ],
      );
      expect(bounded.nextOccurrenceOnOrAfter(const CalendarDate(2026, 9, 4)),
          isNull);
    });

    test('an inactive rule produces nothing', () {
      final off = EventRule(
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2020, 1, 1),
        timeOfDay: 7 * 60,
        isActive: false,
      );
      expect(
        expand(off, const CalendarDate(2026, 9, 1),
            const CalendarDate(2026, 9, 30)),
        isEmpty,
      );
      expect(off.nextOccurrenceOnOrAfter(const CalendarDate(2026, 9, 1)),
          isNull);
    });
  });

  group('WEEKLY', () {
    // Dance class, Saturdays 17:00.
    final dance = EventRule(
      recurrence: Recurrence.weekly,
      startDate: const CalendarDate(2026, 9, 1),
      timeOfDay: 17 * 60,
      daysOfWeek: Weekdays.saturday,
    );

    test('only the masked weekday', () {
      final dates = expand(dance, const CalendarDate(2026, 9, 1),
          const CalendarDate(2026, 9, 30));
      expect(dates, [
        const CalendarDate(2026, 9, 5),
        const CalendarDate(2026, 9, 12),
        const CalendarDate(2026, 9, 19),
        const CalendarDate(2026, 9, 26),
      ]);
      expect(dates.every((d) => d.weekday == DateTime.saturday), isTrue);
    });

    test('multi-day mask, Mon/Wed/Fri', () {
      final mwf = EventRule(
        recurrence: Recurrence.weekly,
        startDate: const CalendarDate(2026, 9, 1),
        timeOfDay: 7 * 60,
        daysOfWeek: Weekdays.maskOf(
            [DateTime.monday, DateTime.wednesday, DateTime.friday]),
      );
      final dates = expand(mwf, const CalendarDate(2026, 9, 1),
          const CalendarDate(2026, 9, 14));
      expect(dates.map((d) => d.day), [2, 4, 7, 9, 11, 14]);
    });

    test('an empty mask never fires', () {
      final never = EventRule(
        recurrence: Recurrence.weekly,
        startDate: const CalendarDate(2026, 9, 1),
        timeOfDay: 7 * 60,
        daysOfWeek: Weekdays.none,
      );
      expect(
        expand(never, const CalendarDate(2026, 9, 1),
            const CalendarDate(2026, 12, 31)),
        isEmpty,
      );
      expect(never.nextOccurrenceOnOrAfter(const CalendarDate(2026, 9, 1)),
          isNull);
    });

    test('next occurrence skips forward to the right weekday', () {
      // 2026-09-01 is a Tuesday; the next Saturday is the 5th.
      expect(dance.nextOccurrenceOnOrAfter(const CalendarDate(2026, 9, 1)),
          const CalendarDate(2026, 9, 5));
      expect(dance.nextOccurrenceOnOrAfter(const CalendarDate(2026, 9, 5)),
          const CalendarDate(2026, 9, 5));
      expect(dance.nextOccurrenceOnOrAfter(const CalendarDate(2026, 9, 6)),
          const CalendarDate(2026, 9, 12));
    });
  });

  group('EVERY_N_DAYS', () {
    // Water the plants, every 3 days from 1 September.
    final plants = EventRule(
      recurrence: Recurrence.everyNDays,
      startDate: const CalendarDate(2026, 9, 1),
      timeOfDay: 9 * 60,
      interval: 3,
    );

    test('counts from the start date', () {
      expect(
        expand(plants, const CalendarDate(2026, 9, 1),
                const CalendarDate(2026, 9, 14))
            .map((d) => d.day),
        [1, 4, 7, 10, 13],
      );
    });

    test('keeps its cadence across a month boundary', () {
      expect(
        expand(plants, const CalendarDate(2026, 9, 28),
            const CalendarDate(2026, 10, 5)),
        [
          const CalendarDate(2026, 9, 28),
          const CalendarDate(2026, 10, 1),
          const CalendarDate(2026, 10, 4),
        ],
      );
    });

    test('keeps its cadence across 29 February', () {
      final leap = EventRule(
        recurrence: Recurrence.everyNDays,
        startDate: const CalendarDate(2024, 2, 26),
        timeOfDay: 9 * 60,
        interval: 3,
      );
      expect(
        expand(leap, const CalendarDate(2024, 2, 26),
            const CalendarDate(2024, 3, 8)),
        [
          const CalendarDate(2024, 2, 26),
          const CalendarDate(2024, 2, 29), // the leap day is a real step
          const CalendarDate(2024, 3, 3),
          const CalendarDate(2024, 3, 6),
        ],
      );
    });

    test('interval of 1 is just daily', () {
      final every1 = EventRule(
        recurrence: Recurrence.everyNDays,
        startDate: const CalendarDate(2026, 9, 1),
        timeOfDay: 9 * 60,
        interval: 1,
      );
      expect(
        expand(every1, const CalendarDate(2026, 9, 1),
            const CalendarDate(2026, 9, 5)),
        hasLength(5),
      );
    });

    test('a nonsense interval fires nothing rather than dividing by zero', () {
      final broken = EventRule(
        recurrence: Recurrence.everyNDays,
        startDate: const CalendarDate(2026, 9, 1),
        timeOfDay: 9 * 60,
        interval: 0,
      );
      expect(
        expand(broken, const CalendarDate(2026, 9, 1),
            const CalendarDate(2026, 9, 30)),
        isEmpty,
      );
      expect(broken.nextOccurrenceOnOrAfter(const CalendarDate(2026, 9, 1)),
          isNull);
    });

    test('next occurrence lands on the cadence, not on the query date', () {
      expect(plants.nextOccurrenceOnOrAfter(const CalendarDate(2026, 9, 2)),
          const CalendarDate(2026, 9, 4));
      expect(plants.nextOccurrenceOnOrAfter(const CalendarDate(2026, 9, 4)),
          const CalendarDate(2026, 9, 4));
      // Queried before it starts, it starts on time.
      expect(plants.nextOccurrenceOnOrAfter(const CalendarDate(2026, 8, 1)),
          const CalendarDate(2026, 9, 1));
    });
  });

  group('MONTHLY', () {
    // Rent, the 1st of every month.
    final rent = EventRule(
      recurrence: Recurrence.monthly,
      startDate: const CalendarDate(2026, 9, 1),
      timeOfDay: 10 * 60,
      dayOfMonth: 1,
    );

    test('one occurrence per month', () {
      expect(
        expand(rent, const CalendarDate(2026, 9, 1),
            const CalendarDate(2026, 12, 31)),
        [
          const CalendarDate(2026, 9, 1),
          const CalendarDate(2026, 10, 1),
          const CalendarDate(2026, 11, 1),
          const CalendarDate(2026, 12, 1),
        ],
      );
    });

    test('the 31st clamps into short months, it never skips one', () {
      final onThe31st = EventRule(
        recurrence: Recurrence.monthly,
        startDate: const CalendarDate(2026, 1, 31),
        timeOfDay: 10 * 60,
        dayOfMonth: 31,
      );
      final dates = expand(onThe31st, const CalendarDate(2026, 1, 1),
          const CalendarDate(2026, 12, 31));
      expect(dates, hasLength(12), reason: 'every month must get one');
      expect(dates.map((d) => '${d.month}/${d.day}'), [
        '1/31',
        '2/28', // clamped
        '3/31',
        '4/30', // clamped
        '5/31',
        '6/30',
        '7/31',
        '8/31',
        '9/30',
        '10/31',
        '11/30',
        '12/31',
      ]);
    });

    test('the 29th clamps only in non-leap Februaries', () {
      final onThe29th = EventRule(
        recurrence: Recurrence.monthly,
        startDate: const CalendarDate(2024, 1, 29),
        timeOfDay: 10 * 60,
        dayOfMonth: 29,
      );
      expect(onThe29th.effectiveDayOfMonth(2024, 2), 29, reason: 'leap year');
      expect(onThe29th.effectiveDayOfMonth(2025, 2), 28);
      expect(onThe29th.effectiveDayOfMonth(2100, 2), 28, reason: 'not a leap year');
    });

    test('day -1 means the last day of the month, whatever it is', () {
      final lastDay = EventRule(
        recurrence: Recurrence.monthly,
        startDate: const CalendarDate(2024, 1, 1),
        timeOfDay: 18 * 60,
        dayOfMonth: -1,
      );
      expect(
        expand(lastDay, const CalendarDate(2024, 1, 1),
                const CalendarDate(2024, 4, 30))
            .map((d) => d.toString()),
        ['2024-01-31', '2024-02-29', '2024-03-31', '2024-04-30'],
      );
    });

    test('falls back to the start date day when dayOfMonth is unset', () {
      final implied = EventRule(
        recurrence: Recurrence.monthly,
        startDate: const CalendarDate(2026, 9, 17),
        timeOfDay: 10 * 60,
      );
      expect(
        expand(implied, const CalendarDate(2026, 9, 1),
                const CalendarDate(2026, 11, 30))
            .map((d) => d.day),
        [17, 17, 17],
      );
    });

    test('next occurrence rolls into the following month once passed', () {
      expect(rent.nextOccurrenceOnOrAfter(const CalendarDate(2026, 9, 1)),
          const CalendarDate(2026, 9, 1));
      expect(rent.nextOccurrenceOnOrAfter(const CalendarDate(2026, 9, 2)),
          const CalendarDate(2026, 10, 1));
      // And across a year boundary.
      expect(rent.nextOccurrenceOnOrAfter(const CalendarDate(2026, 12, 2)),
          const CalendarDate(2027, 1, 1));
    });

    test('next occurrence clamps when rolling into February', () {
      final onThe31st = EventRule(
        recurrence: Recurrence.monthly,
        startDate: const CalendarDate(2026, 1, 31),
        timeOfDay: 10 * 60,
        dayOfMonth: 31,
      );
      expect(onThe31st.nextOccurrenceOnOrAfter(const CalendarDate(2026, 2, 1)),
          const CalendarDate(2026, 2, 28));
    });
  });

  test('a rule never fires before its start date', () {
    for (final rule in [
      EventRule(
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 10),
        timeOfDay: 0,
      ),
      EventRule(
        recurrence: Recurrence.weekly,
        startDate: const CalendarDate(2026, 9, 10),
        timeOfDay: 0,
        daysOfWeek: Weekdays.everyDay,
      ),
      EventRule(
        recurrence: Recurrence.monthly,
        startDate: const CalendarDate(2026, 9, 10),
        timeOfDay: 0,
        dayOfMonth: 5,
      ),
    ]) {
      expect(
        expand(rule, const CalendarDate(2026, 8, 1),
            const CalendarDate(2026, 9, 9)),
        isEmpty,
        reason: '${rule.recurrence} leaked before its start date',
      );
    }
  });
}
