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

  /// Which of the circles just crossed is the one to record a stay at.
  ///
  /// The OS will not watch a circle much smaller than a hundred metres, so two
  /// places on the same street are inside each other's radius, and standing in
  /// one of them the device reports both — often in a single callback. Neither
  /// report is wrong and the device is in one place, so the crossing has to
  /// resolve to one of them:
  ///
  /// * a circle the device is not already inside is the news; one it has an
  ///   open stay at is not, because that stay is already recorded.
  /// * failing that, the smallest circle, because the tighter fence is the
  ///   more specific description of where you are — the gym inside the office
  ///   campus, not the campus.
  ///
  /// Null when the crossing names nothing that still exists.
  Future<int?> resolveArrival(Iterable<int> placeIds) async {
    final ids = placeIds.toList();
    if (ids.length < 2) return ids.isEmpty ? null : ids.first;

    final rows =
        await (select(places)..where((p) => p.id.isIn(ids))).get();
    if (rows.isEmpty) return null;

    final openAt = {
      for (final row in await (select(visits)
            ..where((v) => v.departedAt.isNull()))
          .get())
        row.placeId,
    };

    rows.sort((a, b) {
      final byNews = (openAt.contains(a.id) ? 1 : 0)
          .compareTo(openAt.contains(b.id) ? 1 : 0);
      if (byNews != 0) return byNews;
      final byRadius = a.radiusMeters.compareTo(b.radiusMeters);
      if (byRadius != 0) return byRadius;
      return a.id.compareTo(b.id);
    });
    return rows.first.id;
  }

  /// Ends every stay still open anywhere but [placeId], because a device
  /// cannot be in two places at once.
  ///
  /// The exit both platforms are likeliest to drop is the one for the place
  /// just left — the crossing they are busy reporting is the arrival. Left
  /// alone, the morning at home never ends: the day at the office is recorded
  /// *inside* it, coming home again finds that stay still open and is folded
  /// into it, and a day that went home to office and back is left saying "home"
  /// once, with no departure and no return.
  ///
  /// A stay that turns out to have lasted less than [shortestStay] is deleted
  /// rather than closed. Its end was our inference, not the OS's, and neither
  /// platform calls an arrival an arrival that quickly: what it records is the
  /// edge of a circle clipped on the way somewhere else.
  ///
  /// Returns the stays this ended — not the ones it threw away, which have
  /// nothing left to say.
  Future<List<Visit>> closeStaysElsewhere(int placeId, DateTime at) async {
    final rows = await (select(visits)
          ..where((v) => v.placeId.equals(placeId).not() &
              v.departedAt.isNull()))
        .get();

    final closed = <Visit>[];
    for (final row in rows) {
      // An arrival older than the stay it would close is a crossing delivered
      // out of order, and says nothing about when that stay ended.
      if (!at.isAfter(row.arrivedAt)) continue;

      if (at.difference(row.arrivedAt) < shortestStay) {
        await (delete(visits)..where((v) => v.id.equals(row.id))).go();
        continue;
      }

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
  /// [closeStaysElsewhere] only knows when the device turned up somewhere else,
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
