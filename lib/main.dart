import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/db/database.dart';
import 'src/db/debug_seed.dart';
import 'src/db/tidy_stays.dart';
import 'src/model/calendar_date.dart';
import 'src/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = DaylineDatabase();
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(database)],
  );

  // The first frame does not wait on any of the OS setup below. A plugin that
  // is slow to answer — or never answers — must not be able to hold the app on
  // a blank screen, which is exactly what it did when this was all awaited
  // ahead of runApp.
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DaylineApp(),
    ),
  );

  unawaited(_startUp(container, database));
}

/// Everything the app needs in place soon, but not before it can draw.
Future<void> _startUp(
  ProviderContainer container,
  DaylineDatabase database,
) async {
  if (kDebugMode) {
    try {
      await DebugSeed.populate(database);
    } catch (error) {
      debugPrint('Dayline: debug seed failed — $error');
    }
  }

  // Two stays that ran at the same time are a device in two places at once.
  // They cannot be recorded any more, but older ones are still on the day, and
  // nothing that happens later goes back for them.
  try {
    final tidied = await tidyRecordedStays(database);
    if (tidied > 0) debugPrint('Dayline: shortened $tidied overlapping stays');
  } catch (error) {
    debugPrint('Dayline: could not tidy visit history — $error');
  }

  // A stay only ever reached the day at the moment it was recorded, so a day
  // could be missing one for reasons of its own — the place was told to add
  // its visits afterwards, or the callback never ran while the app was dead.
  // The visits themselves are the record, so the day is filled in from them.
  try {
    final today = CalendarDate.fromDateTime(DateTime.now());
    final filled = await database.eventsDao.fillDayFromVisits(today) +
        await database.eventsDao.fillDayFromVisits(today.addDays(-1));
    if (filled > 0) debugPrint('Dayline: put $filled stays back on the day');
  } catch (error) {
    debugPrint('Dayline: could not fill the day from visits — $error');
  }

  // Set up the OS side early, so a cold start repairs anything a reboot or a
  // timezone change knocked out.
  try {
    await container.read(notificationServiceProvider).initialise();
    unawaited(container.read(reminderSyncProvider).start());
  } catch (error) {
    debugPrint('Dayline: could not initialise notifications — $error');
  }

  // From here on, anything the geofence isolate writes while the app is in the
  // background shows up when the user comes back to it.
  container.read(foregroundRefreshProvider).start();

  // Geofences do not survive a reboot either, so they are re-registered on
  // every cold start for the same reason the reminders are.
  unawaited(
    container.read(geofenceServiceProvider).reconcile().catchError((
      Object error,
    ) {
      debugPrint('Dayline: could not register geofences — $error');
      return 0;
    }),
  );
}
