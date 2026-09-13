import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// The generated part file is written against this library's imports, so the
// converter types have to be visible from here even though nothing below names
// them directly.
import '../model/calendar_date.dart';
import '../model/event.dart';
import '../model/holiday.dart';
import '../model/place.dart';
import '../model/recurrence.dart';
import 'converters.dart';
import 'events_dao.dart';
import 'holidays_dao.dart';
import 'places_dao.dart';
import 'settings_dao.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Events, Completions, Overrides, Settings, Places, Visits, Holidays],
  daos: [EventsDao, SettingsDao, PlacesDao, HolidaysDao],
)
class DaylineDatabase extends _$DaylineDatabase {
  DaylineDatabase() : super(_openConnection());

  /// For tests: an isolated in-memory database.
  DaylineDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // v2 added the settings store.
      if (from < 2) await m.createTable(settings);
      // v3 added places, visits, and the optional link from a rule to a place.
      if (from < 3) {
        await m.createTable(places);
        await m.createTable(visits);
        await m.addColumn(events, events.placeId);
      }
      // v4 added auto-completion on arrival, and the flag that says a
      // completion was made by the app rather than by the user.
      if (from < 4) {
        await m.addColumn(events, events.autoCompleteOnArrival);
        await m.addColumn(completions, completions.isAutomatic);
      }
      // v5 added putting a visit on the day as an event of its own.
      if (from < 5) {
        await m.addColumn(places, places.addVisitsToDay);
        await m.addColumn(events, events.fromVisitId);
      }
      // v6 added holidays, and which timetable an event belongs to.
      if (from < 6) {
        await m.createTable(holidays);
        await m.addColumn(events, events.holidayScope);
      }
    },
    beforeOpen: (details) async {
      // Overrides and completions are meaningless without their event.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() =>
      driftDatabase(name: 'dayline');
}
