import 'calendar_date.dart';
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
  });

  final int eventId;
  final CalendarDate date;
  final CompletionStatus status;

  /// When the user tapped. A real instant, so this one *is* a UTC-backed
  /// timestamp — unlike anything schedule-shaped.
  final DateTime completedAt;
}
