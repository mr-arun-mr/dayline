import 'package:flutter/material.dart';

import '../../model/occurrence.dart';
import '../../model/rule_description.dart';
import '../day_rail.dart';
import '../event_colors.dart';
import '../theme.dart';

/// One event on one day: time, marker, title.
///
/// The row is built around the time column, because reading down a straight
/// column of clock times is what makes the day scannable at a glance — and
/// beside it the day's thread, which every row hangs from. A done event keeps
/// its place on that thread rather than being swept into a pile at the
/// bottom: it happened, and where it happened in the day is part of the day.
class OccurrenceTile extends StatelessWidget {
  const OccurrenceTile({
    required this.occurrence,
    required this.isPast,
    this.linkedAbove = true,
    this.linkedBelow = true,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final Occurrence occurrence;

  /// Whether its time has already gone by. Dims the row rather than hiding it.
  final bool isPast;

  /// Whether the day's thread carries on to the row above or below.
  final bool linkedAbove;
  final bool linkedBelow;

  /// Marking done and back again.
  final VoidCallback? onTap;

  /// The per-occurrence sheet.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colour = EventColors.of(occurrence.event.colorValue);
    // Its time has gone and nothing has been done about it. Not dimmed and
    // not tucked away: it is the one thing on the day still asking for
    // something.
    final overdue = isPast && occurrence.isPending;
    // Dealt with, so it can recede — but it keeps its place in the day.
    final dim = occurrence.isPending ? 1.0 : 0.45;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: DaylineTheme.rowMinHeight,
        ),
        // The row's own padding is on its contents rather than around them, so
        // that the thread runs the full height and one row's line meets the
        // next instead of stopping short of it.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: DaylineTheme.gutter),
              Center(
                child: Opacity(
                  opacity: dim,
                  child: _TimeColumn(occurrence: occurrence),
                ),
              ),
              const SizedBox(width: DaylineTheme.railGap),
              DayRail.moment(
                colour: colour,
                // Filled once it has been dealt with, hollow while it is still
                // waiting to be.
                filled: !occurrence.isPending,
                linkedAbove: linkedAbove,
                linkedBelow: linkedBelow,
              ),
              const SizedBox(width: DaylineTheme.railGap),
              Expanded(
                child: Opacity(
                  opacity: dim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          occurrence.event.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            decoration: occurrence.isPending
                                ? null
                                : TextDecoration.lineThrough,
                            color: occurrence.isPending
                                ? null
                                : scheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_subtitle(occurrence, overdue)
                            case final subtitle?) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: overdue
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Center(child: _StatusMark(occurrence: occurrence)),
              const SizedBox(width: DaylineTheme.gutter),
            ],
          ),
        ),
      ),
    );
  }

  static String? _subtitle(Occurrence occurrence, bool overdue) {
    final parts = <String>[
      // Said on the row rather than by a section of its own, now that the day
      // is one line: the row is in its place in the day, and this is what is
      // wrong with it.
      if (overdue) 'Overdue',
      if (occurrence.isSkipped) 'Skipped',
      // Why this row exists at all, for one the user did not write.
      if (occurrence.isVisitRecord) 'Visited',
      // A tick the user does not remember making needs a reason attached, so
      // this comes early: it is the answer to "why is that already done?".
      if (occurrence.isDone &&
          occurrence.isAutomatic &&
          !occurrence.isVisitRecord)
        'Done on arrival',
      // The planned time is already the column on the left. This is the other
      // half of the row's job: when the user was actually there.
      ?formatActualTimes(occurrence),
      if (occurrence.isMoved)
        'Moved from ${formatWallClock(occurrence.scheduledTimeOfDay)}',
      if (occurrence.event.durationMin case final minutes?)
        _formatDuration(minutes),
      if (occurrence.event.notes case final notes?
          when notes.trim().isNotEmpty)
        notes.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }
}

/// "07:04 → 08:12" for a stay that is over, "07:04 → still there" for one that
/// is not, and nothing at all when there is no stay to report.
///
/// Deliberately silent rather than negative when nothing matched. No arrival
/// recorded means one of two things — the user did not go, or the phone was
/// never watching — and the row has no way to tell them apart. Saying
/// "missed" when background location was simply switched off would be the app
/// inventing a fact about someone's day.
String? formatActualTimes(Occurrence occurrence) {
  final visit = occurrence.visit;
  if (visit == null) return null;

  final arrived = _clock(visit.arrivedAt);
  final departed = visit.departedAt;
  return departed == null
      ? '$arrived → still there'
      : '$arrived → ${_clock(departed)}';
}

String _clock(DateTime at) =>
    formatWallClock(at.hour * 60 + at.minute);

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({required this.occurrence});

  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: DaylineTheme.timeColumnWidth,
      child: Text(
        formatWallClock(occurrence.effectiveTimeOfDay),
        textAlign: TextAlign.right,
        style: theme.textTheme.titleMedium
            ?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            )
            .merge(monospacedFigures),
      ),
    );
  }
}

/// The tick, or the empty circle waiting for one.
///
/// A real target rather than decoration: the row's whole width is tappable,
/// but the mark is where the eye goes, so it has to look pressable.
class _StatusMark extends StatelessWidget {
  const _StatusMark({required this.occurrence});

  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (occurrence.isSkipped) {
      return Icon(Icons.remove_circle_outline,
          size: 26, color: scheme.onSurfaceVariant);
    }
    if (occurrence.isDone) {
      return Icon(
        // A different tick for a tick nobody made: still unmistakably done,
        // but visibly not the one the user pressed.
        occurrence.isAutomatic ? Icons.where_to_vote : Icons.check_circle,
        size: 26,
        color: _doneGreen,
      );
    }
    return Icon(Icons.circle_outlined, size: 26, color: scheme.outline);
  }

  static const _doneGreen = Color(0xFF10B981);
}
