import 'event.dart';
import 'occurrence.dart';

/// Where an occurrence sits on the Today screen.
enum DaySection {
  /// Already happened: a stay, a finished event, or one whose time has gone.
  earlier,

  /// The next thing that has not happened yet. At most one.
  nextUp,

  /// Still to come.
  later,
}

/// A day in the order it happened, sorted into the parts the Today screen
/// draws.
///
/// One line, not four piles. Everything the day contains keeps its place in
/// time — a finished event stays where it was done rather than being swept
/// into a heap at the bottom, and a stay sits between the events either side
/// of it. What was *planned* is counted separately from what merely happened,
/// which is the one distinction the progress ring cares about.
///
/// Pure, so the rules about what counts as overdue — and what the ring divides
/// by — can be tested without building a widget.
class DaySummary {
  const DaySummary({
    required this.earlier,
    required this.nextUp,
    required this.later,
    required this.plans,
    required this.visits,
    required this.isToday,
  });

  factory DaySummary.from({
    required List<Occurrence> occurrences,
    required DateTime now,
    required bool isToday,
  }) {
    final earlier = <Occurrence>[];
    final later = <Occurrence>[];
    final plans = <Occurrence>[];
    final visits = <Occurrence>[];
    Occurrence? nextUp;

    for (final occurrence in occurrences) {
      // Somewhere the device went is a record of the day, not a plan for it.
      // It is never counted, and — unlike an event — never hidden: there is
      // nothing to tick off and nothing to tidy away.
      if (occurrence.isVisitRecord) {
        visits.add(occurrence);
      } else {
        plans.add(occurrence);
      }

      // A stay has, by definition, already happened.
      if (occurrence.isVisitRecord || occurrence.isPast(now)) {
        earlier.add(occurrence);
        continue;
      }
      // The first thing still to come is drawn as a card of its own, and only
      // on today: on another day there is no "next" to count down to.
      if (isToday && nextUp == null && occurrence.isPending) {
        nextUp = occurrence;
        continue;
      }
      later.add(occurrence);
    }

    return DaySummary(
      earlier: earlier,
      nextUp: nextUp,
      later: later,
      plans: plans,
      visits: visits,
      isToday: isToday,
    );
  }

  /// The part of the day that has already happened, in the order it did.
  ///
  /// Events and stays together: a finished event, one whose time went by
  /// without being touched, and the places the device was — the day as it
  /// turned out, rather than three separate accounts of it.
  final List<Occurrence> earlier;

  final Occurrence? nextUp;

  /// Still to come, in order. [nextUp] is drawn separately and left out.
  final List<Occurrence> later;

  /// Everything on the day that was a plan, whatever became of it.
  ///
  /// The ring answers "how much of what I meant to do did I do", so a place
  /// the phone noticed you were at is not in here — counting it would inflate
  /// both halves of the fraction and quietly make every day look better.
  final List<Occurrence> plans;

  /// The stays filed onto this day, in the order they happened.
  final List<Occurrence> visits;

  final bool isToday;

  /// Plans whose time has gone with nothing done about them.
  ///
  /// Only today: on another day there is no "now" to be on the wrong side of.
  List<Occurrence> get overdue => isToday
      ? earlier.where((o) => o.isPending && !o.isVisitRecord).toList()
      : const [];

  /// Plans that have been ticked or skipped — the ones the day list can be
  /// asked to hide, and the only ones.
  List<Occurrence> get done => plans.where((o) => !o.isPending).toList();

  bool get isEmpty => earlier.isEmpty && nextUp == null && later.isEmpty;

  int get total => plans.length;

  /// How many were actually done, as opposed to consciously skipped.
  int get doneCount =>
      plans.where((o) => o.status == CompletionStatus.done).length;

  int get skippedCount =>
      plans.where((o) => o.status == CompletionStatus.skipped).length;

  /// The denominator of "3 of 6 done".
  ///
  /// Skipped occurrences come out of it entirely. The user decided that one
  /// was not happening today, and a ring that punishes them for saying so is
  /// a ring that teaches them not to say so.
  int get expected => total - skippedCount;

  double get progress => expected == 0 ? 0 : doneCount / expected;

  bool get isComplete => expected > 0 && doneCount == expected;

  /// "3 of 6 done", or something kinder when there is nothing to count.
  String get progressLabel {
    if (total == 0) return 'Nothing scheduled';
    if (expected == 0) return 'All skipped';
    return '$doneCount of $expected done';
  }

  /// Whether to draw the now line, which sits between what has happened and
  /// what has not.
  ///
  /// Only on today, and only when something is actually behind it. With an
  /// empty morning the boundary is the top of the list, and a line there
  /// separates the day from nothing at all.
  bool get showsNowDivider => isToday && earlier.isNotEmpty;
}
