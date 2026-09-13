import 'package:flutter/material.dart';

import '../../model/occurrence.dart';
import '../../model/rule_description.dart';
import '../event_colors.dart';
import '../theme.dart';

/// One event on one day: time, colour, title.
///
/// The row is built around the time column, because reading down a straight
/// column of clock times is what makes the day scannable at a glance.
class OccurrenceTile extends StatelessWidget {
  const OccurrenceTile({
    required this.occurrence,
    required this.isPast,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final Occurrence occurrence;

  /// Whether its time has already gone by. Dims the row rather than hiding it.
  final bool isPast;

  /// Marking done and back again.
  final VoidCallback? onTap;

  /// The per-occurrence sheet.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colour = EventColors.of(occurrence.event.colorValue);
    final dim = isPast ? 0.45 : 1.0;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: DaylineTheme.rowMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DaylineTheme.gutter,
            vertical: 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Opacity(
                opacity: dim,
                child: _TimeColumn(occurrence: occurrence),
              ),
              const SizedBox(width: 14),
              Opacity(
                opacity: dim,
                child: Container(
                  width: 4,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colour,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Opacity(
                  opacity: dim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                      if (_subtitle(occurrence) case final subtitle?) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusMark(occurrence: occurrence),
            ],
          ),
        ),
      ),
    );
  }

  static String? _subtitle(Occurrence occurrence) {
    final parts = <String>[
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
      width: 52,
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
