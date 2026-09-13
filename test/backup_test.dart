import 'package:dayline/src/data/backup.dart';
import 'package:dayline/src/data/backup_service.dart';
import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/event.dart';
import 'package:dayline/src/model/holiday.dart';
import 'package:dayline/src/model/place.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  const today = CalendarDate(2026, 9, 11);

  late DaylineDatabase db;
  late BackupService backups;

  setUp(() {
    db = DaylineDatabase.forTesting(NativeDatabase.memory());
    backups = BackupService(db);
  });

  tearDown(() => db.close());

  Future<int> addGym() => db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Gym',
        notes: const Value('Bring the towel'),
        colorValue: 0xFF3B82F6,
        timeOfDay: 7 * 60,
        durationMin: const Value(60),
        recurrence: Recurrence.weekly,
        startDate: today.addDays(-30),
        endDate: Value(today.addDays(300)),
        daysOfWeek: Value(
          Weekdays.maskOf([DateTime.monday, DateTime.thursday]),
        ),
        leadMinutes: const Value([60, 15]),
      ));

  group('the file itself', () {
    test('round trips every field of a rule', () async {
      await addGym();
      final restored = Backup.decode(await backups.exportJson());
      final event = restored.events.single;

      expect(event.title, 'Gym');
      expect(event.notes, 'Bring the towel');
      expect(event.colorValue, 0xFF3B82F6);
      expect(event.timeOfDay, 420);
      expect(event.durationMin, 60);
      expect(event.recurrence, Recurrence.weekly);
      expect(event.daysOfWeek,
          Weekdays.maskOf([DateTime.monday, DateTime.thursday]));
      expect(event.startDate, today.addDays(-30));
      expect(event.endDate, today.addDays(300));
      expect(event.leadMinutes, [60, 15]);
    });

    test('writes dates as plain calendar dates, not timestamps', () async {
      // A backup taken in Sydney has to restore unchanged in Los Angeles.
      await addGym();
      final json = await backups.exportJson();

      expect(json, contains('"startDate": "2026-08-12"'));
      expect(json, isNot(contains('T00:00:00')));
      expect(json, isNot(contains('Z"')), reason: 'no UTC instants anywhere');
    });

    test('is readable, and says what it is', () async {
      await addGym();
      final json = await backups.exportJson();
      expect(json, contains('"app": "dayline"'));
      expect(json, contains('"version": ${Backup.formatVersion}'));
      expect(json, contains('\n  '), reason: 'indented for a human');
    });
  });

  group('holidays', () {
    test('round trip with their dates and what they close', () async {
      await db.holidaysDao.insertHoliday(HolidaysCompanion.insert(
        name: 'Half-term',
        startDate: today,
        endDate: today.addDays(4),
        scopes: const Value(HolidayScopes.school),
      ));
      final json = await backups.exportJson();

      await backups.importJson(json);

      final holiday = (await db.holidaysDao.allHolidays()).single;
      expect(holiday.name, 'Half-term');
      expect(holiday.startDate, today);
      expect(holiday.endDate, today.addDays(4));
      expect(holiday.scopes, HolidayScopes.school);
    });

    test("an event's timetable survives the trip", () async {
      await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'School run',
        colorValue: 1,
        timeOfDay: 8 * 60,
        recurrence: Recurrence.daily,
        startDate: today,
        holidayScope: const Value(HolidayScope.school),
      ));
      final json = await backups.exportJson();

      await backups.importJson(json);

      expect((await db.eventsDao.allEvents()).single.holidayScope,
          HolidayScope.school);
    });

    test('written as dates, like everything else in the file', () async {
      await db.holidaysDao.insertHoliday(HolidaysCompanion.insert(
        name: 'Christmas',
        startDate: today,
        endDate: today,
      ));

      final json = await backups.exportJson();
      expect(json, contains('"startDate": "$today"'));
      expect(json, isNot(contains('T00:00:00')));
    });

    test('replace clears the old ones rather than stacking them', () async {
      await db.holidaysDao.insertHoliday(HolidaysCompanion.insert(
        name: 'Christmas',
        startDate: today,
        endDate: today,
      ));
      final json = await backups.exportJson();

      await backups.importJson(json);
      await backups.importJson(json);

      expect(await db.holidaysDao.allHolidays(), hasLength(1));
    });

    test('a version 4 file restores with no holidays and nothing paused',
        () async {
      const raw = '{"app":"dayline","version":4,"events":[{"id":1,'
          '"title":"Standup","colorValue":1,"timeOfDay":540,'
          '"recurrence":"daily","startDate":"2026-08-12"}]}';

      await backups.importJson(raw);

      expect(await db.holidaysDao.allHolidays(), isEmpty);
      expect((await db.eventsDao.allEvents()).single.holidayScope, isNull);
    });

    test('an unknown timetable is dropped, not guessed at', () async {
      // Written by a newer build. The event restores and simply never pauses,
      // which is the safe direction to fail in.
      const raw = '{"app":"dayline","version":5,"events":[{"id":1,'
          '"title":"Gym","colorValue":1,"timeOfDay":420,"recurrence":"daily",'
          '"startDate":"2026-08-12","holidayScope":"university"}]}';

      await backups.importJson(raw);

      final event = (await db.eventsDao.allEvents()).single;
      expect(event.title, 'Gym');
      expect(event.holidayScope, isNull);
    });

    test('a holiday with no end date is that one day', () async {
      const raw = '{"app":"dayline","version":5,"events":[],'
          '"holidays":[{"name":"Christmas","startDate":"2026-12-25"}]}';

      await backups.importJson(raw);

      final holiday = (await db.holidaysDao.allHolidays()).single;
      expect(holiday.isSingleDay, isTrue);
      expect(holiday.startDate, const CalendarDate(2026, 12, 25));
    });
  });

  group('refusing files that are not ours', () {
    test('not JSON at all', () {
      expect(
        () => Backup.decode('hello'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('JSON, but not a backup', () {
      expect(
        () => Backup.decode('{"hello":"world"}'),
        throwsA(isA<BackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('not made by Dayline'),
        )),
      );
    });

    test('a version 1 file still restores', () async {
      // Places arrived in version 2; an older backup simply has none.
      final result = await backups.importJson(
        '{"app":"dayline","version":1,"events":[{"id":1,"title":"Gym",'
        '"colorValue":1,"timeOfDay":420,"recurrence":"daily",'
        '"startDate":"2026-09-11"}]}',
      );
      expect(result.events, 1);
      expect(result.places, 0);
    });

    test('a backup from a future version', () {
      expect(
        () => Backup.decode('{"app":"dayline","version":99,"events":[]}'),
        throwsA(isA<BackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('newer version'),
        )),
      );
    });

    test('a damaged entry names the missing field', () {
      expect(
        () => Backup.decode(
          '{"app":"dayline","version":1,"events":[{"id":1}]}',
        ),
        throwsA(isA<BackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('title'),
        )),
      );
    });

    test('an unknown recurrence is refused rather than guessed at', () {
      expect(
        () => Backup.decode(
          '{"app":"dayline","version":1,"events":[{"id":1,"title":"X",'
          '"colorValue":1,"timeOfDay":420,"recurrence":"fortnightly",'
          '"startDate":"2026-09-11"}]}',
        ),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });

  group('restoring', () {
    test('replace leaves exactly what was in the file', () async {
      final gym = await addGym();
      await db.eventsDao.setCompletion(
          eventId: gym, date: today, status: CompletionStatus.done);
      final json = await backups.exportJson();

      // Somewhere else entirely.
      await db.delete(db.events).go();
      await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Something else',
        colorValue: 1,
        timeOfDay: 600,
        recurrence: Recurrence.daily,
        startDate: today,
      ));

      final result = await backups.importJson(json);

      expect(result.events, 1);
      expect(result.completions, 1);
      final events = await db.eventsDao.allEvents();
      expect(events.map((e) => e.title), ['Gym']);
    });

    test('merge keeps what is already there', () async {
      final json = await backups.exportJson();
      await addGym();
      final withGym = await backups.exportJson();

      await db.delete(db.events).go();
      await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Existing',
        colorValue: 1,
        timeOfDay: 600,
        recurrence: Recurrence.daily,
        startDate: today,
      ));

      await backups.importJson(withGym, mode: ImportMode.merge);

      final titles = (await db.eventsDao.allEvents()).map((e) => e.title);
      expect(titles, containsAll(['Existing', 'Gym']));
      expect(json, isNotEmpty);
    });

    test('ids are reassigned, and history follows its own event', () async {
      // The file's ids cannot be trusted on a merge: reusing them would attach
      // the gym's history to whatever already held that id.
      final gym = await addGym();
      await db.eventsDao.setCompletion(
          eventId: gym, date: today, status: CompletionStatus.done);
      final json = await backups.exportJson();

      await db.delete(db.events).go();
      // Burn some ids so the restore cannot land on the originals.
      for (var i = 0; i < 5; i++) {
        await db.eventsDao.insertEvent(EventsCompanion.insert(
          title: 'Filler $i',
          colorValue: 1,
          timeOfDay: 600,
          recurrence: Recurrence.daily,
          startDate: today,
        ));
      }

      await backups.importJson(json, mode: ImportMode.merge);

      final restored =
          (await db.eventsDao.allEvents()).firstWhere((e) => e.title == 'Gym');
      expect(restored.id, isNot(gym));

      final rows = await db.select(db.completions).get();
      expect(rows.single.eventId, restored.id,
          reason: 'the completion followed the event, not the old id');
    });

    test('a completion for an event not in the file is dropped', () async {
      const orphaned = '{"app":"dayline","version":1,"events":[],'
          '"completions":[{"eventId":42,"date":"2026-09-11","status":"done",'
          '"completedAt":"2026-09-11T07:00:00.000"}]}';

      final result = await backups.importJson(orphaned);

      expect(result.completions, 0);
      expect(await db.select(db.completions).get(), isEmpty);
    });

    test('a failed import leaves the database untouched', () async {
      await addGym();
      final before = await db.eventsDao.allEvents();

      await expectLater(
        backups.importJson('{"app":"dayline","version":1,"events":[{"id":1}]}'),
        throwsA(isA<BackupFormatException>()),
      );

      // Decoding fails before anything is written, so replace never ran.
      expect(await db.eventsDao.allEvents(), hasLength(before.length));
    });

    test('overrides survive the trip', () async {
      final gym = await addGym();
      await db.eventsDao.setOverride(EventOverride(
        eventId: gym,
        date: today,
        type: OverrideType.moved,
        newTimeOfDay: 20 * 60,
      ));

      final json = await backups.exportJson();
      await backups.importJson(json);

      final rows = await db.select(db.overrides).get();
      expect(rows.single.type, OverrideType.moved);
      expect(rows.single.newTimeOfDay, 1200);
      expect(rows.single.date, today);
    });

    test('an empty backup is valid and empties the database', () async {
      await addGym();
      await backups.importJson('{"app":"dayline","version":1,"events":[]}');
      expect(await db.eventsDao.allEvents(), isEmpty);
    });
  });

  test('the suggested filename sorts chronologically', () {
    expect(
      BackupService.suggestedFileName(DateTime(2026, 9, 11)),
      'dayline-2026-09-11.json',
    );
  });

  group('places and visits', () {
    Future<int> addGymPlace() => db.placesDao.insertPlace(
      PlacesCompanion.insert(
        name: 'Gym',
        latitude: 51.50123,
        longitude: -0.12456,
        radiusMeters: const Value(180),
        colorValue: 0xFF10B981,
        kind: PlaceKind.gym,
      ),
    );

    test('round trip, with the coordinates intact', () async {
      await addGymPlace();
      final restored = Backup.decode(await backups.exportJson());

      final place = restored.places.single;
      expect(place.name, 'Gym');
      expect(place.latitude, closeTo(51.50123, 1e-9));
      expect(place.longitude, closeTo(-0.12456, 1e-9));
      expect(place.radiusMeters, 180);
      expect(place.kind, PlaceKind.gym);
    });

    test('visits follow their place through a merge', () async {
      final gym = await addGymPlace();
      await db.placesDao.recordArrival(gym, DateTime(2026, 9, 11, 7));
      await db.placesDao.recordDeparture(gym, DateTime(2026, 9, 11, 8));
      final json = await backups.exportJson();

      await db.delete(db.places).go();
      // Burn ids so the restore cannot land on the originals.
      for (var i = 0; i < 4; i++) {
        await db.placesDao.insertPlace(PlacesCompanion.insert(
          name: 'Filler $i',
          latitude: 0,
          longitude: 0,
          colorValue: 1,
          kind: PlaceKind.other,
        ));
      }

      await backups.importJson(json, mode: ImportMode.merge);

      final restored =
          (await db.placesDao.allPlaces()).firstWhere((p) => p.name == 'Gym');
      expect(restored.id, isNot(gym));

      final visits = await db.placesDao.visitsForPlace(restored.id);
      expect(visits, hasLength(1));
      expect(visits.single.arrivedAt, DateTime(2026, 9, 11, 7));
    });

    test("a rule's link to a place is remapped, not left dangling", () async {
      final gym = await addGymPlace();
      await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Gym',
        colorValue: 1,
        timeOfDay: 7 * 60,
        recurrence: Recurrence.daily,
        startDate: today,
        placeId: Value(gym),
      ));
      final json = await backups.exportJson();

      await backups.importJson(json);

      final place = (await db.placesDao.allPlaces()).single;
      final event = (await db.eventsDao.allEvents()).single;
      expect(event.placeId, place.id,
          reason: 'a link to the wrong place is worse than none');
    });

    test('auto-completion survives the round trip', () async {
      final gym = await addGymPlace();
      final id = await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Gym',
        colorValue: 1,
        timeOfDay: 7 * 60,
        recurrence: Recurrence.daily,
        startDate: today,
        placeId: Value(gym),
        autoCompleteOnArrival: const Value(true),
      ));
      await db.eventsDao.setCompletion(
        eventId: id,
        date: today,
        status: CompletionStatus.done,
        at: DateTime(2026, 8, 12, 7, 4),
        automatic: true,
      );
      final json = await backups.exportJson();

      await backups.importJson(json);

      final event = (await db.eventsDao.allEvents()).single;
      expect(event.autoCompleteOnArrival, isTrue);
      // The restored tick has to keep saying it was not the user's, or a
      // restore quietly rewrites history as something they did by hand.
      final completion = (await db.select(db.completions).get()).single;
      expect(completion.isAutomatic, isTrue);
    });

    test('a rule with the flag but no place restores with the flag', () async {
      // The flag can outlive the place. Dropping it on restore would silently
      // change the rule; it is the link that is missing, not the intent.
      const raw = '{"app":"dayline","version":3,"events":[{"id":1,'
          '"title":"Gym","colorValue":1,"timeOfDay":420,"recurrence":"daily",'
          '"startDate":"2026-08-12","autoCompleteOnArrival":true}]}';

      await backups.importJson(raw);

      final event = (await db.eventsDao.allEvents()).single;
      expect(event.autoCompleteOnArrival, isTrue);
      expect(event.placeId, isNull);
      expect(event.completesOnArrival, isFalse,
          reason: 'nothing to arrive at, so nothing will ever fire');
    });

    test('a version 2 file restores with auto-completion off', () async {
      const raw = '{"app":"dayline","version":2,"events":[{"id":1,'
          '"title":"Gym","colorValue":1,"timeOfDay":420,"recurrence":"daily",'
          '"startDate":"2026-08-12"}],"completions":[{"eventId":1,'
          '"date":"2026-08-12","status":"done",'
          '"completedAt":"2026-08-12T07:04:00.000"}]}';

      await backups.importJson(raw);

      expect((await db.eventsDao.allEvents()).single.autoCompleteOnArrival,
          isFalse);
      expect((await db.select(db.completions).get()).single.isAutomatic,
          isFalse);
    });

    test('a visit filed onto the day keeps pointing at its own stay',
        () async {
      // Ids are reassigned on the way in. A row that survives pointing at
      // whatever now holds that id would attach one day's visit to another.
      final gym = await addGymPlace();
      await db.placesDao.recordArrival(gym, DateTime(2026, 8, 12, 7));
      await db.placesDao.recordDeparture(gym, DateTime(2026, 8, 12, 8));
      final noise = await db.placesDao.recordArrival(
        gym,
        DateTime(2026, 8, 12, 19),
      );
      final visitId = (await db.placesDao.visitsForPlace(gym)).first.id;
      expect(visitId, isNot(noise));

      await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Gym',
        colorValue: 1,
        timeOfDay: 7 * 60,
        recurrence: Recurrence.once,
        startDate: today,
        placeId: Value(gym),
        fromVisitId: Value(visitId),
      ));
      final json = await backups.exportJson();

      await backups.importJson(json);

      final event = (await db.select(db.events).get()).single;
      final stays = await db.placesDao.visitsForPlace(
        (await db.placesDao.allPlaces()).single.id,
      );
      final linked = stays.firstWhere((v) => v.id == event.fromVisitId);
      expect(linked.arrivedAt, DateTime(2026, 8, 12, 7),
          reason: 'the morning stay, not the evening one');
    });

    test('a place that files its visits restores still doing so', () async {
      await db.placesDao.insertPlace(PlacesCompanion.insert(
        name: 'Gym',
        latitude: 51.5,
        longitude: -0.12,
        colorValue: 1,
        kind: PlaceKind.gym,
        addVisitsToDay: const Value(true),
      ));
      final json = await backups.exportJson();

      await backups.importJson(json);

      expect((await db.placesDao.allPlaces()).single.addVisitsToDay, isTrue);
    });

    test('a visit link that cannot be resolved is dropped, not guessed at',
        () async {
      // The event stays — as an ordinary one of the user's own, which is
      // exactly what an unlinked visit record is.
      const raw = '{"app":"dayline","version":4,"events":[{"id":1,'
          '"title":"Gym","colorValue":1,"timeOfDay":420,"recurrence":"once",'
          '"startDate":"2026-08-12","fromVisitId":77}],"places":[],'
          '"visits":[]}';

      await backups.importJson(raw);

      final event = (await db.select(db.events).get()).single;
      expect(event.title, 'Gym');
      expect(event.fromVisitId, isNull);
    });

    test('a version 3 file restores with nothing filing visits', () async {
      const raw = '{"app":"dayline","version":3,"places":[{"id":1,'
          '"name":"Gym","latitude":51.5,"longitude":-0.12,"colorValue":1,'
          '"kind":"gym"}],"events":[],"visits":[{"placeId":1,'
          '"arrivedAt":"2026-08-12T07:00:00.000"}]}';

      final result = await backups.importJson(raw);

      expect(result.visits, 1, reason: 'visits without ids still restore');
      expect((await db.placesDao.allPlaces()).single.addVisitsToDay, isFalse);
    });

    test('a visit whose place is missing is dropped', () async {
      const orphaned = '{"app":"dayline","version":2,"events":[],"places":[],'
          '"visits":[{"placeId":9,"arrivedAt":"2026-09-11T07:00:00.000"}]}';

      final result = await backups.importJson(orphaned);

      expect(result.visits, 0);
      expect(await db.select(db.visits).get(), isEmpty);
    });

    test('an open visit stays open through the round trip', () async {
      final gym = await addGymPlace();
      await db.placesDao.recordArrival(gym, DateTime(2026, 9, 11, 7));

      await backups.importJson(await backups.exportJson());

      final place = (await db.placesDao.allPlaces()).single;
      expect((await db.placesDao.visitsForPlace(place.id)).single.isOpen,
          isTrue);
    });
  });
}
