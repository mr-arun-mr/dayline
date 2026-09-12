import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/calendar_date.dart';
import '../../model/event.dart';
import '../../model/place.dart';
import '../../model/place_stats.dart';
import '../../model/rule_description.dart';
import '../../providers.dart';
import '../event_colors.dart';
import '../theme.dart';
import 'dashboard_screen.dart';

/// Whether the routines tied to a place were actually kept.
///
/// The one card that joins the two halves of the app: everything else here is
/// a record of where the phone went, and this asks whether that matches what
/// the user said they meant to do.
class AdherenceSection extends ConsumerWidget {
  const AdherenceSection({
    required this.places,
    required this.visits,
    required this.today,
    required this.now,
    required this.days,
    super.key,
  });

  final List<Place> places;
  final List<Visit> visits;
  final CalendarDate today;
  final DateTime now;
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final events = ref.watch(allEventsProvider).value ?? const <Event>[];
    final linked =
        events.where((e) => e.placeId != null && e.isActive).toList();

    if (linked.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DashboardHeading(label: 'Did you go?'),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DaylineTheme.gutter,
              0,
              DaylineTheme.gutter,
              12,
            ),
            child: Text(
              'Link a routine to a place when editing it, and this will show '
              'whether you actually went.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
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
          label: 'Did you go?',
          hint: 'Occurrences you were actually there for',
        ),
        for (final event in linked)
          _Row(
            event: event,
            place: placeById(places, event.placeId!),
            adherence: adherenceFor(
              occurrenceDates: _pastOccurrences(event),
              timeOfDay: event.timeOfDay,
              visits: visits,
              placeId: event.placeId!,
              now: now,
            ),
          ),
      ],
    );
  }

  /// The rule's occurrences inside the window being looked at.
  List<CalendarDate> _pastOccurrences(Event event) {
    final from = today.addDays(-(days - 1));
    final dates = <CalendarDate>[];
    for (var day = from.epochDay; day <= today.epochDay; day++) {
      final date = CalendarDate.fromEpochDay(day);
      if (event.rule.occursOn(date)) dates.add(date);
    }
    return dates;
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.event,
    required this.place,
    required this.adherence,
  });

  final Event event;
  final Place? place;
  final Adherence adherence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Nothing has come due yet, so there is nothing to judge.
    if (adherence.expected == 0) return const SizedBox.shrink();

    final good = adherence.rate >= 0.8;
    final fair = adherence.rate >= 0.5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        8,
        DaylineTheme.gutter,
        8,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: EventColors.of(event.colorValue),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${place?.name ?? 'a place'} · '
                  '${formatWallClock(event.timeOfDay)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${adherence.attended} of ${adherence.expected}',
                style: theme.textTheme.titleSmall
                    ?.copyWith(
                      color: good
                          ? const Color(0xFF10B981)
                          : fair
                              ? scheme.onSurface
                              : scheme.error,
                      fontWeight: FontWeight.w700,
                    )
                    .merge(monospacedFigures),
              ),
              const SizedBox(height: 2),
              Text(
                '${(adherence.rate * 100).round()}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
