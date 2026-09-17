import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/location/geofence_service.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/occurrence.dart';
import 'package:dayline/src/model/place.dart';
import 'package:dayline/src/model/place_stats.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_geofence/native_geofence.dart' show GeofenceEvent;

/// The day line and the dashboard, told about the same stays.
///
/// They read the same history and used to disagree about it: the dashboard
/// lists every stay it can find, while the day only ever showed the rows that
/// happened to be written at the moment of arrival. A stay recorded before the
/// place was told to add its visits, one the callback never got to, one that
/// began last night, one that was a second trip to the same place that
/// afternoon — each of those was on the dashboard and missing from the day.
void main() {
  const monday = CalendarDate(2026, 9, 14);
  const tuesday = CalendarDate(2026, 9, 15);

  late DaylineDatabase db;
  late int home;
  late int gym;

  setUp(() async {
    db = DaylineDatabase.forTesting(NativeDatabase.memory());
    home = await db.placesDao.insertPlace(PlacesCompanion.insert(
      name: 'Brindley Point',
      latitude: 52.479,
      longitude: -1.905,
      colorValue: 0xFF3B82F6,
      kind: PlaceKind.home,
      addVisitsToDay: const Value(true),
    ));
    gym = await db.placesDao.insertPlace(PlacesCompanion.insert(
      name: 'LUXE Gym',
      latitude: 52.4793,
      longitude: -1.9054,
      colorValue: 0xFFF43F5E,
      kind: PlaceKind.gym,
    ));
  });

  tearDown(() => db.close());

  DateTime on(CalendarDate date, int hour, [int minute = 0]) =>
      date.localDateTimeAt(hour * 60 + minute);

  Future<void> arrive(int placeId, DateTime when) => applyGeofenceEvent(
        db: db,
        placeIds: [placeId],
        event: GeofenceEvent.enter,
        at: when,
      );

  Future<void> leave(int placeId, DateTime when) => applyGeofenceEvent(
        db: db,
        placeIds: [placeId],
        event: GeofenceEvent.exit,
        at: when,
      );

  Future<int> stay(int placeId, DateTime from, [DateTime? to]) =>
      db.into(db.visits).insert(VisitsCompanion.insert(
            placeId: placeId,
            arrivedAt: from,
            departedAt: Value(to),
          ));

  Future<void> addVisitsToDay(int placeId) async {
    final place = (await db.placesDao.placeById(placeId))!;
    await db.placesDao.updatePlace(PlacesCompanion(
      id: Value(place.id),
      name: Value(place.name),
      latitude: Value(place.latitude),
      longitude: Value(place.longitude),
      radiusMeters: Value(place.radiusMeters),
      colorValue: Value(place.colorValue),
      kind: Value(place.kind),
      isActive: Value(place.isActive),
      addVisitsToDay: const Value(true),
    ));
  }

  Future<List<Occurrence>> day(CalendarDate date, DateTime now) =>
      db.eventsDao.occurrencesForDate(date, clock: () => now);

  Future<List<Occurrence>> staysOn(CalendarDate date, DateTime now) async =>
      (await day(date, now)).where((o) => o.isVisitRecord).toList();

  group('a stay that ran over from the night before', () {
    test('is on the morning it ran into, at the top of it', () async {
      await arrive(home, on(monday, 19, 41));
      await leave(home, on(tuesday, 8, 46));

      final carried = await staysOn(tuesday, on(tuesday, 11, 18));
      expect(carried, hasLength(1));
      expect(carried.single.event.title, 'Brindley Point');
      expect(carried.single.effectiveTimeOfDay, 0,
          reason: 'the day found it already in progress');
      expect(carried.single.arrivedAt, on(monday, 19, 41),
          reason: 'the row still knows when the stay really began');
      expect(carried.single.departedAt, on(tuesday, 8, 46));
    });

    test('is still on the day it began, where it began', () async {
      await arrive(home, on(monday, 19, 41));
      await leave(home, on(tuesday, 8, 46));

      final began = await staysOn(monday, on(tuesday, 11, 18));
      expect(began, hasLength(1));
      expect(began.single.effectiveTimeOfDay, 19 * 60 + 41);
    });

    test('is drawn once on each, never twice on either', () async {
      await arrive(home, on(monday, 19, 41));
      await leave(home, on(tuesday, 8, 46));

      expect(await staysOn(monday, on(tuesday, 11, 18)), hasLength(1));
      expect(await staysOn(tuesday, on(tuesday, 11, 18)), hasLength(1));
      expect(await db.select(db.events).get(), hasLength(1),
          reason: 'one stay, one row — the other day only draws it');
    });

    test('is on the day even when nothing at all was planned', () async {
      // The empty day is the one that used to return before it had looked at
      // where the device had been.
      await arrive(home, on(monday, 22));

      final tonight = await day(monday, on(monday, 23));
      expect(tonight, hasLength(1));
      expect(tonight.single.isVisitRecord, isTrue);
    });

    test('an open one is on every day it has reached', () async {
      await arrive(home, on(monday, 19, 41));

      expect(await staysOn(monday, on(tuesday, 11)), hasLength(1));
      expect(await staysOn(tuesday, on(tuesday, 11)), hasLength(1));
      expect(await staysOn(tuesday.addDays(1), on(tuesday, 11)), isEmpty,
          reason: 'it has not got to tomorrow yet');
    });
  });

  group('a crossing the OS re-delivered', () {
    test('files the stay under the day it began, not the day it was '
        'reported', () async {
      // Both platforms report an enter for a circle the device is already
      // sitting in, on every app start. Last night's arrival is not news this
      // morning, and it is certainly not a stay that began this morning.
      await stay(home, on(monday, 19, 41));

      await arrive(home, on(tuesday, 8, 28));

      final row = (await db.select(db.events).get()).single;
      expect(row.startDate, monday);
      expect(row.timeOfDay, 19 * 60 + 41);
    });

    test('ticks it off at the moment it began', () async {
      await stay(home, on(monday, 19, 41));

      await arrive(home, on(tuesday, 8, 28));

      final completion = (await db.select(db.completions).get()).single;
      expect(completion.date, monday);
      expect(completion.completedAt, on(monday, 19, 41));
    });

    test('still writes nothing twice', () async {
      await arrive(home, on(monday, 19, 41));
      await arrive(home, on(tuesday, 8, 28));
      await arrive(home, on(tuesday, 9, 15));

      expect(await db.select(db.events).get(), hasLength(1));
    });
  });

  group('going back to the same place', () {
    test('gets a row of its own, however soon it was', () async {
      // Four stays at the gym in a day is four stays. The dashboard has always
      // listed them; the day used to swallow any that fell within two hours of
      // one already on it.
      await addVisitsToDay(gym);

      await arrive(gym, on(tuesday, 9, 3));
      await leave(gym, on(tuesday, 12, 40));
      await arrive(gym, on(tuesday, 12, 41));
      await leave(gym, on(tuesday, 13, 19));
      await arrive(gym, on(tuesday, 14, 7));
      await leave(gym, on(tuesday, 20, 20));
      await arrive(gym, on(tuesday, 20, 20, ));
      await leave(gym, on(tuesday, 20, 30));

      final stays = await staysOn(tuesday, on(tuesday, 23));
      expect(stays, hasLength(4));
      expect(
        stays.map((o) => o.effectiveTimeOfDay),
        [9 * 60 + 3, 12 * 60 + 41, 14 * 60 + 7, 20 * 60 + 20],
      );
    });

    test('the day and the dashboard count the same stays', () async {
      await addVisitsToDay(gym);

      await arrive(home, on(monday, 19, 41));
      await arrive(gym, on(tuesday, 9, 3));
      await leave(gym, on(tuesday, 12, 40));
      await arrive(gym, on(tuesday, 12, 41));
      await leave(gym, on(tuesday, 13, 19));
      await arrive(gym, on(tuesday, 14, 7));
      await leave(gym, on(tuesday, 20, 20));

      final now = on(tuesday, 22);
      final dashboard = visitsOnDay(
        await db.placesDao.visitsBetween(
          monday.localDateTimeAt(0),
          tuesday.addDays(1).localDateTimeAt(0),
        ),
        tuesday,
        now: now,
      );

      expect(
        (await staysOn(tuesday, now)).map((o) => o.visit?.id).toList(),
        dashboard.map((v) => v.id).toList(),
        reason: 'the two views read the same history',
      );
    });
  });

  group('a plan that is already showing the stay', () {
    test('keeps the second row off the day', () async {
      await addVisitsToDay(gym);
      await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Workout',
        colorValue: 1,
        timeOfDay: 9 * 60,
        recurrence: Recurrence.daily,
        startDate: monday.addDays(-10),
        placeId: Value(gym),
      ));

      await arrive(gym, on(tuesday, 9, 3));

      final today = await day(tuesday, on(tuesday, 10));
      expect(today, hasLength(1));
      expect(today.single.event.title, 'Workout');
      expect(today.single.arrivedAt, on(tuesday, 9, 3),
          reason: 'the plan is the record of that stay, and says so');
    });

    test('but only of the one it is showing', () async {
      // The afternoon is a different stay. Nothing on the day accounts for it,
      // whatever the morning's routine says.
      await addVisitsToDay(gym);
      await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Workout',
        colorValue: 1,
        timeOfDay: 9 * 60,
        recurrence: Recurrence.daily,
        startDate: monday.addDays(-10),
        placeId: Value(gym),
      ));

      await arrive(gym, on(tuesday, 9, 3));
      await leave(gym, on(tuesday, 10));
      await arrive(gym, on(tuesday, 10, 30));

      final stays = await staysOn(tuesday, on(tuesday, 11));
      expect(stays, hasLength(1));
      expect(stays.single.effectiveTimeOfDay, 10 * 60 + 30);
    });
  });

  group('filling the day in from the visits', () {
    test('puts a stay recorded before the place asked onto the day', () async {
      // The gym was not adding its visits when this was recorded, so nothing
      // wrote a row — and nothing ever went back for it.
      await arrive(gym, on(tuesday, 9, 3));
      await leave(gym, on(tuesday, 12, 40));
      expect(await staysOn(tuesday, on(tuesday, 13)), isEmpty);

      await addVisitsToDay(gym);
      expect(await db.eventsDao.fillDayFromVisits(tuesday), 1);

      final stays = await staysOn(tuesday, on(tuesday, 13));
      expect(stays.single.event.title, 'LUXE Gym');
      expect(stays.single.effectiveTimeOfDay, 9 * 60 + 3);
      expect(stays.single.isDone, isTrue);
    });

    test('fills in a whole day of them at once', () async {
      await stay(gym, on(tuesday, 9, 3), on(tuesday, 12, 40));
      await stay(gym, on(tuesday, 12, 41), on(tuesday, 13, 19));
      await stay(gym, on(tuesday, 14, 7), on(tuesday, 20, 20));
      await addVisitsToDay(gym);

      expect(await db.eventsDao.fillDayFromVisits(tuesday), 3);
      expect(await staysOn(tuesday, on(tuesday, 23)), hasLength(3));
    });

    test('changes nothing on a day that is already right', () async {
      await addVisitsToDay(gym);
      await arrive(gym, on(tuesday, 9, 3));

      expect(await db.eventsDao.fillDayFromVisits(tuesday), 0);
      expect(await db.eventsDao.fillDayFromVisits(tuesday), 0);
      expect(await staysOn(tuesday, on(tuesday, 13)), hasLength(1));
    });

    test('leaves a place that never asked alone', () async {
      await stay(gym, on(tuesday, 9, 3), on(tuesday, 12, 40));

      expect(await db.eventsDao.fillDayFromVisits(tuesday), 0);
      expect(await staysOn(tuesday, on(tuesday, 13)), isEmpty,
          reason: 'off by default, and filling in does not change that');
    });

    test('leaves a stay that began yesterday to yesterday', () async {
      await stay(home, on(monday, 19, 41), on(tuesday, 8, 46));

      expect(await db.eventsDao.fillDayFromVisits(tuesday), 0);
      expect(await db.eventsDao.fillDayFromVisits(monday), 1);
      expect(
        (await db.select(db.events).get()).single.startDate,
        monday,
      );
    });

    test('writes nothing a plan on the day already shows', () async {
      await addVisitsToDay(gym);
      await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Workout',
        colorValue: 1,
        timeOfDay: 9 * 60,
        recurrence: Recurrence.daily,
        startDate: monday.addDays(-10),
        placeId: Value(gym),
      ));
      await stay(gym, on(tuesday, 9, 3), on(tuesday, 10));

      expect(await db.eventsDao.fillDayFromVisits(tuesday), 0);
    });
  });
}
