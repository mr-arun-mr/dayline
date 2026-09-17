import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/location/geofence_service.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/place.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_geofence/native_geofence.dart' show GeofenceEvent;

/// Putting somewhere you went onto the day you went there.
///
/// The other half of tying events to places: auto-completion covers what was
/// planned, this covers what was not, and between them the day reads as what
/// actually happened. The whole risk is noise — a row nobody asked for, or two
/// rows for one stay — so most of this is about what it declines to write.
void main() {
  const today = CalendarDate(2026, 9, 11);

  late DaylineDatabase db;
  late int gym;
  late int home;

  setUp(() async {
    db = DaylineDatabase.forTesting(NativeDatabase.memory());
    gym = await db.placesDao.insertPlace(PlacesCompanion.insert(
      name: 'Gym',
      latitude: 51.5,
      longitude: -0.12,
      colorValue: 0xFF3B82F6,
      kind: PlaceKind.gym,
      addVisitsToDay: const Value(true),
    ));
    home = await db.placesDao.insertPlace(PlacesCompanion.insert(
      name: 'Home',
      latitude: 51.4,
      longitude: -0.1,
      colorValue: 0xFF64748B,
      kind: PlaceKind.home,
    ));
  });

  tearDown(() => db.close());

  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 9, 11, hour, minute);

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

  Future<int> addRoutine({
    required int placeId,
    int timeOfDay = 7 * 60,
    String title = 'Workout',
  }) =>
      db.eventsDao.insertEvent(EventsCompanion.insert(
        title: title,
        colorValue: 0xFF3B82F6,
        timeOfDay: timeOfDay,
        recurrence: Recurrence.daily,
        startDate: today.addDays(-10),
        placeId: Value(placeId),
      ));

  group('a place that asked for it', () {
    test('puts the visit on the day, already done', () async {
      await arrive(gym, at(10, 15));

      final occurrence = (await db.eventsDao.occurrencesForDate(today)).single;
      expect(occurrence.event.title, 'Gym');
      expect(occurrence.effectiveTimeOfDay, 10 * 60 + 15);
      expect(occurrence.isDone, isTrue,
          reason: 'it happened; leaving it pending would file it as overdue');
      expect(occurrence.isVisitRecord, isTrue);
    });

    test('writes a one-off, not a routine', () async {
      await arrive(gym, at(10));
      // Left again, because a stay still running has genuinely reached
      // tomorrow and the day line says so. This is about the rule.
      await leave(gym, at(11));

      final row = (await db.select(db.events).get()).single;
      expect(row.recurrence, Recurrence.once);
      expect(row.startDate, today);
      // Tomorrow did not also acquire a gym visit.
      expect(await db.eventsDao.occurrencesForDate(today.addDays(1)), isEmpty);
    });

    test('asks for no reminder, having already happened', () async {
      await arrive(gym, at(10));

      expect((await db.select(db.events).get()).single.leadMinutes, isEmpty);
    });

    test('takes the place name and colour', () async {
      await arrive(gym, at(10));

      final row = (await db.select(db.events).get()).single;
      expect(row.title, 'Gym');
      expect(row.colorValue, 0xFF3B82F6);
      expect(row.placeId, gym);
    });

    test('fills in how long it lasted once the visit ends', () async {
      await arrive(gym, at(10));
      await leave(gym, at(11, 20));

      expect((await db.select(db.events).get()).single.durationMin, 80);
    });

    test('leaves the duration open while still there', () async {
      await arrive(gym, at(10));

      expect((await db.select(db.events).get()).single.durationMin, isNull);
    });
  });

  group('what it declines to write', () {
    test('nothing for a place that did not ask', () async {
      await arrive(home, at(19));

      expect(await db.select(db.events).get(), isEmpty);
      expect(await db.placesDao.visitsForPlace(home), hasLength(1),
          reason: 'the visit itself is still recorded for the dashboard');
    });

    test('nothing when a routine at that place already covers it', () async {
      // The 07:00 workout is already the record of having been to the gym.
      // A second row an hour later is the noise this exists to avoid.
      await addRoutine(placeId: gym, timeOfDay: 7 * 60);

      await arrive(gym, at(7, 5));

      final occurrences = await db.eventsDao.occurrencesForDate(today);
      expect(occurrences, hasLength(1));
      expect(occurrences.single.event.title, 'Workout');
      expect(occurrences.single.isVisitRecord, isFalse);
    });

    test('but does write one for a second, unrelated visit', () async {
      // Back at the gym in the evening is a different stay, and nothing on the
      // day accounts for it.
      await addRoutine(placeId: gym, timeOfDay: 7 * 60);

      await arrive(gym, at(7, 5));
      await leave(gym, at(8));
      await arrive(gym, at(19));

      final occurrences = await db.eventsDao.occurrencesForDate(today);
      expect(occurrences, hasLength(2));
      expect(occurrences.last.isVisitRecord, isTrue);
      expect(occurrences.last.effectiveTimeOfDay, 19 * 60);
    });

    test('nothing twice for one stay, however often the OS says so', () async {
      // Every app start re-registers the fences, and both platforms fire an
      // enter for a place the device is already sitting in.
      await arrive(gym, at(10));
      await arrive(gym, at(10, 30));
      await arrive(gym, at(11));

      expect(await db.select(db.events).get(), hasLength(1));
    });

    test('nothing for a departure', () async {
      await leave(gym, at(10));

      expect(await db.select(db.events).get(), isEmpty);
    });

    test('nothing when a routine there was already auto-completed', () async {
      final id = await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Workout',
        colorValue: 1,
        timeOfDay: 7 * 60,
        recurrence: Recurrence.daily,
        startDate: today.addDays(-10),
        placeId: Value(gym),
        autoCompleteOnArrival: const Value(true),
      ));

      await arrive(gym, at(7, 5));

      final occurrences = await db.eventsDao.occurrencesForDate(today);
      expect(occurrences, hasLength(1));
      expect(occurrences.single.eventId, id);
      expect(occurrences.single.isDone, isTrue);
    });
  });

  group('keeping them out of the way', () {
    test('they are not listed under All events', () async {
      await addRoutine(placeId: home, title: 'Dinner', timeOfDay: 19 * 60);
      await arrive(gym, at(10));

      final listed = await db.eventsDao.allEvents();
      expect(listed.map((e) => e.title), ['Dinner']);
    });

    test('they are still on the day itself', () async {
      await arrive(gym, at(10));

      expect(await db.eventsDao.occurrencesForDate(today), hasLength(1));
    });

    test('they can still be opened by id, to be edited', () async {
      await arrive(gym, at(10));
      final id = (await db.select(db.events).get()).single.id;

      expect((await db.eventsDao.eventById(id))?.title, 'Gym');
    });

    test('clearing visit history takes them with it', () async {
      // They are visit history, drawn on the day. Leaving them behind would
      // strand a row nothing can explain.
      await addRoutine(placeId: home, title: 'Dinner', timeOfDay: 19 * 60);
      await arrive(gym, at(10));
      expect(await db.select(db.events).get(), hasLength(2));

      await db.placesDao.clearHistory();

      final left = await db.select(db.events).get();
      expect(left.single.title, 'Dinner');
    });

    test('deleting the place takes them with it', () async {
      await arrive(gym, at(10));

      await db.placesDao.deletePlace(gym);

      expect(await db.select(db.events).get(), isEmpty);
    });
  });

  group('adopting one', () {
    test('a row saved from the editor stops being visit history', () async {
      await arrive(gym, at(10));
      final id = (await db.select(db.events).get()).single.id;

      // What the editor does on save.
      await db.eventsDao.updateEvent(EventsCompanion(
        id: Value(id),
        title: const Value('Swimming'),
        colorValue: const Value(0xFF3B82F6),
        timeOfDay: const Value(10 * 60),
        recurrence: const Value(Recurrence.once),
        startDate: Value(today),
        placeId: Value(gym),
        fromVisitId: const Value(null),
      ));

      final event = (await db.eventsDao.eventById(id))!;
      expect(event.isVisitRecord, isFalse);
      expect(await db.eventsDao.allEvents(), hasLength(1),
          reason: 'it is the user\'s event now, so it belongs in the list');
    });

    test('and survives the history being cleared', () async {
      await arrive(gym, at(10));
      final id = (await db.select(db.events).get()).single.id;
      await db.eventsDao.updateEvent(EventsCompanion(
        id: Value(id),
        title: const Value('Swimming'),
        colorValue: const Value(1),
        timeOfDay: const Value(10 * 60),
        recurrence: const Value(Recurrence.once),
        startDate: Value(today),
        fromVisitId: const Value(null),
      ));

      await db.placesDao.clearHistory();

      expect((await db.select(db.events).get()).single.title, 'Swimming');
    });

    test('and a later departure does not rewrite it', () async {
      await arrive(gym, at(10));
      final id = (await db.select(db.events).get()).single.id;
      await db.eventsDao.updateEvent(EventsCompanion(
        id: Value(id),
        title: const Value('Swimming'),
        colorValue: const Value(1),
        timeOfDay: const Value(10 * 60),
        durationMin: const Value(30),
        recurrence: const Value(Recurrence.once),
        startDate: Value(today),
        fromVisitId: const Value(null),
      ));

      await leave(gym, at(11, 20));

      expect((await db.select(db.events).get()).single.durationMin, 30,
          reason: 'the user said half an hour; the fence does not overrule it');
    });
  });

  group('the progress ring', () {
    test('does not count a visit as something you planned', () async {
      await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Standup',
        colorValue: 1,
        timeOfDay: 9 * 60,
        recurrence: Recurrence.daily,
        startDate: today.addDays(-10),
      ));
      await arrive(gym, at(10));

      final occurrences = await db.eventsDao.occurrencesForDate(today);
      final planned = occurrences.where((o) => !o.isVisitRecord);
      expect(occurrences, hasLength(2));
      expect(planned, hasLength(1));
    });
  });
}
