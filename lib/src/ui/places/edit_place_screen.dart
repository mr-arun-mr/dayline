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
  bool _addVisitsToDay = false;

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
      _addVisitsToDay = place.addVisitsToDay;
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
      addVisitsToDay: Value(_addVisitsToDay),
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

  /// The nearest place whose circle this one runs into.
  ///
  /// Worth saying out loud, because the floor on the radius makes it easy to
  /// do by accident: two shops on the same street are inside each other's
  /// hundred metres, and standing in either one the OS reports both.
  Place? _overlapping(List<Place> others) {
    final lat = _latitude;
    final lon = _longitude;
    if (lat == null || lon == null) return null;

    final here = Place(
      id: widget.placeId ?? -1,
      name: '',
      latitude: lat,
      longitude: lon,
      radiusMeters: _radius,
      colorValue: _colorValue,
    );

    Place? nearest;
    var gap = double.infinity;
    for (final other in others) {
      if (other.id == widget.placeId) continue;
      final metres = here.metresTo(other.latitude, other.longitude);
      if (metres >= gap || !here.overlaps(other)) continue;
      nearest = other;
      gap = metres;
    }
    return nearest;
  }

  /// How far this place's centre is from [other]'s.
  double _overlapDistance(Place other) => Place(
    id: -1,
    name: '',
    latitude: _latitude!,
    longitude: _longitude!,
    radiusMeters: _radius,
    colorValue: _colorValue,
  ).metresTo(other.latitude, other.longitude);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    final others = ref.watch(placesProvider).value ?? const <Place>[];
    final clash = _overlapping(others);

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
            if (clash != null)
              _OverlapNote(
                other: clash,
                metres: _overlapDistance(clash),
              ),
            const Divider(),
            _AddVisitsSwitch(
              value: _addVisitsToDay,
              onChanged: (value) => setState(() => _addVisitsToDay = value),
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

/// "Add visits here to my day".
///
/// The only setting in Dayline that writes rows the user did not ask for, so
/// it is off until asked for, and per place rather than global: worth having
/// for the gym and the office, and quietly wrong for home, which would file an
/// event every single evening.
class _AddVisitsSwitch extends ConsumerWidget {
  const _AddVisitsSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Null while it is still being read — no claim either way until it is
    // known.
    final hasBackground = ref.watch(backgroundLocationProvider).value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DaylineTheme.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const ValueKey('add-visits-switch'),
            contentPadding: EdgeInsets.zero,
            value: value,
            onChanged: onChanged,
            title: const Text('Add visits to my day'),
            subtitle: const Text(
              'Put a stay here onto the day it happened, so the timeline '
              'shows where the time went and not only what was planned',
            ),
            secondary: Icon(
              Icons.playlist_add,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (value) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Nothing is added when something on the day already covers '
                'being here — a routine tied to this place is that record '
                'already.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
            if (hasBackground == false)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Background location is off, so no arrivals are '
                        'noticed and nothing will be added.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
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
    final tight = radius < Place.reliableRadiusMeters;

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
            // 50 m a step, from the tightest circle the phone will take to the
            // widest worth drawing.
            divisions: 39,
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 8),
            child: Text(
              tight
                  // Said plainly, because this is the trade and the user is
                  // the only one who can make it: a tighter circle is the only
                  // way to keep two places apart, and it is also the one the
                  // phone is worst at noticing.
                  ? 'Under 100 m the phone may miss arrivals altogether, or '
                      'report them twice while it sits on a table. Worth it '
                      'only to keep this place apart from one next to it.'
                  : 'Bigger is steadier but catches the street outside. '
                      'Around 100 m is what both phones are happiest with.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tight
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
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

/// "Gym is 40 m from here."
///
/// Two circles that overlap cannot be told apart: standing in the overlap the
/// OS reports both, and neither report is wrong. Dayline records the stay at
/// the smaller of the two rather than at both — but the user is the only one
/// who knows which of them they actually meant, so they are told rather than
/// quietly corrected.
class _OverlapNote extends StatelessWidget {
  const _OverlapNote({required this.other, required this.metres});

  final Place other;
  final double metres;

  /// What would actually separate them, or that nothing would.
  ///
  /// Half the distance between the centres is the widest each circle can be
  /// and still not touch — and below the floor that is not a radius the phone
  /// will watch, which is worth saying rather than letting the user chase a
  /// setting that cannot work.
  String get _advice {
    final apart = metres / 2;
    return apart >= Place.minimumRadiusMeters
        ? 'Under ${apart.floor()} m each they would be separate circles.'
        : 'Nothing the phone will watch is tight enough to separate them, so '
            'keep whichever one you meant.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        0,
        DaylineTheme.gutter,
        14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '${other.name} is ${metres.round()} m away, so the two circles '
              'overlap. The phone cannot tell them apart: arriving at either '
              'reports both, and the stay is recorded at whichever circle is '
              'smaller. $_advice',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
