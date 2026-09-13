import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/location/geofence_service.dart';
import 'package:dayline/src/model/auto_complete.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/event.dart';
import 'package:dayline/src/model/place.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_geofence/native_geofence.dart' show GeofenceEvent;

/// Marking an event done by turning up to it.
///
/// The rule the whole feature rests on: the app may tick off a day the user has
/// not touched, and may never touch a day the user has. Everything below is
/// some version of that.
void main() {
  const today = CalendarDate(2026, 9, 11);

  late DaylineDatabase db;
  late int gym;
  late int office;

  setUp(() async {
    db = DaylineDatabase.forTesting(NativeDatabase.memory());
    gym = await db.placesDao.insertPlace(PlacesCompanion.insert(
      name: 'Gym',
      latitude: 51.5,
      longitude: -0.12,
      colorValue: 0xFF3B82F6,
      kind: PlaceKind.gym,
    ));
    office = await db.placesDao.insertPlace(PlacesCompanion.insert(
      name: 'Office',
      latitude: 51.51,
      longitude: -0.13,
      colorValue: 0xFF64748B,
      kind: PlaceKind.work,
    ));
  });

  tearDown(() => db.close());

  Future<int> addEvent({
    String title = 'Gym',
    int timeOfDay = 7 * 60,
    int? placeId,
    bool autoComplete = true,
    bool isActive = true,
    Recurrence recurrence = Recurrence.daily,
    CalendarDate? startDate,
  }) =>
      db.eventsDao.insertEvent(EventsCompanion.insert(
        title: title,
        colorValue: 0xFF3B82F6,
        timeOfDay: timeOfDay,
        recurrence: recurrence,
        startDate: startDate ?? today.addDays(-10),
        placeId: Value(placeId),
        autoCompleteOnArrival: Value(autoComplete),
        isActive: Value(isActive),
      ));

  /// A crossing, through the same entry point the OS callback uses.
  Future<void> arriveAt(int placeId, DateTime at) => applyGeofenceEvent(
        db: db,
        placeIds: [placeId],
        event: GeofenceEvent.enter,
        at: at,
      );

  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 9, 11, hour, minute);

  Future<CompletionRow?> completionFor(int eventId) =>
      (db.select(db.completions)..where((c) => c.eventId.equals(eventId)))
          .getSingleOrNull();

  group('arriving at the place', () {
    test('marks the occurrence done', () async {
      final id = await addEvent(placeId: gym);

      await arriveAt(gym, at(6, 55));

      final completion = await completionFor(id);
      expect(completion, isNotNull);
      expect(completion!.status, CompletionStatus.done);
      expect(completion.date, today);
    });

    test('records the arrival time, not the moment the callback ran', () async {
      // The OS can deliver a crossing minutes late; the tick is about when the
      // user got there.
      final id = await addEvent(placeId: gym);

      await arriveAt(gym, at(7, 3));

      expect((await completionFor(id))!.completedAt, at(7, 3));
    });

    test('says the app did it, not the user', () async {
      final id = await addEvent(placeId: gym);

      await arriveAt(gym, at(7));

      expect((await completionFor(id))!.isAutomatic, isTrue);
      final occurrence = (await db.eventsDao.occurrencesForDate(today)).single;
      expect(occurrence.isDone, isTrue);
      expect(occurrence.isAutomatic, isTrue);
    });

    test('reports back what it ticked off', () async {
      await addEvent(title: 'Gym', placeId: gym);

      final completed = await applyGeofenceEvent(
        db: db,
        placeIds: [gym],
        event: GeofenceEvent.enter,
        at: at(7),
      );

      expect(completed.single.event.title, 'Gym');
      expect(completed.single.isAutomatic, isTrue);
    });

    test('still records the visit itself', () async {
      await addEvent(placeId: gym);

      await arriveAt(gym, at(7));

      expect(await db.placesDao.visitsForPlace(gym), hasLength(1));
    });
  });

  group('what it leaves alone', () {
    test('a rule that did not ask for it', () async {
      final id = await addEvent(placeId: gym, autoComplete: false);

      await arriveAt(gym, at(7));

      expect(await completionFor(id), isNull);
    });

    test('a rule tied to somewhere else', () async {
      final id = await addEvent(placeId: office);

      await arriveAt(gym, at(7));

      expect(await completionFor(id), isNull);
    });

    test('a rule tied to nowhere at all', () async {
      // The flag can outlive the place it was set for; a rule with nothing to
      // arrive at simply never completes itself.
      final id = await addEvent(placeId: null);

      await arriveAt(gym, at(7));

      expect(await completionFor(id), isNull);
    });

    test('a paused rule', () async {
      final id = await addEvent(placeId: gym, isActive: false);

      await arriveAt(gym, at(7));

      expect(await completionFor(id), isNull);
    });

    test('an arrival well outside the window', () async {
      final id = await addEvent(placeId: gym, timeOfDay: 7 * 60);

      // Three hours late for a 07:00 class is not turning up for it.
      await arriveAt(gym, at(10));

      expect(await completionFor(id), isNull);
    });

    test('a day the rule does not run', () async {
      final id = await addEvent(
        placeId: gym,
        recurrence: Recurrence.weekly,
        startDate: today.addDays(-30),
      );
      // Weekly with no days ticked never occurs — and 2026-09-11 is a Friday.
      await arriveAt(gym, at(7));

      expect(await completionFor(id), isNull);
    });

    test('a day the user already skipped', () async {
      // "I let that one go" must not become "you went". The dashboard would
      // repeat the lie afterwards.
      final id = await addEvent(placeId: gym);
      await db.eventsDao.setCompletion(
        eventId: id,
        date: today,
        status: CompletionStatus.skipped,
        at: at(6),
      );

      await arriveAt(gym, at(7));

      final completion = await completionFor(id);
      expect(completion!.status, CompletionStatus.skipped);
      expect(completion.isAutomatic, isFalse);
    });

    test('a day the user already marked done by hand', () async {
      final id = await addEvent(placeId: gym);
      await db.eventsDao.setCompletion(
        eventId: id,
        date: today,
        status: CompletionStatus.done,
        at: at(6, 30),
      );

      await arriveAt(gym, at(7));

      final completion = await completionFor(id);
      expect(completion!.completedAt, at(6, 30), reason: 'not re-stamped');
      expect(completion.isAutomatic, isFalse);
    });

    test('a single occurrence deleted from the series', () async {
      final id = await addEvent(placeId: gym);
      await db.eventsDao.deleteOccurrence(id, today);

      await arriveAt(gym, at(7));

      expect(await completionFor(id), isNull);
    });

    test('a departure', () async {
      final id = await addEvent(placeId: gym);

      await applyGeofenceEvent(
        db: db,
        placeIds: [gym],
        event: GeofenceEvent.exit,
        at: at(7),
      );

      expect(await completionFor(id), isNull);
    });
  });

  group('the grace window', () {
    test('early counts, up to the edge', () async {
      final id = await addEvent(placeId: gym, timeOfDay: 19 * 60);

      // Turning up early for the 19:00 class is still turning up.
      await arriveAt(gym, at(17, 1));

      expect(await completionFor(id), isNotNull);
    });

    test('late counts, up to the edge', () async {
      final id = await addEvent(placeId: gym, timeOfDay: 7 * 60);

      await arriveAt(gym, at(8, 59));

      expect(await completionFor(id), isNotNull);
    });

    test('exactly at the edge still counts', () async {
      final id = await addEvent(placeId: gym, timeOfDay: 7 * 60);

      await arriveAt(gym, at(9));

      expect(await completionFor(id), isNotNull);
    });

    test('a minute past the edge does not', () async {
      final id = await addEvent(placeId: gym, timeOfDay: 7 * 60);

      await arriveAt(gym, at(9, 1));

      expect(await completionFor(id), isNull);
    });

    test('reaches into tomorrow across midnight', () async {
      // A 00:30 shift, arrived at half an hour before it starts.
      final id = await addEvent(placeId: office, timeOfDay: 30);

      await applyGeofenceEvent(
        db: db,
        placeIds: [office],
        event: GeofenceEvent.enter,
        at: DateTime(2026, 9, 10, 23, 55),
      );

      expect((await completionFor(id))!.date, today);
    });

    test('reaches back into yesterday across midnight', () async {
      final id = await addEvent(placeId: office, timeOfDay: 23 * 60 + 30);

      await arriveAt(office, DateTime(2026, 9, 12, 0, 20));

      expect((await completionFor(id))!.date, today);
    });

    test('is the same grace the dashboard judges adherence by', () {
      expect(arrivalGrace, const Duration(hours: 2));
    });
  });

  group('what the OS actually delivers', () {
    test('a repeated enter for the same stay ticks once', () async {
      // Both platforms re-deliver enters. The second must not re-stamp the
      // row with a later time, or the record of when you arrived drifts.
      final id = await addEvent(placeId: gym);

      await arriveAt(gym, at(6, 50));
      await arriveAt(gym, at(7, 10));
      await arriveAt(gym, at(7, 30));

      expect((await completionFor(id))!.completedAt, at(6, 50));
    });

    test('a dwell completes as well as an enter', () async {
      // Android sometimes reports only the dwell, after the loitering delay.
      final id = await addEvent(placeId: gym);

      await applyGeofenceEvent(
        db: db,
        placeIds: [gym],
        event: GeofenceEvent.dwell,
        at: at(7, 2),
      );

      expect(await completionFor(id), isNotNull);
    });

    test('one arrival completes every routine tied to that place', () async {
      final stretch = await addEvent(title: 'Stretch', placeId: gym);
      final weights =
          await addEvent(title: 'Weights', placeId: gym, timeOfDay: 7 * 60 + 30);

      await arriveAt(gym, at(7));

      expect(await completionFor(stretch), isNotNull);
      expect(await completionFor(weights), isNotNull);
    });

    test('a crossing carrying two places is handled for both', () async {
      // Places can overlap — a gym inside an office block reports both.
      final atGym = await addEvent(title: 'Gym', placeId: gym);
      final atWork = await addEvent(title: 'Standup', placeId: office);

      await applyGeofenceEvent(
        db: db,
        placeIds: [gym, office],
        event: GeofenceEvent.enter,
        at: at(7),
      );

      expect(await completionFor(atGym), isNotNull);
      expect(await completionFor(atWork), isNotNull);
    });

    test('an arrival nowhere near a routine costs nothing', () async {
      await arriveAt(gym, at(7));

      expect(await db.select(db.completions).get(), isEmpty);
    });
  });

  group('a moved occurrence', () {
    test('is matched against the time it was moved to', () async {
      final id = await addEvent(placeId: gym, timeOfDay: 7 * 60);
      await db.eventsDao.setOverride(EventOverride(
        eventId: id,
        date: today,
        type: OverrideType.moved,
        newTimeOfDay: 20 * 60,
      ));

      await arriveAt(gym, at(19, 45));

      expect(await completionFor(id), isNotNull);
    });

    test('is not matched against the time it was moved from', () async {
      final id = await addEvent(placeId: gym, timeOfDay: 7 * 60);
      await db.eventsDao.setOverride(EventOverride(
        eventId: id,
        date: today,
        type: OverrideType.moved,
        newTimeOfDay: 20 * 60,
      ));

      await arriveAt(gym, at(7));

      expect(await completionFor(id), isNull);
    });
  });

  group('candidate dates', () {
    test('a two-hour grace reaches one day either side', () {
      final dates = datesInGraceOf(DateTime(2026, 9, 11, 12));
      expect(dates, [
        const CalendarDate(2026, 9, 10),
        today,
        const CalendarDate(2026, 9, 12),
      ]);
    });

    test('a grace of several days reaches all of them', () {
      final dates = datesInGraceOf(
        DateTime(2026, 9, 11, 12),
        grace: const Duration(days: 2),
      );
      expect(dates.first, const CalendarDate(2026, 9, 9));
      expect(dates.last, const CalendarDate(2026, 9, 13));
    });
  });

  group('one-off events', () {
    test('a dentist appointment completes on arrival too', () async {
      final id = await addEvent(
        title: 'Dentist',
        placeId: office,
        timeOfDay: 14 * 60 + 30,
        recurrence: Recurrence.once,
        startDate: today,
      );

      await arriveAt(office, at(14, 25));

      expect(await completionFor(id), isNotNull);
    });

    test('arriving on the wrong day does nothing', () async {
      final id = await addEvent(
        title: 'Dentist',
        placeId: office,
        timeOfDay: 14 * 60 + 30,
        recurrence: Recurrence.once,
        startDate: today.addDays(3),
      );

      await arriveAt(office, at(14, 25));

      expect(await completionFor(id), isNull);
    });
  });
}
