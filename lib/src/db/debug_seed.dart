import 'package:drift/drift.dart';

import '../model/calendar_date.dart';
import '../model/recurrence.dart';
import 'database.dart';

/// The sample day from the product spec. Debug builds only — nothing here ever
/// runs in a release build, and no seeded row is special in any way.
abstract final class DebugSeed {
  static const _blue = 0xFF3B82F6;
  static const _violet = 0xFF8B5CF6;
  static const _green = 0xFF10B981;
  static const _amber = 0xFFF59E0B;
  static const _rose = 0xFFF43F5E;

  /// Inserts the sample events, unless the database already has some.
  ///
  /// Idempotent, so a hot restart does not pile up five more copies.
  static Future<void> populate(DaylineDatabase db, {CalendarDate? today}) async {
    final existing = await db.eventsDao.allEvents();
    if (existing.isNotEmpty) return;

    final from = today ?? CalendarDate.fromDateTime(DateTime.now());
    final dao = db.eventsDao;

    await dao.insertEvent(EventsCompanion.insert(
      title: 'Gym',
      colorValue: _blue,
      timeOfDay: 7 * 60,
      recurrence: Recurrence.daily,
      startDate: from,
      durationMin: const Value(60),
      leadMinutes: const Value([15]),
    ));

    await dao.insertEvent(EventsCompanion.insert(
      title: 'Dance class',
      notes: const Value('Kid drop-off, take the bag'),
      colorValue: _violet,
      timeOfDay: 17 * 60,
      recurrence: Recurrence.weekly,
      startDate: from,
      daysOfWeek: const Value(Weekdays.saturday),
      durationMin: const Value(90),
      leadMinutes: const Value([60, 10]),
    ));

    await dao.insertEvent(EventsCompanion.insert(
      title: 'Water the plants',
      colorValue: _green,
      timeOfDay: 9 * 60,
      recurrence: Recurrence.everyNDays,
      startDate: from,
      interval: const Value(3),
    ));

    await dao.insertEvent(EventsCompanion.insert(
      title: 'Rent',
      colorValue: _amber,
      timeOfDay: 10 * 60,
      recurrence: Recurrence.monthly,
      startDate: from,
      dayOfMonth: const Value(1),
      leadMinutes: const Value([1440]),
    ));

    await dao.insertEvent(EventsCompanion.insert(
      title: 'Dentist',
      colorValue: _rose,
      timeOfDay: 14 * 60 + 30,
      recurrence: Recurrence.once,
      startDate: _nextWeekday(from, DateTime.tuesday),
      durationMin: const Value(45),
      leadMinutes: const Value([120, 15]),
    ));
  }

  /// The next [isoWeekday] strictly after [from].
  static CalendarDate _nextWeekday(CalendarDate from, int isoWeekday) {
    final delta = (isoWeekday - from.weekday + 7) % 7;
    return from.addDays(delta == 0 ? 7 : delta);
  }
}
