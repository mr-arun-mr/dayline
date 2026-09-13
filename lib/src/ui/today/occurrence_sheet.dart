import 'package:flutter/material.dart';

import '../../model/occurrence.dart';
import '../../model/recurrence.dart';
import '../../model/rule_description.dart';
import '../theme.dart';
import 'occurrence_tile.dart';

/// What a long press on a row offers.
enum OccurrenceAction { markDone, markSkipped, clear, move, editSeries }

/// The per-occurrence sheet: deal with today without touching the series.
Future<OccurrenceAction?> showOccurrenceSheet(
  BuildContext context,
  Occurrence occurrence,
) =>
    showModalBottomSheet<OccurrenceAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final isRecurring = occurrence.event.recurrence != Recurrence.once;

        return SafeArea(
          // Scrollable rather than a plain Column: with a planned-against-
          // actual block above four actions, a recurring event at a place is
          // taller than the sheet's own height cap on a small phone, and a
          // Column there simply overflows.
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DaylineTheme.gutter,
                  0,
                  DaylineTheme.gutter,
                  4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      occurrence.event.title,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatWallClock(occurrence.effectiveTimeOfDay)} · '
                      '${formatMediumDate(occurrence.date)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (occurrence.visit != null) ...[
                      const SizedBox(height: 10),
                      _PlannedVersusActual(occurrence: occurrence),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (occurrence.isPending) ...[
                _Action(
                  icon: Icons.check_circle_outline,
                  label: 'Mark done',
                  action: OccurrenceAction.markDone,
                ),
                _Action(
                  icon: Icons.remove_circle_outline,
                  label: 'Skip today',
                  subtitle: 'Let this one go without it counting against you',
                  action: OccurrenceAction.markSkipped,
                ),
              ] else
                _Action(
                  icon: Icons.undo,
                  label: occurrence.isDone ? 'Not done after all' : 'Un-skip',
                  action: OccurrenceAction.clear,
                ),
              if (isRecurring)
                _Action(
                  icon: Icons.schedule,
                  label: 'Move today',
                  subtitle: 'Change the time for this day only',
                  action: OccurrenceAction.move,
                ),
              _Action(
                icon: Icons.edit_outlined,
                label: 'Edit series',
                subtitle: isRecurring
                    ? 'Changes every occurrence'
                    : 'Edit this event',
                action: OccurrenceAction.editSeries,
              ),
              const SizedBox(height: 12),
            ],
          ),
          ),
        );
      },
    );

/// What was meant to happen, and what did.
///
/// The row on the day only has room for the second half. Here there is space
/// to put them side by side, which is the comparison the whole place feature
/// exists to make: the class was at 07:00, you were in the building from 07:04
/// until 08:12.
class _PlannedVersusActual extends StatelessWidget {
  const _PlannedVersusActual({required this.occurrence});

  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visit = occurrence.visit!;
    final departed = visit.departedAt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _Half(
            label: 'Planned',
            value: formatWallClock(occurrence.effectiveTimeOfDay),
            // An event with no stated length has nothing to close with.
            detail: switch (occurrence.event.durationMin) {
              final minutes? => 'for ${_shortDuration(minutes)}',
              null => null,
            },
          ),
          const SizedBox(width: 16),
          Icon(Icons.arrow_forward, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 16),
          _Half(
            label: 'Actually there',
            value: formatActualTimes(occurrence) ?? '—',
            detail: departed == null
                ? null
                : _shortDuration(departed.difference(visit.arrivedAt).inMinutes),
          ),
        ],
      ),
    );
  }
}

String _shortDuration(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

class _Half extends StatelessWidget {
  const _Half({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)
                .merge(monospacedFigures),
          ),
          if (detail case final detail?) ...[
            const SizedBox(height: 1),
            Text(
              detail,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.action,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final OccurrenceAction action;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: DaylineTheme.rowMinHeight,
    leading: Icon(icon),
    title: Text(label),
    subtitle: subtitle == null ? null : Text(subtitle!),
    onTap: () => Navigator.of(context).pop(action),
  );
}
