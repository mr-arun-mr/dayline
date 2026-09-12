import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/place.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/providers.dart';
import 'package:dayline/src/ui/dashboard/dashboard_screen.dart';
import 'package:dayline/src/ui/dashboard/place_bars.dart';
import 'package:dayline/src/ui/theme.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const today = CalendarDate(2026, 9, 11);
  final now = DateTime(2026, 9, 11, 20, 15);

  late DaylineDatabase db;

  setUp(() => db = DaylineDatabase.forTesting(NativeDatabase.memory()));

  Future<int> addPlace(String name, {int colour = 0xFF3B82F6}) =>
      db.placesDao.insertPlace(PlacesCompanion.insert(
        name: name,
        latitude: 51.5,
        longitude: -0.12,
        colorValue: colour,
        kind: PlaceKind.other,
      ));

  Future<void> stay(int placeId, CalendarDate date, int from, int to) =>
      db.into(db.visits).insert(VisitsCompanion.insert(
        placeId: placeId,
        arrivedAt: date.localDateTimeAt(from),
        departedAt: Value(date.localDateTimeAt(to)),
      ));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
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
          home: const DashboardScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  /// The same duration can appear in the bars and again in the timeline, so
  /// assertions about totals have to say which they mean.
  Finder inBars(String text) => find.descendant(
    of: find.byType(PlaceBars),
    matching: find.text(text),
  );

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  }

  testWidgets('with no places it explains itself rather than showing zeroes',
      (tester) async {
    await pump(tester);
    expect(find.text('Nothing to show yet'), findsOneWidget);
    await close(tester);
  });

  testWidgets('totals the time at each place', (tester) async {
    final office = await addPlace('Office');
    final gym = await addPlace('Gym', colour: 0xFF10B981);

    await stay(office, today, 9 * 60, 17 * 60);
    await stay(office, today.addDays(-1), 9 * 60, 17 * 60);
    await stay(gym, today, 7 * 60, 8 * 60);

    await pump(tester);

    expect(find.text('TIME PER PLACE'), findsOneWidget);
    expect(inBars('16h'), findsOneWidget, reason: 'two days at the office');
    expect(inBars('1h'), findsOneWidget);

    await close(tester);
  });

  testWidgets('an open visit is shown as still happening', (tester) async {
    final home = await addPlace('Home');
    await db.placesDao.recordArrival(home, today.localDateTimeAt(18 * 60));

    await pump(tester);

    expect(find.textContaining('18:00 –'), findsOneWidget);
    expect(find.textContaining('now · 2h 15m'), findsOneWidget);

    await close(tester);
  });

  group('did you go', () {
    testWidgets('says nothing useful until a routine is linked to a place',
        (tester) async {
      final gym = await addPlace('Gym');
      await stay(gym, today, 7 * 60, 8 * 60);
      await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Gym',
        colorValue: 1,
        timeOfDay: 7 * 60,
        recurrence: Recurrence.daily,
        startDate: today.addDays(-10),
      ));

      await pump(tester);

      expect(find.textContaining('Link a routine to a place'), findsOneWidget);

      await close(tester);
    });

    testWidgets('counts the occurrences you were actually there for',
        (tester) async {
      final gym = await addPlace('Gym');
      await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Gym',
        colorValue: 1,
        timeOfDay: 7 * 60,
        recurrence: Recurrence.daily,
        startDate: today.addDays(-10),
        placeId: Value(gym),
      ));

      // Three of the last seven mornings.
      for (final back in [0, -1, -3]) {
        await stay(gym, today.addDays(back), 7 * 60, 8 * 60);
      }

      await pump(tester);

      expect(find.text('DID YOU GO?'), findsOneWidget);
      expect(find.text('3 of 7'), findsOneWidget);
      expect(find.text('43%'), findsOneWidget);

      await close(tester);
    });

    testWidgets('a visit at the wrong time is not attendance', (tester) async {
      final gym = await addPlace('Gym');
      await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Gym',
        colorValue: 1,
        timeOfDay: 7 * 60,
        recurrence: Recurrence.daily,
        startDate: today.addDays(-10),
        placeId: Value(gym),
      ));
      // Turned up in the afternoon, hours outside the grace window.
      await stay(gym, today, 15 * 60, 16 * 60);

      await pump(tester);

      expect(find.text('0 of 7'), findsOneWidget);

      await close(tester);
    });
  });

  testWidgets('changing the window changes the totals', (tester) async {
    final office = await addPlace('Office');
    // Inside 30 days but outside 7.
    await stay(office, today.addDays(-20), 9 * 60, 17 * 60);
    await stay(office, today, 9 * 60, 10 * 60);

    await pump(tester);
    expect(inBars('1h'), findsOneWidget);

    await tester.tap(find.text('30 days'));
    await settle(tester);
    expect(inBars('9h'), findsOneWidget);

    await close(tester);
  });
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 450));
}
