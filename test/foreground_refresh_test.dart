import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/db/foreground_refresh.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/occurrence.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seeing what a background isolate wrote.
///
/// The geofence callback runs on its own connection to the same file, and
/// drift's update notifications do not cross an isolate boundary. Without a
/// nudge on resume, a row ticked off while the app was in a pocket goes on
/// looking untouched — which is indistinguishable from the feature not
/// working.
void main() {
  const today = CalendarDate(2026, 9, 11);

  late DaylineDatabase db;

  setUp(() {
    db = DaylineDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('a refresh re-reads the day', () async {
    final gym = await db.eventsDao.insertEvent(EventsCompanion.insert(
      title: 'Gym',
      colorValue: 0xFF3B82F6,
      timeOfDay: 7 * 60,
      recurrence: Recurrence.daily,
      startDate: today,
    ));

    final seen = <List<Occurrence>>[];
    final subscription =
        db.eventsDao.watchOccurrencesForDate(today).listen(seen.add);
    await pumpEventQueue();
    expect(seen.last.single.isPending, isTrue);

    // Stand in for the other isolate: write without drift noticing.
    await db.customStatement(
      'INSERT INTO completions (event_id, date, status, completed_at, '
      'is_automatic) VALUES (?, ?, 0, ?, 1)',
      [gym, today.epochDay, DateTime(2026, 9, 11, 7, 4).millisecondsSinceEpoch ~/ 1000],
    );
    await pumpEventQueue();
    expect(seen.last.single.isPending, isTrue,
        reason: 'a raw statement is exactly what the app does not hear about');

    ForegroundRefresh(db).refresh();
    await pumpEventQueue();

    expect(seen.last.single.isDone, isTrue);
    expect(seen.last.single.isAutomatic, isTrue);

    await subscription.cancel();
  });

  test('a refresh with nothing new changes nothing', () async {
    await db.eventsDao.insertEvent(EventsCompanion.insert(
      title: 'Gym',
      colorValue: 0xFF3B82F6,
      timeOfDay: 7 * 60,
      recurrence: Recurrence.daily,
      startDate: today,
    ));

    final seen = <List<Occurrence>>[];
    final subscription =
        db.eventsDao.watchOccurrencesForDate(today).listen(seen.add);
    await pumpEventQueue();

    ForegroundRefresh(db).refresh();
    await pumpEventQueue();

    expect(seen.last.single.status, isNull);

    await subscription.cancel();
  });
}
