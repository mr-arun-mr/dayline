import 'package:dayline/src/model/calendar_date.dart';
import 'package:test/test.dart';

void main() {
  group('epoch day round trip', () {
    test('known anchors', () {
      expect(const CalendarDate(1970, 1, 1).epochDay, 0);
      expect(const CalendarDate(1969, 12, 31).epochDay, -1);
      expect(const CalendarDate(2000, 3, 1).epochDay, 11017);
      expect(const CalendarDate(2026, 9, 11).epochDay, 20707);
    });

    test('survives 20 years of dates, day by day', () {
      var day = const CalendarDate(2015, 1, 1).epochDay;
      final end = const CalendarDate(2035, 12, 31).epochDay;
      while (day <= end) {
        final date = CalendarDate.fromEpochDay(day);
        expect(date.epochDay, day, reason: 'round trip failed for $date');
        day++;
      }
    });

    test('agrees with DateTime on weekday, including across DST', () {
      // DateTime.weekday is already ISO; if our integer math ever drifts from
      // it, every WEEKLY rule silently fires on the wrong day.
      var day = const CalendarDate(2024, 1, 1).epochDay;
      final end = const CalendarDate(2027, 12, 31).epochDay;
      while (day <= end) {
        final date = CalendarDate.fromEpochDay(day);
        final dt = DateTime.utc(date.year, date.month, date.day);
        expect(date.weekday, dt.weekday, reason: '$date');
        day++;
      }
    });
  });

  group('leap years', () {
    test('the rule, including the century exceptions', () {
      expect(CalendarDate.isLeapYear(2024), isTrue);
      expect(CalendarDate.isLeapYear(2025), isFalse);
      expect(CalendarDate.isLeapYear(1900), isFalse, reason: 'divisible by 100');
      expect(CalendarDate.isLeapYear(2000), isTrue, reason: 'divisible by 400');
      expect(CalendarDate.isLeapYear(2100), isFalse);
    });

    test('29 February exists only in leap years', () {
      expect(CalendarDate.daysInMonth(2024, 2), 29);
      expect(CalendarDate.daysInMonth(2025, 2), 28);
      expect(CalendarDate.daysInMonth(2100, 2), 28);
    });

    test('stepping over 29 February 2024', () {
      expect(const CalendarDate(2024, 2, 28).addDays(1),
          const CalendarDate(2024, 2, 29));
      expect(const CalendarDate(2024, 2, 29).addDays(1),
          const CalendarDate(2024, 3, 1));
      // And the same window in a non-leap year skips straight past.
      expect(const CalendarDate(2025, 2, 28).addDays(1),
          const CalendarDate(2025, 3, 1));
    });

    test('a leap year is 366 days long', () {
      expect(
        const CalendarDate(2024, 1, 1).daysUntil(const CalendarDate(2025, 1, 1)),
        366,
      );
      expect(
        const CalendarDate(2025, 1, 1).daysUntil(const CalendarDate(2026, 1, 1)),
        365,
      );
    });
  });

  group('clampDayOfMonth', () {
    test('short months pull the day back, they do not skip', () {
      expect(CalendarDate.clampDayOfMonth(31, 2026, 2), 28);
      expect(CalendarDate.clampDayOfMonth(31, 2024, 2), 29);
      expect(CalendarDate.clampDayOfMonth(31, 2026, 4), 30);
      expect(CalendarDate.clampDayOfMonth(31, 2026, 5), 31);
    });

    test('negative days count back from the end', () {
      expect(CalendarDate.clampDayOfMonth(-1, 2026, 2), 28);
      expect(CalendarDate.clampDayOfMonth(-1, 2024, 2), 29);
      expect(CalendarDate.clampDayOfMonth(-1, 2026, 1), 31);
      expect(CalendarDate.clampDayOfMonth(-2, 2026, 1), 30);
    });
  });

  test('parse and toString are inverses', () {
    expect(CalendarDate.parse('2026-09-11'), const CalendarDate(2026, 9, 11));
    expect(const CalendarDate(2026, 9, 11).toString(), '2026-09-11');
    expect(const CalendarDate(999, 1, 2).toString(), '0999-01-02');
  });

  test('ordering', () {
    const a = CalendarDate(2026, 9, 11);
    const b = CalendarDate(2026, 10, 1);
    expect(a.isBefore(b), isTrue);
    expect(b.isAfter(a), isTrue);
    expect(a.isBefore(a), isFalse);
    expect([b, a]..sort(), [a, b]);
  });
}
