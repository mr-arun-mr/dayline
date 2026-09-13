import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/db/settings_dao.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/place.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/providers.dart';
import 'package:dayline/src/ui/edit/edit_event_screen.dart';
import 'package:dayline/src/ui/theme.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Building each of the five recurrence shapes through the editor, and reading
/// back the rule that was actually stored.
void main() {
  // A Friday.
  const today = CalendarDate(2026, 9, 11);
  final now = DateTime(2026, 9, 11, 8, 42);

  late DaylineDatabase db;

  setUp(() async {
    db = DaylineDatabase.forTesting(NativeDatabase.memory());
    await db.settingsDao.setFlag(SettingsDao.batteryCardDismissed, value: true);
  });

  Future<void> pumpEditor(WidgetTester tester, {int? eventId}) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
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
          home: EditEventScreen(eventId: eventId, initialDate: today),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  }

  // The weekday circles are single letters, two of them literally "T", so they
  // are addressed by key rather than by what they say.
  Finder weekday(int isoWeekday) => find.byKey(ValueKey('weekday-$isoWeekday'));

  Future<void> type(WidgetTester tester, String title) async {
    await tester.enterText(find.byType(TextFormField).first, title);
    await settle(tester);
  }

  testWidgets('all five recurrence types are offered', (tester) async {
    await pumpEditor(tester);
    for (final label in ['Once', 'Daily', 'Weekly', 'Every N days', 'Monthly']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await close(tester);
  });

  testWidgets('weekly: picking days builds the mask and the preview sentence',
      (tester) async {
    await pumpEditor(tester);
    await type(tester, 'Dance class');

    await tester.tap(find.text('Weekly'));
    await settle(tester);

    // Defaults to the start date's own weekday rather than to nothing.
    expect(find.textContaining('Every Friday'), findsOneWidget);

    // Monday and Wednesday on, Friday off.
    await tester.tap(weekday(DateTime.monday));
    await settle(tester);
    await tester.tap(weekday(DateTime.wednesday));
    await settle(tester);
    await tester.tap(weekday(DateTime.friday));
    await settle(tester);

    expect(find.textContaining('Every Mon, Wed at'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await settle(tester);

    final event = (await db.eventsDao.allEvents()).single;
    expect(event.recurrence, Recurrence.weekly);
    expect(
      event.rule.daysOfWeek,
      Weekdays.maskOf([DateTime.monday, DateTime.wednesday]),
    );

    await close(tester);
  });

  testWidgets('weekly: refuses to save a rule that could never fire',
      (tester) async {
    await pumpEditor(tester);
    await type(tester, 'Nothing');
    await tester.tap(find.text('Weekly'));
    await settle(tester);

    // Turn off the day it defaulted to, leaving an empty mask.
    await tester.tap(weekday(DateTime.friday));
    await settle(tester);
    expect(find.textContaining('Never at'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(await db.eventsDao.allEvents(), isEmpty);
    expect(find.text('Pick at least one day of the week'), findsOneWidget);

    await close(tester);
  });

  testWidgets('every N days: the interval cannot drop to 1', (tester) async {
    // One would be Daily, which is its own option.
    await pumpEditor(tester);
    await type(tester, 'Water the plants');
    await tester.tap(find.text('Every N days'));
    await settle(tester);

    expect(find.textContaining('Every other day'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await settle(tester);
    expect(find.textContaining('Every other day'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await settle(tester);
    expect(find.textContaining('Every 3 days'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect((await db.eventsDao.allEvents()).single.rule.interval, 3);

    await close(tester);
  });

  testWidgets('monthly: picks a day and warns about short months',
      (tester) async {
    await pumpEditor(tester);
    await type(tester, 'Rent');
    await tester.tap(find.text('Monthly'));
    await settle(tester);

    // Defaults to the start date's day.
    expect(find.textContaining('Monthly on the 11th'), findsOneWidget);

    await tester.tap(find.text('31'));
    await settle(tester);
    expect(find.textContaining('Monthly on the 31st'), findsOneWidget);
    expect(find.textContaining('never skips a month'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await settle(tester);

    final event = (await db.eventsDao.allEvents()).single;
    expect(event.rule.dayOfMonth, 31);
    // February still gets one.
    expect(event.rule.effectiveDayOfMonth(2027, 2), 28);

    await close(tester);
  });

  testWidgets('monthly: last day of the month is its own idea', (tester) async {
    await pumpEditor(tester);
    await type(tester, 'Payday');
    await tester.tap(find.text('Monthly'));
    await settle(tester);

    await tester.tap(find.text('Last day of the month'));
    await settle(tester);
    expect(find.textContaining('Monthly on the last day'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect((await db.eventsDao.allEvents()).single.rule.dayOfMonth, -1);

    await close(tester);
  });

  testWidgets('switching away from a shape does not leave its settings behind',
      (tester) async {
    await pumpEditor(tester);
    await type(tester, 'Gym');

    await tester.tap(find.text('Weekly'));
    await settle(tester);
    await tester.tap(weekday(DateTime.monday));
    await settle(tester);

    await tester.tap(find.text('Daily'));
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    final event = (await db.eventsDao.allEvents()).single;
    expect(event.recurrence, Recurrence.daily);
    expect(event.rule.daysOfWeek, Weekdays.none,
        reason: 'a stale mask would confuse the scheduler later');
    expect(event.rule.interval, 1);
    expect(event.rule.dayOfMonth, isNull);

    await close(tester);
  });

  group('marking done on arrival', () {
    // The switch hangs off the place picker, which only appears once the user
    // has somewhere to put an event.
    Future<int> addGym() => db.placesDao.insertPlace(PlacesCompanion.insert(
          name: 'Gym',
          latitude: 51.5,
          longitude: -0.12,
          colorValue: 0xFF3B82F6,
          kind: PlaceKind.gym,
        ));

    final switchKey = find.byKey(const ValueKey('auto-complete-switch'));

    testWidgets('is not offered with no places at all', (tester) async {
      await pumpEditor(tester);

      expect(find.text('Where'), findsNothing);
      expect(switchKey, findsNothing);

      await close(tester);
    });

    testWidgets('is not offered until a place is picked', (tester) async {
      await addGym();
      await pumpEditor(tester);

      // "Anywhere" is the default, and arriving anywhere is not an arrival.
      expect(find.text('Where'), findsOneWidget);
      expect(switchKey, findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Gym'));
      await settle(tester);

      expect(switchKey, findsOneWidget);

      await close(tester);
    });

    testWidgets('is off by default, and saves on when switched on',
        (tester) async {
      await addGym();
      await pumpEditor(tester);
      await type(tester, 'Gym');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Gym'));
      await settle(tester);
      await tester.tap(switchKey);
      await settle(tester);

      await tester.tap(find.text('Save'));
      await settle(tester);

      final event = (await db.eventsDao.allEvents()).single;
      expect(event.autoCompleteOnArrival, isTrue);
      expect(event.completesOnArrival, isTrue);

      await close(tester);
    });

    testWidgets('stays off when left alone', (tester) async {
      await addGym();
      await pumpEditor(tester);
      await type(tester, 'Gym');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Gym'));
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);

      expect((await db.eventsDao.allEvents()).single.autoCompleteOnArrival,
          isFalse);

      await close(tester);
    });

    testWidgets('clearing the place takes the switch with it', (tester) async {
      // A promise the app cannot keep is worse than one it never made.
      await addGym();
      await pumpEditor(tester);
      await type(tester, 'Gym');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Gym'));
      await settle(tester);
      await tester.tap(switchKey);
      await settle(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Anywhere'));
      await settle(tester);
      expect(switchKey, findsNothing);

      await tester.tap(find.text('Save'));
      await settle(tester);

      final event = (await db.eventsDao.allEvents()).single;
      expect(event.placeId, isNull);
      expect(event.autoCompleteOnArrival, isFalse);

      await close(tester);
    });

    testWidgets('loads back on for a rule that has it', (tester) async {
      final place = await addGym();
      final id = await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Gym',
        colorValue: 0xFF3B82F6,
        timeOfDay: 7 * 60,
        recurrence: Recurrence.daily,
        startDate: today,
        placeId: Value(place),
        autoCompleteOnArrival: const Value(true),
      ));

      await pumpEditor(tester, eventId: id);

      expect(tester.widget<SwitchListTile>(switchKey).value, isTrue);

      await close(tester);
    });

    testWidgets('turning it back off saves off', (tester) async {
      final place = await addGym();
      final id = await db.eventsDao.insertEvent(EventsCompanion.insert(
        title: 'Gym',
        colorValue: 0xFF3B82F6,
        timeOfDay: 7 * 60,
        recurrence: Recurrence.daily,
        startDate: today,
        placeId: Value(place),
        autoCompleteOnArrival: const Value(true),
      ));

      await pumpEditor(tester, eventId: id);
      await tester.tap(switchKey);
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);

      final event = (await db.eventsDao.allEvents()).single;
      expect(event.autoCompleteOnArrival, isFalse);
      expect(event.placeId, place, reason: 'the place link is untouched');

      await close(tester);
    });
  });

  testWidgets('an existing rule loads back into the right controls',
      (tester) async {
    final id = await db.eventsDao.insertEvent(
      EventsCompanion.insert(
        title: 'Dance class',
        colorValue: 0xFF8B5CF6,
        timeOfDay: 17 * 60,
        recurrence: Recurrence.weekly,
        startDate: today,
        daysOfWeek: const Value(Weekdays.saturday),
      ),
    );

    await pumpEditor(tester, eventId: id);

    expect(find.text('Edit event'), findsOneWidget);
    expect(find.textContaining('Every Saturday at 17:00'), findsOneWidget);

    await close(tester);
  });
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 450));
}
