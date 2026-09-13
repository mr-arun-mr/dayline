import 'package:drift/drift.dart';

import '../db/database.dart';
import 'backup.dart';

/// How an import should treat what is already there.
enum ImportMode {
  /// Everything currently stored is deleted first. The result is exactly the
  /// backup — which is what "restore" means.
  replace,

  /// Keeps what is there and adds the backup's events alongside. Useful for
  /// pulling routines off an old phone onto one already in use.
  merge,
}

/// What an import actually did.
class ImportResult {
  const ImportResult({
    required this.events,
    required this.completions,
    required this.overrides,
    this.places = 0,
    this.visits = 0,
  });

  final int events;
  final int completions;
  final int overrides;
  final int places;
  final int visits;
}

/// Reads and writes the whole database as one JSON document.
class BackupService {
  const BackupService(this._db);

  final DaylineDatabase _db;

  Future<Backup> export({DateTime? at}) async {
    final events = await _db.select(_db.events).get();
    final completions = await _db.select(_db.completions).get();
    final overrides = await _db.select(_db.overrides).get();
    final places = await _db.select(_db.places).get();
    final visits = await _db.select(_db.visits).get();

    return Backup(
      exportedAt: at ?? DateTime.now(),
      events: [
        for (final e in events)
          BackupEvent(
            id: e.id,
            title: e.title,
            notes: e.notes,
            colorValue: e.colorValue,
            timeOfDay: e.timeOfDay,
            durationMin: e.durationMin,
            recurrence: e.recurrence,
            daysOfWeek: e.daysOfWeek,
            interval: e.interval,
            dayOfMonth: e.dayOfMonth,
            startDate: e.startDate,
            endDate: e.endDate,
            leadMinutes: e.leadMinutes,
            isActive: e.isActive,
            placeId: e.placeId,
            autoCompleteOnArrival: e.autoCompleteOnArrival,
          ),
      ],
      places: [
        for (final p in places)
          BackupPlace(
            id: p.id,
            name: p.name,
            latitude: p.latitude,
            longitude: p.longitude,
            radiusMeters: p.radiusMeters,
            colorValue: p.colorValue,
            kind: p.kind,
            isActive: p.isActive,
          ),
      ],
      visits: [
        for (final v in visits)
          BackupVisit(
            placeId: v.placeId,
            arrivedAt: v.arrivedAt,
            departedAt: v.departedAt,
          ),
      ],
      completions: [
        for (final c in completions)
          BackupCompletion(
            eventId: c.eventId,
            date: c.date,
            status: c.status,
            completedAt: c.completedAt,
            isAutomatic: c.isAutomatic,
          ),
      ],
      overrides: [
        for (final o in overrides)
          BackupOverride(
            eventId: o.eventId,
            date: o.date,
            type: o.type,
            newTimeOfDay: o.newTimeOfDay,
          ),
      ],
    );
  }

  Future<String> exportJson({DateTime? at}) async =>
      (await export(at: at)).encode();

  /// Restores a backup.
  ///
  /// Event ids are reassigned as rows go in rather than trusted from the file,
  /// and completions and overrides are remapped through the new ids. Trusting
  /// them would either collide with existing rows on a merge or, worse,
  /// silently attach someone's gym history to their dentist appointment.
  ///
  /// The whole thing runs in one transaction: a half-restored database is
  /// worse than a failed restore.
  Future<ImportResult> import(
    Backup backup, {
    ImportMode mode = ImportMode.replace,
  }) async {
    var events = 0;
    var completions = 0;
    var overrides = 0;
    var places = 0;
    var visits = 0;

    await _db.transaction(() async {
      if (mode == ImportMode.replace) {
        // Completions and overrides cascade with their events, visits with
        // their places.
        await _db.delete(_db.events).go();
        await _db.delete(_db.places).go();
      }

      // Places go in first: an event can point at one, so the new ids have to
      // exist before the events that reference them.
      final placeIdMap = <int, int>{};
      for (final place in backup.places) {
        final newId = await _db.into(_db.places).insert(
          PlacesCompanion.insert(
            name: place.name,
            latitude: place.latitude,
            longitude: place.longitude,
            radiusMeters: Value(place.radiusMeters),
            colorValue: place.colorValue,
            kind: place.kind,
            isActive: Value(place.isActive),
          ),
        );
        placeIdMap[place.id] = newId;
        places++;
      }

      for (final visit in backup.visits) {
        final placeId = placeIdMap[visit.placeId];
        if (placeId == null) continue;
        await _db.into(_db.visits).insert(
          VisitsCompanion.insert(
            placeId: placeId,
            arrivedAt: visit.arrivedAt,
            departedAt: Value(visit.departedAt),
          ),
        );
        visits++;
      }

      final idMap = <int, int>{};
      for (final event in backup.events) {
        final newId = await _db.into(_db.events).insert(
          EventsCompanion.insert(
            title: event.title,
            notes: Value(event.notes),
            colorValue: event.colorValue,
            timeOfDay: event.timeOfDay,
            durationMin: Value(event.durationMin),
            recurrence: event.recurrence,
            daysOfWeek: Value(event.daysOfWeek),
            interval: Value(event.interval),
            dayOfMonth: Value(event.dayOfMonth),
            startDate: event.startDate,
            endDate: Value(event.endDate),
            leadMinutes: Value(event.leadMinutes),
            isActive: Value(event.isActive),
            // Remapped like everything else; a rule pointing at a place id
            // that no longer means the same place is worse than no link.
            placeId: Value(
              event.placeId == null ? null : placeIdMap[event.placeId],
            ),
            autoCompleteOnArrival: Value(event.autoCompleteOnArrival),
          ),
        );
        idMap[event.id] = newId;
        events++;
      }

      for (final completion in backup.completions) {
        final eventId = idMap[completion.eventId];
        // An orphan is dropped rather than guessed at.
        if (eventId == null) continue;
        await _db.into(_db.completions).insertOnConflictUpdate(
          CompletionsCompanion.insert(
            eventId: eventId,
            date: completion.date,
            status: completion.status,
            completedAt: completion.completedAt,
            isAutomatic: Value(completion.isAutomatic),
          ),
        );
        completions++;
      }

      for (final override in backup.overrides) {
        final eventId = idMap[override.eventId];
        if (eventId == null) continue;
        await _db.into(_db.overrides).insertOnConflictUpdate(
          OverridesCompanion.insert(
            eventId: eventId,
            date: override.date,
            type: override.type,
            newTimeOfDay: Value(override.newTimeOfDay),
          ),
        );
        overrides++;
      }
    });

    return ImportResult(
      events: events,
      completions: completions,
      overrides: overrides,
      places: places,
      visits: visits,
    );
  }

  /// Marked async deliberately: decoding can fail, and a `Future`-returning
  /// method that throws synchronously is a trap for every caller that reaches
  /// for `catchError` instead of `try`.
  Future<ImportResult> importJson(
    String raw, {
    ImportMode mode = ImportMode.replace,
  }) async =>
      import(Backup.decode(raw), mode: mode);

  /// A filename that sorts chronologically and says what it is.
  static String suggestedFileName(DateTime at) =>
      'dayline-${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}.json';
}
