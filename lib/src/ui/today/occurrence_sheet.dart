import 'package:flutter/material.dart';

import '../../model/occurrence.dart';
import '../../model/recurrence.dart';
import '../../model/rule_description.dart';
import '../theme.dart';

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
        );
      },
    );

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
