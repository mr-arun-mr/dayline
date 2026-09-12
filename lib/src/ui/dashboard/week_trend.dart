import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/calendar_date.dart';
import '../../model/place.dart';
import '../../model/place_stats.dart';
import '../../providers.dart';
import '../event_colors.dart';
import '../theme.dart';
import 'dashboard_screen.dart';

/// Six weeks per place, so a drift in either direction is visible.
///
/// Weeks run Monday to Monday and are built from calendar dates, not by
/// subtracting seven-day durations — a DST week is still a week.
class WeekTrend extends ConsumerWidget {
  const WeekTrend({
    required this.places,
    required this.today,
    required this.now,
    super.key,
  });

  final List<Place> places;
  final CalendarDate today;
  final DateTime now;

  static const _weeks = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Six weeks back from the start of this week.
    final thisMonday = today.addDays(-(today.weekday - 1));
    final range = DateRange(
      thisMonday.addDays(-7 * (_weeks - 1)).localDateTimeAt(0),
      thisMonday.addDays(7).localDateTimeAt(0),
    );
    final visits = ref.watch(visitsProvider(range)).value ?? const <Visit>[];

    final rows = places
        .map((place) => (
              place,
              weeklyTotals(
                visits,
                placeId: place.id,
                today: today,
                now: now,
                weeks: _weeks,
              ),
            ))
        .where((row) => row.$2.any((w) => w.total > Duration.zero))
        .toList();

    final theme = Theme.of(context);
    if (rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DashboardHeading(label: 'Week by week'),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DaylineTheme.gutter,
              0,
              DaylineTheme.gutter,
              12,
            ),
            child: Text(
              'Not enough history yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashboardHeading(
          label: 'Week by week',
          hint: 'Last six weeks, this one last',
        ),
        for (final (place, totals) in rows)
          _TrendRow(place: place, totals: totals),
      ],
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.place, required this.totals});

  final Place place;
  final List<WeeklyTotal> totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = EventColors.of(place.colorValue);
    final peak = totals
        .map((t) => t.total)
        .reduce((a, b) => a > b ? a : b);

    final thisWeek = totals.last.total;
    final lastWeek = totals.length > 1
        ? totals[totals.length - 2].total
        : Duration.zero;
    final change = thisWeek - lastWeek;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        10,
        DaylineTheme.gutter,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(place.name, style: theme.textTheme.titleSmall),
              ),
              _Change(change: change, hadPrevious: lastWeek > Duration.zero),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            // Tall enough for the bar, the gap and the date label under it —
            // 46 was sized for the bar alone and clipped the label.
            height: 62,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final week in totals)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: peak.inSeconds == 0
                                ? 2
                                : (2 +
                                    36 *
                                        week.total.inSeconds /
                                        peak.inSeconds),
                            decoration: BoxDecoration(
                              // The current week is the one being judged, so
                              // the earlier ones step back.
                              color: week == totals.last
                                  ? colour
                                  : colour.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${week.weekStart.day}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Change extends StatelessWidget {
  const _Change({required this.change, required this.hadPrevious});

  final Duration change;
  final bool hadPrevious;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Comparing against a week with nothing in it says more about the data
    // than about the habit.
    if (!hadPrevious) {
      return Text(
        'new',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final up = change > Duration.zero;
    final flat = change.inMinutes.abs() < 15;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          flat
              ? Icons.remove
              : up
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 3),
        Text(
          flat ? 'about the same' : formatDuration(change.abs()),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
