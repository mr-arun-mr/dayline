import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/event.dart';
import 'package:dayline/src/model/occurrence.dart';
import 'package:dayline/src/model/place.dart';
import 'package:dayline/src/model/place_stats.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/ui/today/occurrence_tile.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Showing what was planned next to what actually happened.
///
/// A row says the gym was at 07:00. These are the rules for it also saying you
/// were in it from 07:04 to 08:12 — and, just as importantly, for staying
/// quiet when it does not know.
void main() {
  const today = CalendarDate(2026, 9, 11);

  late DaylineDatabase db;
  late int gym;
  late int office;

  setUp(() async {
    db = DaylineDatabase.forTesting(NativeDatabase.memory());
    gym = await db.placesDao.insertPlace(PlacesCompanion.insert(
      name: 'Gym',
      latitude: 51.5,
      longitude: -0.12,
      colorValue: 1,
      kind: PlaceKind.gym,
    ));
    office = await db.placesDao.insertPlace(PlacesCompanion.insert(
      name: 'Office',
      latitude: 51.51,
      longitude: -0.13,
      colorValue: 2,
      kind: PlaceKind.work,
    ));
  });

  tearDown(() => db.close());

  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 9, 11, hour, minute);

  Future<int> addEvent({
    int? placeId,
    int timeOfDay = 7 * 60,
    String title = 'Gym',
  }) =>
      db.eventsDao.insertEvent(EventsCompanion.insert(
        title: title,
        colorValue: 1,
        timeOfDay: timeOfDay,
        recurrence: Recurrence.daily,
        startDate: today.addDays(-10),
        placeId: Value(placeId),
      ));

  Future<void> visit(int placeId, DateTime from, [DateTime? to]) async {
    await db.placesDao.recordArrival(placeId, from);
    if (to != null) await db.placesDao.recordDeparture(placeId, to);
  }

  Future<Occurrence> only() async =>
      (await db.eventsDao.occurrencesForDate(today)).single;

  group('the day carries the actual times', () {
    test('a stay around the scheduled time is attached', () async {
      await addEvent(placeId: gym, timeOfDay: 7 * 60);
      await visit(gym, at(7, 4), at(8, 12));

      final occurrence = await only();
      expect(occurrence.arrivedAt, at(7, 4));
      expect(occurrence.departedAt, at(8, 12));
      expect(formatActualTimes(occurrence), '07:04 → 08:12');
    });

    test('a stay still running says so rather than inventing an end',
        () async {
      await addEvent(placeId: gym, timeOfDay: 7 * 60);
      await visit(gym, at(7, 4));

      final occurrence = await only();
      expect(occurrence.isStillThere, isTrue);
      expect(occurrence.departedAt, isNull);
      expect(formatActualTimes(occurrence), '07:04 → still there');
    });

    test('an event tied to nowhere never gets one', () async {
      await addEvent(placeId: null);
      await visit(gym, at(7, 4), at(8, 12));

      final occurrence = await only();
      expect(occurrence.visit, isNull);
      expect(formatActualTimes(occurrence), isNull);
    });

    test('a stay somewhere else is not borrowed', () async {
      await addEvent(placeId: gym, timeOfDay: 7 * 60);
      await visit(office, at(7, 4), at(8, 12));

      expect((await only()).visit, isNull);
    });

    test('a stay well outside the window is not claimed', () async {
      await addEvent(placeId: gym, timeOfDay: 7 * 60);
      await visit(gym, at(14), at(15));

      expect((await only()).visit, isNull);
    });

    test('no stay at all says nothing, rather than saying you missed it',
        () async {
      // With background location off there are no visits at all, and "missed"
      // would be the app inventing a fact about someone's day.
      await addEvent(placeId: gym, timeOfDay: 7 * 60);

      final occurrence = await only();
      expect(occurrence.visit, isNull);
      expect(formatActualTimes(occurrence), isNull);
    });

    test('a moved occurrence is matched against where it was moved to',
        () async {
      final id = await addEvent(placeId: gym, timeOfDay: 7 * 60);
      await db.eventsDao.setOverride(EventOverride(
        eventId: id,
        date: today,
        type: OverrideType.moved,
        newTimeOfDay: 20 * 60,
      ));
      await visit(gym, at(7, 4), at(8, 12));
      await visit(gym, at(19, 50), at(21));

      expect((await only()).arrivedAt, at(19, 50));
    });

    test('the nearest stay wins when two overlap the window', () async {
      // Out for coffee and back again. The one that began nearest the
      // scheduled time is the one a person would point at.
      await addEvent(placeId: gym, timeOfDay: 7 * 60);
      await visit(gym, at(5, 30), at(6));
      await visit(gym, at(6, 55), at(8));

      expect((await only()).arrivedAt, at(6, 55));
    });

    test('a stay that began yesterday still counts this morning', () async {
      await addEvent(placeId: office, timeOfDay: 30, title: 'Night shift');
      await visit(office, DateTime(2026, 9, 10, 23, 30), at(6));

      expect((await only()).arrivedAt, DateTime(2026, 9, 10, 23, 30));
    });
  });

  group('a row written from a visit', () {
    test('is matched to its own stay outright', () async {
      // Nothing to infer: the row exists because of that visit.
      final visitId = await db.placesDao.recordArrival(gym, at(10));
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
        at: at(10),
      );

      final occurrence = await only();
      expect(occurrence.isVisitRecord, isTrue);
      expect(occurrence.visit?.id, visitId);
      expect(occurrence.arrivedAt, at(10));
    });
  });

  group('the pure matcher', () {
    Occurrence occurrenceAt(int timeOfDay, {int? placeId, int? fromVisitId}) =>
        Occurrence(
          event: Event(
            id: 1,
            title: 'Gym',
            colorValue: 1,
            placeId: placeId,
            fromVisitId: fromVisitId,
            rule: EventRule(
              recurrence: Recurrence.daily,
              startDate: today,
              timeOfDay: timeOfDay,
            ),
          ),
          date: today,
          effectiveTimeOfDay: timeOfDay,
        );

    test('picks nothing out of an empty list', () {
      expect(visitForOccurrence(occurrenceAt(420, placeId: 1), const []),
          isNull);
    });

    test('honours a narrowed grace', () {
      final stay = Visit(id: 1, placeId: 1, arrivedAt: at(8));
      expect(
        visitForOccurrence(occurrenceAt(420, placeId: 1), [stay]),
        isNotNull,
        reason: 'an hour late is inside the default two',
      );
      expect(
        visitForOccurrence(
          occurrenceAt(420, placeId: 1),
          [stay],
          grace: const Duration(minutes: 30),
        ),
        isNull,
      );
    });

    test('a visit record with a missing stay resolves to nothing', () {
      // Rather than falling back to matching by time, which would attach the
      // wrong stay to a row that names exactly one.
      final other = Visit(id: 9, placeId: 1, arrivedAt: at(7));
      expect(
        visitForOccurrence(
          occurrenceAt(420, placeId: 1, fromVisitId: 4),
          [other],
        ),
        isNull,
      );
    });

    test('withVisits leaves placeless occurrences untouched', () {
      final plain = occurrenceAt(420);
      final result = withVisits(
        [plain],
        [Visit(id: 1, placeId: 1, arrivedAt: at(7))],
      );
      expect(identical(result.single, plain), isTrue);
    });
  });
}
