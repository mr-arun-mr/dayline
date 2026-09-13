import 'dart:convert';

import 'package:drift/drift.dart';

import '../model/calendar_date.dart';
import '../model/event.dart';
import '../model/holiday.dart';
import '../model/place.dart';
import '../model/recurrence.dart';

/// Stores a [CalendarDate] as its epoch-day integer.
///
/// Deliberately **not** a `DateTimeColumn`. Drift would store a real instant,
/// which forces a timezone onto something that has none: a "start date" of
/// 2026-03-29 is that date everywhere on earth, and reading it back through a
/// different offset must not shift it to the 28th.
class CalendarDateConverter extends TypeConverter<CalendarDate, int> {
  const CalendarDateConverter();

  @override
  CalendarDate fromSql(int fromDb) => CalendarDate.fromEpochDay(fromDb);

  @override
  int toSql(CalendarDate value) => value.epochDay;
}

class RecurrenceConverter extends TypeConverter<Recurrence, int> {
  const RecurrenceConverter();

  @override
  Recurrence fromSql(int fromDb) => Recurrence.fromCode(fromDb);

  @override
  int toSql(Recurrence value) => value.code;
}

class CompletionStatusConverter extends TypeConverter<CompletionStatus, int> {
  const CompletionStatusConverter();

  @override
  CompletionStatus fromSql(int fromDb) => CompletionStatus.fromCode(fromDb);

  @override
  int toSql(CompletionStatus value) => value.code;
}

class OverrideTypeConverter extends TypeConverter<OverrideType, int> {
  const OverrideTypeConverter();

  @override
  OverrideType fromSql(int fromDb) => OverrideType.fromCode(fromDb);

  @override
  int toSql(OverrideType value) => value.code;
}

/// Lead reminders as a JSON array of minutes, e.g. `[60,10]`.
class LeadMinutesConverter extends TypeConverter<List<int>, String> {
  const LeadMinutesConverter();

  @override
  List<int> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const [];
    final decoded = jsonDecode(fromDb);
    if (decoded is! List) return const [];
    return decoded.whereType<num>().map((n) => n.toInt()).toList();
  }

  @override
  String toSql(List<int> value) => jsonEncode(value);
}

/// A single scope on an event: which timetable it belongs to, if any.
///
/// An unrecognised code reads back as [HolidayScope.work] rather than
/// throwing — but [HolidayScope.fromCode] is the one that decides, and a row
/// written by a newer build simply stops pausing rather than taking the whole
/// query down with it.
class HolidayScopeConverter extends TypeConverter<HolidayScope, int> {
  const HolidayScopeConverter();

  @override
  HolidayScope fromSql(int fromDb) =>
      HolidayScope.fromCode(fromDb) ?? HolidayScope.work;

  @override
  int toSql(HolidayScope value) => value.code;
}

class PlaceKindConverter extends TypeConverter<PlaceKind, int> {
  const PlaceKindConverter();

  @override
  PlaceKind fromSql(int fromDb) => PlaceKind.fromCode(fromDb);

  @override
  int toSql(PlaceKind value) => value.code;
}
