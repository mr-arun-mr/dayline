import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/location/geofence_service.dart';
import 'package:dayline/src/model/place.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_geofence/native_geofence.dart' show GeofenceEvent;

/// Turning what the OS reports into visit rows.
///
/// Both platforms are unreliable here in specific, known ways — repeated
/// enters, an enter with no matching exit, an exit for a place we never saw an
/// arrival at — so these are the cases that matter.
void main() {
  late DaylineDatabase db;
  late int gym;

  setUp(() async {
    db = DaylineDatabase.forTesting(NativeDatabase.memory());
    gym = await db.placesDao.insertPlace(PlacesCompanion.insert(
      name: 'Gym',
      latitude: 51.5,
      longitude: -0.12,
      colorValue: 0xFF3B82F6,
      kind: PlaceKind.gym,
    ));
  });

  tearDown(() => db.close());

  Future<void> event(GeofenceEvent kind, DateTime at, {int? placeId}) =>
      applyGeofenceEvent(
        db: db,
        placeIds: [placeId ?? gym],
        event: kind,
        at: at,
      );

  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 9, 11, hour, minute);

  test('an enter then an exit is one visit', () async {
    await event(GeofenceEvent.enter, at(7));
    await event(GeofenceEvent.exit, at(8, 15));

    final visits = await db.placesDao.visitsForPlace(gym);
    expect(visits, hasLength(1));
    expect(visits.single.arrivedAt, at(7));
    expect(visits.single.departedAt, at(8, 15));
    expect(visits.single.durationAt(at(9)), const Duration(hours: 1, minutes: 15));
  });

  test('a repeated enter does not start a second visit', () async {
    // Both platforms re-deliver enters; two rows would double the time spent.
    await event(GeofenceEvent.enter, at(7));
    await event(GeofenceEvent.enter, at(7, 5));
    await event(GeofenceEvent.enter, at(7, 20));

    final visits = await db.placesDao.visitsForPlace(gym);
    expect(visits, hasLength(1));
    expect(visits.single.arrivedAt, at(7), reason: 'the first arrival stands');
  });

  test('a dwell after an enter is the same visit', () async {
    await event(GeofenceEvent.enter, at(7));
    await event(GeofenceEvent.dwell, at(7, 2));

    expect(await db.placesDao.visitsForPlace(gym), hasLength(1));
  });

  test('a dwell with no enter still opens a visit', () async {
    // Android sometimes reports only the dwell, once the loitering delay has
    // passed.
    await event(GeofenceEvent.dwell, at(7, 2));

    final visits = await db.placesDao.visitsForPlace(gym);
    expect(visits.single.arrivedAt, at(7, 2));
  });

  test('an exit with no arrival is dropped, not invented', () async {
    // A visit of unknown length is worse than no visit, because it gets
    // counted.
    await event(GeofenceEvent.exit, at(8));

    expect(await db.placesDao.visitsForPlace(gym), isEmpty);
  });

  test('a second exit does nothing', () async {
    await event(GeofenceEvent.enter, at(7));
    await event(GeofenceEvent.exit, at(8));
    await event(GeofenceEvent.exit, at(8, 30));

    final visits = await db.placesDao.visitsForPlace(gym);
    expect(visits.single.departedAt, at(8));
  });

  test('an exit before its arrival throws the visit away', () async {
    // The clock moved backwards — a time zone change or an NTP correction.
    // Keeping it would record a negative stay.
    await event(GeofenceEvent.enter, at(8));
    await event(GeofenceEvent.exit, at(7));

    expect(await db.placesDao.visitsForPlace(gym), isEmpty);
  });

  test('two places are tracked independently', () async {
    final office = await db.placesDao.insertPlace(PlacesCompanion.insert(
      name: 'Office',
      latitude: 51.51,
      longitude: -0.13,
      colorValue: 0xFF64748B,
      kind: PlaceKind.work,
    ));

    await event(GeofenceEvent.enter, at(7), placeId: gym);
    await event(GeofenceEvent.enter, at(9), placeId: office);
    await event(GeofenceEvent.exit, at(8), placeId: gym);

    expect((await db.placesDao.visitsForPlace(gym)).single.departedAt, at(8));
    expect((await db.placesDao.visitsForPlace(office)).single.isOpen, isTrue);
  });

  test('deleting a place takes its visits with it', () async {
    await event(GeofenceEvent.enter, at(7));
    await event(GeofenceEvent.exit, at(8));

    await db.placesDao.deletePlace(gym);

    expect(await db.select(db.visits).get(), isEmpty);
  });

  test('an open visit is still returned for a window that began later',
      () async {
    // The device has been at home since yesterday; today is not visit-free.
    await event(GeofenceEvent.enter, DateTime(2026, 9, 10, 22));

    final todays = await db.placesDao.visitsBetween(at(0), at(23, 59));
    expect(todays, hasLength(1));
    expect(todays.single.isOpen, isTrue);
  });

  test('clearing history keeps the places', () async {
    await event(GeofenceEvent.enter, at(7));
    await db.placesDao.clearHistory();

    expect(await db.select(db.visits).get(), isEmpty);
    expect(await db.placesDao.allPlaces(), hasLength(1));
  });

  test('geofence ids round trip through the place id', () {
    expect(GeofenceService.placeIdFrom(GeofenceService.idFor(42)), 42);
    expect(GeofenceService.placeIdFrom('nonsense'), isNull);
  });
}
