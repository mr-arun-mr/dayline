import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/calendar_date.dart';
import '../../model/day_summary.dart';
import '../../model/event.dart';
import '../../model/occurrence.dart';
import '../../model/rule_description.dart';
import '../../providers.dart';
import '../edit/edit_event_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../events/all_events_screen.dart';
import '../settings/settings_screen.dart';
import '../theme.dart';
import 'battery_card.dart';
import 'day_strip.dart';
import 'holiday_banner.dart';
import 'move_occurrence_sheet.dart';
import 'next_up_card.dart';
import 'now_divider.dart';
import 'occurrence_sheet.dart';
import 'occurrence_tile.dart';
import 'progress_ring.dart';
import 'section_header.dart';

/// The home screen: one line of a day's events, in order.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final selected = ref.watch(selectedDateProvider);
    final occurrences = ref.watch(occurrencesProvider(selected));
    final now = ref.watch(clockProvider)();

    final summary = switch (occurrences) {
      AsyncData(:final value) => DaySummary.from(
        occurrences: value,
        now: now,
        isToday: selected == today,
      ),
      _ => null,
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(today: today, selected: selected, summary: summary),
            DayStrip(
              today: today,
              selected: selected,
              onSelected: (date) =>
                  ref.read(selectedDateProvider.notifier).select(date),
            ),
            const Divider(height: 1),
            const BatteryOptimisationCard(),
            HolidayBanner(date: selected),
            Expanded(
              child: switch (occurrences) {
                AsyncData() =>
                  _DayList(summary: summary!, now: now, date: selected),
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
  const _Header({
    required this.today,
    required this.selected,
    required this.summary,
  });

  final CalendarDate today;
  final CalendarDate selected;
  final DaySummary? summary;

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
        DaylineTheme.gutter,
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
                // One line rather than a Row of three: on a 390pt phone the
                // date, the separator and "3 of 6 done" together overflow the
                // space the progress ring leaves.
                Text(
                  [
                    relative == null
                        ? '${selected.year}'
                        : formatDayAndMonth(selected),
                    if (summary != null && summary!.total > 0)
                      summary!.progressLabel,
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            )
          else if (summary != null && summary!.total > 0)
            ProgressRing(
              progress: summary!.progress,
              doneCount: summary!.doneCount,
              expected: summary!.expected,
              isComplete: summary!.isComplete,
            ),
          IconButton(
            onPressed: () => AllEventsScreen.open(context),
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: 'All events',
          ),
          IconButton(
            onPressed: () => DashboardScreen.open(context),
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Dashboard',
          ),
          IconButton(
            onPressed: () => SettingsScreen.open(context),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Overdue, then the now line, then what is next, then the rest, then what has
/// already been dealt with — folded away, because a finished thing should stop
/// taking up room.
class _DayList extends ConsumerStatefulWidget {
  const _DayList({
    required this.summary,
    required this.now,
    required this.date,
  });

  final DaySummary summary;
  final DateTime now;
  final CalendarDate date;

  @override
  ConsumerState<_DayList> createState() => _DayListState();
}

class _DayListState extends ConsumerState<_DayList> {
  bool _doneExpanded = false;

  Future<void> _toggleDone(Occurrence occurrence) async {
    final dao = ref.read(eventsDaoProvider);
    if (occurrence.isPending) {
      await dao.setCompletion(
        eventId: occurrence.eventId,
        date: occurrence.date,
        status: CompletionStatus.done,
      );
    } else {
      await dao.clearCompletion(occurrence.eventId, occurrence.date);
    }
  }

  Future<void> _openSheet(Occurrence occurrence) async {
    final action = await showOccurrenceSheet(context, occurrence);
    if (action == null || !mounted) return;

    final dao = ref.read(eventsDaoProvider);
    switch (action) {
      case OccurrenceAction.markDone:
        await dao.setCompletion(
          eventId: occurrence.eventId,
          date: occurrence.date,
          status: CompletionStatus.done,
        );
      case OccurrenceAction.markSkipped:
        await dao.setCompletion(
          eventId: occurrence.eventId,
          date: occurrence.date,
          status: CompletionStatus.skipped,
        );
      case OccurrenceAction.clear:
        await dao.clearCompletion(occurrence.eventId, occurrence.date);
      case OccurrenceAction.move:
        if (!mounted) return;
        await showMoveOccurrenceSheet(context, ref, occurrence);
      case OccurrenceAction.editSeries:
        if (!mounted) return;
        await EditEventScreen.open(
          context,
          eventId: occurrence.eventId,
          occurrenceDate: occurrence.date,
        );
    }
  }

  Widget _tile(Occurrence occurrence, {required bool isPast}) => OccurrenceTile(
    key: ValueKey('row-${occurrence.eventId}-${occurrence.date}'),
    occurrence: occurrence,
    isPast: isPast,
    onTap: () => _toggleDone(occurrence),
    onLongPress: () => _openSheet(occurrence),
  );

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    if (summary.isEmpty) return _EmptyState(isToday: summary.isToday);

    final children = <Widget>[];

    if (summary.overdue.isNotEmpty) {
      children.add(SectionHeader(
        label: 'Overdue',
        count: summary.overdue.length,
        emphasis: true,
      ));
      children.addAll(
        summary.overdue.map((o) => _tile(o, isPast: true)),
      );
    }

    if (summary.showsNowDivider) children.add(NowDivider(now: widget.now));

    if (summary.nextUp case final next?) {
      children.add(const SectionHeader(label: 'Next up'));
      children.add(NextUpCard(
        key: ValueKey('next-${next.eventId}'),
        occurrence: next,
        onTap: () => _toggleDone(next),
        onLongPress: () => _openSheet(next),
      ));
    }

    if (summary.later.isNotEmpty) {
      children.add(SectionHeader(
        label: summary.isToday ? 'Later today' : 'Planned',
      ));
      children.addAll(summary.later.map((o) => _tile(o, isPast: false)));
    }

    if (summary.done.isNotEmpty) {
      children.add(SectionHeader(
        label: 'Done',
        count: summary.done.length,
        trailing: TextButton(
          onPressed: () => setState(() => _doneExpanded = !_doneExpanded),
          child: Text(_doneExpanded ? 'Hide' : 'Show'),
        ),
      ));
      if (_doneExpanded) {
        children.addAll(summary.done.map((o) => _tile(o, isPast: true)));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
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
