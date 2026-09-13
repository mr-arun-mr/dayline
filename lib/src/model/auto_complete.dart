import 'calendar_date.dart';

/// How far either side of the scheduled time an arrival still counts.
///
/// Generous on purpose, and the same grace the dashboard judges adherence by:
/// arriving twenty minutes late is still going to the gym, and a geofence a
/// hundred metres across does not report an arrival the instant you walk
/// through the door. It is symmetric because turning up early for the 19:00
/// class is not a different thing from turning up late for it.
const arrivalGrace = Duration(hours: 2);

/// Whether arriving at [arrivedAt] falls close enough to the occurrence of
/// [timeOfDay] on [date] to count as turning up for it.
///
/// Pure, and deliberately built from the occurrence's wall clock rather than
/// by adding durations to an instant, so the hour a clock change adds or takes
/// away cannot widen or narrow the window.
bool arrivalCountsFor({
  required CalendarDate date,
  required int timeOfDay,
  required DateTime arrivedAt,
  Duration grace = arrivalGrace,
}) {
  final scheduled = date.localDateTimeAt(timeOfDay);
  return !arrivedAt.isBefore(scheduled.subtract(grace)) &&
      !arrivedAt.isAfter(scheduled.add(grace));
}

/// Every calendar date that could hold an occurrence [arrivedAt] is within
/// [grace] of, oldest first.
///
/// An arrival at 23:30 can be turning up for something at 00:30 tomorrow, and
/// one at 00:30 can be turning up for something at 23:00 yesterday, so the
/// neighbouring days are candidates too. Kept to whole days rather than
/// clock arithmetic: the set of *dates* to expand is the question, and the
/// per-occurrence answer is [arrivalCountsFor]'s.
List<CalendarDate> datesInGraceOf(
  DateTime arrivedAt, {
  Duration grace = arrivalGrace,
}) {
  final middle = CalendarDate.fromDateTime(arrivedAt);
  // A grace under a day reaches at most one day either side; anything longer
  // reaches as many days as it spans, rounded up.
  final span = (grace.inMinutes / Duration.minutesPerDay).ceil().clamp(1, 31);
  return [
    for (var offset = -span; offset <= span; offset++) middle.addDays(offset),
  ];
}
