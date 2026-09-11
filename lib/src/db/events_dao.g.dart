// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events_dao.dart';

// ignore_for_file: type=lint
mixin _$EventsDaoMixin on DatabaseAccessor<DaylineDatabase> {
  $EventsTable get events => attachedDatabase.events;
  $CompletionsTable get completions => attachedDatabase.completions;
  $OverridesTable get overrides => attachedDatabase.overrides;
  EventsDaoManager get managers => EventsDaoManager(this);
}

class EventsDaoManager {
  final _$EventsDaoMixin _db;
  EventsDaoManager(this._db);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
  $$CompletionsTableTableManager get completions =>
      $$CompletionsTableTableManager(_db.attachedDatabase, _db.completions);
  $$OverridesTableTableManager get overrides =>
      $$OverridesTableTableManager(_db.attachedDatabase, _db.overrides);
}
