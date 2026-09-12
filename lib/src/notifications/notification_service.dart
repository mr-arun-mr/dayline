import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../db/database.dart';
import '../model/calendar_date.dart';
import '../model/event.dart';
import '../model/wall_clock.dart';
import 'notification_payload.dart';
import 'reminder_plan.dart';

/// Everything that talks to the OS scheduler.
///
/// The decisions live in [planReminders], which is pure and tested; this class
/// exists to carry that plan across to the platform and to keep the two in
/// step — on start, on resume, whenever an event changes, and whenever the
/// device's timezone moves out from under us.
class NotificationService {
  NotificationService(this._db, {FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final DaylineDatabase _db;
  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'dayline.reminders';
  static const _channelName = 'Reminders';

  /// Guards against two reconciles overlapping — resume and a save landing
  /// together would otherwise race to cancel each other's work.
  Future<void>? _inFlight;

  String? _lastTimeZone;
  bool _initialised = false;

  bool get isInitialised => _initialised;

  /// The timezone the last reconcile was built against.
  String? get lastTimeZone => _lastTimeZone;

  Future<void> initialise() async {
    if (_initialised) return;

    tzdata.initializeTimeZones();
    await _syncTimeZone();

    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked for separately, after the onboarding card has explained why.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              NotificationActions.category,
              actions: [
                DarwinNotificationAction.plain(
                  NotificationActions.done,
                  'Done',
                ),
                DarwinNotificationAction.plain(
                  NotificationActions.snooze,
                  'Snooze 10m',
                ),
              ],
              // No `foreground` option on either action: both are meant to be
              // dealt with from the notification, without the app coming up.
              options: const {
                DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
              },
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _createAndroidChannel();
    _initialised = true;
  }

  Future<void> _createAndroidChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Reminders before your events',
        importance: Importance.high,
      ),
    );
  }

  /// Reads the device's zone and points the `timezone` package at it.
  ///
  /// Returns whether it changed. Everything scheduled is anchored to a
  /// wall-clock time in a specific zone, so a change here invalidates the lot.
  Future<bool> _syncTimeZone() async {
    String name;
    try {
      name = (await FlutterTimezone.getLocalTimezone()).identifier;
    } on Object catch (error) {
      debugPrint('Dayline: could not read the device timezone ($error)');
      return false;
    }

    final changed = _lastTimeZone != null && _lastTimeZone != name;
    try {
      tz.setLocalLocation(tz.getLocation(name));
    } on tz.LocationNotFoundException {
      debugPrint('Dayline: unknown timezone "$name", staying on UTC');
    }
    _lastTimeZone = name;
    return changed;
  }

  /// Asks for whatever the platform needs before it will show anything.
  ///
  /// Returns false if the user declined, so the caller can leave the
  /// explanation on screen instead of pretending reminders are set up.
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      // Android 13+ needs this at runtime; older versions grant it at install.
      final granted = await android.requestNotificationsPermission() ?? false;
      // Separate, and separately refusable: without it Android downgrades our
      // alarms to an inexact window that can drift by many minutes.
      await android.requestExactAlarmsPermission();
      return granted;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  Future<bool> hasPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  /// Whether Android will let us schedule to the minute.
  ///
  /// Without it a 07:00 alarm can arrive at 07:20, which for a medication
  /// reminder is a different product.
  Future<bool> canScheduleExactAlarms() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? false;
  }

  /// Brings the OS's pending notifications in line with the current rules.
  ///
  /// Call on app start, on resume, after any create/edit/delete, and when the
  /// timezone changes. Cheap enough to call freely: it is a read of the rules
  /// plus at most [ReminderPlan.length] scheduling calls.
  Future<ReminderPlan> reconcile({DateTime? now}) {
    // Serialised rather than skipped: a save that lands mid-reconcile must
    // still take effect, so it queues behind the one in progress.
    final previous = _inFlight ?? Future<void>.value();
    final next = previous
        .catchError((_) {})
        .then((_) => _reconcile(now ?? DateTime.now()));
    _inFlight = next;
    return next;
  }

  Future<ReminderPlan> _reconcile(DateTime now) async {
    if (!_initialised) await initialise();
    await _syncTimeZone();

    final events = await _db.eventsDao.allEvents();
    final exceptions = await _loadExceptions(now);

    final plan = planReminders(
      events: events,
      now: now,
      exceptions: exceptions,
      // iOS keeps 64 pending notifications and drops the rest silently; the
      // gap below it absorbs anything the OS counts that we do not.
      budget: 60,
    );

    await _clearScheduled();
    for (final reminder in plan.reminders) {
      await _schedule(reminder);
    }
    return plan;
  }

  /// Cancels what we scheduled, leaving anything already on screen alone.
  ///
  /// `cancelAll` would also sweep away notifications the user has not dealt
  /// with yet, which on every resume would quietly delete their to-do list.
  Future<void> _clearScheduled() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      await _plugin.cancel(id: request.id);
    }
  }

  Future<Map<int, List<OccurrenceException>>> _loadExceptions(
    DateTime now,
  ) async {
    final today = CalendarDate.fromDateTime(now);
    final rows = await _db.eventsDao.overridesBetween(
      today,
      today.addDays(defaultHorizonDays),
    );
    final byEvent = <int, List<OccurrenceException>>{};
    for (final row in rows) {
      byEvent.putIfAbsent(row.eventId, () => []).add(
        OccurrenceException(
          date: row.date,
          newTimeOfDay:
              row.type == OverrideType.moved ? row.newTimeOfDay : null,
        ),
      );
    }
    return byEvent;
  }

  Future<void> _schedule(ScheduledReminder reminder) async {
    final payload = NotificationPayload(
      eventId: reminder.eventId,
      leadMinutes: reminder.leadMinutes,
      date: reminder.occurrenceDate,
    ).encode();

    await _plugin.zonedSchedule(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body,
      scheduledDate: _tzTime(reminder.fireAt),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // The whole point of the repeating kinds: the OS matches wall-clock
      // components, so 07:00 stays 07:00 through a DST change rather than
      // sliding an hour the way a fixed interval would.
      matchDateTimeComponents: switch (reminder.trigger) {
        ReminderTrigger.exact => null,
        ReminderTrigger.everyDay => DateTimeComponents.time,
        ReminderTrigger.everyWeek => DateTimeComponents.dayOfWeekAndTime,
      },
      payload: payload,
    );
  }

  tz.TZDateTime _tzTime(DateTime local) => wallClockLocal(
    CalendarDate.fromDateTime(local),
    local.hour * 60 + local.minute,
  );

  static NotificationDetails _details() => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      actions: [
        // showsUserInterface stays false so the tap is handled in the
        // background isolate instead of bringing the app to the front.
        AndroidNotificationAction(
          NotificationActions.done,
          'Done',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          NotificationActions.snooze,
          'Snooze 10m',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    ),
    iOS: DarwinNotificationDetails(
      categoryIdentifier: NotificationActions.category,
      presentAlert: true,
      presentSound: true,
    ),
  );

  Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();

  void _onForegroundResponse(NotificationResponse response) {
    unawaited(handleNotificationResponse(response, database: _db));
  }
}

/// How far ahead the non-repeating kinds are scheduled, topped up on resume.
const defaultHorizonDays = 14;

/// Entry point for taps that arrive while the app is not running.
///
/// Must be a top-level function annotated for the VM, because the OS spins up
/// a fresh isolate to deliver it — nothing from the running app is in scope,
/// including the open database.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  unawaited(handleNotificationResponse(response));
}

/// Applies Done or Snooze.
///
/// [database] is passed in when the app is already running; the background
/// isolate has no such thing and opens its own connection, which SQLite is
/// happy to arbitrate as long as it is closed again afterwards.
Future<void> handleNotificationResponse(
  NotificationResponse response, {
  DaylineDatabase? database,
  DateTime? now,
}) async {
  final payload = NotificationPayload.tryDecode(response.payload);
  if (payload == null) return;

  final action = response.actionId;
  if (action != NotificationActions.done &&
      action != NotificationActions.snooze) {
    // A plain tap on the body. Opening the app is the platform's job; there is
    // nothing for us to record.
    return;
  }

  final firedAt = now ?? DateTime.now();
  final date = payload.occurrenceDateFor(firedAt);

  final db = database ?? DaylineDatabase();
  try {
    switch (action) {
      case NotificationActions.done:
        await db.eventsDao.setCompletion(
          eventId: payload.eventId,
          date: date,
          status: CompletionStatus.done,
          at: firedAt,
        );
      case NotificationActions.snooze:
        await _snooze(payload, date, firedAt);
    }
  } finally {
    if (database == null) await db.close();
  }
}

Future<void> _snooze(
  NotificationPayload payload,
  CalendarDate date,
  DateTime firedAt,
) async {
  final plugin = FlutterLocalNotificationsPlugin();
  final when = firedAt.add(NotificationActions.snoozeDuration);

  await plugin.zonedSchedule(
    // Outside the range reconcile owns, so the next reconcile does not sweep
    // the snooze away before it has had a chance to fire.
    id: _snoozeIdFor(payload.eventId, date),
    title: 'Snoozed reminder',
    body: 'Due at ${_clock(when)}',
    scheduledDate: wallClockLocal(
      CalendarDate.fromDateTime(when),
      when.hour * 60 + when.minute,
    ),
    notificationDetails: NotificationService._details(),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    payload: NotificationPayload(
      eventId: payload.eventId,
      leadMinutes: 0,
      date: date,
    ).encode(),
  );
}

/// Snooze ids sit above the reconcile range so the two never collide.
int _snoozeIdFor(int eventId, CalendarDate date) =>
    100000 + ((eventId * 397 + date.epochDay) % 100000);

String _clock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';
