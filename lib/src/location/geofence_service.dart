import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_geofence/native_geofence.dart';

import '../db/database.dart';
import '../model/occurrence.dart';
import '../model/place.dart';

/// Registers the user's places with the OS and records what it reports back.
///
/// Nothing here talks to a network. The OS watches a handful of circles the
/// user drew themselves and wakes the app when the device crosses one; there is
/// no places API, no coordinates leaving the device, and no continuous location
/// stream burning the battery.
class GeofenceService {
  GeofenceService(this._db);

  final DaylineDatabase _db;

  bool _initialised = false;

  /// Geofence ids are the place id as a string, so the callback can find its
  /// way back to a row without a lookup table.
  static String idFor(int placeId) => 'place-$placeId';

  static int? placeIdFrom(String geofenceId) =>
      int.tryParse(geofenceId.replaceFirst('place-', ''));

  Future<void> initialise() async {
    if (_initialised) return;
    await NativeGeofenceManager.instance.initialize();
    _initialised = true;
  }

  /// Whether the OS will report crossings while the app is closed.
  ///
  /// "While in use" is not enough: the whole point is being told about the gym
  /// when the phone is in a pocket.
  Future<bool> hasBackgroundPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  /// Walks the user up the permission ladder.
  ///
  /// Both platforms insist on being asked for coarse access first and only
  /// then for always-on, and Android will refuse the second request outright if
  /// the first has not been granted.
  Future<LocationPermission> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermission.denied;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse) {
      // Asking again is what prompts for "Always" on both platforms.
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Where the device is right now, for the "use my location" button.
  ///
  /// The only time Dayline reads a position directly rather than letting the OS
  /// watch a circle for it.
  Future<Position> currentPosition() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      timeLimit: Duration(seconds: 20),
    ),
  );

  /// Brings the OS's registered geofences in line with the stored places.
  ///
  /// Called on start, on resume, and whenever a place changes — the same
  /// reconcile-everything shape the notification scheduler uses, for the same
  /// reason: a path that forgets to update cannot then exist.
  Future<int> reconcile() async {
    if (!_initialised) await initialise();
    if (!await hasBackgroundPermission()) {
      // Registering without always-on permission silently does nothing on
      // both platforms, so do not pretend otherwise.
      return 0;
    }

    await NativeGeofenceManager.instance.removeAllGeofences();

    final active =
        (await _db.placesDao.allPlaces()).where((p) => p.isActive).toList();

    var registered = 0;
    for (final place in active.take(_osLimit)) {
      try {
        await NativeGeofenceManager.instance.createGeofence(
          Geofence(
            id: idFor(place.id),
            location: Location(
              latitude: place.latitude,
              longitude: place.longitude,
            ),
            // Clamped: below about a hundred metres both platforms report
            // arrivals and departures that never happened.
            radiusMeters: place.radiusMeters
                .clamp(Place.minimumRadiusMeters, Place.maximumRadiusMeters),
            triggers: const {GeofenceEvent.enter, GeofenceEvent.exit},
            iosSettings: const IosGeofenceSettings(initialTrigger: true),
            androidSettings: const AndroidGeofenceSettings(
              initialTriggers: {GeofenceEvent.enter},
              // Wait before calling it an arrival, so walking past the gym on
              // the way to the shops is not a gym visit.
              loiteringDelay: Duration(minutes: 2),
            ),
          ),
          geofenceTriggered,
        );
        registered++;
      } on Object catch (error) {
        debugPrint('Dayline: could not register ${place.name} — $error');
      }
    }
    return registered;
  }

  /// iOS allows 20 monitored regions per app and Android 100. Twenty places is
  /// already far more than this app is for, so the lower limit is the limit.
  static const _osLimit = 20;
}

/// Entry point the OS calls when a geofence is crossed.
///
/// Runs in its own isolate with the app closed, so nothing from the running
/// app is in scope — including the open database, which is why this opens its
/// own and closes it again.
@pragma('vm:entry-point')
Future<void> geofenceTriggered(GeofenceCallbackParams params) async {
  final db = DaylineDatabase();
  try {
    await applyGeofenceEvent(
      db: db,
      placeIds: params.geofences
          .map((g) => GeofenceService.placeIdFrom(g.id))
          .whereType<int>()
          .toList(),
      event: params.event,
      at: DateTime.now(),
    );
  } finally {
    await db.close();
  }
}

/// The part worth testing: turning a crossing into a visit row, into a tick
/// for whatever the user said arriving there completes, and — where the place
/// asked for it — into a row on the day of its own.
///
/// Returns the occurrences this crossing marked done or wrote, which is
/// nothing at all for the ordinary case of arriving somewhere with no routine
/// tied to it.
Future<List<Occurrence>> applyGeofenceEvent({
  required DaylineDatabase db,
  required List<int> placeIds,
  required GeofenceEvent event,
  required DateTime at,
}) async {
  final touched = <Occurrence>[];

  // Turning up somewhere ends whatever stay was still open somewhere else.
  // Done once for the whole batch rather than per place, so two overlapping
  // circles crossed together do not close each other; and done before any
  // arrival is recorded, so that coming back to a place finds nothing of its
  // own still open and starts a stay of its own.
  if (event != GeofenceEvent.exit) {
    for (final left in await db.placesDao.closeStaysAwayFrom(placeIds, at)) {
      await db.eventsDao.closeVisitEvent(left);
    }
  }

  for (final placeId in placeIds) {
    switch (event) {
      case GeofenceEvent.enter:
      // Android's dwell fires after the loitering delay, by which point the
      // device is definitely there. Treated as an arrival; recordArrival is
      // idempotent, so an enter followed by a dwell is still one visit.
      case GeofenceEvent.dwell:
        final visitId = await db.placesDao.recordArrival(placeId, at);
        // Deliberately after the visit is recorded. If the tick were written
        // first and the isolate died, there would be a completion with no
        // arrival behind it — a tick the dashboard could not account for.
        touched.addAll(
          await db.eventsDao.completeOnArrival(placeId: placeId, at: at),
        );

        // And only then a row of its own, so that a stay which just ticked off
        // a planned event is never also filed as an unplanned one.
        final place = await db.placesDao.placeById(placeId);
        if (place != null) {
          final recorded = await db.eventsDao.recordVisitAsEvent(
            place: place,
            visitId: visitId,
            at: at,
          );
          if (recorded != null) touched.add(recorded);
        }

      case GeofenceEvent.exit:
        final closed = await db.placesDao.recordDeparture(placeId, at);
        // Now that the stay has an end, the row it wrote can say how long it
        // lasted.
        if (closed != null) await db.eventsDao.closeVisitEvent(closed);
    }
  }
  return touched;
}
