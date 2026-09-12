import 'calendar_date.dart';
import 'place.dart';

/// Total time spent at each place inside a window.
///
/// Visits are clipped to the window rather than counted whole, so a night's
/// sleep at home does not put eight hours into a window covering the morning.
/// An open visit — the device is still there — is treated as running up to
/// [now], never past it.
Map<int, Duration> timePerPlace(
  Iterable<Visit> visits, {
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  final totals = <int, Duration>{};
  for (final visit in visits) {
    final overlap = _overlap(visit, from: from, to: to, now: now);
    if (overlap <= Duration.zero) continue;
    totals[visit.placeId] = (totals[visit.placeId] ?? Duration.zero) + overlap;
  }
  return totals;
}

/// How much of [visit] falls inside the window.
Duration _overlap(
  Visit visit, {
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  // An open visit cannot have run past the present moment.
  final end = visit.departedAt ?? (now.isBefore(to) ? now : to);
  final start = visit.arrivedAt;

  final clippedStart = start.isAfter(from) ? start : from;
  final clippedEnd = end.isBefore(to) ? end : to;
  if (!clippedEnd.isAfter(clippedStart)) return Duration.zero;
  return clippedEnd.difference(clippedStart);
}

/// The visits touching one calendar day, in the order they happened.
///
/// A visit that starts on Monday and ends on Tuesday appears in both days,
/// which is what a timeline should show — it is one stay seen from two days.
List<Visit> visitsOnDay(
  Iterable<Visit> visits,
  CalendarDate date, {
  required DateTime now,
}) {
  final dayStart = date.localDateTimeAt(0);
  final dayEnd = date.addDays(1).localDateTimeAt(0);

  final touching = visits.where((visit) {
    final end = visit.departedAt ?? now;
    return visit.arrivedAt.isBefore(dayEnd) && end.isAfter(dayStart);
  }).toList()
    ..sort((a, b) => a.arrivedAt.compareTo(b.arrivedAt));
  return touching;
}

/// Whether a routine was actually kept, judged by where the device was.
class Adherence {
  const Adherence({required this.expected, required this.attended});

  static const none = Adherence(expected: 0, attended: 0);

  /// Occurrences that have already come and gone.
  final int expected;

  /// Of those, the ones the device was at the right place for.
  final int attended;

  int get missed => expected - attended;

  double get rate => expected == 0 ? 0 : attended / expected;
}

/// Cross-references a routine's past occurrences against visits to its place.
///
/// "Did you actually go to the gym when the reminder fired" is the one question
/// that ties location back to what this app is for, and it is the only place
/// visit data is read for anything other than showing it back to the user.
///
/// [window] is the grace either side of the scheduled time. It is generous on
/// purpose: arriving twenty minutes late is still going to the gym, and a
/// geofence of a hundred metres does not report arrival at the instant you walk
/// through the door.
Adherence adherenceFor({
  required Iterable<CalendarDate> occurrenceDates,
  required int timeOfDay,
  required Iterable<Visit> visits,
  required int placeId,
  required DateTime now,
  Duration window = const Duration(hours: 2),
}) {
  final relevant = visits.where((v) => v.placeId == placeId).toList();
  var expected = 0;
  var attended = 0;

  for (final date in occurrenceDates) {
    final scheduled = date.localDateTimeAt(timeOfDay);
    // An occurrence still ahead of us cannot have been missed.
    if (!scheduled.isBefore(now)) continue;
    expected++;

    final from = scheduled.subtract(window);
    final to = scheduled.add(window);
    final wasThere = relevant.any((visit) {
      final end = visit.departedAt ?? now;
      return visit.arrivedAt.isBefore(to) && end.isAfter(from);
    });
    if (wasThere) attended++;
  }

  return Adherence(expected: expected, attended: attended);
}

/// A week's total at one place, for the trend strip.
class WeeklyTotal {
  const WeeklyTotal({required this.weekStart, required this.total});

  /// The Monday the week begins on.
  final CalendarDate weekStart;
  final Duration total;
}

/// Weekly totals for one place, most recent week last.
///
/// Weeks start on Monday and are built from calendar dates rather than by
/// subtracting seven-day durations, so a DST week is still a week.
List<WeeklyTotal> weeklyTotals(
  Iterable<Visit> visits, {
  required int placeId,
  required CalendarDate today,
  required DateTime now,
  int weeks = 6,
}) {
  final mine = visits.where((v) => v.placeId == placeId).toList();
  final thisMonday = today.addDays(-(today.weekday - 1));

  return [
    for (var i = weeks - 1; i >= 0; i--)
      () {
        final start = thisMonday.addDays(-7 * i);
        final totals = timePerPlace(
          mine,
          from: start.localDateTimeAt(0),
          to: start.addDays(7).localDateTimeAt(0),
          now: now,
        );
        return WeeklyTotal(
          weekStart: start,
          total: totals[placeId] ?? Duration.zero,
        );
      }(),
  ];
}

/// "3h 20m", or "—" for nothing at all.
String formatDuration(Duration duration) {
  if (duration <= Duration.zero) return '—';
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}
