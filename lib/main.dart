import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/db/database.dart';
import 'src/db/debug_seed.dart';
import 'src/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = DaylineDatabase();
  if (kDebugMode) await DebugSeed.populate(database);

  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(database)],
  );

  // Set up the OS side before the first frame, so a cold start repairs
  // anything a reboot or a timezone change knocked out.
  await container.read(notificationServiceProvider).initialise();
  unawaited(container.read(reminderSyncProvider).start());

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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DaylineApp(),
    ),
  );
}
