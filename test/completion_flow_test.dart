import 'package:dayline/src/app.dart';
import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/db/settings_dao.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/event.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/providers.dart';
import 'package:dayline/src/ui/today/next_up_card.dart';
import 'package:dayline/src/ui/today/occurrence_tile.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  testWidgets('tapping a row marks it done and moves it out of the timeline',
      (tester) async {
    final gym = await add('Gym', 7 * 60);
    await add('Standup', 9 * 60 + 30);
    await pumpApp(tester);

    expect(find.text('OVERDUE  1'), findsOneWidget);

    await tester.tap(find.byType(OccurrenceTile).first);
    await settle(tester);

    final rows = await db.select(db.completions).get();
    expect(rows.single.eventId, gym);
    expect(rows.single.status, CompletionStatus.done);

    // Gone from Overdue, folded into Done.
    expect(find.text('OVERDUE  1'), findsNothing);
    expect(find.text('DONE  1'), findsOneWidget);

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

    // Open the Done section and tap it again.
    await tester.tap(find.widgetWithText(TextButton, 'Show'));
    await settle(tester);
    await tester.tap(find.byType(OccurrenceTile).first);
    await settle(tester);

    expect(await db.select(db.completions).get(), isEmpty);
    expect(find.text('OVERDUE  1'), findsOneWidget);

    await close(tester);
  });

  testWidgets('the Done section is folded away until asked for',
      (tester) async {
    final gym = await add('Gym', 7 * 60);
    await add('Standup', 9 * 60 + 30);
    await db.eventsDao.setCompletion(
        eventId: gym, date: today, status: CompletionStatus.done);

    await pumpApp(tester);

    expect(find.text('DONE  1'), findsOneWidget);
    expect(find.text('Gym'), findsNothing, reason: 'collapsed by default');

    await tester.tap(find.widgetWithText(TextButton, 'Show'));
    await settle(tester);
    expect(find.text('Gym'), findsOneWidget);

    await close(tester);
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

      await tester.tap(find.widgetWithText(TextButton, 'Show'));
      await settle(tester);
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
}

/// Enough frames for a route or sheet transition to finish. Not
/// `pumpAndSettle`, which never returns once a text field owns a blinking
/// caret.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 450));
}
