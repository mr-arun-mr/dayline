import 'package:dayline/src/app.dart';
import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/db/settings_dao.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/providers.dart';
import 'package:dayline/src/ui/today/next_up_card.dart';
import 'package:dayline/src/ui/today/now_divider.dart';
import 'package:dayline/src/ui/today/occurrence_tile.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const today = CalendarDate(2026, 9, 11);

  late DaylineDatabase db;

  setUp(() => db = DaylineDatabase.forTesting(NativeDatabase.memory()));

  Future<void> add(
    String title,
    int timeOfDay, {
    Recurrence recurrence = Recurrence.daily,
    CalendarDate? startDate,
  }) =>
      db.eventsDao.insertEvent(EventsCompanion.insert(
        title: title,
        colorValue: 0xFF3B82F6,
        timeOfDay: timeOfDay,
        recurrence: recurrence,
        startDate: startDate ?? today.addDays(-10),
      ));

  /// Pumps the app with "now" pinned. Not `pumpAndSettle`, because the editor's
  /// autofocused field blinks a caret that never settles.
  Future<void> pumpApp(
    WidgetTester tester, {
    required DateTime now,
    bool dismissBatteryCard = true,
  }) async {
    // Tests run as Android, where the one-time battery warning shows and eats
    // a chunk of the viewport. Dealt with here so the other tests are about
    // the day, not about the card; it has a test of its own below.
    if (dismissBatteryCard) {
      await db.settingsDao
          .setFlag(SettingsDao.batteryCardDismissed, value: true);
    }

    // The default 800x600 test surface is the wrong shape for this screen, and
    // with section headers added it pushes later rows out of the lazy list
    // entirely — which reads as a missing widget rather than an off-screen one.
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  }

  testWidgets('sections the day, with the now line between past and future',
      (tester) async {
    await add('Gym', 7 * 60);
    await add('Standup', 9 * 60 + 30);
    await add('Medication', 21 * 60);

    await pumpApp(tester, now: DateTime(2026, 9, 11, 8, 42));

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('OVERDUE  1'), findsOneWidget);
    expect(find.text('NEXT UP'), findsOneWidget);
    expect(find.text('LATER TODAY'), findsOneWidget);
    expect(find.byType(NowDivider), findsOneWidget);

    // Gym has gone; the other two have not.
    final divider = tester.getTopLeft(find.byType(NowDivider)).dy;
    expect(tester.getTopLeft(find.text('Gym')).dy, lessThan(divider));
    expect(tester.getTopLeft(find.text('Standup')).dy, greaterThan(divider));

    await close(tester);
  });

  testWidgets('the next event gets the card and a countdown', (tester) async {
    await add('Gym', 7 * 60);
    await add('Standup', 9 * 60 + 30);

    await pumpApp(tester, now: DateTime(2026, 9, 11, 8, 42));

    expect(find.byType(NextUpCard), findsOneWidget);
    expect(find.text('NEXT UP'), findsOneWidget);
    expect(find.descendant(
      of: find.byType(NextUpCard),
      matching: find.text('Standup'),
    ), findsOneWidget);
    expect(find.text('in 48m'), findsOneWidget);

    // Gym has already been, so it stays an ordinary row.
    expect(find.byType(OccurrenceTile), findsOneWidget);

    await close(tester);
  });

  testWidgets('once the day is over everything left is overdue', (tester) async {
    await add('Gym', 7 * 60);
    await add('Medication', 21 * 60);

    await pumpApp(tester, now: DateTime(2026, 9, 11, 23, 30));

    expect(find.byType(NextUpCard), findsNothing);
    expect(find.text('OVERDUE  2'), findsOneWidget);
    expect(find.byType(OccurrenceTile), findsNWidgets(2));

    await close(tester);
  });

  testWidgets('another day has no now line and no countdown', (tester) async {
    await add('Gym', 7 * 60);

    await pumpApp(tester, now: DateTime(2026, 9, 11, 8, 42));
    await tester.tap(find.text('12').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Tomorrow'), findsOneWidget);
    // "Now" does not exist on a day that is not today, so nothing can be
    // overdue and nothing is singled out as next.
    expect(find.byType(NowDivider), findsNothing);
    expect(find.byType(NextUpCard), findsNothing);
    expect(find.text('PLANNED'), findsOneWidget);
    expect(find.byType(OccurrenceTile), findsOneWidget);

    await close(tester);
  });

  testWidgets('the Today button only appears once you have scrubbed away',
      (tester) async {
    await add('Gym', 7 * 60);
    await pumpApp(tester, now: DateTime(2026, 9, 11, 8, 42));

    // The header says Today; there is nothing to go back to.
    expect(find.widgetWithText(TextButton, 'Today'), findsNothing);

    await tester.tap(find.text('13').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.widgetWithText(TextButton, 'Today'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Today'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('Today'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Today'), findsNothing);

    await close(tester);
  });

  testWidgets('an empty day says so', (tester) async {
    await pumpApp(tester, now: DateTime(2026, 9, 11, 8, 42));
    expect(find.text('Nothing today'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a rule that does not fall on the day is not drawn',
      (tester) async {
    await add('Dentist', 14 * 60 + 30,
        recurrence: Recurrence.once, startDate: today.addDays(3));

    await pumpApp(tester, now: DateTime(2026, 9, 11, 8, 42));
    expect(find.text('Nothing today'), findsOneWidget);
    expect(find.text('Dentist'), findsNothing);

    await close(tester);
  });

  testWidgets('the list follows the database without a manual refresh',
      (tester) async {
    await add('Gym', 7 * 60);
    await pumpApp(tester, now: DateTime(2026, 9, 11, 8, 42));
    expect(find.text('Medication'), findsNothing);

    await add('Medication', 21 * 60);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.text('Medication'), findsOneWidget);

    await close(tester);
  });

  testWidgets('the battery warning shows once, then stays gone', (tester) async {
    await add('Gym', 7 * 60);
    await pumpApp(
      tester,
      now: DateTime(2026, 9, 11, 8, 42),
      dismissBatteryCard: false,
    );

    expect(find.text('Keep reminders working'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Got it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Keep reminders working'), findsNothing);
    expect(
      await db.settingsDao.flag(SettingsDao.batteryCardDismissed),
      isTrue,
      reason: 'it must not come back on the next launch',
    );

    await close(tester);
  });
}
