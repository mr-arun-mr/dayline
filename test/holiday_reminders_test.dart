import 'package:dayline/src/db/database.dart';
import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/holiday.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/notifications/notification_service.dart';
import 'package:dayline/src/notifications/reminder_plan.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A holiday has to reach the alarm clock, not just the screen.
///
/// This is the half that is easy to get wrong and impossible to notice until
/// it happens: a DAILY rule becomes one native repeating trigger that fires
/// forever, and the OS knows nothing about holidays. Hiding the school run
/// from the day while the phone still sounds at 07:00 on Christmas morning
/// would be worse than not having the feature.
void main() {
  // A Friday morning.
  final now = DateTime(2026, 9, 11, 8, 42);
  const today = CalendarDate(2026, 9, 11);

  late DaylineDatabase db;

  setUp(() {
    db = DaylineDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<int> addEvent({
    required String title,
    HolidayScope? scope,
    int timeOfDay = 7 * 60,
    Recurrence recurrence = Recurrence.daily,
  }) =>
      db.eventsDao.insertEvent(EventsCompanion.insert(
        title: title,
        colorValue: 1,
        timeOfDay: timeOfDay,
        recurrence: recurrence,
        startDate: today.addDays(-30),
        leadMinutes: const Value([15]),
        holidayScope: Value(scope),
      ));

  Future<void> addHoliday({
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

  /// The plan the service would schedule, built from the database exactly as
  /// reconcile does — minus the OS call, which needs a plugin.
  Future<ReminderPlan> plan() async {
    final events = await db.eventsDao.allEvents();
    final exceptions =
        await NotificationService.loadExceptions(db, now, events);
    return planReminders(events: events, now: now, exceptions: exceptions);
  }

  Set<CalendarDate> firesFor(ReminderPlan plan, int eventId) => {
        for (final reminder in plan.reminders)
          if (reminder.eventId == eventId && reminder.occurrenceDate != null)
            reminder.occurrenceDate!,
      };

  test('a daily rule uses one repeating trigger when nothing is closed',
      () async {
    final id = await addEvent(title: 'School run', scope: HolidayScope.school);

    final result = await plan();
    final mine = result.reminders.where((r) => r.eventId == id).toList();
    expect(mine.single.trigger, ReminderTrigger.everyDay);
  });

  test('a holiday in the window drops the repeat for exact days', () async {
    // The whole point: a native repeat cannot skip Christmas, so the event
    // falls back to one slot per day and the closed day is simply not one of
    // them.
    final id = await addEvent(title: 'School run', scope: HolidayScope.school);
    await addHoliday(from: today.addDays(3));

    final result = await plan();
    final mine = result.reminders.where((r) => r.eventId == id).toList();

    expect(mine.every((r) => r.trigger == ReminderTrigger.exact), isTrue);
    expect(firesFor(result, id), isNot(contains(today.addDays(3))));
    expect(firesFor(result, id), contains(today.addDays(2)));
    expect(firesFor(result, id), contains(today.addDays(4)));
  });

  test('every day of a week off is dropped', () async {
    final id = await addEvent(title: 'Standup', scope: HolidayScope.work);
    await addHoliday(
      name: 'Week off',
      from: today.addDays(2),
      to: today.addDays(6),
      scopes: HolidayScopes.work,
    );

    final fires = firesFor(await plan(), id);
    for (var i = 2; i <= 6; i++) {
      expect(fires, isNot(contains(today.addDays(i))), reason: 'day $i');
    }
    expect(fires, contains(today.addDays(7)));
  });

  test('an event on another timetable keeps its repeating trigger', () async {
    final school =
        await addEvent(title: 'School run', scope: HolidayScope.school);
    final work = await addEvent(title: 'Standup', scope: HolidayScope.work);
    await addHoliday(name: 'Half-term', scopes: HolidayScopes.school);

    final result = await plan();
    expect(
      result.reminders.firstWhere((r) => r.eventId == work).trigger,
      ReminderTrigger.everyDay,
      reason: 'work is untouched, so it keeps its single slot',
    );
    expect(
      result.reminders.where((r) => r.eventId == school).every(
            (r) => r.trigger == ReminderTrigger.exact,
          ),
      isTrue,
    );
  });

  test('an event with no timetable is never disturbed', () async {
    final id = await addEvent(title: 'Medication');
    await addHoliday();

    final result = await plan();
    final mine = result.reminders.where((r) => r.eventId == id).toList();
    expect(mine.single.trigger, ReminderTrigger.everyDay,
        reason: 'not one slot more, and not one fewer');
  });

  test('a holiday beyond the horizon changes nothing', () async {
    final id = await addEvent(title: 'Standup', scope: HolidayScope.work);
    await addHoliday(from: today.addDays(90));

    final result = await plan();
    expect(
      result.reminders.firstWhere((r) => r.eventId == id).trigger,
      ReminderTrigger.everyDay,
    );
  });

  test('a holiday still to come today drops only today', () async {
    final id = await addEvent(
      title: 'Standup',
      scope: HolidayScope.work,
      timeOfDay: 17 * 60,
    );
    await addHoliday(from: today);

    final fires = firesFor(await plan(), id);
    expect(fires, isNot(contains(today)));
    expect(fires, contains(today.addDays(1)));
  });
}
