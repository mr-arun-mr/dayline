import 'dart:convert';

import 'package:drift/drift.dart';

import '../model/calendar_date.dart';
import '../model/event.dart';
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

class PlaceKindConverter extends TypeConverter<PlaceKind, int> {
  const PlaceKindConverter();

  @override
  PlaceKind fromSql(int fromDb) => PlaceKind.fromCode(fromDb);

  @override
  int toSql(PlaceKind value) => value.code;
}
