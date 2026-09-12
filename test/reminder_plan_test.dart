import 'package:dayline/src/model/calendar_date.dart';
import 'package:dayline/src/model/event.dart';
import 'package:dayline/src/model/recurrence.dart';
import 'package:dayline/src/notifications/reminder_plan.dart';
import 'package:test/test.dart';

void main() {
  // A Friday morning.
  final now = DateTime(2026, 9, 11, 8, 42);
  const today = CalendarDate(2026, 9, 11);

  var nextId = 1;
  Event event({
    required Recurrence recurrence,
    required int timeOfDay,
    List<int> leadMinutes = const [15],
    int daysOfWeek = Weekdays.none,
    int interval = 1,
    int? dayOfMonth,
    CalendarDate? startDate,
    CalendarDate? endDate,
    bool isActive = true,
    String? title,
  }) {
    final id = nextId++;
    return Event(
      id: id,
      title: title ?? 'Event $id',
      colorValue: 0xFF3B82F6,
      leadMinutes: leadMinutes,
      rule: EventRule(
        recurrence: recurrence,
        timeOfDay: timeOfDay,
        startDate: startDate ?? today.addDays(-30),
        endDate: endDate,
        daysOfWeek: daysOfWeek,
        interval: interval,
        dayOfMonth: dayOfMonth,
        isActive: isActive,
      ),
    );
  }

  setUp(() => nextId = 1);

  group('repeating triggers', () {
    test('a daily rule costs one slot per lead, however long it runs', () {
      final plan = planReminders(
        events: [
          event(
            recurrence: Recurrence.daily,
            timeOfDay: 7 * 60,
            leadMinutes: const [60, 15],
          ),
        ],
        now: now,
      );

      expect(plan.reminders, hasLength(2));
      expect(
        plan.reminders.every((r) => r.trigger == ReminderTrigger.everyDay),
        isTrue,
      );
      expect(plan.dropped, 0);
    });

    test('the first fire is the next one still ahead of now', () {
      final plan = planReminders(
        events: [
          event(
            recurrence: Recurrence.daily,
            timeOfDay: 7 * 60,
            leadMinutes: const [15],
          ),
        ],
        now: now,
      );

      // 06:45 today has gone, so it starts tomorrow.
      expect(plan.reminders.single.fireAt, DateTime(2026, 9, 12, 6, 45));
    });

    test('a weekly rule costs one slot per selected day per lead', () {
      final plan = planReminders(
        events: [
          event(
            recurrence: Recurrence.weekly,
            timeOfDay: 17 * 60,
            daysOfWeek: Weekdays.maskOf(
                [DateTime.monday, DateTime.wednesday, DateTime.friday]),
            leadMinutes: const [60, 10],
          ),
        ],
        now: now,
      );

      expect(plan.reminders, hasLength(6));
      expect(
        plan.reminders.every((r) => r.trigger == ReminderTrigger.everyWeek),
        isTrue,
      );
      expect(
        plan.reminders.map((r) => r.weekday).toSet(),
        {DateTime.monday, DateTime.wednesday, DateTime.friday},
      );
    });

    test('a weekly rule on all seven days collapses to a daily trigger', () {
      // Seven weekly slots for what one daily slot covers is six slots wasted.
      final plan = planReminders(
        events: [
          event(
            recurrence: Recurrence.weekly,
            timeOfDay: 7 * 60,
            daysOfWeek: Weekdays.everyDay,
            leadMinutes: const [15],
          ),
        ],
        now: now,
      );

      expect(plan.reminders, hasLength(1));
      expect(plan.reminders.single.trigger, ReminderTrigger.everyDay);
    });

    test('a rule with an end date cannot repeat forever', () {
      final plan = planReminders(
        events: [
          event(
            recurrence: Recurrence.daily,
            timeOfDay: 7 * 60,
            endDate: today.addDays(3),
            leadMinutes: const [15],
          ),
        ],
        now: now,
      );

      expect(
        plan.reminders.every((r) => r.trigger == ReminderTrigger.exact),
        isTrue,
        reason: 'a repeating trigger would keep firing past the end date',
      );
      // Tomorrow through to the end date; today's 06:45 has already gone.
      expect(plan.reminders, hasLength(3));
    });
  });

  group('leads that cross midnight', () {
    test('a daily reminder before midnight is still daily', () {
      final plan = planReminders(
        events: [
          event(
            recurrence: Recurrence.daily,
            timeOfDay: 30, // 00:30
            leadMinutes: const [60],
          ),
        ],
        now: now,
      );

      final reminder = plan.reminders.single;
      expect(reminder.trigger, ReminderTrigger.everyDay);
      expect(reminder.fireMinuteOfDay, 23 * 60 + 30, reason: '23:30');
    });

    test('a weekly reminder before midnight moves to the previous weekday', () {
      // A Monday 00:30 event reminded an hour ahead fires on Sunday.
      final plan = planReminders(
        events: [
          event(
            recurrence: Recurrence.weekly,
            timeOfDay: 30,
            daysOfWeek: Weekdays.monday,
            leadMinutes: const [60],
          ),
        ],
        now: now,
      );

      final reminder = plan.reminders.single;
      expect(reminder.weekday, DateTime.sunday);
      expect(reminder.fireMinuteOfDay, 23 * 60 + 30);
      expect(reminder.fireAt.weekday, DateTime.sunday);
    });

    test('a windowed reminder a day ahead lands on the day before', () {
      final plan = planReminders(
        events: [
          event(
            recurrence: Recurrence.monthly,
            timeOfDay: 10 * 60,
            dayOfMonth: 20,
            leadMinutes: const [1440],
          ),
        ],
        now: now,
      );

      expect(plan.reminders.single.fireAt, DateTime(2026, 9, 19, 10, 0));
      expect(plan.reminders.single.occurrenceDate,
          const CalendarDate(2026, 9, 20),
          reason: 'the reminder belongs to the occurrence, not to its own day');
    });
  });

  group('the rolling window', () {
    test('every-N-days is expanded, not repeated', () {
      final plan = planReminders(
        events: [
          event(
            recurrence: Recurrence.everyNDays,
            timeOfDay: 9 * 60,
            interval: 3,
            startDate: today,
            leadMinutes: const [0],
          ),
        ],
        now: now,
        horizonDays: 14,
      );

      expect(
        plan.reminders.every((r) => r.trigger == ReminderTrigger.exact),
        isTrue,
      );
      // Today 09:00 is still ahead, then every third day to the horizon.
      expect(
        plan.reminders.map((r) => r.occurrenceDate.toString()),
        [
          '2026-09-11',
          '2026-09-14',
          '2026-09-17',
          '2026-09-20',
          '2026-09-23',
        ],
      );
    });

    test('nothing is scheduled beyond the horizon', () {
      final plan = planReminders(
        events: [
          event(
            recurrence: Recurrence.once,
            timeOfDay: 14 * 60,
            startDate: today.addDays(20),
          ),
        ],
        now: now,
        horizonDays: 14,
      );

      expect(plan.reminders, isEmpty,
          reason: 'the next resume will pick it up once it is near enough');
    });

    test('a moment that has already passed is not scheduled', () {
      final plan = planReminders(
        events: [
          event(
            recurrence: Recurrence.once,
            timeOfDay: 7 * 60, // 07:00 today, already gone at 08:42
            startDate: today,
            leadMinutes: const [0],
          ),
        ],
        now: now,
      );

      expect(plan.reminders, isEmpty);
    });
  });

  group('overrides', () {
    test('a skipped day is dropped, and the rule stops repeating', () {
      final gym = event(
        recurrence: Recurrence.daily,
        timeOfDay: 7 * 60,
        leadMinutes: const [0],
      );

      final plan = planReminders(
        events: [gym],
        now: now,
        exceptions: {
          gym.id: [
            OccurrenceException(date: today.addDays(2)),
          ],
        },
        horizonDays: 5,
      );

      // A repeating trigger has no way to know one day was skipped, so the
      // whole window falls back to exact slots.
      expect(
        plan.reminders.every((r) => r.trigger == ReminderTrigger.exact),
        isTrue,
      );
      expect(
        plan.reminders.map((r) => r.occurrenceDate.toString()),
        ['2026-09-12', '2026-09-14', '2026-09-15', '2026-09-16'],
        reason: 'the 13th was skipped',
      );
    });

    test('a moved occurrence is reminded at its new time', () {
      final gym = event(
        recurrence: Recurrence.daily,
        timeOfDay: 7 * 60,
        leadMinutes: const [0],
      );

      final plan = planReminders(
        events: [gym],
        now: now,
        exceptions: {
          gym.id: [
            OccurrenceException(
              date: today.addDays(1),
              newTimeOfDay: 20 * 60,
            ),
          ],
        },
        horizonDays: 2,
      );

      final moved = plan.reminders
          .firstWhere((r) => r.occurrenceDate == today.addDays(1));
      expect(moved.fireAt, DateTime(2026, 9, 12, 20, 0));
      expect(moved.body, contains('20:00'));
    });

    test('an exception outside the window does not disturb the repeat', () {
      final gym = event(
        recurrence: Recurrence.daily,
        timeOfDay: 7 * 60,
        leadMinutes: const [0],
      );

      final plan = planReminders(
        events: [gym],
        now: now,
        exceptions: {
          gym.id: [OccurrenceException(date: today.addDays(60))],
        },
        horizonDays: 14,
      );

      expect(plan.reminders.single.trigger, ReminderTrigger.everyDay);
    });
  });

  group('the budget', () {
    test('is never exceeded', () {
      final events = [
        for (var i = 0; i < 40; i++)
          event(
            recurrence: Recurrence.everyNDays,
            timeOfDay: 9 * 60,
            interval: 1,
            startDate: today,
            leadMinutes: const [30, 10],
          ),
      ];

      final plan = planReminders(events: events, now: now, budget: 60);

      expect(plan.reminders, hasLength(60));
      expect(plan.dropped, greaterThan(0));
      expect(plan.reminders.map((r) => r.id).toSet(), hasLength(60),
          reason: 'ids must be unique or slots overwrite each other');
    });

    test('a repeating trigger survives a flood of sooner one-offs', () {
      // The daily gym reminder is tomorrow morning; thirty one-off reminders
      // all fire tonight. Purely by fire time the gym trigger loses, and with
      // it every future gym reminder — so repeating slots are claimed first.
      final gym = event(
        recurrence: Recurrence.daily,
        timeOfDay: 7 * 60,
        leadMinutes: const [0],
        title: 'Gym',
      );
      final noise = [
        for (var i = 0; i < 30; i++)
          event(
            recurrence: Recurrence.everyNDays,
            timeOfDay: 23 * 60,
            interval: 1,
            startDate: today,
            leadMinutes: const [0],
          ),
      ];

      final plan =
          planReminders(events: [...noise, gym], now: now, budget: 10);

      expect(plan.reminders, hasLength(10));
      expect(
        plan.reminders.any((r) => r.eventId == gym.id),
        isTrue,
        reason: 'one forever-trigger is worth more than one extra one-off',
      );
      // The exact slots that did fit are the nearest ones.
      final exact = plan.reminders
          .where((r) => r.trigger == ReminderTrigger.exact)
          .map((r) => r.fireAt)
          .toList();
      expect(exact, orderedEquals(List.of(exact)..sort()));
      expect(plan.reminders, hasLength(10));
    });

    test('a realistic household stays far inside the iOS limit', () {
      final plan = planReminders(
        events: [
          event(
            recurrence: Recurrence.daily,
            timeOfDay: 7 * 60,
            leadMinutes: const [15],
            title: 'Gym',
          ),
          event(
            recurrence: Recurrence.weekly,
            timeOfDay: 17 * 60,
            daysOfWeek: Weekdays.saturday,
            leadMinutes: const [60, 10],
            title: 'Dance class',
          ),
          event(
            recurrence: Recurrence.everyNDays,
            timeOfDay: 9 * 60,
            interval: 3,
            startDate: today,
            leadMinutes: const [0],
            title: 'Water the plants',
          ),
          event(
            recurrence: Recurrence.monthly,
            timeOfDay: 10 * 60,
            dayOfMonth: 1,
            leadMinutes: const [1440],
            title: 'Rent',
          ),
          event(
            recurrence: Recurrence.once,
            timeOfDay: 14 * 60 + 30,
            startDate: today.addDays(4),
            leadMinutes: const [120, 15],
            title: 'Dentist',
          ),
        ],
        now: now,
      );

      expect(plan.dropped, 0);
      expect(plan.length, lessThan(20),
          reason: 'the whole point is not to go near 64');
    });
  });

  group('what is left out', () {
    test('inactive rules', () {
      final plan = planReminders(
        events: [
          event(
            recurrence: Recurrence.daily,
            timeOfDay: 7 * 60,
            isActive: false,
          ),
        ],
        now: now,
      );
      expect(plan.reminders, isEmpty);
    });

    test('rules with no reminders set', () {
      final plan = planReminders(
        events: [
          event(
            recurrence: Recurrence.daily,
            timeOfDay: 7 * 60,
            leadMinutes: const [],
          ),
        ],
        now: now,
      );
      expect(plan.reminders, isEmpty);
    });
  });

  group('notification text', () {
    test('reads as a countdown', () {
      expect(reminderBody(7 * 60, 0), 'Now · 07:00');
      expect(reminderBody(7 * 60, 15), 'In 15 minutes · 07:00');
      expect(reminderBody(7 * 60, 60), 'In 1 hour · 07:00');
      expect(reminderBody(7 * 60, 120), 'In 2 hours · 07:00');
      expect(reminderBody(7 * 60, 90), 'In 1h 30m · 07:00');
      expect(reminderBody(10 * 60, 1440), 'Tomorrow · 10:00');
      expect(reminderBody(10 * 60, 2880), 'In 2 days · 10:00');
    });
  });
}
