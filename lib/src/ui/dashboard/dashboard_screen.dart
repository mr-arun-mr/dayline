import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/place.dart';
import '../../model/place_stats.dart';
import '../../providers.dart';
import '../event_colors.dart';
import '../theme.dart';
import '../places/places_screen.dart';
import 'adherence_card.dart';
import 'place_bars.dart';
import 'visit_timeline.dart';
import 'week_trend.dart';

/// Where the time actually went.
///
/// Four questions, in the order they are worth asking: how long at each place,
/// whether the routines tied to those places were kept, what today looked like,
/// and whether any of it is getting better or worse.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final now = ref.watch(clockProvider)();
    final places = ref.watch(placesProvider).value ?? const <Place>[];
    final range = DateRange.lastDays(today, _days);
    final visits = ref.watch(visitsProvider(range));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: () => PlacesScreen.open(context),
            icon: const Icon(Icons.place_outlined),
            tooltip: 'Places',
          ),
        ],
      ),
      body: switch (visits) {
        AsyncData() when places.isEmpty => const _NoPlaces(),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            _RangePicker(
              days: _days,
              onChanged: (days) => setState(() => _days = days),
            ),
            PlaceBars(
              places: places,
              totals: timePerPlace(
                value,
                from: range.from,
                to: range.to,
                now: now,
              ),
            ),
            const _SectionGap(),
            AdherenceSection(
              places: places,
              visits: value,
              today: today,
              now: now,
              days: _days,
            ),
            const _SectionGap(),
            VisitTimeline(
              visits: visitsOnDay(value, today, now: now),
              places: places,
              date: today,
              now: now,
            ),
            const _SectionGap(),
            WeekTrend(places: places, today: today, now: now),
          ],
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Divider(height: 1),
  );
}

class _RangePicker extends StatelessWidget {
  const _RangePicker({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      DaylineTheme.gutter,
      14,
      DaylineTheme.gutter,
      4,
    ),
    child: SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 7, label: Text('7 days')),
        ButtonSegment(value: 30, label: Text('30 days')),
        ButtonSegment(value: 90, label: Text('90 days')),
      ],
      selected: {days},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.single),
    ),
  );
}

class _NoPlaces extends StatelessWidget {
  const _NoPlaces();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_outlined,
                size: 44, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Nothing to show yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a place or two and Dayline will start noticing when you '
              'arrive and leave.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => PlacesScreen.open(context),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add a place'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared section heading for the dashboard cards.
class DashboardHeading extends StatelessWidget {
  const DashboardHeading({required this.label, this.hint, super.key});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        14,
        DaylineTheme.gutter,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Looks a place up by id without exploding when it has been deleted.
Place? placeById(List<Place> places, int id) {
  for (final place in places) {
    if (place.id == id) return place;
  }
  return null;
}

/// Colour for a place, falling back to something neutral.
Color placeColour(List<Place> places, int id) {
  final place = placeById(places, id);
  return EventColors.of(place?.colorValue ?? EventColors.fallback);
}

/// The labels used by more than one card.
String placeName(List<Place> places, int id) =>
    placeById(places, id)?.name ?? 'Somewhere';
