import 'package:dayline/src/app.dart';
import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/db/settings_dao.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/event.dart';
import 'package:dayline/src/model/place.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/providers.dart';
import 'package:dayline/src/ui/today/next_up_card.dart';
import 'package:dayline/src/ui/today/occurrence_tile.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Marking things done from the Today screen, and the long-press sheet.
void main() {
  const today = CalendarDate(2026, 9, 11);
  final now = DateTime(2026, 9, 11, 8, 42);

  late DaylineDatabase db;

  setUp(() async {
    db = DaylineDatabase.forTesting(NativeDatabase.memory());
    await db.settingsDao.setFlag(SettingsDao.batteryCardDismissed, value: true);
  });

  Future<int> add(
    String title,
    int timeOfDay, {
    Recurrence recurrence = Recurrence.daily,
  }) =>
      db.eventsDao.insertEvent(EventsCompanion.insert(
        title: title,
        colorValue: 0xFF3B82F6,
        timeOfDay: timeOfDay,
        recurrence: recurrence,
        // A ONCE rule fires on its start date and nowhere else, so backdating
        // it the way a recurring rule wants would mean it never shows up.
        startDate: recurrence == Recurrence.once ? today : today.addDays(-10),
      ));

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          secondTickProvider.overrideWith((ref) => Stream.value(now)),
        ],
        child: const DaylineApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  }

  testWidgets('tapping a row marks it done and it keeps its place in the day',
      (tester) async {
    final gym = await add('Gym', 7 * 60);
    await add('Standup', 9 * 60 + 30);
    await pumpApp(tester);

    expect(find.textContaining('Overdue'), findsOneWidget);

    await tester.tap(find.byType(OccurrenceTile).first);
    await settle(tester);

    final rows = await db.select(db.completions).get();
    expect(rows.single.eventId, gym);
    expect(rows.single.status, CompletionStatus.done);

    // No longer asking for anything, but still where it happened: the day is
    // one line, and a finished thing is part of it.
    expect(find.textContaining('Overdue'), findsNothing);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Hide done'), findsOneWidget);

    await close(tester);
  });

  testWidgets('the progress ring counts up as things are ticked off',
      (tester) async {
    await add('Gym', 7 * 60);
    await add('Standup', 9 * 60 + 30);
    await add('Physio', 13 * 60);
    await pumpApp(tester);

    expect(find.text('0/3'), findsOneWidget);

    await tester.tap(find.byType(OccurrenceTile).first);
    await settle(tester);

    expect(find.text('1/3'), findsOneWidget);
    expect(find.textContaining('1 of 3 done'), findsOneWidget);

    await close(tester);
  });

  testWidgets('a done row can be tapped back to pending', (tester) async {
    await add('Gym', 7 * 60);
    await pumpApp(tester);

    await tester.tap(find.byType(OccurrenceTile).first);
    await settle(tester);
    expect(await db.select(db.completions).get(), hasLength(1));

    // Still there to be tapped again, in the same place.
    await tester.tap(find.byType(OccurrenceTile).first);
    await settle(tester);

    expect(await db.select(db.completions).get(), isEmpty);
    expect(find.textContaining('Overdue'), findsOneWidget);

    await close(tester);
  });

  testWidgets('a done event is shown in its place, and can be folded away',
      (tester) async {
    final gym = await add('Gym', 7 * 60);
    await add('Standup', 9 * 60 + 30);
    await db.eventsDao.setCompletion(
        eventId: gym, date: today, status: CompletionStatus.done);

    await pumpApp(tester);

    expect(find.text('Gym'), findsOneWidget,
        reason: 'done, and still where the day put it');

    await tester.tap(find.widgetWithText(TextButton, 'Hide done'));
    await settle(tester);
    expect(find.text('Gym'), findsNothing);

    // And the way back is still on screen.
    await tester.tap(find.widgetWithText(TextButton, 'Show done'));
    await settle(tester);
    expect(find.text('Gym'), findsOneWidget);

    await close(tester);
  });

  group('a tick the app made', () {
    testWidgets('says so on the row', (tester) async {
      // The one thing auto-completion must never be is a mystery: a tick the
      // user does not remember making needs its reason attached.
      final gym = await add('Gym', 7 * 60);
      await db.eventsDao.setCompletion(
        eventId: gym,
        date: today,
        status: CompletionStatus.done,
        at: DateTime(2026, 9, 11, 7, 4),
        automatic: true,
      );

      await pumpApp(tester);

      expect(find.textContaining('Done on arrival'), findsOneWidget);

      await close(tester);
    });

    testWidgets('a tick the user made says nothing extra', (tester) async {
      final gym = await add('Gym', 7 * 60);
      await db.eventsDao.setCompletion(
          eventId: gym, date: today, status: CompletionStatus.done);

      await pumpApp(tester);

      expect(find.textContaining('Done on arrival'), findsNothing);

      await close(tester);
    });

    testWidgets('can still be undone by hand', (tester) async {
      // The app's guess is never the last word.
      final gym = await add('Gym', 7 * 60);
      await db.eventsDao.setCompletion(
        eventId: gym,
        date: today,
        status: CompletionStatus.done,
        automatic: true,
      );

      await pumpApp(tester);
      await tester.tap(find.byType(OccurrenceTile).first);
      await settle(tester);

      expect(await db.select(db.completions).get(), isEmpty);
      expect(find.textContaining('Overdue'), findsOneWidget);

      await close(tester);
    });
  });

  group('planned against actual', () {
    Future<int> addPlace(String name) =>
        db.placesDao.insertPlace(PlacesCompanion.insert(
          name: name,
          latitude: 51.5,
          longitude: -0.12,
          colorValue: 0xFF3B82F6,
          kind: PlaceKind.gym,
        ));

    testWidgets('the row shows when you were actually there', (tester) async {
      final gym = await addPlace('Gym');
      await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Gym',
        colorValue: 0xFF3B82F6,
        timeOfDay: 7 * 60,
        recurrence: Recurrence.daily,
        startDate: today.addDays(-10),
        placeId: Value(gym),
      ));
      await db.placesDao.recordArrival(gym, DateTime(2026, 9, 11, 7, 4));
      await db.placesDao.recordDeparture(gym, DateTime(2026, 9, 11, 8, 12));

      await pumpApp(tester);

      // The planned time keeps the column; the actual goes underneath.
      expect(find.text('07:00'), findsOneWidget);
      expect(find.textContaining('07:04 → 08:12'), findsOneWidget);

      await close(tester);
    });

    testWidgets('an open stay says still there', (tester) async {
      final gym = await addPlace('Gym');
      await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Gym',
        colorValue: 0xFF3B82F6,
        timeOfDay: 7 * 60,
        recurrence: Recurrence.daily,
        startDate: today.addDays(-10),
        placeId: Value(gym),
      ));
      await db.placesDao.recordArrival(gym, DateTime(2026, 9, 11, 7, 4));

      await pumpApp(tester);

      expect(find.textContaining('07:04 → still there'), findsOneWidget);

      await close(tester);
    });

    testWidgets('the sheet puts the two side by side', (tester) async {
      final gym = await addPlace('Gym');
      await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Gym',
        colorValue: 0xFF3B82F6,
        timeOfDay: 7 * 60,
        recurrence: Recurrence.daily,
        startDate: today.addDays(-10),
        placeId: Value(gym),
      ));
      await db.placesDao.recordArrival(gym, DateTime(2026, 9, 11, 7, 4));
      await db.placesDao.recordDeparture(gym, DateTime(2026, 9, 11, 8, 12));

      await pumpApp(tester);
      await tester.longPress(find.byType(OccurrenceTile).first);
      await settle(tester);

      expect(find.text('PLANNED'), findsOneWidget);
      expect(find.text('ACTUALLY THERE'), findsOneWidget);
      expect(find.text('1h 8m'), findsOneWidget);

      await close(tester);
    });

    testWidgets('a row with no place says nothing extra', (tester) async {
      await add('Gym', 7 * 60);

      await pumpApp(tester);
      await tester.longPress(find.byType(OccurrenceTile).first);
      await settle(tester);

      expect(find.text('PLANNED'), findsNothing);

      await close(tester);
    });

    testWidgets('a visit filed onto the day says it was a visit',
        (tester) async {
      final gym = await addPlace('Gym');
      final visitId =
          await db.placesDao.recordArrival(gym, DateTime(2026, 9, 11, 7, 4));
      final place = (await db.placesDao.placeById(gym))!;
      await db.eventsDao.recordVisitAsEvent(
        place: Place(
          id: place.id,
          name: place.name,
          latitude: place.latitude,
          longitude: place.longitude,
          radiusMeters: place.radiusMeters,
          colorValue: place.colorValue,
          addVisitsToDay: true,
        ),
        visitId: visitId,
        at: DateTime(2026, 9, 11, 7, 4),
      );

      await pumpApp(tester);

      expect(find.textContaining('Visited'), findsOneWidget);
      // Not also "Done on arrival" — the row is the arrival.
      expect(find.textContaining('Done on arrival'), findsNothing);

      await close(tester);
    });

    testWidgets('a stay is not folded away with what was done',
        (tester) async {
      // Hiding is for events the user has dealt with. Somewhere the phone
      // recorded you at is the day's own record, and it stays put.
      final gym = await addPlace('Gym');
      final standup = await add('Standup', 8 * 60);
      await db.eventsDao.setCompletion(
          eventId: standup, date: today, status: CompletionStatus.done);

      final visitId =
          await db.placesDao.recordArrival(gym, DateTime(2026, 9, 11, 7, 4));
      final place = (await db.placesDao.placeById(gym))!;
      await db.eventsDao.recordVisitAsEvent(
        place: Place(
          id: place.id,
          name: place.name,
          latitude: place.latitude,
          longitude: place.longitude,
          radiusMeters: place.radiusMeters,
          colorValue: place.colorValue,
          addVisitsToDay: true,
        ),
        visitId: visitId,
        at: DateTime(2026, 9, 11, 7, 4),
      );

      await pumpApp(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Hide done'));
      await settle(tester);

      expect(find.text('Standup'), findsNothing);
      expect(find.textContaining('Visited'), findsOneWidget);

      await close(tester);
    });

    testWidgets('the ring counts plans, not places you went', (tester) async {
      final gym = await addPlace('Gym');
      await add('Standup', 9 * 60 + 30);
      final visitId =
          await db.placesDao.recordArrival(gym, DateTime(2026, 9, 11, 7));
      final place = (await db.placesDao.placeById(gym))!;
      await db.eventsDao.recordVisitAsEvent(
        place: Place(
          id: place.id,
          name: place.name,
          latitude: place.latitude,
          longitude: place.longitude,
          radiusMeters: place.radiusMeters,
          colorValue: place.colorValue,
          addVisitsToDay: true,
        ),
        visitId: visitId,
        at: DateTime(2026, 9, 11, 7),
      );

      await pumpApp(tester);

      // One standup to do, and it is not done. The gym visit is on the day
      // but was never on the list.
      expect(find.text('0/1'), findsOneWidget);

      await close(tester);
    });
  });

  group('the long-press sheet', () {
    testWidgets('skips today without counting it against you', (tester) async {
      await add('Gym', 7 * 60);
      await pumpApp(tester);

      await tester.longPress(find.byType(OccurrenceTile).first);
      await settle(tester);
      expect(find.text('Skip today'), findsOneWidget);

      await tester.tap(find.text('Skip today'));
      await settle(tester);

      final rows = await db.select(db.completions).get();
      expect(rows.single.status, CompletionStatus.skipped);
      // A skip leaves the denominator, so a lone skipped day is not a failure.
      expect(find.textContaining('All skipped'), findsOneWidget);

      await close(tester);
    });

    testWidgets('offers to undo once something is marked', (tester) async {
      final gym = await add('Gym', 7 * 60);
      await db.eventsDao.setCompletion(
          eventId: gym, date: today, status: CompletionStatus.done);
      await pumpApp(tester);

      await tester.longPress(find.byType(OccurrenceTile).first);
      await settle(tester);

      expect(find.text('Not done after all'), findsOneWidget);
      expect(find.text('Mark done'), findsNothing);

      await tester.tap(find.text('Not done after all'));
      await settle(tester);
      expect(await db.select(db.completions).get(), isEmpty);

      await close(tester);
    });

    testWidgets('does not offer to move a one-off', (tester) async {
      // "Move today" on an event that happens once is just "edit the time".
      await add('Dentist', 14 * 60 + 30, recurrence: Recurrence.once);
      await pumpApp(tester);

      // It has not happened yet and nothing else has, so it is the next-up
      // card rather than an ordinary row.
      await tester.longPress(find.byType(NextUpCard));
      await settle(tester);

      expect(find.text('Move today'), findsNothing);
      expect(find.text('Edit series'), findsOneWidget);

      await close(tester);
    });

    testWidgets('offers to move a recurring occurrence', (tester) async {
      await add('Gym', 7 * 60);
      await pumpApp(tester);

      await tester.longPress(find.byType(OccurrenceTile).first);
      await settle(tester);

      expect(find.text('Move today'), findsOneWidget);

      await close(tester);
    });
  });

  group('moving one occurrence', () {
    testWidgets('changes today and leaves the series alone', (tester) async {
      final gym = await add('Gym', 7 * 60);
      await db.eventsDao.setOverride(EventOverride(
        eventId: gym,
        date: today,
        type: OverrideType.moved,
        newTimeOfDay: 20 * 60,
      ));

      await pumpApp(tester);

      // Moved to the evening, so it is no longer overdue at 08:42.
      expect(find.textContaining('Overdue'), findsNothing);
      expect(find.text('20:00'), findsOneWidget);
      expect(find.textContaining('Moved from 07:00'), findsOneWidget);

      // Tomorrow is untouched.
      final tomorrow =
          await db.eventsDao.occurrencesForDate(today.addDays(1));
      expect(tomorrow.single.effectiveTimeOfDay, 7 * 60);
      expect(tomorrow.single.isMoved, isFalse);

      await close(tester);
    });

    testWidgets('a skip override removes the day without touching the rule',
        (tester) async {
      final gym = await add('Gym', 7 * 60);
      await db.eventsDao.deleteOccurrence(gym, today);

      await pumpApp(tester);

      expect(find.text('Gym'), findsNothing);
      expect(find.text('Nothing today'), findsOneWidget);
      expect(
        (await db.eventsDao.occurrencesForDate(today.addDays(1))),
        hasLength(1),
      );

      await close(tester);
    });
  });
}

/// Enough frames for a route or sheet transition to finish. Not
/// `pumpAndSettle`, which never returns once a text field owns a blinking
/// caret.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 450));
}
