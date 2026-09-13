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

  /// Optionally ties this routine to a place, which is what makes "did you
  /// actually go to the gym when the reminder fired" answerable.
  IntColumn get placeId => integer()
      .nullable()
      .customConstraint('REFERENCES places(id) ON DELETE SET NULL')();

  /// Tick this one off by itself when the device arrives at [placeId] around
  /// the time it is due.
  ///
  /// Meaningless without a place, and the editor only offers it once one is
  /// picked — but stored independently so that clearing the place cannot leave
  /// a rule quietly waiting for an arrival that can never come.
  BoolColumn get autoCompleteOnArrival =>
      boolean().withDefault(const Constant(false))();

  /// Set when the app wrote this rule itself to record a visit, rather than
  /// the user writing it to plan something.
  ///
  /// It is what separates "somewhere I went" from "something I meant to do",
  /// and the two must not be counted together: a visit is not an intention, so
  /// these stay out of All Events, out of the dashboard's adherence, and out
  /// of the progress ring — while still being on the day, which is the point
  /// of writing them at all.
  ///
  /// Also the idempotency key: one stay produces one row however many times
  /// the OS re-delivers the crossing. Cascades, because an event that is only
  /// a record of a visit has nothing left to say once the visit is forgotten
  /// — and clearing visit history is offered as exactly that. Editing one in
  /// the editor clears this, which adopts it as an ordinary event of the
  /// user's own.
  IntColumn get fromVisitId => integer()
      .nullable()
      .customConstraint('REFERENCES visits(id) ON DELETE CASCADE')();
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

  /// True when the app ticked this off on arrival rather than the user. Kept
  /// so the row can say why it is ticked: a tick the user did not make and
  /// cannot account for is worse than no tick.
  BoolColumn get isAutomatic => boolean().withDefault(const Constant(false))();

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

/// Somewhere the user added by standing there and tapping "use my location".
///
/// Coordinates only. There is no places database to look a name up in and no
/// network permission to reach one, so a place is whatever the user called it.
@DataClassName('PlaceRow')
class Places extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  RealColumn get latitude => real()();

  RealColumn get longitude => real()();

  /// How close counts as "here", in metres.
  RealColumn get radiusMeters =>
      real().withDefault(const Constant(150))();

  IntColumn get colorValue => integer()();

  IntColumn get kind => integer().map(const PlaceKindConverter())();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Put a stay at this place onto the day it happened, as an event.
  ///
  /// Off by default and per place, because it is the one setting that writes
  /// rows the user did not ask for. Sensible for the gym and the office;
  /// wrong for home, which would otherwise file an event every evening.
  BoolColumn get addVisitsToDay =>
      boolean().withDefault(const Constant(false))();
}

/// One stay at a place. Written by the geofence callback, which may be running
/// in a background isolate with the app closed.
@TableIndex(name: 'idx_visits_place', columns: {#placeId})
@TableIndex(name: 'idx_visits_arrived', columns: {#arrivedAt})
@DataClassName('VisitRow')
class Visits extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get placeId => integer().customConstraint(
        'NOT NULL REFERENCES places(id) ON DELETE CASCADE',
      )();

  /// Real instants, not wall clock: a visit is a thing that happened at a
  /// moment, unlike a schedule, which is a thing that happens at a time.
  DateTimeColumn get arrivedAt => dateTime()();

  /// Null while the device is still inside the geofence.
  DateTimeColumn get departedAt => dateTime().nullable()();
}
