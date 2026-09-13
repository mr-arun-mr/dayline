import 'dart:io';

import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Upgrading a database that predates auto-completion.
///
/// Everyone already running Dayline has one. The upgrade has to add the two
/// columns without touching a single row of what is there — a migration that
/// loses a user's history is the one bug a local-only app cannot apologise
/// for, because there is no server copy to restore from.
void main() {
  const today = CalendarDate(2026, 9, 11);

  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dayline-migration');
    file = File('${dir.path}/dayline.sqlite');
  });

  tearDown(() => dir.delete(recursive: true));

  /// Builds a database in the shape v3 left behind.
  ///
  /// Made by taking the current schema back a version rather than by writing
  /// the old DDL out by hand, so it stays a real v3 database however the rest
  /// of the schema moves on.
  Future<void> writeVersion3Database() async {
    final db = DaylineDatabase.forTesting(NativeDatabase(file));
    await db.customStatement('SELECT 1'); // Force the open, and the migration.

    await db.customStatement(
      'ALTER TABLE events DROP COLUMN auto_complete_on_arrival',
    );
    await db.customStatement(
      'ALTER TABLE completions DROP COLUMN is_automatic',
    );

    await db.customStatement(
      'INSERT INTO events (id, title, color_value, time_of_day, recurrence, '
      'start_date, lead_minutes) VALUES (1, ?, ?, ?, 1, ?, ?)',
      ['Gym', 0xFF3B82F6, 7 * 60, today.epochDay, '[15]'],
    );
    await db.customStatement(
      'INSERT INTO completions (event_id, date, status, completed_at) '
      'VALUES (1, ?, 0, ?)',
      [
        today.epochDay,
        DateTime(2026, 9, 11, 7, 4).millisecondsSinceEpoch ~/ 1000,
      ],
    );

    await db.customStatement('PRAGMA user_version = 3');
    await db.close();
  }

  test('a v3 database opens, and keeps everything in it', () async {
    await writeVersion3Database();

    final db = DaylineDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    final event = (await db.eventsDao.allEvents()).single;
    expect(event.title, 'Gym');
    expect(event.timeOfDay, 7 * 60);
    expect(event.leadMinutes, [15]);

    final completion = (await db.select(db.completions).get()).single;
    expect(completion.status, CompletionStatus.done);
    expect(completion.date, today);
  });

  test('rules that predate the feature do not auto-complete', () async {
    // The default has to be off. Turning it on for everyone would start
    // ticking off days nobody asked the app to decide about.
    await writeVersion3Database();

    final db = DaylineDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    expect((await db.eventsDao.allEvents()).single.autoCompleteOnArrival,
        isFalse);
  });

  test("ticks that predate the feature are still the user's own", () async {
    await writeVersion3Database();

    final db = DaylineDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    expect((await db.select(db.completions).get()).single.isAutomatic, isFalse);
    expect((await db.eventsDao.occurrencesForDate(today)).single.isAutomatic,
        isFalse);
  });

  test('the upgraded database takes new rows with the new columns', () async {
    await writeVersion3Database();

    final db = DaylineDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    await db.eventsDao.setCompletion(
      eventId: 1,
      date: today.addDays(1),
      status: CompletionStatus.done,
      automatic: true,
    );

    final row = await (db.select(db.completions)
          ..where((c) => c.date.equals(today.addDays(1).epochDay)))
        .getSingle();
    expect(row.isAutomatic, isTrue);
  });
}
