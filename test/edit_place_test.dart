import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/model/place.dart';
import 'package:dayline/src/providers.dart';
import 'package:dayline/src/ui/places/edit_place_screen.dart';
import 'package:dayline/src/ui/theme.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The place editor, and the one switch in Dayline that writes rows the user
/// did not ask for.
void main() {
  late DaylineDatabase db;

  setUp(() {
    db = DaylineDatabase.forTesting(NativeDatabase.memory());
  });

  Future<int> addGym({bool addVisitsToDay = false}) =>
      db.placesDao.insertPlace(PlacesCompanion.insert(
        name: 'Gym',
        latitude: 51.5,
        longitude: -0.12,
        colorValue: 0xFF3B82F6,
        kind: PlaceKind.gym,
        addVisitsToDay: Value(addVisitsToDay),
      ));

  Future<void> pumpEditor(WidgetTester tester, {int? placeId}) async {
    // Wider than a phone on purpose. flutter_test draws with a fallback font
    // whose every glyph is a full em square, so the radius row's explanation
    // overflows here at 390pt and nowhere on a real device — which is what
    // the screenshot test loads real fonts to avoid. Widening keeps this test
    // about the switch rather than about font metrics.
    tester.view.physicalSize = const Size(700 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: DaylineTheme.light,
          home: EditPlaceScreen(placeId: placeId),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  }

  final switchKey = find.byKey(const ValueKey('add-visits-switch'));

  Future<int> addNeighbour({
    double latitude = 51.5004,
    double radius = Place.defaultRadiusMeters,
  }) =>
      db.placesDao.insertPlace(PlacesCompanion.insert(
        name: 'GS',
        latitude: latitude,
        longitude: -0.12,
        radiusMeters: Value(radius),
        colorValue: 0xFF10B981,
        kind: PlaceKind.shop,
      ));

  group('circles that run into each other', () {
    testWidgets('says which place is too close, and how close', (tester) async {
      // 44 m apart, with the radius floor at 100 m: standing in either one the
      // OS reports both, which is how the same hours end up on the day twice
      // under two names.
      await addNeighbour();
      final gym = await addGym();

      await pumpEditor(tester, placeId: gym);

      expect(find.textContaining('GS is 44 m away'), findsOneWidget);

      await close(tester);
    });

    testWidgets('and nothing at all when they are comfortably apart',
        (tester) async {
      // 556 m between the centres, 300 m of radius between them.
      await addNeighbour(latitude: 51.505);
      final gym = await addGym();

      await pumpEditor(tester, placeId: gym);

      expect(find.textContaining('away'), findsNothing);

      await close(tester);
    });

    testWidgets('a place does not run into itself', (tester) async {
      final gym = await addGym();

      await pumpEditor(tester, placeId: gym);

      expect(find.textContaining('away'), findsNothing);

      await close(tester);
    });
  });

  testWidgets('is offered, and off, on a place that has never had it',
      (tester) async {
    final gym = await addGym();
    await pumpEditor(tester, placeId: gym);

    expect(switchKey, findsOneWidget);
    expect(tester.widget<SwitchListTile>(switchKey).value, isFalse);

    await close(tester);
  });

  testWidgets('is off for a brand new place', (tester) async {
    // Nothing should start writing rows on the strength of being created.
    await pumpEditor(tester);

    expect(tester.widget<SwitchListTile>(switchKey).value, isFalse);

    await close(tester);
  });

  testWidgets('loads back on for a place that has it', (tester) async {
    final gym = await addGym(addVisitsToDay: true);
    await pumpEditor(tester, placeId: gym);

    expect(tester.widget<SwitchListTile>(switchKey).value, isTrue);

    await close(tester);
  });

  testWidgets('explains itself only once switched on', (tester) async {
    final gym = await addGym();
    await pumpEditor(tester, placeId: gym);

    expect(find.textContaining('already covers being here'), findsNothing);

    await tester.tap(switchKey);
    await settle(tester);

    expect(find.textContaining('already covers being here'), findsOneWidget);

    await close(tester);
  });

  testWidgets('turning it on and saving stores it', (tester) async {
    final gym = await addGym();
    await pumpEditor(tester, placeId: gym);

    await tester.tap(switchKey);
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect((await db.placesDao.placeById(gym))!.addVisitsToDay, isTrue);

    await close(tester);
  });

  testWidgets('turning it back off saves off', (tester) async {
    final gym = await addGym(addVisitsToDay: true);
    await pumpEditor(tester, placeId: gym);

    await tester.tap(switchKey);
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect((await db.placesDao.placeById(gym))!.addVisitsToDay, isFalse);

    await close(tester);
  });

  testWidgets('saving an unrelated change does not disturb it', (tester) async {
    // The place companion is written with replace, so every column has to be
    // carried deliberately or an edit silently resets this one.
    final gym = await addGym(addVisitsToDay: true);
    await pumpEditor(tester, placeId: gym);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Work'));
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    final place = (await db.placesDao.placeById(gym))!;
    expect(place.kind, PlaceKind.work);
    expect(place.addVisitsToDay, isTrue);

    await close(tester);
  });
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 450));
}
