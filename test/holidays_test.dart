import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/event.dart';
import 'package:dayline/src/model/holiday.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Days that do not happen, and what they take with them.
///
/// The rule the whole thing turns on: a holiday closes a *timetable*, not a
/// day. An event with no timetable goes on happening — medication is still
/// medication on Christmas Day — and an app that quietly cancelled it because
/// the office was shut would be dangerous rather than clever.
void main() {
  // A Friday.
  const today = CalendarDate(2026, 9, 11);

  late DaylineDatabase db;

  setUp(() {
    db = DaylineDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<int> addEvent({
    required String title,
    HolidayScope? scope,
    int timeOfDay = 8 * 60,
    Recurrence recurrence = Recurrence.daily,
    CalendarDate? startDate,
  }) =>
      db.eventsDao.insertEvent(EventsCompanion.insert(
        title: title,
        colorValue: 1,
        timeOfDay: timeOfDay,
        recurrence: recurrence,
        startDate: startDate ?? today.addDays(-30),
        holidayScope: Value(scope),
      ));

  Future<int> addHoliday({
    String name = 'Bank holiday',
    CalendarDate? from,
    CalendarDate? to,
    int scopes = HolidayScopes.everything,
  }) =>
      db.holidaysDao.insertHoliday(HolidaysCompanion.insert(
        name: name,
        startDate: from ?? today,
        endDate: to ?? from ?? today,
        scopes: Value(scopes),
      ));

  Future<List<String>> titlesOn(CalendarDate date) async =>
      (await db.eventsDao.occurrencesForDate(date))
          .map((o) => o.event.title)
          .toList();

  group('what a holiday takes off the day', () {
    test('everything on a closed timetable', () async {
      await addEvent(title: 'School run', scope: HolidayScope.school);
      await addEvent(title: 'Standup', scope: HolidayScope.work);
      await addHoliday();

      expect(await titlesOn(today), isEmpty);
    });

    test('and nothing else', () async {
      // The point of the whole design.
      await addEvent(title: 'School run', scope: HolidayScope.school);
      await addEvent(title: 'Medication');
      await addHoliday();

      expect(await titlesOn(today), ['Medication']);
    });

    test('only the timetable it actually closes', () async {
      // Half-term is not a day off work.
      await addEvent(title: 'School run', scope: HolidayScope.school);
      await addEvent(title: 'Standup', scope: HolidayScope.work);
      await addHoliday(name: 'Half-term', scopes: HolidayScopes.school);

      expect(await titlesOn(today), ['Standup']);
    });

    test('and the other way round', () async {
      await addEvent(title: 'School run', scope: HolidayScope.school);
      await addEvent(title: 'Standup', scope: HolidayScope.work);
      await addHoliday(name: 'Annual leave', scopes: HolidayScopes.work);

      expect(await titlesOn(today), ['School run']);
    });

    test('nothing at all on a day it does not cover', () async {
      await addEvent(title: 'Standup', scope: HolidayScope.work);
      await addHoliday(from: today);

      expect(await titlesOn(today.addDays(1)), ['Standup']);
      expect(await titlesOn(today.addDays(-1)), ['Standup']);
    });
  });

  group('a run of days', () {
    test('covers every day from start to end, inclusive', () async {
      await addEvent(title: 'Standup', scope: HolidayScope.work);
      await addHoliday(
        name: 'Week off',
        from: today,
        to: today.addDays(4),
      );

      for (var i = 0; i <= 4; i++) {
        expect(await titlesOn(today.addDays(i)), isEmpty, reason: 'day $i');
      }
      expect(await titlesOn(today.addDays(5)), ['Standup']);
    });

    test('a single day is a range whose ends are equal', () async {
      final id = await addHoliday();
      final holiday = (await db.holidaysDao.holidayById(id))!;

      expect(holiday.isSingleDay, isTrue);
      expect(holiday.days, 1);
      expect(holiday.covers(today), isTrue);
      expect(holiday.covers(today.addDays(1)), isFalse);
    });

    test('counts its own length', () async {
      final id = await addHoliday(from: today, to: today.addDays(6));
      expect((await db.holidaysDao.holidayById(id))!.days, 7);
    });
  });

  group('overlapping holidays', () {
    test('two on one day close the union of what they close', () async {
      await addEvent(title: 'School run', scope: HolidayScope.school);
      await addEvent(title: 'Standup', scope: HolidayScope.work);
      await addHoliday(name: 'Half-term', scopes: HolidayScopes.school);
      await addHoliday(name: 'Leave', scopes: HolidayScopes.work);

      expect(await titlesOn(today), isEmpty);
      expect(
        scopesClosedOn(await db.holidaysDao.allHolidays(), today),
        {HolidayScope.work, HolidayScope.school},
      );
    });

    test('the same day covered twice is still closed exactly once', () async {
      await addEvent(title: 'Standup', scope: HolidayScope.work);
      await addHoliday(name: 'Bank holiday');
      await addHoliday(name: 'Bank holiday');

      expect(await titlesOn(today), isEmpty);
      expect(holidaysOn(await db.holidaysDao.allHolidays(), today),
          hasLength(2));
    });
  });

  group('what it leaves alone', () {
    test('a completion already recorded against a paused day', () async {
      // The row vanishes from the day, but the history is not rewritten: the
      // user did do it, on a day that later turned out to be a holiday.
      final id = await addEvent(title: 'Standup', scope: HolidayScope.work);
      await db.eventsDao.setCompletion(
        eventId: id,
        date: today,
        status: CompletionStatus.done,
      );
      await addHoliday();

      expect(await titlesOn(today), isEmpty);
      expect(await db.select(db.completions).get(), hasLength(1));
    });

    test('the rule itself, which is untouched', () async {
      final id = await addEvent(title: 'Standup', scope: HolidayScope.work);
      await addHoliday();

      final event = (await db.eventsDao.eventById(id))!;
      expect(event.isActive, isTrue);
      expect(event.holidayScope, HolidayScope.work);
    });

    test('deleting the holiday brings the day back', () async {
      await addEvent(title: 'Standup', scope: HolidayScope.work);
      final id = await addHoliday();
      expect(await titlesOn(today), isEmpty);

      await db.holidaysDao.deleteHoliday(id);

      expect(await titlesOn(today), ['Standup']);
    });

    test('a one-off on a paused day is hidden, not destroyed', () async {
      await addEvent(
        title: 'Appraisal',
        scope: HolidayScope.work,
        recurrence: Recurrence.once,
        startDate: today,
      );
      final id = await addHoliday();

      expect(await titlesOn(today), isEmpty);
      await db.holidaysDao.deleteHoliday(id);
      expect(await titlesOn(today), ['Appraisal']);
    });
  });

  group('the query', () {
    test('finds a holiday that began before the window', () async {
      await addHoliday(name: 'Week off', from: today, to: today.addDays(6));

      final found = await db.holidaysDao.holidaysBetween(
        today.addDays(3),
        today.addDays(3),
      );
      expect(found.single.name, 'Week off');
    });

    test('does not find one that ended before it', () async {
      await addHoliday(from: today.addDays(-5), to: today.addDays(-1));

      expect(await db.holidaysDao.holidaysOnDate(today), isEmpty);
    });

    test('does not find one that starts after it', () async {
      await addHoliday(from: today.addDays(1));

      expect(await db.holidaysDao.holidaysOnDate(today), isEmpty);
    });

    test('lists soonest first', () async {
      await addHoliday(name: 'Later', from: today.addDays(10));
      await addHoliday(name: 'Sooner', from: today.addDays(2));

      expect(
        (await db.holidaysDao.allHolidays()).map((h) => h.name),
        ['Sooner', 'Later'],
      );
    });
  });

  group('the scopes mask', () {
    test('round trips through a set', () {
      expect(HolidayScopes.of([HolidayScope.work]), HolidayScopes.work);
      expect(
        HolidayScopes.of(HolidayScope.values),
        HolidayScopes.everything,
      );
      expect(
        HolidayScopes.from(HolidayScopes.everything),
        [HolidayScope.work, HolidayScope.school],
      );
      expect(HolidayScopes.from(HolidayScopes.none), isEmpty);
    });

    test('a holiday closing nothing pauses nothing', () async {
      // Reachable only through a hand-edited backup — the editor refuses to
      // save one — but it must not take the day down with it.
      await addEvent(title: 'Standup', scope: HolidayScope.work);
      await addHoliday(scopes: HolidayScopes.none);

      expect(await titlesOn(today), ['Standup']);
    });

    test('an unknown scope code does not pause anything', () {
      expect(HolidayScope.fromCode(99), isNull);
    });
  });

  group('the pure decision', () {
    final bankHoliday = Holiday(
      id: 1,
      name: 'Bank holiday',
      startDate: today,
      endDate: today,
    );

    test('no scope is never paused', () {
      expect(pausedByHoliday(null, [bankHoliday], today), isFalse);
    });

    test('a matching scope on a covered day is paused', () {
      expect(
        pausedByHoliday(HolidayScope.work, [bankHoliday], today),
        isTrue,
      );
    });

    test('an uncovered day is not', () {
      expect(
        pausedByHoliday(HolidayScope.work, [bankHoliday], today.addDays(1)),
        isFalse,
      );
    });

    test('no holidays at all is not', () {
      expect(pausedByHoliday(HolidayScope.work, const [], today), isFalse);
    });
  });
}
