import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/notifications/notification_payload.dart';
import 'package:dayline/src/notifications/notification_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Done button has to work without the app coming to the front, so the
/// path it takes is worth testing directly: payload in, completion row out.
void main() {
  late DaylineDatabase db;
  late int gym;

  const date = CalendarDate(2026, 9, 11);

  setUp(() async {
    db = DaylineDatabase.forTesting(NativeDatabase.memory());
    gym = await db.eventsDao.insertEvent(EventsCompanion.insert(
      title: 'Gym',
      colorValue: 0xFF3B82F6,
      timeOfDay: 7 * 60,
      recurrence: Recurrence.daily,
      startDate: const CalendarDate(2026, 9, 1),
      leadMinutes: const Value([15]),
    ));
  });

  tearDown(() => db.close());

  NotificationResponse response({
    required String action,
    required NotificationPayload payload,
  }) =>
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: action,
        payload: payload.encode(),
      );

  test('Done marks the dated occurrence complete', () async {
    await handleNotificationResponse(
      response(
        action: NotificationActions.done,
        payload: NotificationPayload(
          eventId: gym,
          leadMinutes: 15,
          date: date,
        ),
      ),
      database: db,
      now: DateTime(2026, 9, 11, 6, 45),
    );

    final day = await db.eventsDao.occurrencesForDate(date);
    expect(day.single.isDone, isTrue);
  });

  test('Done on a repeating reminder works out the day from when it fired',
      () async {
    // No date in the payload — a repeating trigger has no single day.
    await handleNotificationResponse(
      response(
        action: NotificationActions.done,
        payload: NotificationPayload(eventId: gym, leadMinutes: 15),
      ),
      database: db,
      now: DateTime(2026, 9, 11, 6, 45),
    );

    expect(
      (await db.eventsDao.occurrencesForDate(date)).single.isDone,
      isTrue,
    );
  });

  test('a reminder that fires before midnight marks the following day',
      () async {
    final midnightEvent = await db.eventsDao.insertEvent(
      EventsCompanion.insert(
        title: 'Medication',
        colorValue: 0xFF8B5CF6,
        timeOfDay: 30, // 00:30
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
        leadMinutes: const Value([60]),
      ),
    );

    // Fires at 23:30 on the 11th, for the occurrence on the 12th.
    await handleNotificationResponse(
      response(
        action: NotificationActions.done,
        payload: NotificationPayload(
          eventId: midnightEvent,
          leadMinutes: 60,
        ),
      ),
      database: db,
      now: DateTime(2026, 9, 11, 23, 30),
    );

    final rows = await db.select(db.completions).get();
    expect(rows.single.date, const CalendarDate(2026, 9, 12),
        reason: 'marking the firing date would tick off the wrong day');
  });

  test('tapping the body records nothing', () async {
    await handleNotificationResponse(
      const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '{"e":1,"l":15}',
      ),
      database: db,
      now: DateTime(2026, 9, 11, 6, 45),
    );

    expect(await db.select(db.completions).get(), isEmpty);
  });

  test('a rubbish payload is ignored rather than fatal', () async {
    // This runs in a background isolate with no one watching; throwing here
    // would be an invisible crash.
    await handleNotificationResponse(
      const NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: NotificationActions.done,
        payload: 'not json',
      ),
      database: db,
    );

    expect(await db.select(db.completions).get(), isEmpty);
  });
}
