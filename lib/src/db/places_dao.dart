import 'package:drift/drift.dart';

import '../model/place.dart';
import 'database.dart';
import 'live_query.dart';
import 'tables.dart';

part 'places_dao.g.dart';

@DriftAccessor(tables: [Places, Visits])
class PlacesDao extends DatabaseAccessor<DaylineDatabase> with _$PlacesDaoMixin {
  PlacesDao(super.db);

  Future<List<Place>> allPlaces() async =>
      (await (select(places)..orderBy([(p) => OrderingTerm(expression: p.name)]))
              .get())
          .map(_toPlace)
          .toList();

  Stream<List<Place>> watchPlaces() => liveQuery(
    updates: attachedDatabase.tableUpdates(TableUpdateQuery.onTable(places)),
    read: allPlaces,
  );

  Future<Place?> placeById(int id) async {
    final row =
        await (select(places)..where((p) => p.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toPlace(row);
  }

  Future<int> insertPlace(PlacesCompanion place) => into(places).insert(place);

  Future<bool> updatePlace(PlacesCompanion place) =>
      update(places).replace(place);

  Future<int> deletePlace(int id) =>
      (delete(places)..where((p) => p.id.equals(id))).go();

  Future<int> setPlaceActive(int id, bool active) =>
      (update(places)..where((p) => p.id.equals(id)))
          .write(PlacesCompanion(isActive: Value(active)));

  /// Visits overlapping `[from, to]`, oldest first.
  ///
  /// Deliberately includes a visit that began before [from] and is still open,
  /// because the device sitting at home since yesterday is very much part of
  /// today.
  Future<List<Visit>> visitsBetween(DateTime from, DateTime to) async {
    final rows = await (select(visits)
          ..where((v) =>
              v.arrivedAt.isSmallerThanValue(to) &
              (v.departedAt.isNull() |
                  v.departedAt.isBiggerThanValue(from)))
          ..orderBy([(v) => OrderingTerm(expression: v.arrivedAt)]))
        .get();
    return rows.map(_toVisit).toList();
  }

  Stream<List<Visit>> watchVisitsBetween(DateTime from, DateTime to) =>
      liveQuery(
        updates: attachedDatabase.tableUpdates(
          TableUpdateQuery.onTable(visits),
        ),
        read: () => visitsBetween(from, to),
      );

  Future<List<Visit>> visitsForPlace(int placeId) async {
    final rows = await (select(visits)
          ..where((v) => v.placeId.equals(placeId))
          ..orderBy([(v) => OrderingTerm(expression: v.arrivedAt)]))
        .get();
    return rows.map(_toVisit).toList();
  }

  /// Records that the device entered a place, and returns the stay's id.
  ///
  /// Idempotent by design: the OS can deliver the same enter twice, and both
  /// platforms occasionally send an enter without ever having sent the matching
  /// exit. A second arrival while one is already open is treated as the same
  /// stay rather than starting a duplicate — and returns that same id, which
  /// is what keeps one stay from producing two of anything downstream.
  Future<int> recordArrival(int placeId, DateTime at) async {
    final open = await _openVisitFor(placeId);
    if (open != null) return open.id;
    return into(visits).insert(
      VisitsCompanion.insert(placeId: placeId, arrivedAt: at),
    );
  }

  /// Records that the device left, and returns the stay it closed.
  ///
  /// An exit with no matching arrival is dropped rather than invented: a visit
  /// of unknown length is worse than no visit, because it would be counted.
  /// Null back means nothing was closed — no arrival to close, or a departure
  /// that turned out not to be one.
  Future<Visit?> recordDeparture(int placeId, DateTime at) async {
    final open = await _openVisitFor(placeId);
    if (open == null) return null;
    // A departure before the arrival is a clock adjustment, not a stay.
    if (!at.isAfter(open.arrivedAt)) {
      await (delete(visits)..where((v) => v.id.equals(open.id))).go();
      return null;
    }
    await (update(visits)..where((v) => v.id.equals(open.id)))
        .write(VisitsCompanion(departedAt: Value(at)));
    return Visit(
      id: open.id,
      placeId: open.placeId,
      arrivedAt: open.arrivedAt,
      departedAt: at,
    );
  }

  Future<Visit?> _openVisitFor(int placeId) async {
    final row = await (select(visits)
          ..where((v) => v.placeId.equals(placeId) & v.departedAt.isNull())
          ..orderBy([
            (v) => OrderingTerm(
              expression: v.arrivedAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toVisit(row);
  }

  /// Forgets every visit, leaving the places themselves alone.
  Future<int> clearHistory() => delete(visits).go();

  Place _toPlace(PlaceRow row) => Place(
    id: row.id,
    name: row.name,
    latitude: row.latitude,
    longitude: row.longitude,
    radiusMeters: row.radiusMeters,
    colorValue: row.colorValue,
    kind: row.kind,
    isActive: row.isActive,
    addVisitsToDay: row.addVisitsToDay,
  );

  Visit _toVisit(VisitRow row) => Visit(
    id: row.id,
    placeId: row.placeId,
    arrivedAt: row.arrivedAt,
    departedAt: row.departedAt,
  );
}
