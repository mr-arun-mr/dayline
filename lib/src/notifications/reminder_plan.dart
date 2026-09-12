import '../model/calendar_date.dart';
import '../model/event.dart';
import '../model/recurrence.dart';
import '../model/rule_description.dart';

/// How the OS should be asked to fire a reminder.
enum ReminderTrigger {
  /// One specific instant. Costs a scheduling slot that is consumed when it
  /// fires, so these have to be topped up.
  exact,

  /// Every day at this wall-clock time, forever, for one slot.
  everyDay,

  /// Every week on this weekday at this wall-clock time, forever, for one slot.
  everyWeek,
}

/// One reminder the OS should hold.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.eventId,
    required this.title,
    required this.body,
    required this.leadMinutes,
    required this.trigger,
    required this.fireAt,
    required this.occurrenceTimeOfDay,
    this.occurrenceDate,
    this.weekday,
  });

  final int id;
  final int eventId;
  final String title;
  final String body;

  /// Minutes before the event this reminder is for. Zero means "at the time".
  final int leadMinutes;

  final ReminderTrigger trigger;

  /// When this fires — for [ReminderTrigger.exact] the only time it fires, and
  /// for the repeating kinds the first time, with the OS matching the
  /// wall-clock components from then on.
  ///
  /// A local [DateTime]: built per occurrence from a wall-clock date and time,
  /// never by adding a [Duration] to a previous one.
  final DateTime fireAt;

  /// The wall-clock time of the event itself, for the notification text.
  final int occurrenceTimeOfDay;

  /// Which day this is for. Null for the repeating kinds, which have no single
  /// day — the handler works the date out from when it actually fired.
  final CalendarDate? occurrenceDate;

  /// ISO weekday the repeat matches. [ReminderTrigger.everyWeek] only.
  final int? weekday;

  /// Minute of the day this reminder fires at, which is not the event's own
  /// time whenever a lead pushes it back past midnight.
  int get fireMinuteOfDay => fireAt.hour * 60 + fireAt.minute;

  ScheduledReminder withId(int id) => ScheduledReminder(
    id: id,
    eventId: eventId,
    title: title,
    body: body,
    leadMinutes: leadMinutes,
    trigger: trigger,
    fireAt: fireAt,
    occurrenceTimeOfDay: occurrenceTimeOfDay,
    occurrenceDate: occurrenceDate,
    weekday: weekday,
  );
}

/// A single occurrence that does not follow its rule.
class OccurrenceException {
  const OccurrenceException({required this.date, this.newTimeOfDay});

  final CalendarDate date;

  /// Null means the occurrence was skipped outright.
  final int? newTimeOfDay;

  bool get isSkipped => newTimeOfDay == null;
}

/// What [planReminders] decided, and what it had to leave out.
class ReminderPlan {
  const ReminderPlan({required this.reminders, required this.dropped});

  final List<ScheduledReminder> reminders;

  /// Reminders that did not fit in the budget. They are the furthest out, and
  /// the next reconcile will pick them up once nearer ones have fired.
  final int dropped;

  int get length => reminders.length;
}

/// Works out the smallest set of OS scheduling slots that covers the next
/// [horizonDays], without ever exceeding [budget].
///
/// iOS keeps only 64 pending notifications and silently drops the rest, so the
/// horizon can never simply be "far enough". Two things keep us under it:
///
///  * DAILY and WEEKLY rules become native repeating triggers — one slot each,
///    firing forever, matched on wall-clock components so they survive DST.
///  * Everything else gets exact slots inside a rolling window, topped up
///    every time the app resumes.
///
/// When even that does not fit, the nearest reminders win: sorting by fire time
/// keeps repeating triggers (which always fire within a day or a week) and
/// discards the far end of the window, which the next reconcile will schedule.
ReminderPlan planReminders({
  required List<Event> events,
  required DateTime now,
  Map<int, List<OccurrenceException>> exceptions = const {},
  int horizonDays = 14,
  int budget = 60,
}) {
  final today = CalendarDate.fromDateTime(now);
  final horizonEnd = today.addDays(horizonDays);
  final candidates = <ScheduledReminder>[];

  for (final event in events) {
    if (!event.isActive || event.leadMinutes.isEmpty) continue;

    final eventExceptions = exceptions[event.id] ?? const [];
    final relevant = eventExceptions
        .where((e) => !e.date.isBefore(today) && !e.date.isAfter(horizonEnd))
        .toList();

    if (_canRepeat(event) && relevant.isEmpty) {
      candidates.addAll(_repeatingReminders(event, now));
    } else {
      // A repeating trigger cannot know that one Thursday was skipped or
      // moved, so an event with exceptions in the window falls back to exact
      // slots for the whole window.
      candidates.addAll(
        _windowedReminders(event, now, today, horizonEnd, relevant),
      );
    }
  }

  int bySoonest(ScheduledReminder a, ScheduledReminder b) {
    final byTime = a.fireAt.compareTo(b.fireAt);
    if (byTime != 0) return byTime;
    return a.eventId.compareTo(b.eventId);
  }

  // Repeating triggers are claimed first, and not because they fire soonest —
  // one of them covers every future occurrence of its rule, where an exact slot
  // covers a single day. Ordering the whole list by fire time would let a
  // morning full of one-off reminders push a daily trigger out of the budget,
  // and losing that is losing the event's reminders outright rather than
  // losing one of them.
  final repeating = candidates
      .where((r) => r.trigger != ReminderTrigger.exact)
      .toList()
    ..sort(bySoonest);
  final exact = candidates
      .where((r) => r.trigger == ReminderTrigger.exact)
      .toList()
    ..sort(bySoonest);

  final kept = <ScheduledReminder>[
    ...repeating.take(budget),
    ...exact.take((budget - repeating.length).clamp(0, budget)),
  ]..sort(bySoonest);

  return ReminderPlan(
    reminders: [
      for (var i = 0; i < kept.length; i++) kept[i].withId(i + _idBase),
    ],
    dropped: candidates.length - kept.length,
  );
}

/// Reminder ids live in their own range so reconciliation can clear exactly
/// what it scheduled and nothing else.
const _idBase = 1000;

bool _canRepeat(Event event) {
  switch (event.recurrence) {
    case Recurrence.daily:
      return event.endDate == null;
    case Recurrence.weekly:
      return event.endDate == null &&
          event.rule.daysOfWeek & Weekdays.everyDay != 0;
    case Recurrence.once:
    case Recurrence.everyNDays:
    case Recurrence.monthly:
      return false;
  }
}

Iterable<ScheduledReminder> _repeatingReminders(Event event, DateTime now) sync* {
  for (final lead in event.leadMinutes) {
    final shifted = _shiftByLead(event.timeOfDay, lead);

    if (event.recurrence == Recurrence.daily ||
        event.rule.daysOfWeek == Weekdays.everyDay) {
      // Seven weekly slots for the same thing a single daily slot covers is
      // six slots wasted against a budget of sixty.
      yield ScheduledReminder(
        id: 0,
        eventId: event.id,
        title: event.title,
        body: reminderBody(event.timeOfDay, lead),
        leadMinutes: lead,
        trigger: ReminderTrigger.everyDay,
        fireAt: _nextDailyFire(now, shifted.minuteOfDay),
        occurrenceTimeOfDay: event.timeOfDay,
      );
      continue;
    }

    for (var weekday = DateTime.monday;
        weekday <= DateTime.sunday;
        weekday++) {
      if (!Weekdays.contains(event.rule.daysOfWeek, weekday)) continue;
      // A lead that crosses midnight fires on the previous weekday.
      final fireWeekday = _rotateWeekday(weekday, shifted.dayShift);
      yield ScheduledReminder(
        id: 0,
        eventId: event.id,
        title: event.title,
        body: reminderBody(event.timeOfDay, lead),
        leadMinutes: lead,
        trigger: ReminderTrigger.everyWeek,
        fireAt: _nextWeeklyFire(now, fireWeekday, shifted.minuteOfDay),
        occurrenceTimeOfDay: event.timeOfDay,
        weekday: fireWeekday,
      );
    }
  }
}

Iterable<ScheduledReminder> _windowedReminders(
  Event event,
  DateTime now,
  CalendarDate today,
  CalendarDate horizonEnd,
  List<OccurrenceException> exceptions,
) sync* {
  final byDate = {for (final e in exceptions) e.date: e};

  var date = today;
  while (!date.isAfter(horizonEnd)) {
    if (!event.rule.occursOn(date)) {
      date = date.addDays(1);
      continue;
    }

    final exception = byDate[date];
    if (exception != null && exception.isSkipped) {
      date = date.addDays(1);
      continue;
    }
    final timeOfDay = exception?.newTimeOfDay ?? event.timeOfDay;

    for (final lead in event.leadMinutes) {
      final shifted = _shiftByLead(timeOfDay, lead);
      final fireAt = date
          .addDays(shifted.dayShift)
          .localDateTimeAt(shifted.minuteOfDay);
      // A reminder for a moment that has already gone is noise.
      if (!fireAt.isAfter(now)) continue;

      yield ScheduledReminder(
        id: 0,
        eventId: event.id,
        title: event.title,
        body: reminderBody(timeOfDay, lead),
        leadMinutes: lead,
        trigger: ReminderTrigger.exact,
        fireAt: fireAt,
        occurrenceTimeOfDay: timeOfDay,
        occurrenceDate: date,
      );
    }
    date = date.addDays(1);
  }
}

/// Where a lead lands relative to the event's own day.
///
/// An hour before 00:30 is 23:30 *yesterday*, so the day has to move with it.
({int dayShift, int minuteOfDay}) _shiftByLead(int timeOfDay, int lead) {
  final raw = timeOfDay - lead;
  // Dart's % is never negative for a positive divisor, which is exactly the
  // floor behaviour wanted here.
  final minuteOfDay = raw % 1440;
  final dayShift = (raw - minuteOfDay) ~/ 1440;
  return (dayShift: dayShift, minuteOfDay: minuteOfDay);
}

int _rotateWeekday(int weekday, int dayShift) =>
    ((weekday - 1 + dayShift) % 7) + 1;

DateTime _nextDailyFire(DateTime now, int minuteOfDay) {
  final today = CalendarDate.fromDateTime(now);
  final candidate = today.localDateTimeAt(minuteOfDay);
  return candidate.isAfter(now)
      ? candidate
      : today.addDays(1).localDateTimeAt(minuteOfDay);
}

DateTime _nextWeeklyFire(DateTime now, int weekday, int minuteOfDay) {
  final today = CalendarDate.fromDateTime(now);
  for (var i = 0; i < 8; i++) {
    final date = today.addDays(i);
    if (date.weekday != weekday) continue;
    final candidate = date.localDateTimeAt(minuteOfDay);
    if (candidate.isAfter(now)) return candidate;
  }
  // Unreachable: eight days always contain a given weekday with room to spare.
  return today.addDays(7).localDateTimeAt(minuteOfDay);
}

/// The line under the event title in the notification.
String reminderBody(int timeOfDay, int leadMinutes) {
  final at = formatWallClock(timeOfDay);
  if (leadMinutes <= 0) return 'Now · $at';
  if (leadMinutes < 60) return 'In $leadMinutes minutes · $at';
  if (leadMinutes < 1440) {
    final hours = leadMinutes ~/ 60;
    final rest = leadMinutes % 60;
    final phrase = rest == 0
        ? 'In $hours hour${hours == 1 ? '' : 's'}'
        : 'In ${hours}h ${rest}m';
    return '$phrase · $at';
  }
  final days = leadMinutes ~/ 1440;
  return days == 1 ? 'Tomorrow · $at' : 'In $days days · $at';
}
