import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/database.dart';
import '../../model/place.dart';
import '../../providers.dart';
import '../event_colors.dart';
import '../theme.dart';

/// Add or edit a place.
///
/// There is no map and no address search, because both need a network. A place
/// is added by standing in it and tapping a button, which is also the only way
/// to be sure the coordinates are the ones the phone will actually report.
class EditPlaceScreen extends ConsumerStatefulWidget {
  const EditPlaceScreen({this.placeId, super.key});

  final int? placeId;

  static Future<void> open(BuildContext context, {int? placeId}) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => EditPlaceScreen(placeId: placeId)),
      );

  @override
  ConsumerState<EditPlaceScreen> createState() => _EditPlaceScreenState();
}

class _EditPlaceScreenState extends ConsumerState<EditPlaceScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  PlaceKind _kind = PlaceKind.other;
  double _radius = Place.defaultRadiusMeters;
  int _colorValue = EventColors.fallback;
  double? _latitude;
  double? _longitude;

  bool _loading = true;
  bool _locating = false;
  bool _saving = false;

  bool get _isNew => widget.placeId == null;
  bool get _hasLocation => _latitude != null && _longitude != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.placeId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final place = await ref.read(placesDaoProvider).placeById(id);
    if (!mounted) return;
    if (place == null) {
      Navigator.of(context).pop();
      return;
    }
    _nameController.text = place.name;
    setState(() {
      _kind = place.kind;
      _radius = place.radiusMeters;
      _colorValue = place.colorValue;
      _latitude = place.latitude;
      _longitude = place.longitude;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final service = ref.read(geofenceServiceProvider);
      await service.requestPermission();
      final position = await service.currentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't get a location: $error")),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set the location first')),
      );
      return;
    }
    setState(() => _saving = true);

    final dao = ref.read(placesDaoProvider);
    final companion = PlacesCompanion(
      id: _isNew ? const Value.absent() : Value(widget.placeId!),
      name: Value(_nameController.text.trim()),
      latitude: Value(_latitude!),
      longitude: Value(_longitude!),
      radiusMeters: Value(_radius),
      colorValue: Value(_colorValue),
      kind: Value(_kind),
      isActive: const Value(true),
    );

    if (_isNew) {
      await dao.insertPlace(companion);
    } else {
      await dao.updatePlace(companion);
    }
    // The OS is watching a stale set of circles until this runs.
    await ref.read(geofenceServiceProvider).reconcile();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New place' : 'Edit place'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DaylineTheme.gutter,
                vertical: 12,
              ),
              child: TextFormField(
                controller: _nameController,
                autofocus: _isNew,
                textCapitalization: TextCapitalization.words,
                style: theme.textTheme.headlineSmall,
                decoration: const InputDecoration(
                  hintText: 'What do you call it?',
                  border: InputBorder.none,
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Give it a name' : null,
              ),
            ),
            const Divider(),
            _LocationTile(
              latitude: _latitude,
              longitude: _longitude,
              busy: _locating,
              onPressed: _locating ? null : _useCurrentLocation,
            ),
            const Divider(),
            _RadiusPicker(
              radius: _radius,
              onChanged: (value) => setState(() => _radius = value),
            ),
            const Divider(),
            _KindPicker(
              kind: _kind,
              onChanged: (value) => setState(() => _kind = value),
            ),
            const Divider(),
            _ColourPicker(
              selected: _colorValue,
              onChanged: (value) => setState(() => _colorValue = value),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.latitude,
    required this.longitude,
    required this.busy,
    required this.onPressed,
  });

  final double? latitude;
  final double? longitude;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final has = latitude != null && longitude != null;

    return ListTile(
      minTileHeight: DaylineTheme.rowMinHeight,
      leading: Icon(Icons.my_location, color: theme.colorScheme.primary),
      title: const Text('Location'),
      subtitle: Text(
        has
            ? '${latitude!.toStringAsFixed(5)}, '
                '${longitude!.toStringAsFixed(5)}'
            : 'Not set — stand here and tap Use current',
      ),
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: onPressed,
              child: Text(has ? 'Update' : 'Use current'),
            ),
    );
  }
}

class _RadiusPicker extends StatelessWidget {
  const _RadiusPicker({required this.radius, required this.onChanged});

  final double radius;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        12,
        DaylineTheme.gutter,
        4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.adjust, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Text('How close counts', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                '${radius.round()} m',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.primary)
                    .merge(monospacedFigures),
              ),
            ],
          ),
          Slider(
            value: radius,
            min: Place.minimumRadiusMeters,
            max: Place.maximumRadiusMeters,
            divisions: 38,
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 8),
            child: Text(
              'Below about 100 m the phone reports arrivals that never '
              'happened. Bigger is steadier but catches the street outside.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KindPicker extends StatelessWidget {
  const _KindPicker({required this.kind, required this.onChanged});

  final PlaceKind kind;
  final ValueChanged<PlaceKind> onChanged;

  static const _labels = {
    PlaceKind.home: 'Home',
    PlaceKind.work: 'Work',
    PlaceKind.gym: 'Gym',
    PlaceKind.shop: 'Shop',
    PlaceKind.leisure: 'Leisure',
    PlaceKind.other: 'Other',
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      DaylineTheme.gutter,
      14,
      DaylineTheme.gutter,
      10,
    ),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in _labels.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: entry.key == kind,
            onSelected: (isOn) {
              if (isOn) onChanged(entry.key);
            },
          ),
      ],
    ),
  );
}

class _ColourPicker extends StatelessWidget {
  const _ColourPicker({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        14,
        DaylineTheme.gutter,
        14,
      ),
      child: Row(
        children: [
          Icon(Icons.palette_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                for (final value in EventColors.all)
                  InkWell(
                    onTap: () => onChanged(value),
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: EventColors.of(value),
                          shape: BoxShape.circle,
                          border: value == selected
                              ? Border.all(color: scheme.onSurface, width: 3)
                              : null,
                        ),
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
