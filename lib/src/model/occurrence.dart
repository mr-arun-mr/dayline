import 'calendar_date.dart';
import 'event.dart';
import 'place.dart';

/// One expanded instance of an event on one date — what a row on the Today
/// screen is. Never persisted.
class Occurrence {
  const Occurrence({
    required this.event,
    required this.date,
    required this.effectiveTimeOfDay,
    this.status,
    this.completedAt,
    this.isMoved = false,
    this.isAutomatic = false,
    this.visit,
  });

  final Event event;
  final CalendarDate date;

  /// Minutes since midnight, wall clock, after any MOVED override.
  final int effectiveTimeOfDay;

  /// The rule's original time, before any move. Shown struck through when the
  /// occurrence was moved.
  int get scheduledTimeOfDay => event.timeOfDay;

  /// True when a MOVED override shifted this one occurrence.
  final bool isMoved;

  /// Null while the user has not acted on this occurrence yet.
  final CompletionStatus? status;
  final DateTime? completedAt;

  /// True when the tick came from arriving at the event's place rather than
  /// from the user. Shown on the row, so a tick nobody remembers making has an
  /// explanation attached.
  final bool isAutomatic;

  /// The stay at this event's place that lines up with it, when there is one.
  ///
  /// What turns a planned time into a planned *and actual* one: the row can
  /// say the gym was at 07:00 and that you were in it from 07:04 to 08:12.
  /// Null for an event tied to nowhere, for a day the phone was not watching,
  /// and for one where you simply did not go.
  final Visit? visit;

  /// When the user actually got there, if it was noticed.
  DateTime? get arrivedAt => visit?.arrivedAt;

  /// When they left. Null while they are still there, or were never seen.
  DateTime? get departedAt => visit?.departedAt;

  /// True while the device is still inside the place's fence.
  bool get isStillThere => visit != null && visit!.isOpen;

  /// Whether this row is a record of somewhere the user went rather than
  /// something they planned.
  bool get isVisitRecord => event.isVisitRecord;

  int get eventId => event.id;

  bool get isDone => status == CompletionStatus.done;
  bool get isSkipped => status == CompletionStatus.skipped;
  bool get isPending => status == null;

  /// This occurrence's wall clock as a local [DateTime] — the only place the
  /// schedule meets the timezone, and only for display and alarm scheduling.
  DateTime get localStart => date.localDateTimeAt(effectiveTimeOfDay);

  /// Whether this occurrence's time has already passed, relative to [now].
  bool isPast(DateTime now) => localStart.isBefore(now);

  Occurrence copyWith({
    int? effectiveTimeOfDay,
    bool? isMoved,
    CompletionStatus? status,
    DateTime? completedAt,
    bool? isAutomatic,
    Visit? visit,
  }) => Occurrence(
    event: event,
    date: date,
    effectiveTimeOfDay: effectiveTimeOfDay ?? this.effectiveTimeOfDay,
    isMoved: isMoved ?? this.isMoved,
    status: status ?? this.status,
    completedAt: completedAt ?? this.completedAt,
    isAutomatic: isAutomatic ?? this.isAutomatic,
    visit: visit ?? this.visit,
  );
}
