import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/db/debug_seed.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/event.dart';
import 'package:dayline/src/model/occurrence.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  late DaylineDatabase db;

  setUp(() {
    db = DaylineDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<int> addEvent({
    required String title,
    required Recurrence recurrence,
    required CalendarDate startDate,
    int timeOfDay = 9 * 60,
    CalendarDate? endDate,
    int daysOfWeek = Weekdays.none,
    int interval = 1,
    int? dayOfMonth,
    List<int> leadMinutes = const [],
    bool isActive = true,
  }) =>
      db.eventsDao.insertEvent(EventsCompanion.insert(
        title: title,
        colorValue: 0xFF3B82F6,
        timeOfDay: timeOfDay,
        recurrence: recurrence,
        startDate: startDate,
        endDate: Value(endDate),
        daysOfWeek: Value(daysOfWeek),
        interval: Value(interval),
        dayOfMonth: Value(dayOfMonth),
        leadMinutes: Value(leadMinutes),
        isActive: Value(isActive),
      ));

  group('round tripping', () {
    test('a rule survives the database unchanged', () async {
      final id = await addEvent(
        title: 'Dance class',
        recurrence: Recurrence.weekly,
        startDate: const CalendarDate(2026, 9, 1),
        endDate: const CalendarDate(2027, 6, 30),
        timeOfDay: 17 * 60,
        daysOfWeek: Weekdays.saturday,
        leadMinutes: const [60, 10],
      );

      final event = await db.eventsDao.eventById(id);
      expect(event, isNotNull);
      expect(event!.title, 'Dance class');
      expect(event.timeOfDay, 1020);
      expect(event.recurrence, Recurrence.weekly);
      expect(event.rule.daysOfWeek, Weekdays.saturday);
      expect(event.leadMinutes, [60, 10]);
      expect(event.startDate, const CalendarDate(2026, 9, 1));
      expect(event.endDate, const CalendarDate(2027, 6, 30));
    });

    test('dates are stored as epoch days, not instants', () async {
      // The guard against someone "helpfully" switching to a DateTimeColumn:
      // the raw column must be a plain integer day number.
      await addEvent(
        title: 'Gym',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 11),
      );
      final raw = await db
          .customSelect('SELECT start_date FROM events LIMIT 1')
          .getSingle();
      expect(raw.data['start_date'], 20707);
    });

    test('deleting an event takes its completions and overrides with it',
        () async {
      final id = await addEvent(
        title: 'Gym',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
      );
      const date = CalendarDate(2026, 9, 11);
      await db.eventsDao.setCompletion(
        eventId: id,
        date: date,
        status: CompletionStatus.done,
      );
      await db.eventsDao.setOverride(const EventOverride(
        eventId: 1,
        date: date,
        type: OverrideType.moved,
        newTimeOfDay: 600,
      ));

      await db.eventsDao.deleteEvent(id);

      expect(await db.select(db.completions).get(), isEmpty);
      expect(await db.select(db.overrides).get(), isEmpty);
    });
  });

  group('occurrencesForDate', () {
    test('returns only the rules that actually fall on the date', () async {
      await addEvent(
        title: 'Gym',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
        timeOfDay: 7 * 60,
      );
      await addEvent(
        title: 'Dance class',
        recurrence: Recurrence.weekly,
        startDate: const CalendarDate(2026, 9, 1),
        timeOfDay: 17 * 60,
        daysOfWeek: Weekdays.saturday,
      );
      await addEvent(
        title: 'Rent',
        recurrence: Recurrence.monthly,
        startDate: const CalendarDate(2026, 9, 1),
        timeOfDay: 10 * 60,
        dayOfMonth: 1,
      );

      // 2026-09-11 is a Friday: gym only.
      final friday =
          await db.eventsDao.occurrencesForDate(const CalendarDate(2026, 9, 11));
      expect(friday.map((o) => o.event.title), ['Gym']);

      // 2026-09-12 is a Saturday: gym, then dance.
      final saturday =
          await db.eventsDao.occurrencesForDate(const CalendarDate(2026, 9, 12));
      expect(saturday.map((o) => o.event.title), ['Gym', 'Dance class']);

      // The 1st: rent joins, sorted by time.
      final first =
          await db.eventsDao.occurrencesForDate(const CalendarDate(2026, 10, 1));
      expect(first.map((o) => o.event.title), ['Gym', 'Rent']);
    });

    test('sorts by effective time, then title, then id', () async {
      await addEvent(
        title: 'Zebra',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
        timeOfDay: 9 * 60,
      );
      await addEvent(
        title: 'apple',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
        timeOfDay: 9 * 60,
      );
      await addEvent(
        title: 'Early',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
        timeOfDay: 6 * 60,
      );

      final day =
          await db.eventsDao.occurrencesForDate(const CalendarDate(2026, 9, 11));
      expect(day.map((o) => o.event.title), ['Early', 'apple', 'Zebra']);
    });

    test('inactive rules are invisible', () async {
      await addEvent(
        title: 'Paused',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
        isActive: false,
      );
      expect(
        await db.eventsDao.occurrencesForDate(const CalendarDate(2026, 9, 11)),
        isEmpty,
      );
    });

    test('an end date closes the series, inclusively', () async {
      await addEvent(
        title: 'Course',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
        endDate: const CalendarDate(2026, 9, 11),
      );
      expect(
        await db.eventsDao.occurrencesForDate(const CalendarDate(2026, 9, 11)),
        hasLength(1),
      );
      expect(
        await db.eventsDao.occurrencesForDate(const CalendarDate(2026, 9, 12)),
        isEmpty,
      );
    });

    test('a SKIP override removes that one day only', () async {
      final id = await addEvent(
        title: 'Gym',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
      );
      await db.eventsDao.setOverride(EventOverride(
        eventId: id,
        date: const CalendarDate(2026, 9, 11),
        type: OverrideType.skip,
      ));

      expect(
        await db.eventsDao.occurrencesForDate(const CalendarDate(2026, 9, 11)),
        isEmpty,
      );
      expect(
        await db.eventsDao.occurrencesForDate(const CalendarDate(2026, 9, 12)),
        hasLength(1),
      );
    });

    test('a MOVED override changes the time and the sort position', () async {
      final gym = await addEvent(
        title: 'Gym',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
        timeOfDay: 7 * 60,
      );
      await addEvent(
        title: 'Standup',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
        timeOfDay: 10 * 60,
      );

      const date = CalendarDate(2026, 9, 11);
      await db.eventsDao.setOverride(const EventOverride(
        eventId: 1,
        date: date,
        type: OverrideType.moved,
        newTimeOfDay: 20 * 60,
      ));
      expect(gym, 1);

      final day = await db.eventsDao.occurrencesForDate(date);
      expect(day.map((o) => o.event.title), ['Standup', 'Gym']);

      final moved = day.last;
      expect(moved.effectiveTimeOfDay, 20 * 60);
      expect(moved.scheduledTimeOfDay, 7 * 60,
          reason: 'the original time is still shown struck through');
      expect(moved.isMoved, isTrue);

      // Tomorrow is untouched.
      final tomorrow =
          await db.eventsDao.occurrencesForDate(const CalendarDate(2026, 9, 12));
      expect(tomorrow.first.effectiveTimeOfDay, 7 * 60);
      expect(tomorrow.first.isMoved, isFalse);
    });

    test('completions are joined onto the right day and nowhere else',
        () async {
      final id = await addEvent(
        title: 'Gym',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
      );
      final at = DateTime(2026, 9, 11, 7, 42);
      await db.eventsDao.setCompletion(
        eventId: id,
        date: const CalendarDate(2026, 9, 11),
        status: CompletionStatus.done,
        at: at,
      );

      final done =
          await db.eventsDao.occurrencesForDate(const CalendarDate(2026, 9, 11));
      expect(done.single.isDone, isTrue);
      expect(done.single.completedAt, at);

      final pending =
          await db.eventsDao.occurrencesForDate(const CalendarDate(2026, 9, 12));
      expect(pending.single.isPending, isTrue);
      expect(pending.single.status, isNull);
    });

    test('re-marking overwrites, and clearing returns to pending', () async {
      final id = await addEvent(
        title: 'Gym',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
      );
      const date = CalendarDate(2026, 9, 11);

      await db.eventsDao.setCompletion(
          eventId: id, date: date, status: CompletionStatus.done);
      await db.eventsDao.setCompletion(
          eventId: id, date: date, status: CompletionStatus.skipped);

      var day = await db.eventsDao.occurrencesForDate(date);
      expect(day.single.status, CompletionStatus.skipped);
      expect(await db.select(db.completions).get(), hasLength(1),
          reason: 'one row per occurrence, not one per tap');

      await db.eventsDao.clearCompletion(id, date);
      day = await db.eventsDao.occurrencesForDate(date);
      expect(day.single.isPending, isTrue);
    });

    test('an empty day is empty, not an error', () async {
      expect(
        await db.eventsDao.occurrencesForDate(const CalendarDate(2026, 9, 11)),
        isEmpty,
      );
    });

    test('no occurrence rows are ever written', () async {
      await addEvent(
        title: 'Gym',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2020, 1, 1),
      );
      // Read two years of days; the database must not grow by a single row.
      for (var i = 0; i < 730; i++) {
        await db.eventsDao
            .occurrencesForDate(const CalendarDate(2026, 1, 1).addDays(i));
      }
      expect(await db.select(db.events).get(), hasLength(1));
      expect(await db.select(db.completions).get(), isEmpty);
      expect(await db.select(db.overrides).get(), isEmpty);
    });
  });

  group('watchOccurrencesForDate', () {
    test('re-emits when the day changes', () async {
      final id = await addEvent(
        title: 'Gym',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
      );
      const date = CalendarDate(2026, 9, 11);

      final emissions = <List<Occurrence>>[];
      final sub =
          db.eventsDao.watchOccurrencesForDate(date).listen(emissions.add);
      addTearDown(sub.cancel);

      await _settle();
      expect(emissions, hasLength(1));
      expect(emissions.last.single.isPending, isTrue);

      await db.eventsDao.setCompletion(
          eventId: id, date: date, status: CompletionStatus.done);
      await _settle();
      expect(emissions.last.single.isDone, isTrue);

      // A change on a different day still re-queries, but the result for this
      // day is unchanged — correctness first, cleverness later.
      await db.eventsDao.setCompletion(
          eventId: id,
          date: const CalendarDate(2026, 9, 12),
          status: CompletionStatus.done);
      await _settle();
      expect(emissions.last.single.isDone, isTrue);
    });

    test('stops emitting once cancelled, and cancelling actually completes',
        () async {
      final id = await addEvent(
        title: 'Gym',
        recurrence: Recurrence.daily,
        startDate: const CalendarDate(2026, 9, 1),
      );
      const date = CalendarDate(2026, 9, 11);

      var emissions = 0;
      final sub = db.eventsDao
          .watchOccurrencesForDate(date)
          .listen((_) => emissions++);
      await _settle();
      expect(emissions, 1);

      // The Today screen cancels one of these every time the user scrubs to
      // another day, so a cancel that never completes is a leak per swipe.
      await sub.cancel().timeout(
            const Duration(seconds: 2),
            onTimeout: () => fail('cancel() hung'),
          );

      await db.eventsDao.setCompletion(
          eventId: id, date: date, status: CompletionStatus.done);
      await _settle();
      expect(emissions, 1, reason: 'emitted after cancellation');
    });
  });

  group('debug seed', () {
    test('produces the sample day from the spec', () async {
      // A Friday, so the seed's "next Tuesday" dentist is unambiguous.
      const today = CalendarDate(2026, 9, 11);
      await DebugSeed.populate(db, today: today);

      final all = await db.eventsDao.allEvents();
      expect(all.map((e) => e.title).toSet(), {
        'Gym',
        'Dance class',
        'Water the plants',
        'Rent',
        'Dentist',
      });

      final friday = await db.eventsDao.occurrencesForDate(today);
      expect(friday.map((o) => o.event.title), ['Gym', 'Water the plants']);

      // Saturday adds the dance class.
      final saturday =
          await db.eventsDao.occurrencesForDate(today.addDays(1));
      expect(saturday.map((o) => o.event.title), ['Gym', 'Dance class']);

      // Tuesday the 15th is the dentist.
      final tuesday = await db.eventsDao.occurrencesForDate(
          const CalendarDate(2026, 9, 15));
      expect(tuesday.map((o) => o.event.title), contains('Dentist'));

      // The 1st of next month is rent.
      final rentDay = await db.eventsDao.occurrencesForDate(
          const CalendarDate(2026, 10, 1));
      expect(rentDay.map((o) => o.event.title), contains('Rent'));

      // Lead reminders survived the JSON round trip.
      final dance = all.firstWhere((e) => e.title == 'Dance class');
      expect(dance.leadMinutes, [60, 10]);
    });

    test('is idempotent', () async {
      await DebugSeed.populate(db, today: const CalendarDate(2026, 9, 11));
      await DebugSeed.populate(db, today: const CalendarDate(2026, 9, 11));
      expect(await db.eventsDao.allEvents(), hasLength(5));
    });
  });
}

/// Lets the watch stream's queued re-query run to completion.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));
