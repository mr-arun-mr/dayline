import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/model/wall_clock.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The promise this file exists to defend: **07:00 gym stays 07:00**.
///
/// These tests pin real zones from the IANA database rather than the machine's
/// own zone, so they assert the same thing on a laptop in Bengaluru and on CI
/// in UTC. Southern-hemisphere DST runs the opposite way round, and one zone
/// has no DST at all and a half-hour offset — between them they catch a
/// duration-based implementation that happens to look right in Europe.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  /// A transition worth testing: the zone, and a date in the middle of the
  /// window where its clocks move.
  const transitions = <String, List<CalendarDate>>{
    'America/New_York': [
      CalendarDate(2026, 3, 8), // spring forward, 02:00 -> 03:00
      CalendarDate(2026, 11, 1), // fall back, 02:00 -> 01:00
    ],
    'Europe/London': [
      CalendarDate(2026, 3, 29),
      CalendarDate(2026, 10, 25),
    ],
    'Australia/Sydney': [
      CalendarDate(2026, 4, 5), // clocks go *back* in April
      CalendarDate(2026, 10, 4), // and forward in October
    ],
    'Asia/Kolkata': [
      CalendarDate(2026, 3, 8), // no DST at all, and UTC+05:30
      CalendarDate(2026, 11, 1),
    ],
  };

  final gym = EventRule(
    recurrence: Recurrence.daily,
    startDate: const CalendarDate(2020, 1, 1),
    timeOfDay: 7 * 60, // 07:00
  );

  group('a daily 07:00 event reads 07:00 on every side of a DST change', () {
    transitions.forEach((zoneName, dates) {
      for (final transition in dates) {
        test('$zoneName around $transition', () {
          final location = tz.getLocation(zoneName);
          final instants = <tz.TZDateTime>[];

          for (var offset = -3; offset <= 3; offset++) {
            final date = transition.addDays(offset);
            expect(gym.occursOn(date), isTrue);

            final instant = wallClockIn(location, date, gym.timeOfDay);
            expect(instant.hour, 7, reason: 'wall clock drifted on $date');
            expect(instant.minute, 0);
            expect(instant.day, date.day, reason: 'slid to another day');
            instants.add(instant);
          }

          // Strictly increasing, and each step is a *day* even when it is not
          // 24 hours.
          for (var i = 1; i < instants.length; i++) {
            expect(instants[i].isAfter(instants[i - 1]), isTrue);
          }
        });
      }
    });
  });

  test('the DST windows really do shift the clock, so the test is not vacuous',
      () {
    // If tzdata ever changed such that these dates were ordinary, the
    // assertions above would pass trivially. This catches that.
    final shifting = <String>[];
    transitions.forEach((zoneName, dates) {
      if (zoneName == 'Asia/Kolkata') return; // the control, no DST expected
      final location = tz.getLocation(zoneName);
      for (final transition in dates) {
        final before = wallClockIn(location, transition.addDays(-1), 7 * 60);
        final after = wallClockIn(location, transition.addDays(1), 7 * 60);
        final hours = after.difference(before).inMinutes / 60.0;
        if (hours != 48.0) shifting.add('$zoneName/$transition: ${hours}h');
      }
    });
    expect(shifting, hasLength(6),
        reason: 'expected all six DST transitions to be 47h or 49h apart, '
            'got: $shifting');
  });

  test('Asia/Kolkata never shifts, and holds a half-hour offset', () {
    final location = tz.getLocation('Asia/Kolkata');
    final january = wallClockIn(location, const CalendarDate(2026, 1, 15), 420);
    final july = wallClockIn(location, const CalendarDate(2026, 7, 15), 420);
    expect(january.timeZoneOffset, july.timeZoneOffset);
    expect(january.timeZoneOffset, const Duration(hours: 5, minutes: 30));
  });

  test('duration arithmetic is the bug we are avoiding', () {
    // Demonstrates *why* CalendarDate.addDays exists. Adding 24 hours to an
    // instant across spring-forward lands on 08:00, not 07:00.
    final location = tz.getLocation('America/New_York');
    final beforeTransition =
        wallClockIn(location, const CalendarDate(2026, 3, 7), 7 * 60);
    final naive = beforeTransition.add(const Duration(days: 1));
    expect(naive.hour, 8, reason: 'this is the drift we must not ship');

    // The real path keeps the wall clock.
    final correct =
        wallClockIn(location, const CalendarDate(2026, 3, 8), 7 * 60);
    expect(correct.hour, 7);
  });

  test('a 02:30 event on a spring-forward day resolves to a real instant', () {
    // 02:30 does not exist on 2026-03-08 in New York. It must not throw and
    // must not silently land on the previous day.
    final location = tz.getLocation('America/New_York');
    final instant =
        wallClockIn(location, const CalendarDate(2026, 3, 8), 2 * 60 + 30);
    expect(instant.day, 8);
    expect(instant.hour, greaterThanOrEqualTo(1));
    expect(instant.hour, lessThanOrEqualTo(3));
  });
}
