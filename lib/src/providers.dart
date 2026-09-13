import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/backup_service.dart';
import 'model/event.dart';
import 'model/holiday.dart';
import 'model/place.dart';
import 'model/streak.dart';

import 'db/database.dart';
import 'db/events_dao.dart';
import 'db/foreground_refresh.dart';
import 'db/holidays_dao.dart';
import 'db/places_dao.dart';
import 'db/settings_dao.dart';
import 'model/calendar_date.dart';
import 'model/occurrence.dart';
import 'location/geofence_service.dart';
import 'notifications/notification_service.dart';
import 'notifications/reminder_sync.dart';

/// Overridden in `main` with the opened database, so widget tests can hand in
/// an in-memory one instead.
final databaseProvider = Provider<DaylineDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final eventsDaoProvider =
    Provider<EventsDao>((ref) => ref.watch(databaseProvider).eventsDao);

final settingsDaoProvider =
    Provider<SettingsDao>((ref) => ref.watch(databaseProvider).settingsDao);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(databaseProvider)),
);

/// Holds the schedule in step with the rules for as long as the app lives.
final reminderSyncProvider = Provider<ReminderSync>((ref) {
  final sync = ReminderSync(
    database: ref.watch(databaseProvider),
    service: ref.watch(notificationServiceProvider),
  );
  ref.onDispose(sync.dispose);
  return sync;
});

/// Whether the one-time battery-optimisation explanation has been dealt with.
final batteryCardDismissedProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(settingsDaoProvider)
      .watchFlag(SettingsDao.batteryCardDismissed),
);

/// The user's appearance choice. Defaults to following the system.
final themeModeProvider = StreamProvider<ThemeMode>(
  (ref) => ref.watch(settingsDaoProvider).watchValue(SettingsDao.themeMode).map(
        (value) => switch (value) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
      ),
);

/// Every rule, for the All Events screen.
final allEventsProvider = StreamProvider<List<Event>>(
  (ref) => ref.watch(eventsDaoProvider).watchAllEvents(),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider)),
);

/// How a rule is going, recomputed whenever its history changes.
///
/// Deliberately `asyncMap` rather than an `async*` generator with an
/// `await for` inside it. A generator suspended in `await for` never finishes
/// cancelling, which hangs every widget test that reaches this provider —
/// the same trap [liveQuery] exists to avoid.
final streakProvider = StreamProvider.family<Streak, int>((ref, eventId) {
  final dao = ref.watch(eventsDaoProvider);
  final clock = ref.watch(clockProvider);

  return dao.watchCompletionsFor(eventId).asyncMap((completions) async {
    final event = await dao.eventById(eventId);
    if (event == null || !supportsStreaks(event.recurrence)) {
      return Streak.none;
    }
    return calculateStreak(
      event: event,
      completions: completions,
      now: clock(),
    );
  });
});

final holidaysDaoProvider =
    Provider<HolidaysDao>((ref) => ref.watch(databaseProvider).holidaysDao);

/// Every holiday the user has recorded, soonest first.
final holidaysProvider = StreamProvider<List<Holiday>>(
  (ref) => ref.watch(holidaysDaoProvider).watchHolidays(),
);

// Which holidays cover a given day is `holidaysOn(...)` over this list. It is
// a pure filter over a handful of rows, so it stays at the call site rather
// than becoming a provider family that opens a fresh query per date scrubbed
// to.

final placesDaoProvider =
    Provider<PlacesDao>((ref) => ref.watch(databaseProvider).placesDao);

/// Picks up what the geofence isolate wrote while the app was in the
/// background, so an arrival that ticked something off is on screen when the
/// user looks.
final foregroundRefreshProvider = Provider<ForegroundRefresh>((ref) {
  final refresh = ForegroundRefresh(ref.watch(databaseProvider));
  ref.onDispose(refresh.dispose);
  return refresh;
});

final geofenceServiceProvider = Provider<GeofenceService>(
  (ref) => GeofenceService(ref.watch(databaseProvider)),
);

final placesProvider = StreamProvider<List<Place>>(
  (ref) => ref.watch(placesDaoProvider).watchPlaces(),
);

/// Whether the OS will report crossings with the app closed. Anything less and
/// the whole feature is decorative.
final backgroundLocationProvider = FutureProvider<bool>(
  (ref) => ref.watch(geofenceServiceProvider).hasBackgroundPermission(),
);

/// Visits inside a window, kept live.
final visitsProvider =
    StreamProvider.family<List<Visit>, DateRange>((ref, range) =>
        ref.watch(placesDaoProvider).watchVisitsBetween(range.from, range.to));

/// A window of time, as a value so it can key a provider family.
class DateRange {
  const DateRange(this.from, this.to);

  /// The last [days] days up to the end of [today].
  factory DateRange.lastDays(CalendarDate today, int days) => DateRange(
    today.addDays(-(days - 1)).localDateTimeAt(0),
    today.addDays(1).localDateTimeAt(0),
  );

  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Whether the OS will actually deliver anything.
final notificationPermissionProvider = FutureProvider<bool>(
  (ref) => ref.watch(notificationServiceProvider).hasPermission(),
);

/// Whether Android will let reminders land on the minute.
final exactAlarmPermissionProvider = FutureProvider<bool>(
  (ref) => ref.watch(notificationServiceProvider).canScheduleExactAlarms(),
);

/// Where "now" comes from.
///
/// Behind a provider rather than called inline so that the screen can be
/// rendered at a chosen moment — for screenshots, and for the tests that check
/// what falls either side of the now line.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The real current date, which changes while the app is open.
///
/// An app whose whole job is "today" cannot afford to still say Thursday at
/// 00:05 on Friday, so this reschedules itself onto each local midnight rather
/// than polling. Built from a local [DateTime], so the DST night where
/// midnight is 23 or 25 hours away still lands correctly.
class TodayNotifier extends Notifier<CalendarDate> {
  Timer? _timer;

  @override
  CalendarDate build() {
    ref.onDispose(() => _timer?.cancel());
    _scheduleRollover();
    return CalendarDate.fromDateTime(ref.read(clockProvider)());
  }

  void _scheduleRollover() {
    final now = ref.read(clockProvider)();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _timer?.cancel();
    _timer = Timer(
      // A second past the hour, so we are never racing the clock itself.
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        state = CalendarDate.fromDateTime(ref.read(clockProvider)());
        _scheduleRollover();
      },
    );
  }
}

final todayProvider =
    NotifierProvider<TodayNotifier, CalendarDate>(TodayNotifier.new);

/// The day being looked at. Starts on today and follows it across midnight
/// unless the user has scrubbed somewhere else.
class SelectedDateNotifier extends Notifier<CalendarDate> {
  CalendarDate? _pinned;

  @override
  CalendarDate build() {
    final today = ref.watch(todayProvider);
    final pinned = _pinned;
    // Deliberately drop a pin that midnight has turned into the past.
    if (pinned != null && !pinned.isBefore(today)) return pinned;
    _pinned = null;
    return today;
  }

  void select(CalendarDate date) {
    _pinned = date;
    state = date;
  }

  void goToToday() {
    _pinned = null;
    state = ref.read(todayProvider);
  }
}

final selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, CalendarDate>(
  SelectedDateNotifier.new,
);

/// Everything happening on one date, kept live.
final occurrencesProvider =
    StreamProvider.family<List<Occurrence>, CalendarDate>(
  (ref, date) => ref.watch(eventsDaoProvider).watchOccurrencesForDate(date),
);

/// A one-second tick, for the "next up" countdown only.
///
/// Kept behind its own provider so that exactly one widget rebuilds per
/// second instead of the whole screen.
final secondTickProvider = StreamProvider<DateTime>(
  (ref) => Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  ).map((now) => now),
);
