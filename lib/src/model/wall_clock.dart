import 'package:timezone/timezone.dart' as tz;

import 'calendar_date.dart';

/// The single place where Dayline's timezone-free schedule meets a real
/// timezone.
///
/// Everything upstream — rules, expansion, overrides — is integers. Only here,
/// at the moment of scheduling an alarm or drawing a clock, does a date plus a
/// minute-of-day become an instant. Because the conversion happens per
/// occurrence rather than once at the start of a series, a 07:00 event is 07:00
/// on both sides of a DST change instead of drifting by an hour.
tz.TZDateTime wallClockIn(
  tz.Location location,
  CalendarDate date,
  int minuteOfDay,
) => tz.TZDateTime(
  location,
  date.year,
  date.month,
  date.day,
  minuteOfDay ~/ 60,
  minuteOfDay % 60,
);

/// As [wallClockIn], in the device's current local zone.
tz.TZDateTime wallClockLocal(CalendarDate date, int minuteOfDay) =>
    wallClockIn(tz.local, date, minuteOfDay);
