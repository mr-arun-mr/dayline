import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/location/geofence_service.dart';
import 'package:dayline/src/model/place.dart';
import 'package:dayline/src/model/place_stats.dart';
import 'package:drift/drift.dart' show Value;
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

  Future<int> addPlace(String name, {double? radius}) =>
      db.placesDao.insertPlace(PlacesCompanion.insert(
        name: name,
        latitude: 51.51,
        longitude: -0.13,
        radiusMeters: radius == null ? const Value.absent() : Value(radius),
        colorValue: 0xFF64748B,
        kind: PlaceKind.other,
      ));

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

  test('a late exit still lands on the stay it belongs to', () async {
    // The gym's exit arrives after the office arrival that already had to
    // guess the gym stay was over. The OS knows when the device left; the
    // guess was only ever "no later than this", so the real time wins.
    final office = await addPlace('Office');

    await event(GeofenceEvent.enter, at(7), placeId: gym);
    await event(GeofenceEvent.enter, at(9), placeId: office);
    await event(GeofenceEvent.exit, at(8), placeId: gym);

    expect((await db.placesDao.visitsForPlace(gym)).single.departedAt, at(8));
    expect((await db.placesDao.visitsForPlace(office)).single.isOpen, isTrue);
  });

  group('one place at a time', () {
    // Both platforms drop exits, and the one they drop is usually the exit for
    // the place just left: the crossing they are busy reporting is the
    // arrival. A device is only ever in one place, so an arrival is also news
    // about everywhere else.

    test('arriving elsewhere ends a stay left open', () async {
      final office = await addPlace('Office');

      await event(GeofenceEvent.enter, at(7), placeId: gym);
      await event(GeofenceEvent.enter, at(9), placeId: office);

      final stay = (await db.placesDao.visitsForPlace(gym)).single;
      expect(stay.departedAt, at(9), reason: 'no exit ever came for the gym');
    });

    test('coming back is a stay of its own', () async {
      // Home, office, home. Left alone, the morning at home stays open, the
      // evening arrival is folded into it, and a day with two stays at home
      // and a day out is one entry saying "home".
      final home = await addPlace('Home');
      final office = await addPlace('Office');

      await event(GeofenceEvent.enter, at(7), placeId: home);
      await event(GeofenceEvent.enter, at(9), placeId: office);
      await event(GeofenceEvent.enter, at(18), placeId: home);

      final athome = await db.placesDao.visitsForPlace(home);
      expect(athome, hasLength(2));
      expect(athome.first.arrivedAt, at(7));
      expect(athome.first.departedAt, at(9));
      expect(athome.last.arrivedAt, at(18));
      expect(athome.last.isOpen, isTrue);

      final atwork = (await db.placesDao.visitsForPlace(office)).single;
      expect(atwork.departedAt, at(18), reason: 'being home ended the office');
    });

    test('the day adds up to the day, not more', () async {
      // Overlapping stays would have the device at home and at the office at
      // once, and the totals would say eleven hours in an eight-hour day.
      final home = await addPlace('Home');
      final office = await addPlace('Office');

      await event(GeofenceEvent.enter, at(7), placeId: home);
      await event(GeofenceEvent.enter, at(9), placeId: office);
      await event(GeofenceEvent.enter, at(18), placeId: home);

      final totals = timePerPlace(
        await db.placesDao.visitsBetween(at(0), at(23, 59)),
        from: at(0),
        to: at(23, 59),
        now: at(20),
      );
      expect(totals[home], const Duration(hours: 4));
      expect(totals[office], const Duration(hours: 9));
    });

    test('a crossing naming two circles records the smaller one', () async {
      // The OS will not watch a circle much under a hundred metres, so a gym
      // inside an office campus is inside the campus fence too and both are
      // reported at once. The device is in one place, and the tighter fence is
      // the more specific description of it.
      final office = await addPlace('Office', radius: 400);

      await applyGeofenceEvent(
        db: db,
        placeIds: [office, gym],
        event: GeofenceEvent.enter,
        at: at(9),
      );

      expect((await db.placesDao.visitsForPlace(gym)).single.isOpen, isTrue);
      expect(await db.placesDao.visitsForPlace(office), isEmpty,
          reason: 'the same hours under two names is the bug');
    });

    test('a circle already open is not what the crossing is about', () async {
      // The real shape of it: two places a street apart. The first arrival
      // reports one, and a minute later the crossing for the second reports
      // both, because the device is inside both. The news is the one that is
      // not already recorded.
      final shop = await addPlace('GS');

      await event(GeofenceEvent.enter, at(9, 1), placeId: shop);
      await applyGeofenceEvent(
        db: db,
        placeIds: [shop, gym],
        event: GeofenceEvent.enter,
        at: at(9, 2),
      );
      await applyGeofenceEvent(
        db: db,
        placeIds: [shop, gym],
        event: GeofenceEvent.exit,
        at: at(12, 30),
      );

      final atGym = await db.placesDao.visitsForPlace(gym);
      expect(atGym.single.arrivedAt, at(9, 2));
      expect(atGym.single.departedAt, at(12, 30));
      expect(await db.placesDao.visitsForPlace(shop), isEmpty,
          reason: 'a minute at the edge of a circle is not a visit');
    });

    test('a stay clipped on the way past is dropped, not recorded', () async {
      // Ended by our own inference rather than by the OS, and shorter than
      // either platform takes to call an arrival an arrival.
      final office = await addPlace('Office');

      await event(GeofenceEvent.enter, at(9), placeId: gym);
      await event(GeofenceEvent.enter, at(9, 1), placeId: office);

      expect(await db.placesDao.visitsForPlace(gym), isEmpty);
      expect((await db.placesDao.visitsForPlace(office)).single.isOpen, isTrue);
    });

    test('a long stay ended the same way is kept', () async {
      final office = await addPlace('Office');

      await event(GeofenceEvent.enter, at(9), placeId: gym);
      await event(GeofenceEvent.enter, at(9, 2), placeId: office);

      expect((await db.placesDao.visitsForPlace(gym)).single.departedAt,
          at(9, 2));
    });

    test('a short stay the OS itself ended is still a stay', () async {
      // Two minutes at the school gate is a drop-off. The OS reported the
      // exit, so the length is a fact rather than a guess, and facts stand.
      await event(GeofenceEvent.enter, at(8, 30));
      await event(GeofenceEvent.exit, at(8, 31));

      expect((await db.placesDao.visitsForPlace(gym)).single.departedAt,
          at(8, 31));
    });

    test('an arrival older than the stay leaves it alone', () async {
      // Crossings can be delivered out of order. An arrival from before a
      // stay even began says nothing about when that stay ended, so it is
      // left open rather than closed at a time it cannot have ended.
      final office = await addPlace('Office');

      await event(GeofenceEvent.enter, at(9), placeId: gym);
      await event(GeofenceEvent.enter, at(8), placeId: office);

      expect((await db.placesDao.visitsForPlace(gym)).single.isOpen, isTrue);
    });

    test('an exit for a stay already ended changes nothing', () async {
      final office = await addPlace('Office');

      await event(GeofenceEvent.enter, at(7), placeId: gym);
      await event(GeofenceEvent.exit, at(8), placeId: gym);
      await event(GeofenceEvent.enter, at(9), placeId: office);
      await event(GeofenceEvent.exit, at(8, 30), placeId: gym);

      expect((await db.placesDao.visitsForPlace(gym)).single.departedAt, at(8));
    });
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
