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

  /// Ends any stay still open somewhere other than [placeIds], because a
  /// device cannot be in two places at once.
  ///
  /// The exit both platforms are likeliest to drop is the one for the place
  /// just left — the crossing they are busy reporting is the arrival. Left
  /// alone, the morning at home never ends: the day at the office is recorded
  /// *inside* it, coming home again finds that stay still open and is folded
  /// into it, and a day that went home to office and back is left saying "home"
  /// once, with no departure and no return.
  ///
  /// [placeIds] is the whole batch the OS reported at once, not one place, so
  /// that two overlapping circles entered together do not close each other.
  ///
  /// Returns the stays this ended, so the rows they wrote onto the day can be
  /// given an end too.
  Future<List<Visit>> closeStaysAwayFrom(
    Iterable<int> placeIds,
    DateTime at,
  ) async {
    final here = placeIds.toList();
    final rows = await (select(visits)
          ..where((v) => v.placeId.isNotIn(here) & v.departedAt.isNull()))
        .get();

    final closed = <Visit>[];
    for (final row in rows) {
      // An arrival older than the stay it would close is a crossing delivered
      // out of order, and says nothing about when that stay ended.
      if (!at.isAfter(row.arrivedAt)) continue;
      await (update(visits)..where((v) => v.id.equals(row.id)))
          .write(VisitsCompanion(departedAt: Value(at)));
      closed.add(Visit(
        id: row.id,
        placeId: row.placeId,
        arrivedAt: row.arrivedAt,
        departedAt: at,
      ));
    }
    return closed;
  }

  /// Records that the device left, and returns the stay it closed.
  ///
  /// An exit with no matching arrival is dropped rather than invented: a visit
  /// of unknown length is worse than no visit, because it would be counted.
  /// Null back means nothing was closed — no arrival to close, or a departure
  /// that turned out not to be one.
  Future<Visit?> recordDeparture(int placeId, DateTime at) async {
    final open = await _openVisitFor(placeId);
    if (open == null) return _correctEndOfStay(placeId, at);
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

  /// An exit that turns up after the stay it belongs to was already closed.
  ///
  /// [closeStaysAwayFrom] only knows when the device turned up somewhere else,
  /// which is later than when it left; the OS knows when it left. So a late
  /// exit landing inside a recorded stay is better information than the end
  /// already on it, and wins. An exit after the stay ended is a duplicate and
  /// changes nothing.
  Future<Visit?> _correctEndOfStay(int placeId, DateTime at) async {
    final row = await (select(visits)
          ..where((v) => v.placeId.equals(placeId))
          ..orderBy([
            (v) => OrderingTerm(
              expression: v.arrivedAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;

    final departed = row.departedAt;
    // No open stay, so this cannot be null; belt and braces.
    if (departed == null) return null;
    if (!at.isAfter(row.arrivedAt) || !departed.isAfter(at)) return null;

    await (update(visits)..where((v) => v.id.equals(row.id)))
        .write(VisitsCompanion(departedAt: Value(at)));
    return Visit(
      id: row.id,
      placeId: row.placeId,
      arrivedAt: row.arrivedAt,
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
