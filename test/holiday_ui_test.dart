import 'package:dayline/src/app.dart';
import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/db/settings_dao.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/holiday.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/providers.dart';
import 'package:dayline/src/ui/edit/edit_event_screen.dart';
import 'package:dayline/src/ui/holidays/edit_holiday_screen.dart';
import 'package:dayline/src/ui/holidays/holidays_screen.dart';
import 'package:dayline/src/ui/theme.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Recording a holiday, putting an event on a timetable, and being told why
/// the day went quiet.
void main() {
  const today = CalendarDate(2026, 9, 11);
  final now = DateTime(2026, 9, 11, 8, 42);

  late DaylineDatabase db;

  setUp(() async {
    db = DaylineDatabase.forTesting(NativeDatabase.memory());
    await db.settingsDao.setFlag(SettingsDao.batteryCardDismissed, value: true);
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(700 * 3, 1600 * 3);
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
        child: home is DaylineApp
            ? home
            : MaterialApp(theme: DaylineTheme.light, home: home),
      ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  }

  Future<int> addEvent({
    required String title,
    HolidayScope? scope,
    int timeOfDay = 8 * 60,
  }) =>
      db.eventsDao.insertEvent(EventsCompanion.insert(
        title: title,
        colorValue: 0xFF3B82F6,
        timeOfDay: timeOfDay,
        recurrence: Recurrence.daily,
        startDate: today.addDays(-30),
        holidayScope: Value(scope),
      ));

  Future<int> addHoliday({
    String name = 'Bank holiday',
    int scopes = HolidayScopes.everything,
    CalendarDate? from,
    CalendarDate? to,
  }) =>
      db.holidaysDao.insertHoliday(HolidaysCompanion.insert(
        name: name,
        startDate: from ?? today,
        endDate: to ?? from ?? today,
        scopes: Value(scopes),
      ));

  group('the holidays screen', () {
    testWidgets('says what to use it for when empty', (tester) async {
      await pump(tester, const HolidaysScreen());

      expect(find.text('No holidays yet'), findsOneWidget);

      await close(tester);
    });

    testWidgets('lists a holiday with its dates and what it closes',
        (tester) async {
      await addHoliday(name: 'Half-term', scopes: HolidayScopes.school);
      await pump(tester, const HolidaysScreen());

      expect(find.text('Half-term'), findsOneWidget);
      expect(find.textContaining('School'), findsOneWidget);

      await close(tester);
    });

    testWidgets('marks one that is on today', (tester) async {
      await addHoliday();
      await pump(tester, const HolidaysScreen());

      expect(find.text('Today'), findsOneWidget);

      await close(tester);
    });

    testWidgets('separates what is coming from what has gone', (tester) async {
      await addHoliday(name: 'Last year', from: today.addDays(-40));
      await addHoliday(name: 'Next month', from: today.addDays(30));
      await pump(tester, const HolidaysScreen());

      expect(find.text('COMING UP'), findsOneWidget);
      expect(find.text('BEEN AND GONE'), findsOneWidget);

      await close(tester);
    });
  });

  group('the holiday editor', () {
    testWidgets('saves a single day closing everything', (tester) async {
      await pump(tester, const EditHolidayScreen());

      await tester.enterText(find.byType(TextFormField).first, 'Christmas');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);

      final holiday = (await db.holidaysDao.allHolidays()).single;
      expect(holiday.name, 'Christmas');
      expect(holiday.isSingleDay, isTrue);
      expect(holiday.scopes, HolidayScopes.everything);

      await close(tester);
    });

    testWidgets('refuses to save one that closes nothing', (tester) async {
      // It would look recorded and do nothing at all.
      await pump(tester, const EditHolidayScreen());
      await tester.enterText(find.byType(TextFormField).first, 'Nothing day');
      await settle(tester);

      for (final scope in HolidayScope.values) {
        await tester.tap(find.byKey(ValueKey('scope-${scope.name}')));
        await settle(tester);
      }
      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(find.text('Pick what is closed'), findsOneWidget);
      expect(await db.holidaysDao.allHolidays(), isEmpty);

      await close(tester);
    });

    testWidgets('saves one that closes only school', (tester) async {
      await pump(tester, const EditHolidayScreen());
      await tester.enterText(find.byType(TextFormField).first, 'Inset day');
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('scope-work')));
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);

      expect((await db.holidaysDao.allHolidays()).single.scopes,
          HolidayScopes.school);

      await close(tester);
    });

    testWidgets('loads an existing one back', (tester) async {
      final id = await addHoliday(
        name: 'Week off',
        from: today,
        to: today.addDays(4),
        scopes: HolidayScopes.work,
      );
      await pump(tester, EditHolidayScreen(holidayId: id));

      expect(find.text('Edit holiday'), findsOneWidget);
      expect(find.textContaining('Work steps aside for 5 days'), findsOneWidget);

      await close(tester);
    });

    testWidgets('a single day reads as one day', (tester) async {
      await pump(tester, const EditHolidayScreen());

      expect(find.textContaining('for the day'), findsOneWidget);

      await close(tester);
    });
  });

  group('putting an event on a timetable', () {
    testWidgets('defaults to nothing', (tester) async {
      // Medication is still medication on Christmas Day.
      await pump(tester, const EditEventScreen(initialDate: today));

      expect(find.text('Pauses on'), findsOneWidget);
      final chip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('holiday-scope-none')),
      );
      expect(chip.selected, isTrue);

      await close(tester);
    });

    testWidgets('saves the chosen timetable', (tester) async {
      await pump(tester, const EditEventScreen(initialDate: today));

      await tester.enterText(find.byType(TextFormField).first, 'School run');
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('holiday-scope-school')));
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);

      expect((await db.eventsDao.allEvents()).single.holidayScope,
          HolidayScope.school);

      await close(tester);
    });

    testWidgets('loads back, and can be cleared again', (tester) async {
      final id = await addEvent(title: 'Standup', scope: HolidayScope.work);
      await pump(tester, EditEventScreen(eventId: id));

      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('holiday-scope-work')),
            )
            .selected,
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('holiday-scope-none')));
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);

      expect((await db.eventsDao.allEvents()).single.holidayScope, isNull);

      await close(tester);
    });

    testWidgets('says nothing pauses it while there are no holidays',
        (tester) async {
      await pump(tester, const EditEventScreen(initialDate: today));
      await tester.tap(find.byKey(const ValueKey('holiday-scope-work')));
      await settle(tester);

      expect(find.textContaining('No holidays recorded yet'), findsOneWidget);

      await close(tester);
    });
  });

  group('the day itself', () {
    testWidgets('names the holiday rather than just going quiet',
        (tester) async {
      // A missing school run with nothing on screen to explain it is
      // indistinguishable from a bug.
      await addEvent(title: 'School run', scope: HolidayScope.school);
      await addHoliday(name: 'Half-term', scopes: HolidayScopes.school);

      await pump(tester, const DaylineApp());

      expect(find.text('School run'), findsNothing);
      expect(find.text('Half-term'), findsOneWidget);
      expect(find.textContaining('School events are paused'), findsOneWidget);

      await close(tester);
    });

    testWidgets('leaves everything else on the day', (tester) async {
      await addEvent(title: 'School run', scope: HolidayScope.school);
      await addEvent(title: 'Medication', timeOfDay: 9 * 60);
      await addHoliday(name: 'Half-term', scopes: HolidayScopes.school);

      await pump(tester, const DaylineApp());

      expect(find.text('Medication'), findsOneWidget);
      expect(find.text('School run'), findsNothing);

      await close(tester);
    });

    testWidgets('shows no banner on an ordinary day', (tester) async {
      await addEvent(title: 'Standup', scope: HolidayScope.work);
      await addHoliday(name: 'Next week', from: today.addDays(7));

      await pump(tester, const DaylineApp());

      expect(find.text('Next week'), findsNothing);
      expect(find.text('Standup'), findsOneWidget);

      await close(tester);
    });

    testWidgets('names both when two land on one day', (tester) async {
      await addHoliday(name: 'Leave', scopes: HolidayScopes.work);
      await addHoliday(name: 'Half-term', scopes: HolidayScopes.school);

      await pump(tester, const DaylineApp());

      expect(find.textContaining('Leave'), findsOneWidget);
      expect(find.textContaining('Half-term'), findsOneWidget);
      expect(
        find.textContaining('Work and school events are paused'),
        findsOneWidget,
      );

      await close(tester);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 450));
}
