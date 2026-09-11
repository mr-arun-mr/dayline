import 'calendar_date.dart';
import 'recurrence.dart';

/// Turns a rule into the sentence shown under the recurrence picker —
/// "Every Mon, Wed, Fri at 07:00".
///
/// Pure, and deliberately outside the widget layer: the preview line is the
/// only thing standing between the user and a misunderstood rule, so it is
/// worth testing directly.
String describeRule(
  EventRule rule, {
  String Function(int minuteOfDay) formatTime = formatWallClock,
  String Function(CalendarDate date) formatDate = formatMediumDate,
}) {
  final time = formatTime(rule.timeOfDay);
  final body = switch (rule.recurrence) {
    Recurrence.once => 'Once on ${formatDate(rule.startDate)} at $time',
    Recurrence.daily => 'Every day at $time',
    Recurrence.weekly => '${_weeklyPrefix(rule.daysOfWeek)} at $time',
    Recurrence.everyNDays => '${_everyNPrefix(rule.interval)} at $time',
    Recurrence.monthly =>
      'Monthly on the ${_monthDayPhrase(rule.dayOfMonth ?? rule.startDate.day)}'
          ' at $time',
  };

  final end = rule.endDate;
  if (end == null || rule.recurrence == Recurrence.once) return body;
  return '$body, until ${formatDate(end)}';
}

String _weeklyPrefix(int mask) {
  if (mask & Weekdays.everyDay == 0) return 'Never';
  if (mask == Weekdays.everyDay) return 'Every day';
  if (mask == Weekdays.weekdays) return 'Every weekday';
  if (mask == Weekdays.weekend) return 'Every weekend';

  final days = [
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
      if (Weekdays.contains(mask, weekday)) weekday,
  ];
  // A single day reads better spelled out: "Every Saturday", not "Every Sat".
  if (days.length == 1) return 'Every ${_weekdayNames[days.single - 1]}';
  return 'Every ${days.map((d) => _shortWeekdayNames[d - 1]).join(', ')}';
}

String _everyNPrefix(int interval) => switch (interval) {
  <= 0 => 'Never',
  1 => 'Every day',
  2 => 'Every other day',
  _ => 'Every $interval days',
};

String _monthDayPhrase(int dayOfMonth) {
  if (dayOfMonth == -1) return 'last day';
  if (dayOfMonth < 0) return '${_ordinal(-dayOfMonth)} to last day';
  return _ordinal(dayOfMonth);
}

String _ordinal(int n) {
  final suffix = switch (n % 100) {
    11 || 12 || 13 => 'th',
    _ => switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' },
  };
  return '$n$suffix';
}

/// 24-hour wall clock, zero padded. The schedule is stored as wall clock, so
/// this is a direct rendering of the stored value rather than a conversion.
String formatWallClock(int minuteOfDay) {
  final hours = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
  final minutes = (minuteOfDay % 60).toString().padLeft(2, '0');
  return '$hours:$minutes';
}

/// "15 Sep 2026".
String formatMediumDate(CalendarDate date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// "Fri 11 Sep".
String formatDayAndMonth(CalendarDate date) =>
    '${_shortWeekdayNames[date.weekday - 1]} ${date.day} '
    '${_monthNames[date.month - 1]}';

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _shortWeekdayNames = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
