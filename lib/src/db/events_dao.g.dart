// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events_dao.dart';

// ignore_for_file: type=lint
mixin _$EventsDaoMixin on DatabaseAccessor<DaylineDatabase> {
  $PlacesTable get places => attachedDatabase.places;
  $VisitsTable get visits => attachedDatabase.visits;
  $EventsTable get events => attachedDatabase.events;
  $CompletionsTable get completions => attachedDatabase.completions;
  $OverridesTable get overrides => attachedDatabase.overrides;
  $HolidaysTable get holidays => attachedDatabase.holidays;
  EventsDaoManager get managers => EventsDaoManager(this);
}

class EventsDaoManager {
  final _$EventsDaoMixin _db;
  EventsDaoManager(this._db);
  $$PlacesTableTableManager get places =>
      $$PlacesTableTableManager(_db.attachedDatabase, _db.places);
  $$VisitsTableTableManager get visits =>
      $$VisitsTableTableManager(_db.attachedDatabase, _db.visits);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
  $$CompletionsTableTableManager get completions =>
      $$CompletionsTableTableManager(_db.attachedDatabase, _db.completions);
  $$OverridesTableTableManager get overrides =>
      $$OverridesTableTableManager(_db.attachedDatabase, _db.overrides);
  $$HolidaysTableTableManager get holidays =>
      $$HolidaysTableTableManager(_db.attachedDatabase, _db.holidays);
}
