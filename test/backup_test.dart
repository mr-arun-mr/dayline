import 'package:dayline/src/data/backup.dart';
import 'package:dayline/src/data/backup_service.dart';
import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/event.dart';
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
      expect(json, contains('"version": 1'));
      expect(json, contains('\n  '), reason: 'indented for a human');
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
}
