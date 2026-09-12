import 'package:flutter/material.dart';

import '../../model/place.dart';
import '../../model/place_stats.dart';
import '../event_colors.dart';
import '../theme.dart';
import 'dashboard_screen.dart';

/// Time spent at each place, as bars scaled against the biggest one.
///
/// Scaled against the largest rather than against the window, because home
/// swamps everything on an absolute scale and the interesting comparison is
/// between the places, not against twenty-four hours.
class PlaceBars extends StatelessWidget {
  const PlaceBars({required this.places, required this.totals, super.key});

  final List<Place> places;
  final Map<int, Duration> totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final rows = places
        .map((place) => (place, totals[place.id] ?? Duration.zero))
        .where((row) => row.$2 > Duration.zero)
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    if (rows.isEmpty) {
      return const _Nothing(
        label: 'Time per place',
        message: 'No visits recorded in this window yet.',
      );
    }

    final longest = rows.first.$2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashboardHeading(label: 'Time per place'),
        for (final (place, total) in rows)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DaylineTheme.gutter,
              6,
              DaylineTheme.gutter,
              6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        place.name,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatDuration(total),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
                          .merge(monospacedFigures),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: longest.inSeconds == 0
                        ? 0
                        : total.inSeconds / longest.inSeconds,
                    minHeight: 10,
                    backgroundColor: theme.colorScheme.outlineVariant,
                    valueColor: AlwaysStoppedAnimation(
                      EventColors.of(place.colorValue),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.label, required this.message});

  final String label;
  final String message;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DashboardHeading(label: label),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          DaylineTheme.gutter,
          0,
          DaylineTheme.gutter,
          12,
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}
