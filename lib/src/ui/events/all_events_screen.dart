import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/event.dart';
import '../../model/rule_description.dart';
import '../../providers.dart';
import '../edit/edit_event_screen.dart';
import '../event_colors.dart';
import '../theme.dart';

/// Every rule in one list: what it is, when it fires, and how it is going.
class AllEventsScreen extends ConsumerWidget {
  const AllEventsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const AllEventsScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(allEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('All events')),
      body: switch (events) {
        AsyncData(:final value) when value.isEmpty => const _Empty(),
        AsyncData(:final value) => ListView.separated(
          padding: const EdgeInsets.only(bottom: 32),
          itemCount: value.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) => _EventRow(event: value[index]),
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _EventRow extends ConsumerWidget {
  const _EventRow({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final streak = ref.watch(streakProvider(event.id)).value;

    return Dismissible(
      key: ValueKey('event-${event.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: DaylineTheme.gutter),
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      // Confirmed rather than undone: deleting a rule takes its whole history
      // with it, and an undo snackbar is easy to miss.
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete "${event.title}"?'),
          content: const Text(
            'The rule and everything recorded against it will be removed. '
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
      onDismissed: (_) => ref.read(eventsDaoProvider).deleteEvent(event.id),
      child: Opacity(
        // A paused rule stays in the list but stops shouting.
        opacity: event.isActive ? 1 : 0.55,
        child: ListTile(
          minTileHeight: DaylineTheme.rowMinHeight,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: DaylineTheme.gutter,
            vertical: 6,
          ),
          leading: Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: EventColors.of(event.colorValue),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          title: Text(event.title, style: theme.textTheme.titleMedium),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(describeRule(event.rule)),
              if (streak != null && streak.current > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      '${streak.current} in a row'
                      '${streak.longest > streak.current
                          ? ' · best ${streak.longest}'
                          : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          trailing: Switch(
            value: event.isActive,
            onChanged: (value) =>
                ref.read(eventsDaoProvider).setActive(event.id, value),
          ),
          onTap: () => EditEventScreen.open(context, eventId: event.id),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_outlined,
                size: 44, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No events yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
