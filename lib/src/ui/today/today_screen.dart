import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/calendar_date.dart';
import '../../model/occurrence.dart';
import '../../model/rule_description.dart';
import '../../providers.dart';
import '../edit/edit_event_screen.dart';
import '../theme.dart';
import 'battery_card.dart';
import 'day_strip.dart';
import 'next_up_card.dart';
import 'now_divider.dart';
import 'occurrence_tile.dart';

/// The home screen: one line of a day's events, in order.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final selected = ref.watch(selectedDateProvider);
    final occurrences = ref.watch(occurrencesProvider(selected));
    final now = ref.watch(clockProvider)();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(today: today, selected: selected),
            DayStrip(
              today: today,
              selected: selected,
              onSelected: (date) =>
                  ref.read(selectedDateProvider.notifier).select(date),
            ),
            const Divider(height: 1),
            const BatteryOptimisationCard(),
            Expanded(
              child: switch (occurrences) {
                AsyncData(:final value) => _DayList(
                  now: now,
                  isToday: selected == today,
                  occurrences: value,
                ),
                AsyncError(:final error) => _ErrorState(error: error),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => EditEventScreen.open(context, initialDate: selected),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.today, required this.selected});

  final CalendarDate today;
  final CalendarDate selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final offset = today.daysUntil(selected);
    final relative = switch (offset) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        12,
        DaylineTheme.gutter - 8,
        4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  relative ?? formatDayAndMonth(selected),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  relative == null
                      ? '${selected.year}'
                      : formatDayAndMonth(selected),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (offset != 0)
            TextButton(
              onPressed: () =>
                  ref.read(selectedDateProvider.notifier).goToToday(),
              child: const Text('Today'),
            ),
        ],
      ),
    );
  }
}

/// The day itself: every occurrence in order, with the now line threaded
/// through it and the next one up given a card.
class _DayList extends StatelessWidget {
  const _DayList({
    required this.now,
    required this.isToday,
    required this.occurrences,
  });

  final DateTime now;
  final bool isToday;
  final List<Occurrence> occurrences;

  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty) return _EmptyState(isToday: isToday);

    // The first thing that has not happened yet. Everything before it is past,
    // and it is the one that gets the card.
    final nextIndex = isToday
        ? occurrences.indexWhere((o) => !o.isPast(now))
        : -1;

    final children = <Widget>[];
    for (var i = 0; i < occurrences.length; i++) {
      final occurrence = occurrences[i];
      if (i == nextIndex) children.add(NowDivider(now: now));

      children.add(
        i == nextIndex
            ? NextUpCard(
                key: ValueKey('next-${occurrence.eventId}'),
                occurrence: occurrence,
                onTap: () => EditEventScreen.open(
                  context,
                  eventId: occurrence.eventId,
                  occurrenceDate: occurrence.date,
                ),
              )
            : OccurrenceTile(
                key: ValueKey('row-${occurrence.eventId}'),
                occurrence: occurrence,
                isPast: isToday && occurrence.isPast(now),
                onTap: () => EditEventScreen.open(
                  context,
                  eventId: occurrence.eventId,
                  occurrenceDate: occurrence.date,
                ),
              ),
      );
    }

    // Everything already happened: the line belongs at the bottom of the day.
    if (isToday && nextIndex == -1) children.add(NowDivider(now: now));

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      children: children,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isToday});

  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 44,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isToday ? 'Nothing today' : 'Nothing on this day',
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        "Couldn't read the day.\n$error",
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}
