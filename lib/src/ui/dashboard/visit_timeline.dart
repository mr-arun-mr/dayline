import 'package:flutter/material.dart';

import '../../model/calendar_date.dart';
import '../../model/place.dart';
import '../../model/place_stats.dart';
import '../../model/rule_description.dart';
import '../theme.dart';
import 'dashboard_screen.dart';

/// Today's comings and goings, in order.
class VisitTimeline extends StatelessWidget {
  const VisitTimeline({
    required this.visits,
    required this.places,
    required this.date,
    required this.now,
    super.key,
  });

  final List<Visit> visits;
  final List<Place> places;
  final CalendarDate date;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardHeading(
          label: 'Today',
          hint: visits.isEmpty ? null : formatMediumDate(date),
        ),
        if (visits.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DaylineTheme.gutter,
              0,
              DaylineTheme.gutter,
              12,
            ),
            child: Text(
              'Nowhere recorded today.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final visit in visits)
            _Row(
              visit: visit,
              colour: placeColour(places, visit.placeId),
              name: placeName(places, visit.placeId),
              now: now,
            ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.visit,
    required this.colour,
    required this.name,
    required this.now,
  });

  final Visit visit;
  final Color colour;
  final String name;
  final DateTime now;

  static String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final departed = visit.departedAt;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DaylineTheme.gutter,
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              departed == null
                  ? '${_clock(visit.arrivedAt)} –'
                  : '${_clock(visit.arrivedAt)}–${_clock(departed)}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
                  .merge(monospacedFigures),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 4,
            height: 30,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            visit.isOpen
                // Still there, so the number is a running total.
                ? 'now · ${formatDuration(visit.durationAt(now))}'
                : formatDuration(visit.durationAt(now)),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
                .merge(monospacedFigures),
          ),
        ],
      ),
    );
  }
}
