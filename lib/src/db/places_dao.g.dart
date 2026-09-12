// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'places_dao.dart';

// ignore_for_file: type=lint
mixin _$PlacesDaoMixin on DatabaseAccessor<DaylineDatabase> {
  $PlacesTable get places => attachedDatabase.places;
  $VisitsTable get visits => attachedDatabase.visits;
  PlacesDaoManager get managers => PlacesDaoManager(this);
}

class PlacesDaoManager {
  final _$PlacesDaoMixin _db;
  PlacesDaoManager(this._db);
  $$PlacesTableTableManager get places =>
      $$PlacesTableTableManager(_db.attachedDatabase, _db.places);
  $$VisitsTableTableManager get visits =>
      $$VisitsTableTableManager(_db.attachedDatabase, _db.visits);
}
