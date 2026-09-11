import 'package:flutter/material.dart';

import '../../model/calendar_date.dart';
import '../../model/recurrence.dart';
import '../../model/rule_description.dart';
import '../theme.dart';

/// How much of a series a delete should take with it.
enum DeleteScope {
  /// Just the day being looked at. The rest of the series carries on.
  thisOccurrence,

  /// This day and every one after it. Days already lived through are kept,
  /// along with whatever was recorded against them.
  thisAndFollowing,

  /// The rule itself, and all its history.
  allOccurrences,
}

/// Asks which of the three a delete means.
///
/// A one-off has only one answer, so it gets a plain confirmation instead of a
/// menu — offering "this and following" for an event that happens once is
/// three ways of saying the same thing.
Future<DeleteScope?> showDeleteScopeSheet(
  BuildContext context, {
  required String title,
  required Recurrence recurrence,
  required CalendarDate? occurrenceDate,
}) {
  final isSeries =
      recurrence != Recurrence.once && occurrenceDate != null;

  if (!isSeries) {
    return showDialog<DeleteScope>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$title"?'),
        content: const Text(
          'The event and everything recorded against it will be removed. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(DeleteScope.allOccurrences),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  final date = formatMediumDate(occurrenceDate);

  return showModalBottomSheet<DeleteScope>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
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
                8,
              ),
              child: Text(
                'Delete "$title"',
                style: theme.textTheme.titleLarge,
              ),
            ),
            _ScopeOption(
              icon: Icons.event_busy_outlined,
              title: 'This occurrence',
              subtitle: 'Only $date. The rest of the series stays.',
              scope: DeleteScope.thisOccurrence,
            ),
            _ScopeOption(
              icon: Icons.playlist_remove,
              title: 'This and all following',
              subtitle: 'Ends the series. Everything before $date is kept.',
              scope: DeleteScope.thisAndFollowing,
            ),
            _ScopeOption(
              icon: Icons.delete_outline,
              title: 'All occurrences',
              subtitle: 'Removes the event and its whole history.',
              scope: DeleteScope.allOccurrences,
              isDestructive: true,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DaylineTheme.gutter,
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class _ScopeOption extends StatelessWidget {
  const _ScopeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.scope,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final DeleteScope scope;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = isDestructive ? scheme.error : scheme.onSurface;
    return ListTile(
      minTileHeight: DaylineTheme.rowMinHeight,
      leading: Icon(icon, color: colour),
      title: Text(title, style: TextStyle(color: colour)),
      subtitle: Text(subtitle),
      onTap: () => Navigator.of(context).pop(scope),
    );
  }
}
