import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/db/settings_dao.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/event.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/providers.dart';
import 'package:dayline/src/ui/events/all_events_screen.dart';
import 'package:dayline/src/ui/theme.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const today = CalendarDate(2026, 9, 11);
  final now = DateTime(2026, 9, 11, 9, 0);

  late DaylineDatabase db;

  setUp(() => db = DaylineDatabase.forTesting(NativeDatabase.memory()));

  Future<int> add(String title, {bool isActive = true}) =>
      db.eventsDao.insertEvent(EventsCompanion.insert(
        title: title,
        colorValue: 0xFF3B82F6,
        timeOfDay: 7 * 60,
        recurrence: Recurrence.daily,
        startDate: today.addDays(-30),
        isActive: Value(isActive),
      ));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          theme: DaylineTheme.light,
          home: const AllEventsScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  }

  testWidgets('lists every rule with its plain-English schedule',
      (tester) async {
    await add('Gym');
    await add('Medication');
    await pump(tester);

    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Medication'), findsOneWidget);
    expect(find.text('Every day at 07:00'), findsNWidgets(2));

    await close(tester);
  });

  testWidgets('the switch pauses a rule without deleting it', (tester) async {
    final gym = await add('Gym');
    await pump(tester);

    await tester.tap(find.byType(Switch));
    await settle(tester);

    final event = await db.eventsDao.eventById(gym);
    expect(event, isNotNull);
    expect(event!.isActive, isFalse);
    // A paused rule produces nothing, but its history is untouched.
    expect(await db.eventsDao.occurrencesForDate(today), isEmpty);

    await close(tester);
  });

  testWidgets('swiping asks before deleting, and cancelling keeps it',
      (tester) async {
    await add('Gym');
    await pump(tester);

    await tester.drag(find.text('Gym'), const Offset(-500, 0));
    await settle(tester);

    expect(find.textContaining('Delete "Gym"?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(await db.eventsDao.allEvents(), hasLength(1));

    await close(tester);
  });

  testWidgets('confirming the swipe deletes it', (tester) async {
    await add('Gym');
    await pump(tester);

    await tester.drag(find.text('Gym'), const Offset(-500, 0));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);

    expect(await db.eventsDao.allEvents(), isEmpty);

    await close(tester);
  });

  testWidgets('shows a streak once there is one', (tester) async {
    final gym = await add('Gym');
    for (final offset in [0, -1, -2]) {
      await db.eventsDao.setCompletion(
        eventId: gym,
        date: today.addDays(offset),
        status: CompletionStatus.done,
      );
    }

    await pump(tester);
    await settle(tester);

    expect(find.textContaining('3 in a row'), findsOneWidget);

    await close(tester);
  });

  testWidgets('an empty list says so', (tester) async {
    await pump(tester);
    expect(find.text('No events yet'), findsOneWidget);
    await close(tester);
  });

  // Not a widget test: the point is that the choice lives in the database and
  // survives anything the UI does. Pumping frames with no widget tree just
  // hangs.
  test('the theme choice is remembered, and its stream follows changes',
      () async {
    await db.settingsDao.write(SettingsDao.themeMode, 'dark');
    expect(await db.settingsDao.read(SettingsDao.themeMode), 'dark');

    final modes = <String?>[];
    final sub =
        db.settingsDao.watchValue(SettingsDao.themeMode).listen(modes.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(modes.last, 'dark');

    await db.settingsDao.write(SettingsDao.themeMode, 'light');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(modes.last, 'light');

    await sub.cancel();
    await db.close();
  });
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 450));
}
