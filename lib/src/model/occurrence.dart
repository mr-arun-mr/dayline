import 'calendar_date.dart';
import 'event.dart';

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
  }) => Occurrence(
    event: event,
    date: date,
    effectiveTimeOfDay: effectiveTimeOfDay ?? this.effectiveTimeOfDay,
    isMoved: isMoved ?? this.isMoved,
    status: status ?? this.status,
    completedAt: completedAt ?? this.completedAt,
  );
}
