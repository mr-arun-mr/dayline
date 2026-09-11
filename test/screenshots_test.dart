@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:dayline/src/app.dart';
import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/providers.dart';
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
  final today = CalendarDate.fromDateTime(now);

  setUpAll(() async {
    await _loadRealFonts();
    Directory(outputDir).createSync(recursive: true);
  });

  Future<DaylineDatabase> seededDatabase() async {
    final db = DaylineDatabase.forTesting(NativeDatabase.memory());
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
    return db;
  }

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Brightness brightness,
    Future<void> Function(WidgetTester tester)? interact,
  }) async {
    // Tests draw shadows as flat black silhouettes by default, which turns
    // every card and button into a heavy outline. These are pictures of the
    // UI, so draw them the way a device would. Restored at the end of this
    // function rather than in a tear-down, because the framework checks that
    // painting flags are back to default before tear-downs ever run.
    debugDisableShadows = false;

    final db = await seededDatabase();

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
          clockProvider.overrideWithValue(() => now),
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
    await shoot(tester, name: '01-today-light', brightness: Brightness.light);
  });

  testWidgets('today dark', (tester) async {
    await shoot(tester, name: '02-today-dark', brightness: Brightness.dark);
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
        await tester.tap(find.text('Standup'));
      },
    );
  });

  testWidgets('delete scope sheet', (tester) async {
    await shoot(
      tester,
      name: '07-delete-scope-light',
      brightness: Brightness.light,
      interact: (tester) async {
        await tester.tap(find.text('Physio exercises'));
        await _settle(tester);
        await tester.tap(find.byIcon(Icons.delete_outline));
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
