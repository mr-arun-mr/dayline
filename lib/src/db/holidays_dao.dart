import 'package:drift/drift.dart';

import '../model/calendar_date.dart';
import '../model/holiday.dart';
import 'database.dart';
import 'live_query.dart';
import 'tables.dart';

part 'holidays_dao.g.dart';

/// The days the user has said do not happen.
@DriftAccessor(tables: [Holidays])
class HolidaysDao extends DatabaseAccessor<DaylineDatabase>
    with _$HolidaysDaoMixin {
  HolidaysDao(super.db);

  /// Every holiday, soonest first.
  Future<List<Holiday>> allHolidays() async {
    final rows = await (select(holidays)
          ..orderBy([
            (h) => OrderingTerm(expression: h.startDate),
            (h) => OrderingTerm(expression: h.name),
          ]))
        .get();
    return rows.map(_toHoliday).toList();
  }

  /// See [liveQuery] for why this is not drift's own `.watch()`.
  Stream<List<Holiday>> watchHolidays() => liveQuery(
    updates: attachedDatabase.tableUpdates(TableUpdateQuery.onTable(holidays)),
    read: allHolidays,
  );

  Future<Holiday?> holidayById(int id) async {
    final row = await (select(holidays)..where((h) => h.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toHoliday(row);
  }

  /// The holidays covering any day in `[from, to]`.
  ///
  /// A range overlaps the window when it starts before the window ends and
  /// ends after the window begins — which is the whole of it, including the
  /// two-week holiday that began last Friday.
  Future<List<Holiday>> holidaysBetween(
    CalendarDate from,
    CalendarDate to,
  ) async {
    final rows = await (select(holidays)
          ..where((h) =>
              h.startDate.isSmallerOrEqualValue(to.epochDay) &
              h.endDate.isBiggerOrEqualValue(from.epochDay))
          ..orderBy([(h) => OrderingTerm(expression: h.startDate)]))
        .get();
    return rows.map(_toHoliday).toList();
  }

  /// The holidays covering one day.
  Future<List<Holiday>> holidaysOnDate(CalendarDate date) =>
      holidaysBetween(date, date);

  Future<int> insertHoliday(HolidaysCompanion holiday) =>
      into(holidays).insert(holiday);

  Future<bool> updateHoliday(HolidaysCompanion holiday) =>
      update(holidays).replace(holiday);

  Future<int> deleteHoliday(int id) =>
      (delete(holidays)..where((h) => h.id.equals(id))).go();

  Holiday _toHoliday(HolidayRow row) => Holiday(
    id: row.id,
    name: row.name,
    startDate: row.startDate,
    endDate: row.endDate,
    scopes: row.scopes,
  );
}
