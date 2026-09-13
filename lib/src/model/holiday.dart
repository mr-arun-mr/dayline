import 'calendar_date.dart';

/// What a holiday closes.
///
/// Deliberately not one flat "it is a holiday". A school inset day is not an
/// office closure, and a week of annual leave is not a school holiday — a
/// parent who marked half-term and then lost their own work reminders would
/// have been told something false about their day.
///
/// The stored [code] is what goes in SQLite, and is explicit so that
/// reordering or inserting values can never silently reinterpret a saved row.
enum HolidayScope {
  work(0),
  school(1);

  const HolidayScope(this.code);

  final int code;

  /// Position in a [HolidayScopes] mask.
  int get bit => 1 << code;

  static HolidayScope? fromCode(int code) {
    for (final scope in values) {
      if (scope.code == code) return scope;
    }
    // An unknown code is a row written by a newer build. Dropping the link is
    // safer than guessing at it: the event simply never pauses.
    return null;
  }
}

/// A set of [HolidayScope]s as a bitmask, so one holiday row can close both.
abstract final class HolidayScopes {
  static const none = 0;
  static const work = 1;
  static const school = 2;

  /// The ordinary public holiday: nobody is anywhere.
  static const everything = work | school;

  static bool contains(int mask, HolidayScope scope) => mask & scope.bit != 0;

  static int of(Iterable<HolidayScope> scopes) =>
      scopes.fold(none, (mask, scope) => mask | scope.bit);

  static List<HolidayScope> from(int mask) =>
      [for (final scope in HolidayScope.values) if (contains(mask, scope)) scope];
}

/// A day, or a run of days, when some part of the week does not happen.
///
/// A range rather than a single date because a week off is the common case and
/// ticking seven days one at a time is not a feature. A single day is simply a
/// range whose ends are equal.
class Holiday {
  const Holiday({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.scopes = HolidayScopes.everything,
  });

  final int id;
  final String name;

  /// First day off. Inclusive.
  final CalendarDate startDate;

  /// Last day off. Inclusive, and equal to [startDate] for a single day.
  final CalendarDate endDate;

  /// Which scopes are closed, as a [HolidayScopes] mask.
  final int scopes;

  bool get isSingleDay => startDate == endDate;

  int get days => startDate.daysUntil(endDate) + 1;

  /// Whether [date] falls inside this holiday.
  ///
  /// Integer comparison on calendar dates, like every other date question in
  /// this app, so a clock change cannot move a day in or out of a holiday.
  bool covers(CalendarDate date) =>
      !date.isBefore(startDate) && !date.isAfter(endDate);

  bool closes(HolidayScope scope) => HolidayScopes.contains(scopes, scope);
}

/// The holidays covering [date], in the order they start.
List<Holiday> holidaysOn(Iterable<Holiday> holidays, CalendarDate date) =>
    holidays.where((holiday) => holiday.covers(date)).toList()
      ..sort((a, b) => a.startDate.epochDay.compareTo(b.startDate.epochDay));

/// Whether an event belonging to [scope] does not happen on [date].
///
/// An event with no scope belongs to nobody's timetable and is never paused:
/// medication is still medication on Christmas Day, and that is the default.
bool pausedByHoliday(
  HolidayScope? scope,
  Iterable<Holiday> holidays,
  CalendarDate date,
) {
  if (scope == null) return false;
  return holidays.any((holiday) => holiday.covers(date) && holiday.closes(scope));
}

/// Every scope closed on [date], for saying so on the day itself.
Set<HolidayScope> scopesClosedOn(
  Iterable<Holiday> holidays,
  CalendarDate date,
) =>
    {
      for (final holiday in holidays)
        if (holiday.covers(date))
          for (final scope in HolidayScopes.from(holiday.scopes)) scope,
    };
