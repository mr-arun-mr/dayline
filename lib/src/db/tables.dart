import 'package:drift/drift.dart';

import '../model/recurrence.dart';
import 'converters.dart';

/// One row per recurrence *rule*. Never one row per occurrence — a daily event
/// running for a decade is one row here, expanded on read.
@DataClassName('EventRow')
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 200)();

  TextColumn get notes => text().nullable()();

  /// ARGB.
  IntColumn get colorValue => integer()();

  /// Minutes since midnight, **wall clock**. 07:00 is 420 in Delhi in January
  /// and 420 in New York in July.
  IntColumn get timeOfDay => integer()();

  IntColumn get durationMin => integer().nullable()();

  IntColumn get recurrence =>
      integer().map(const RecurrenceConverter())();

  /// 7-bit mask, see [Weekdays]. WEEKLY only.
  IntColumn get daysOfWeek => integer().withDefault(const Constant(0))();

  /// EVERY_N_DAYS only. Named `interval_days` because `interval` is a keyword
  /// in enough SQL dialects to be worth dodging.
  IntColumn get interval =>
      integer().named('interval_days').withDefault(const Constant(1))();

  /// MONTHLY only. Clamped into short months on read; -1 means last day.
  IntColumn get dayOfMonth => integer().nullable()();

  IntColumn get startDate => integer().map(const CalendarDateConverter())();

  IntColumn get endDate =>
      integer().nullable().map(const CalendarDateConverter())();

  /// JSON list of minutes before the event, e.g. `[60,10]`.
  TextColumn get leadMinutes => text()
      .withDefault(const Constant('[]'))
      .map(const LeadMinutesConverter())();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Written only when the user acts on an occurrence. An untouched day costs no
/// rows at all.
@DataClassName('CompletionRow')
@TableIndex(name: 'idx_completions_date', columns: {#date})
class Completions extends Table {
  // Spelled as a raw constraint rather than `references(Events, #id)`: the
  // typed form is resolved by drift's analyzer and silently emitted nothing
  // here, leaving orphan rows behind after a delete.
  IntColumn get eventId => integer().customConstraint(
        'NOT NULL REFERENCES events(id) ON DELETE CASCADE',
      )();

  IntColumn get date => integer().map(const CalendarDateConverter())();

  IntColumn get status => integer().map(const CompletionStatusConverter())();

  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {eventId, date};
}

/// Written only when a single occurrence is changed — skipped outright, or
/// moved to another time on the same day.
@DataClassName('OverrideRow')
@TableIndex(name: 'idx_overrides_date', columns: {#date})
class Overrides extends Table {
  // Spelled as a raw constraint rather than `references(Events, #id)`: the
  // typed form is resolved by drift's analyzer and silently emitted nothing
  // here, leaving orphan rows behind after a delete.
  IntColumn get eventId => integer().customConstraint(
        'NOT NULL REFERENCES events(id) ON DELETE CASCADE',
      )();

  IntColumn get date => integer().map(const CalendarDateConverter())();

  IntColumn get type => integer().map(const OverrideTypeConverter())();

  /// Minutes since midnight, wall clock. MOVED only.
  IntColumn get newTimeOfDay => integer().nullable()();

  @override
  Set<Column> get primaryKey => {eventId, date};
}

/// Small key/value store for app-level settings.
///
/// In SQLite rather than a preferences plugin so that "all data on-device in
/// one place" stays literally true, and so a future export carries settings
/// along with the events.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
