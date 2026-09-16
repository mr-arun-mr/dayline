import 'package:flutter/material.dart';

import '../../model/calendar_date.dart';
import '../../model/place.dart';
import '../../model/place_stats.dart';
import '../../model/rule_description.dart';
import '../day_rail.dart';
import '../theme.dart';
import 'dashboard_screen.dart';

/// Today's comings and goings, in order.
///
/// One row per stay rather than per place, each saying when the device arrived
/// and when it left. Going out and coming back is two stays at that place, and
/// the timeline shows them as two: home, office, home, down the page, with a
/// rail joining them so the day reads as one journey.
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
          for (var i = 0; i < visits.length; i++)
            _Stay(
              visit: visits[i],
              colour: placeColour(places, visits[i].placeId),
              name: placeName(places, visits[i].placeId),
              date: date,
              now: now,
              isFirst: i == 0,
              isLast: i == visits.length - 1,
            ),
      ],
    );
  }
}

class _Stay extends StatelessWidget {
  const _Stay({
    required this.visit,
    required this.colour,
    required this.name,
    required this.date,
    required this.now,
    required this.isFirst,
    required this.isLast,
  });

  final Visit visit;
  final Color colour;
  final String name;

  /// The day being shown, which a stay may have begun before or end after.
  final CalendarDate date;

  final DateTime now;
  final bool isFirst;
  final bool isLast;

  static String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  /// "07:00", or "22:40 yesterday" for a stay that ran over from another day.
  ///
  /// A time with no date on it is read as today's, so the overnight stay at
  /// the top of the list has to say otherwise or it looks like a stay that
  /// began this morning.
  String _timeOn(DateTime time) {
    final day = CalendarDate.fromDateTime(time);
    final relative = switch (date.daysUntil(day)) {
      0 => null,
      -1 => 'yesterday',
      1 => 'tomorrow',
      _ => formatDayAndMonth(day),
    };
    return relative == null ? _clock(time) : '${_clock(time)} $relative';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final departed = visit.departedAt;

    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
        .merge(monospacedFigures);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DaylineTheme.gutter),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DayRail.span(
              colour: colour,
              isOpen: visit.isOpen,
              linkedAbove: !isFirst,
              linkedBelow: !isLast,
              bottomInset: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          visit.isOpen
                              // Still there, so the number is a running total.
                              ? 'now · ${formatDuration(visit.durationAt(now))}'
                              : formatDuration(visit.durationAt(now)),
                          style: muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // Both ends spelled out, because the question the
                      // timeline answers is when you got there and when you
                      // left — a stay with only one of those is half a story.
                      departed == null
                          ? 'Arrived ${_timeOn(visit.arrivedAt)} · still there'
                          : 'Arrived ${_timeOn(visit.arrivedAt)} · '
                              'left ${_timeOn(departed)}',
                      style: muted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
