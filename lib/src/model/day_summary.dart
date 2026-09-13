import 'event.dart';
import 'occurrence.dart';

/// Where an occurrence belongs on the Today screen.
enum DaySection {
  /// Its time has gone and nothing was done about it.
  overdue,

  /// The next thing that has not happened yet. At most one.
  nextUp,

  /// Still to come.
  later,

  /// Dealt with, one way or the other. Collapsed by default.
  done,
}

/// A day, sorted into the sections the Today screen draws.
///
/// Pure, so the rules about what counts as overdue — and what the progress
/// ring divides by — can be tested without building a widget.
class DaySummary {
  const DaySummary({
    required this.overdue,
    required this.nextUp,
    required this.later,
    required this.done,
    required this.isToday,
  });

  factory DaySummary.from({
    required List<Occurrence> occurrences,
    required DateTime now,
    required bool isToday,
  }) {
    final overdue = <Occurrence>[];
    final later = <Occurrence>[];
    final done = <Occurrence>[];
    Occurrence? nextUp;

    for (final occurrence in occurrences) {
      if (!occurrence.isPending) {
        done.add(occurrence);
        continue;
      }
      // On any day but today there is no "now" to be on the wrong side of, so
      // everything pending is simply still to come.
      if (!isToday) {
        later.add(occurrence);
        continue;
      }
      if (occurrence.isPast(now)) {
        overdue.add(occurrence);
      } else if (nextUp == null) {
        nextUp = occurrence;
      } else {
        later.add(occurrence);
      }
    }

    return DaySummary(
      overdue: overdue,
      nextUp: nextUp,
      later: later,
      done: done,
      isToday: isToday,
    );
  }

  final List<Occurrence> overdue;
  final Occurrence? nextUp;
  final List<Occurrence> later;
  final List<Occurrence> done;
  final bool isToday;

  bool get isEmpty =>
      overdue.isEmpty && nextUp == null && later.isEmpty && done.isEmpty;

  /// Everything on the day that was a plan.
  ///
  /// Rows the app wrote to record a visit are not counted. The ring answers
  /// "how much of what I meant to do did I do", and a place the phone noticed
  /// you were at was never on that list — counting it would inflate both
  /// halves of the fraction and quietly make every day look better.
  int get total => overdue.length + (nextUp == null ? 0 : 1) + later.length +
      done.where((o) => !o.isVisitRecord).length;

  /// How many were actually done, as opposed to consciously skipped.
  int get doneCount => done
      .where((o) => o.status == CompletionStatus.done && !o.isVisitRecord)
      .length;

  int get skippedCount => done
      .where((o) => o.status == CompletionStatus.skipped && !o.isVisitRecord)
      .length;

  /// The visits filed onto this day. Shown, never counted.
  List<Occurrence> get visitRecords =>
      done.where((o) => o.isVisitRecord).toList();

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

  /// Whether to draw the now line, which sits directly below Overdue.
  ///
  /// Only on today, and only when something is actually behind it. With
  /// nothing overdue the boundary is the top of the list, and a line there
  /// separates the day from nothing at all.
  bool get showsNowDivider => isToday && overdue.isNotEmpty;
}
