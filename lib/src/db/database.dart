import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// The generated part file is written against this library's imports, so the
// converter types have to be visible from here even though nothing below names
// them directly.
import '../model/calendar_date.dart';
import '../model/event.dart';
import '../model/place.dart';
import '../model/recurrence.dart';
import 'converters.dart';
import 'events_dao.dart';
import 'places_dao.dart';
import 'settings_dao.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Events, Completions, Overrides, Settings, Places, Visits],
  daos: [EventsDao, SettingsDao, PlacesDao],
)
class DaylineDatabase extends _$DaylineDatabase {
  DaylineDatabase() : super(_openConnection());

  /// For tests: an isolated in-memory database.
  DaylineDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

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
    },
    beforeOpen: (details) async {
      // Overrides and completions are meaningless without their event.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() =>
      driftDatabase(name: 'dayline');
}
