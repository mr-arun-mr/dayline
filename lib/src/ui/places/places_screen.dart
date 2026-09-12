import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/place.dart';
import '../../providers.dart';
import '../event_colors.dart';
import '../theme.dart';
import 'edit_place_screen.dart';

/// The places the user has told Dayline about.
class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const PlacesScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(placesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Places')),
      body: Column(
        children: [
          const _PermissionBanner(),
          Expanded(
            child: switch (places) {
              AsyncData(:final value) when value.isEmpty => const _Empty(),
              AsyncData(:final value) => ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: value.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _PlaceRow(place: value[i]),
              ),
              AsyncError(:final error) => Center(child: Text('$error')),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => EditPlaceScreen.open(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add place'),
      ),
    );
  }
}

/// Says plainly when the feature cannot work, rather than looking like it does.
class _PermissionBanner extends ConsumerWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granted = ref.watch(backgroundLocationProvider).value;
    if (granted != false) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        12,
        DaylineTheme.gutter,
        4,
      ),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_off_outlined,
                      color: theme.colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Places need background location',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Dayline can only notice you arriving somewhere if the system '
                'is allowed to tell it while the app is closed — "Allow all the '
                'time" rather than "While using". Nothing is sent anywhere; the '
                'app has no internet permission.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () async {
                    await ref
                        .read(geofenceServiceProvider)
                        .requestPermission();
                    ref.invalidate(backgroundLocationProvider);
                  },
                  child: const Text('Allow'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceRow extends ConsumerWidget {
  const _PlaceRow({required this.place});

  final Place place;

  static const _icons = {
    PlaceKind.home: Icons.home_outlined,
    PlaceKind.work: Icons.work_outline,
    PlaceKind.gym: Icons.fitness_center,
    PlaceKind.shop: Icons.shopping_bag_outlined,
    PlaceKind.leisure: Icons.local_activity_outlined,
    PlaceKind.other: Icons.place_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey('place-${place.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: DaylineTheme.gutter),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete "${place.name}"?'),
          content: const Text(
            'Every visit recorded there will be removed too.',
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
      onDismissed: (_) async {
        await ref.read(placesDaoProvider).deletePlace(place.id);
        await ref.read(geofenceServiceProvider).reconcile();
      },
      child: Opacity(
        opacity: place.isActive ? 1 : 0.55,
        child: ListTile(
          minTileHeight: DaylineTheme.rowMinHeight,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: DaylineTheme.gutter,
            vertical: 6,
          ),
          leading: CircleAvatar(
            backgroundColor: EventColors.of(place.colorValue).withValues(
              alpha: 0.18,
            ),
            child: Icon(
              _icons[place.kind],
              color: EventColors.of(place.colorValue),
            ),
          ),
          title: Text(place.name, style: theme.textTheme.titleMedium),
          subtitle: Text(
            '${place.radiusMeters.round()} m radius · '
            '${place.latitude.toStringAsFixed(4)}, '
            '${place.longitude.toStringAsFixed(4)}',
          ),
          trailing: Switch(
            value: place.isActive,
            onChanged: (value) async {
              await ref
                  .read(placesDaoProvider)
                  .setPlaceActive(place.id, value);
              await ref.read(geofenceServiceProvider).reconcile();
            },
          ),
          onTap: () => EditPlaceScreen.open(context, placeId: place.id),
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
            Icon(Icons.place_outlined,
                size: 44, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No places yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Stand somewhere you go often — home, the office, the gym — and '
              'add it with your current location.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
