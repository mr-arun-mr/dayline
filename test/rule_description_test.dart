import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/model/rule_description.dart';
import 'package:test/test.dart';

void main() {
  EventRule rule(
    Recurrence recurrence, {
    int timeOfDay = 7 * 60,
    int daysOfWeek = Weekdays.none,
    int interval = 1,
    int? dayOfMonth,
    CalendarDate? endDate,
  }) =>
      EventRule(
        recurrence: recurrence,
        startDate: const CalendarDate(2026, 9, 15),
        timeOfDay: timeOfDay,
        daysOfWeek: daysOfWeek,
        interval: interval,
        dayOfMonth: dayOfMonth,
        endDate: endDate,
      );

  test('ONCE names the date', () {
    expect(
      describeRule(rule(Recurrence.once, timeOfDay: 14 * 60 + 30)),
      'Once on 15 Sep 2026 at 14:30',
    );
  });

  test('DAILY', () {
    expect(describeRule(rule(Recurrence.daily)), 'Every day at 07:00');
  });

  group('WEEKLY', () {
    test('the spec example', () {
      expect(
        describeRule(rule(
          Recurrence.weekly,
          daysOfWeek: Weekdays.maskOf(
              [DateTime.monday, DateTime.wednesday, DateTime.friday]),
        )),
        'Every Mon, Wed, Fri at 07:00',
      );
    });

    test('a single day is spelled out', () {
      expect(
        describeRule(rule(
          Recurrence.weekly,
          timeOfDay: 17 * 60,
          daysOfWeek: Weekdays.saturday,
        )),
        'Every Saturday at 17:00',
      );
    });

    test('common sets get their own phrasing', () {
      expect(
        describeRule(rule(Recurrence.weekly, daysOfWeek: Weekdays.everyDay)),
        'Every day at 07:00',
      );
      expect(
        describeRule(rule(Recurrence.weekly, daysOfWeek: Weekdays.weekdays)),
        'Every weekday at 07:00',
      );
      expect(
        describeRule(rule(Recurrence.weekly, daysOfWeek: Weekdays.weekend)),
        'Every weekend at 07:00',
      );
    });

    test('an empty mask says so rather than lying', () {
      expect(
        describeRule(rule(Recurrence.weekly, daysOfWeek: Weekdays.none)),
        'Never at 07:00',
      );
    });

    test('days always read in week order, whatever order they were set', () {
      expect(
        describeRule(rule(
          Recurrence.weekly,
          daysOfWeek: Weekdays.maskOf(
              [DateTime.sunday, DateTime.tuesday, DateTime.saturday]),
        )),
        'Every Tue, Sat, Sun at 07:00',
      );
    });
  });

  group('EVERY_N_DAYS', () {
    test('reads naturally at 1, 2 and n', () {
      expect(describeRule(rule(Recurrence.everyNDays, interval: 1)),
          'Every day at 07:00');
      expect(describeRule(rule(Recurrence.everyNDays, interval: 2)),
          'Every other day at 07:00');
      expect(
        describeRule(
            rule(Recurrence.everyNDays, interval: 3, timeOfDay: 9 * 60)),
        'Every 3 days at 09:00',
      );
    });
  });

  group('MONTHLY', () {
    test('ordinals', () {
      for (final (day, expected) in [
        (1, '1st'),
        (2, '2nd'),
        (3, '3rd'),
        (4, '4th'),
        (11, '11th'),
        (12, '12th'),
        (13, '13th'),
        (21, '21st'),
        (22, '22nd'),
        (23, '23rd'),
        (31, '31st'),
      ]) {
        expect(
          describeRule(
              rule(Recurrence.monthly, dayOfMonth: day, timeOfDay: 10 * 60)),
          'Monthly on the $expected at 10:00',
        );
      }
    });

    test('last day of month', () {
      expect(
        describeRule(rule(Recurrence.monthly, dayOfMonth: -1)),
        'Monthly on the last day at 07:00',
      );
    });

    test('falls back to the start date day', () {
      expect(
        describeRule(rule(Recurrence.monthly)),
        'Monthly on the 15th at 07:00',
      );
    });
  });

  group('end date', () {
    test('is appended when the series stops', () {
      expect(
        describeRule(rule(
          Recurrence.daily,
          endDate: const CalendarDate(2027, 6, 30),
        )),
        'Every day at 07:00, until 30 Jun 2027',
      );
    });

    test('is never appended to a one-off, which already names its date', () {
      expect(
        describeRule(rule(
          Recurrence.once,
          endDate: const CalendarDate(2027, 6, 30),
        )),
        'Once on 15 Sep 2026 at 07:00',
      );
    });
  });

  test('wall clock formatting pads both halves', () {
    expect(formatWallClock(0), '00:00');
    expect(formatWallClock(9 * 60 + 5), '09:05');
    expect(formatWallClock(23 * 60 + 59), '23:59');
  });
}
