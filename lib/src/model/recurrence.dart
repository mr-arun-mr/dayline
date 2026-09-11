import 'calendar_date.dart';

/// How an event repeats.
///
/// The stored [code] is what goes in SQLite. It is explicit so that reordering
/// or inserting enum values can never silently reinterpret existing rows.
enum Recurrence {
  once(0),
  daily(1),
  weekly(2),
  everyNDays(3),
  monthly(4);

  const Recurrence(this.code);

  final int code;

  static Recurrence fromCode(int code) =>
      Recurrence.values.firstWhere((r) => r.code == code);
}

/// Bit positions in [EventRule.daysOfWeek]: bit 0 = Monday … bit 6 = Sunday,
/// matching ISO-8601 weekday numbering shifted down by one.
abstract final class Weekdays {
  static const monday = 1 << 0;
  static const tuesday = 1 << 1;
  static const wednesday = 1 << 2;
  static const thursday = 1 << 3;
  static const friday = 1 << 4;
  static const saturday = 1 << 5;
  static const sunday = 1 << 6;

  static const none = 0;
  static const everyDay = 0x7F;
  static const weekdays =
      monday | tuesday | wednesday | thursday | friday;
  static const weekend = saturday | sunday;

  /// [isoWeekday] is 1 = Monday … 7 = Sunday, as [CalendarDate.weekday] gives.
  static int bit(int isoWeekday) => 1 << (isoWeekday - 1);

  static bool contains(int mask, int isoWeekday) =>
      mask & bit(isoWeekday) != 0;

  /// Builds a mask from ISO weekday numbers, e.g. `maskOf([1, 3, 5])`.
  static int maskOf(Iterable<int> isoWeekdays) =>
      isoWeekdays.fold(0, (mask, d) => mask | bit(d));
}

/// The recurrence half of an event — everything needed to answer "does this
/// happen on date X, and at what wall-clock time".
///
/// Deliberately free of any Drift or Flutter import so the expansion logic can
/// be unit-tested as plain Dart.
class EventRule {
  const EventRule({
    required this.recurrence,
    required this.startDate,
    required this.timeOfDay,
    this.endDate,
    this.daysOfWeek = Weekdays.none,
    this.interval = 1,
    this.dayOfMonth,
    this.isActive = true,
  });

  final Recurrence recurrence;

  /// Minutes since midnight, **wall clock**. Never a UTC offset.
  final int timeOfDay;

  /// First day the rule can produce an occurrence. Inclusive. For
  /// [Recurrence.once] this *is* the occurrence date.
  final CalendarDate startDate;

  /// Last day the rule can produce an occurrence. Inclusive. Null = forever.
  final CalendarDate? endDate;

  /// 7-bit mask, [Weekdays]. Meaningful for [Recurrence.weekly] only.
  final int daysOfWeek;

  /// Every N days, counted from [startDate]. [Recurrence.everyNDays] only.
  final int interval;

  /// Nominal day of the month, clamped into short months. Negative counts back
  /// from the end (-1 = last day). [Recurrence.monthly] only; when null the
  /// day of [startDate] is used.
  final int? dayOfMonth;

  final bool isActive;

  /// The day-of-month this rule lands on in a given month, after clamping.
  int effectiveDayOfMonth(int year, int month) => CalendarDate.clampDayOfMonth(
    dayOfMonth ?? startDate.day,
    year,
    month,
  );

  /// Whether an occurrence of this rule falls on [date].
  ///
  /// Pure integer arithmetic — no [DateTime], so DST cannot perturb it.
  bool occursOn(CalendarDate date) {
    if (!isActive) return false;
    if (date.isBefore(startDate)) return false;
    final end = endDate;
    if (end != null && date.isAfter(end)) return false;

    switch (recurrence) {
      case Recurrence.once:
        return date == startDate;
      case Recurrence.daily:
        return true;
      case Recurrence.weekly:
        return Weekdays.contains(daysOfWeek, date.weekday);
      case Recurrence.everyNDays:
        if (interval <= 0) return false;
        return startDate.daysUntil(date) % interval == 0;
      case Recurrence.monthly:
        return date.day == effectiveDayOfMonth(date.year, date.month);
    }
  }

  /// The first occurrence on or after [from], or null if the rule is finished.
  ///
  /// Used by the Today screen's "next up" and, from step 3, by the notification
  /// scheduler filling its rolling window. Each branch jumps straight to the
  /// candidate rather than walking day by day, so an inactive rule with a
  /// distant start costs the same as a rule firing tomorrow.
  CalendarDate? nextOccurrenceOnOrAfter(CalendarDate from) {
    if (!isActive) return null;
    var cursor = from.isBefore(startDate) ? startDate : from;
    final end = endDate;

    CalendarDate? guard(CalendarDate? candidate) {
      if (candidate == null) return null;
      if (end != null && candidate.isAfter(end)) return null;
      return candidate;
    }

    switch (recurrence) {
      case Recurrence.once:
        return guard(cursor.isAfter(startDate) ? null : startDate);
      case Recurrence.daily:
        return guard(cursor);
      case Recurrence.weekly:
        if (daysOfWeek & Weekdays.everyDay == 0) return null;
        for (var i = 0; i < 7; i++) {
          final candidate = cursor.addDays(i);
          if (Weekdays.contains(daysOfWeek, candidate.weekday)) {
            return guard(candidate);
          }
        }
        return null;
      case Recurrence.everyNDays:
        if (interval <= 0) return null;
        final elapsed = startDate.daysUntil(cursor);
        final remainder = elapsed % interval;
        return guard(remainder == 0 ? cursor : cursor.addDays(interval - remainder));
      case Recurrence.monthly:
        // At most two probes: this month, then next. The clamped target day in
        // the current month may already have passed.
        var year = cursor.year;
        var month = cursor.month;
        for (var i = 0; i < 2; i++) {
          final target = CalendarDate(
            year,
            month,
            effectiveDayOfMonth(year, month),
          );
          if (!target.isBefore(cursor)) return guard(target);
          month++;
          if (month > 12) {
            month = 1;
            year++;
          }
        }
        return null;
    }
  }
}
