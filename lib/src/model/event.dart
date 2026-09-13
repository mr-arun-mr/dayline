import 'calendar_date.dart';
import 'holiday.dart';
import 'recurrence.dart';

/// A recurrence rule plus everything the UI needs to draw it.
///
/// One row in `events`. Occurrences are never stored — they are expanded from
/// this on demand for whichever date is being shown.
class Event {
  const Event({
    required this.id,
    required this.title,
    required this.colorValue,
    required this.rule,
    this.notes,
    this.durationMin,
    this.leadMinutes = const [],
    this.placeId,
    this.autoCompleteOnArrival = false,
    this.fromVisitId,
    this.holidayScope,
  });

  final int id;
  final String title;
  final String? notes;

  /// ARGB, as [Color.value] would give.
  final int colorValue;

  /// How long the thing takes, if the user said. Display only.
  final int? durationMin;

  /// Minutes *before* the occurrence to fire a reminder, e.g. `[60, 10]`.
  /// Stored as a JSON list. Sorted descending by convention.
  final List<int> leadMinutes;

  final EventRule rule;

  /// Optionally ties this routine to a place, which is what makes "did you
  /// actually go to the gym when the reminder fired" answerable. Null for the
  /// many routines that happen nowhere in particular.
  final int? placeId;

  /// Whether arriving at [placeId] around the time this is due ticks it off
  /// without the user having to.
  final bool autoCompleteOnArrival;

  /// Only true when there is somewhere to arrive at. A rule can carry the flag
  /// with no place — clearing the place does not clear it — and that rule
  /// simply never completes itself.
  bool get completesOnArrival => autoCompleteOnArrival && placeId != null;

  /// The stay this event was written to record, if the app wrote it rather
  /// than the user.
  final int? fromVisitId;

  /// Whether this is somewhere the user went rather than something they meant
  /// to do. Both belong on the day; only the second is a plan, so only the
  /// second is counted, listed under All events, or judged on the dashboard.
  bool get isVisitRecord => fromVisitId != null;

  /// Which timetable this belongs to, and so which holidays cancel it.
  ///
  /// Null for almost everything. An event only has a scope if it belongs to
  /// something that closes — the school run, the standup — and everything
  /// else goes on happening whatever the calendar says.
  final HolidayScope? holidayScope;

  /// Whether this event does not happen on [date], given [holidays].
  bool isPausedOn(CalendarDate date, Iterable<Holiday> holidays) =>
      pausedByHoliday(holidayScope, holidays, date);

  int get timeOfDay => rule.timeOfDay;
  Recurrence get recurrence => rule.recurrence;
  bool get isActive => rule.isActive;
  CalendarDate get startDate => rule.startDate;
  CalendarDate? get endDate => rule.endDate;
}

/// What the user did about a single occurrence.
enum CompletionStatus {
  done(0),
  skipped(1);

  const CompletionStatus(this.code);

  final int code;

  static CompletionStatus fromCode(int code) =>
      CompletionStatus.values.firstWhere((s) => s.code == code);
}

/// A deliberate, one-off change to a single occurrence.
enum OverrideType {
  /// This one occurrence does not happen. Distinct from
  /// [CompletionStatus.skipped], which records that the user consciously let it
  /// go and still wants it counted in the day's tally.
  skip(0),

  /// This one occurrence happens at a different wall-clock time.
  moved(1);

  const OverrideType(this.code);

  final int code;

  static OverrideType fromCode(int code) =>
      OverrideType.values.firstWhere((t) => t.code == code);
}

/// A row in `overrides`: "on this date, this event is different".
class EventOverride {
  const EventOverride({
    required this.eventId,
    required this.date,
    required this.type,
    this.newTimeOfDay,
  });

  final int eventId;
  final CalendarDate date;
  final OverrideType type;

  /// Minutes since midnight, wall clock. Set for [OverrideType.moved] only.
  /// A move stays within the same calendar day; moving to another day is a
  /// different gesture and is not modelled here.
  final int? newTimeOfDay;
}

/// A row in `completions`. Written only when the user acts, so an untouched
/// day costs zero rows.
class Completion {
  const Completion({
    required this.eventId,
    required this.date,
    required this.status,
    required this.completedAt,
    this.isAutomatic = false,
  });

  final int eventId;
  final CalendarDate date;
  final CompletionStatus status;

  /// When the user tapped. A real instant, so this one *is* a UTC-backed
  /// timestamp — unlike anything schedule-shaped.
  final DateTime completedAt;

  /// True when the app wrote this on arrival at a place rather than the user
  /// marking it. The row says so, and so does the UI.
  final bool isAutomatic;
}
