import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/db/tidy_stays.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/place.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Putting right the stays an older recorder could write.
///
/// Two stays running at the same time are a device in two places at once. The
/// recorder cannot produce them any more, but the rows it already wrote are
/// still on the day, and nothing that happens later goes back for them.
void main() {
  late DaylineDatabase db;

  setUp(() => db = DaylineDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addPlace(String name, {bool onTheDay = false}) =>
      db.placesDao.insertPlace(PlacesCompanion.insert(
        name: name,
        latitude: 51.5,
        longitude: -0.12,
        colorValue: 0xFF3B82F6,
        kind: PlaceKind.other,
        addVisitsToDay: Value(onTheDay),
      ));

  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 9, 16, hour, minute);

  Future<int> stay(int placeId, DateTime from, [DateTime? to]) =>
      db.into(db.visits).insert(VisitsCompanion.insert(
        placeId: placeId,
        arrivedAt: from,
        departedAt: Value(to),
      ));

  Future<List<VisitRow>> allStays() => (db.select(db.visits)
        ..orderBy([(v) => OrderingTerm(expression: v.arrivedAt)]))
      .get();

  test('a minute at the edge of a circle is dropped', () async {
    // The reported day: two places a street apart, both reported, both left at
    // the same moment — the same three and a half hours under two names.
    final shop = await addPlace('GS');
    final gym = await addPlace('LUXE Gym');

    await stay(shop, at(9, 1), at(12, 30));
    await stay(gym, at(9, 2), at(12, 30));

    expect(await tidyRecordedStays(db), 0, reason: 'nothing was shortened');

    final left = await allStays();
    expect(left, hasLength(1));
    expect(left.single.placeId, gym);
    expect(left.single.arrivedAt, at(9, 2));
    expect(left.single.departedAt, at(12, 30));
  });

  test('a real overlap is cut short where the next stay began', () async {
    // Home never closed because the exit was dropped, so the office was
    // recorded inside it.
    final home = await addPlace('Home');
    final office = await addPlace('Office');

    await stay(home, at(7), at(18));
    await stay(office, at(9), at(17, 30));

    expect(await tidyRecordedStays(db), 1);

    final left = await allStays();
    expect(left.first.placeId, home);
    expect(left.first.departedAt, at(9));
    expect(left.last.departedAt, at(17, 30), reason: 'the office is untouched');
  });

  test('a stay still open across a later one is closed at it', () async {
    final home = await addPlace('Home');
    final office = await addPlace('Office');

    await stay(home, at(7));
    await stay(office, at(9), at(17, 30));

    await tidyRecordedStays(db);

    final left = await allStays();
    expect(left.first.departedAt, at(9));
    expect(left.last.departedAt, at(17, 30));
  });

  test('the stay that is still running stays running', () async {
    final office = await addPlace('Office');
    final home = await addPlace('Home');

    await stay(office, at(9), at(17, 30));
    await stay(home, at(18));

    expect(await tidyRecordedStays(db), 0);
    expect((await allStays()).last.departedAt, isNull);
  });

  test('a day that never overlapped is left alone', () async {
    final home = await addPlace('Home');
    final office = await addPlace('Office');

    await stay(home, at(7), at(8, 30));
    await stay(office, at(9), at(17, 30));
    await stay(home, at(18), at(23));

    expect(await tidyRecordedStays(db), 0);
    expect(await tidyRecordedStays(db), 0, reason: 'and again, unchanged');

    final left = await allStays();
    expect(left, hasLength(3));
    expect(left.first.departedAt, at(8, 30));
    expect(left.last.arrivedAt, at(18));
  });

  test('the row a dropped stay put on the day goes with it', () async {
    final shop = await addPlace('GS', onTheDay: true);
    final gym = await addPlace('LUXE Gym', onTheDay: true);

    final shopStay = await stay(shop, at(9, 1), at(12, 30));
    final gymStay = await stay(gym, at(9, 2), at(12, 30));
    await db.into(db.events).insert(EventsCompanion.insert(
      title: 'GS',
      colorValue: 1,
      timeOfDay: 9 * 60 + 1,
      recurrence: Recurrence.once,
      startDate: const CalendarDate(2026, 9, 16),
      fromVisitId: Value(shopStay),
    ));
    await db.into(db.events).insert(EventsCompanion.insert(
      title: 'LUXE Gym',
      colorValue: 1,
      timeOfDay: 9 * 60 + 2,
      recurrence: Recurrence.once,
      startDate: const CalendarDate(2026, 9, 16),
      fromVisitId: Value(gymStay),
    ));

    await tidyRecordedStays(db);

    final rows = await db.select(db.events).get();
    expect(rows.single.title, 'LUXE Gym');
  });

  test('a shortened row is told how long it really lasted', () async {
    final home = await addPlace('Home', onTheDay: true);
    final office = await addPlace('Office');

    final homeStay = await stay(home, at(7), at(18));
    await stay(office, at(9), at(17, 30));
    await db.into(db.events).insert(EventsCompanion.insert(
      title: 'Home',
      colorValue: 1,
      timeOfDay: 7 * 60,
      recurrence: Recurrence.once,
      startDate: const CalendarDate(2026, 9, 16),
      durationMin: const Value(660),
      fromVisitId: Value(homeStay),
    ));

    await tidyRecordedStays(db);

    final row = (await db.select(db.events).get()).single;
    expect(row.durationMin, 120, reason: '07:00 to 09:00, not to 18:00');
  });
}
