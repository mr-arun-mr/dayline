@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayline/src/app.dart';
import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/db/settings_dao.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/event.dart';
import 'package:dayline/src/model/place.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/providers.dart';
import 'package:dayline/src/ui/dashboard/dashboard_screen.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the real app at phone size and writes PNGs to `test/screenshots/`.
///
/// Not an assertion suite — it exists so the UI can be looked at without a
/// simulator, which this machine has no Xcode for. It runs with the rest of
/// the suite and earns its place there as a smoke test: any screen that throws
/// while building fails this file. Filter it out with `--exclude-tags
/// screenshots` when the PNGs are not wanted.
void main() {
  const outputDir = 'test/screenshots';

  // A Friday morning: some of the day has happened, most has not. Pinning it
  // keeps the screenshots identical between runs.
  final now = DateTime(2026, 9, 11, 8, 42);
  // The place screenshots want an evening, so the open "at home" visit reads
  // as still happening rather than as a gap.
  final evening = DateTime(2026, 9, 11, 20, 15);
  final today = CalendarDate.fromDateTime(now);

  setUpAll(() async {
    await _loadRealFonts();
    Directory(outputDir).createSync(recursive: true);
  });

  Future<DaylineDatabase> seededDatabase({
    List<String> markDone = const [],
    List<String> markSkipped = const [],
    bool showBatteryCard = false,
    bool withPlaces = false,
  }) async {
    final db = DaylineDatabase.forTesting(NativeDatabase.memory());
    if (!showBatteryCard) {
      await db.settingsDao
          .setFlag(SettingsDao.batteryCardDismissed, value: true);
    }
    Future<void> add({
      required String title,
      required int timeOfDay,
      required int colorValue,
      Recurrence recurrence = Recurrence.daily,
      String? notes,
      int? durationMin,
      int daysOfWeek = Weekdays.none,
      int interval = 1,
      int? dayOfMonth,
      CalendarDate? startDate,
      List<int> leadMinutes = const [15],
    }) =>
        db.eventsDao.insertEvent(EventsCompanion.insert(
          title: title,
          notes: Value(notes),
          colorValue: colorValue,
          timeOfDay: timeOfDay,
          durationMin: Value(durationMin),
          recurrence: recurrence,
          startDate: startDate ?? today.addDays(-30),
          daysOfWeek: Value(daysOfWeek),
          interval: Value(interval),
          dayOfMonth: Value(dayOfMonth),
          leadMinutes: Value(leadMinutes),
        ));

    await add(
      title: 'Gym',
      timeOfDay: 7 * 60,
      colorValue: 0xFF3B82F6,
      durationMin: 60,
    );
    await add(
      title: 'Water the plants',
      timeOfDay: 8 * 60,
      colorValue: 0xFF10B981,
      recurrence: Recurrence.everyNDays,
      interval: 3,
      startDate: today.addDays(-30),
    );
    await add(
      title: 'Standup',
      timeOfDay: 9 * 60 + 30,
      colorValue: 0xFF64748B,
      durationMin: 15,
      notes: 'Video call',
      leadMinutes: const [5],
    );
    await add(
      title: 'Physio exercises',
      timeOfDay: 13 * 60,
      colorValue: 0xFF14B8A6,
      durationMin: 20,
    );
    await add(
      title: 'Pick up the kid',
      timeOfDay: 15 * 60 + 45,
      colorValue: 0xFFF59E0B,
      leadMinutes: const [30, 10],
    );
    await add(
      title: 'Dentist',
      timeOfDay: 14 * 60 + 30,
      colorValue: 0xFFF43F5E,
      recurrence: Recurrence.once,
      startDate: today.addDays(1),
      durationMin: 45,
    );
    await add(
      title: 'Medication',
      timeOfDay: 21 * 60,
      colorValue: 0xFF8B5CF6,
    );

    if (withPlaces) await _seedPlaces(db, today, now);

    for (final (titles, status) in [
      (markDone, CompletionStatus.done),
      (markSkipped, CompletionStatus.skipped),
    ]) {
      final all = await db.eventsDao.allEvents();
      for (final title in titles) {
        await db.eventsDao.setCompletion(
          eventId: all.firstWhere((e) => e.title == title).id,
          date: today,
          status: status,
          at: now,
        );
      }
    }
    return db;
  }

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Brightness brightness,
    Future<void> Function(WidgetTester tester)? interact,
    List<String> markDone = const [],
    List<String> markSkipped = const [],
    bool showBatteryCard = false,
    bool withPlaces = false,
  }) async {
    // Tests draw shadows as flat black silhouettes by default, which turns
    // every card and button into a heavy outline. These are pictures of the
    // UI, so draw them the way a device would. Restored at the end of this
    // function rather than in a tear-down, because the framework checks that
    // painting flags are back to default before tear-downs ever run.
    debugDisableShadows = false;

    final db = await seededDatabase(
      markDone: markDone,
      markSkipped: markSkipped,
      showBatteryCard: showBatteryCard,
      withPlaces: withPlaces,
    );

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => withPlaces ? evening : now),
          // A fixed tick, so the countdown does not animate mid-capture.
          secondTickProvider.overrideWith((ref) => Stream.value(now)),
        ],
        child: const RepaintBoundary(
          key: ValueKey('shot'),
          child: DaylineApp(),
        ),
      ),
    );
    await _settle(tester);
    if (interact != null) {
      await interact(tester);
      await _settle(tester);
    }

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    // Rasterising is real engine work, not fake-clock work. Awaited inside the
    // fake async zone it simply never completes, and the test sits there until
    // the ten minute timeout.
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$outputDir/$name.png').writeAsBytesSync(
        bytes!.buffer.asUint8List(),
      );
      image.dispose();
    });

    // Order matters: the live query has to let go of the database before the
    // database goes away. Closing it first leaves the stream's cancellation
    // waiting on a connection that will never answer, and the test hangs.
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
    debugDisableShadows = true;
  }

  testWidgets('today light', (tester) async {
    await shoot(
      tester,
      name: '01-today-light',
      brightness: Brightness.light,
      markDone: const ['Gym'],
    );
  });

  testWidgets('today dark', (tester) async {
    await shoot(
      tester,
      name: '02-today-dark',
      brightness: Brightness.dark,
      markDone: const ['Gym'],
    );
  });

  testWidgets('a day mostly dealt with', (tester) async {
    await shoot(
      tester,
      name: '08-progress-light',
      brightness: Brightness.light,
      markDone: const ['Gym', 'Water the plants', 'Standup'],
      markSkipped: const ['Physio exercises'],
    );
  });

  testWidgets('the long-press sheet', (tester) async {
    await shoot(
      tester,
      name: '09-occurrence-sheet-light',
      brightness: Brightness.light,
      interact: (tester) async {
        await tester.longPress(find.text('Water the plants'));
      },
    );
  });

  testWidgets('the battery warning', (tester) async {
    await shoot(
      tester,
      name: '10-battery-card-light',
      brightness: Brightness.light,
      showBatteryCard: true,
    );
  });

  testWidgets('another day', (tester) async {
    await shoot(
      tester,
      name: '03-other-day-light',
      brightness: Brightness.light,
      interact: (tester) async {
        // Scrub to tomorrow, which has the one-off dentist appointment. Only
        // the days actually on screen are built, so this taps a visible cell.
        await tester.tap(find.text('12').first);
      },
    );
  });

  testWidgets('edit, new event', (tester) async {
    await shoot(
      tester,
      name: '04-new-event-light',
      brightness: Brightness.light,
      interact: (tester) async {
        await tester.tap(find.text('Add'));
      },
    );
  });

  testWidgets('edit, existing event', (tester) async {
    await shoot(
      tester,
      name: '05-edit-event-dark',
      brightness: Brightness.dark,
      interact: (tester) async {
        // Tapping a row marks it done now, so editing is behind the sheet.
        await tester.longPress(find.text('Standup'));
        await _settle(tester);
        await tester.tap(find.text('Edit series'));
      },
    );
  });

  testWidgets('delete scope sheet', (tester) async {
    await shoot(
      tester,
      name: '07-delete-scope-light',
      brightness: Brightness.light,
      interact: (tester) async {
        await tester.longPress(find.text('Physio exercises'));
        await _settle(tester);
        await tester.tap(find.text('Edit series'));
        await _settle(tester);
        await tester.tap(find.byIcon(Icons.delete_outline));
      },
    );
  });

  testWidgets('weekly editor', (tester) async {
    await shoot(
      tester,
      name: '11-weekly-light',
      brightness: Brightness.light,
      interact: (tester) async {
        await tester.longPress(find.text('Water the plants'));
        await _settle(tester);
        await tester.tap(find.text('Edit series'));
        await _settle(tester);
        await tester.tap(find.text('Weekly'));
      },
    );
  });

  testWidgets('monthly editor', (tester) async {
    await shoot(
      tester,
      name: '12-monthly-dark',
      brightness: Brightness.dark,
      interact: (tester) async {
        await tester.longPress(find.text('Water the plants'));
        await _settle(tester);
        await tester.tap(find.text('Edit series'));
        await _settle(tester);
        await tester.tap(find.text('Monthly'));
      },
    );
  });

  testWidgets('all events', (tester) async {
    await shoot(
      tester,
      name: '13-all-events-light',
      brightness: Brightness.light,
      markDone: const ['Gym'],
      interact: (tester) async {
        await tester.tap(find.byIcon(Icons.list_alt_outlined));
      },
    );
  });

  testWidgets('settings', (tester) async {
    await shoot(
      tester,
      name: '14-settings-dark',
      brightness: Brightness.dark,
      interact: (tester) async {
        await tester.tap(find.byIcon(Icons.settings_outlined));
      },
    );
  });

  testWidgets('dashboard', (tester) async {
    await shoot(
      tester,
      name: '15-dashboard-light',
      brightness: Brightness.light,
      withPlaces: true,
      interact: (tester) async {
        await tester.tap(find.byIcon(Icons.insights_outlined));
      },
    );
  });

  testWidgets('dashboard, dark', (tester) async {
    await shoot(
      tester,
      name: '16-dashboard-dark',
      brightness: Brightness.dark,
      withPlaces: true,
      interact: (tester) async {
        await tester.tap(find.byIcon(Icons.insights_outlined));
        await _settle(tester);
        await tester.drag(
          find.byType(DashboardScreen),
          const Offset(0, -520),
        );
      },
    );
  });

  testWidgets('places', (tester) async {
    await shoot(
      tester,
      name: '17-places-light',
      brightness: Brightness.light,
      withPlaces: true,
      interact: (tester) async {
        await tester.tap(find.byIcon(Icons.insights_outlined));
        await _settle(tester);
        await tester.tap(find.byIcon(Icons.place_outlined).first);
      },
    );
  });

  testWidgets('edit, once', (tester) async {
    await shoot(
      tester,
      name: '06-once-light',
      brightness: Brightness.light,
      interact: (tester) async {
        await tester.tap(find.text('Add'));
        await _settle(tester);
        await tester.tap(find.text('Once'));
      },
    );
  });
}

/// Pumps enough frames for a route transition to finish.
///
/// Deliberately not `pumpAndSettle`: the editor autofocuses its title field,
/// and a blinking caret is an animation that never settles.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 450));
}

/// `flutter test` ships a font that draws every glyph as a box, which would
/// make these screenshots useless. Registering a real system face under
/// `Roboto` — the default family the theme resolves to — fixes that.
/// Whatever family the icon set actually declares, rather than a guess.
final _iconFontFamily = Icons.add.fontFamily ?? 'MaterialIcons';

Future<void> _loadRealFonts() async {
  final faces = {
    'Roboto': [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    ],
    // Without this every icon draws as an empty square.
    _iconFontFamily: [
      '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/'
          'MaterialIcons-Regular.otf',
    ],
  };
  for (final MapEntry(key: family, value: paths) in faces.entries) {
    final loader = FontLoader(family);
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) {
        throw StateError('Screenshot font missing: $path');
      }
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
    await loader.load();
  }
}

/// Two weeks of plausible comings and goings, so the dashboard has something
/// to draw. Weekdays at the office, most mornings at the gym, evenings home.
Future<void> _seedPlaces(
  DaylineDatabase db,
  CalendarDate today,
  DateTime now,
) async {
  final gym = await db.placesDao.insertPlace(PlacesCompanion.insert(
    name: 'Gym',
    latitude: 51.5012,
    longitude: -0.1246,
    radiusMeters: const Value(160),
    colorValue: 0xFF10B981,
    kind: PlaceKind.gym,
  ));
  final office = await db.placesDao.insertPlace(PlacesCompanion.insert(
    name: 'Office',
    latitude: 51.5155,
    longitude: -0.1410,
    colorValue: 0xFF64748B,
    kind: PlaceKind.work,
  ));
  final home = await db.placesDao.insertPlace(PlacesCompanion.insert(
    name: 'Home',
    latitude: 51.4900,
    longitude: -0.1700,
    radiusMeters: const Value(200),
    colorValue: 0xFF3B82F6,
    kind: PlaceKind.home,
  ));

  Future<void> stay(int placeId, CalendarDate date, int fromMin, int toMin) =>
      db.into(db.visits).insert(VisitsCompanion.insert(
        placeId: placeId,
        arrivedAt: date.localDateTimeAt(fromMin),
        departedAt: Value(date.localDateTimeAt(toMin)),
      ));

  for (var back = 41; back >= 0; back--) {
    final date = today.addDays(-back);
    final isWeekend = date.weekday >= DateTime.saturday;

    // Skipped the gym on a few days, which is the point of the adherence card.
    final wentToGym = !isWeekend && back % 4 != 1;
    if (wentToGym) await stay(gym, date, 7 * 60, 8 * 60 + 10);
    if (!isWeekend) await stay(office, date, 9 * 60, 17 * 60 + 30);

    if (back == 0) {
      // Still at home right now, so the timeline has an open visit in it.
      await db.into(db.visits).insert(VisitsCompanion.insert(
        placeId: home,
        arrivedAt: date.localDateTimeAt(18 * 60),
      ));
    } else {
      await stay(home, date, 18 * 60, 23 * 60 + 30);
    }
  }

  // Tie the gym routine to the gym, which is what the adherence card reads.
  final gymEvent =
      (await db.eventsDao.allEvents()).firstWhere((e) => e.title == 'Gym');
  await (db.update(db.events)..where((e) => e.id.equals(gymEvent.id)))
      .write(EventsCompanion(placeId: Value(gym)));
}
