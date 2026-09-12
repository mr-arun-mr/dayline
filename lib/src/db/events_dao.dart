import 'dart:async';

import 'package:drift/drift.dart';

import '../model/calendar_date.dart';
import '../model/event.dart';
import '../model/occurrence.dart';
import '../model/recurrence.dart';
import 'database.dart';
import 'live_query.dart';
import 'tables.dart';

part 'events_dao.g.dart';

@DriftAccessor(tables: [Events, Completions, Overrides])
class EventsDao extends DatabaseAccessor<DaylineDatabase> with _$EventsDaoMixin {
  EventsDao(super.db);

  /// Every rule, newest first. Backs the All Events screen.
  Future<List<Event>> allEvents() async {
    final rows = await (select(events)
          ..orderBy([
            (e) => OrderingTerm(expression: e.timeOfDay),
            (e) => OrderingTerm(expression: e.title),
          ]))
        .get();
    return rows.map(_toEvent).toList();
  }

  /// [allEvents], kept live. See [liveQuery] for why this is not `.watch()`.
  Stream<List<Event>> watchAllEvents() => liveQuery(
    updates: attachedDatabase.tableUpdates(TableUpdateQuery.onTable(events)),
    read: allEvents,
  );

  Future<Event?> eventById(int id) async {
    final row = await (select(events)..where((e) => e.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEvent(row);
  }

  /// Everything happening on [date], in the order it happens.
  ///
  /// Expand active rules → drop SKIP overrides → apply MOVED overrides → join
  /// completions → sort by effective time.
  ///
  /// SQL narrows the candidates to rules whose date window contains [date];
  /// the rule itself (weekday mask, every-N modulo, clamped month day) is
  /// applied in Dart, where the arithmetic is integer-exact and testable.
  Future<List<Occurrence>> occurrencesForDate(CalendarDate date) async {
    final epochDay = date.epochDay;

    final candidateRows = await (select(events)
          ..where((e) =>
              e.isActive.equals(true) &
              e.startDate.isSmallerOrEqualValue(epochDay) &
              (e.endDate.isNull() |
                  e.endDate.isBiggerOrEqualValue(epochDay))))
        .get();

    final candidates = candidateRows
        .map(_toEvent)
        .where((event) => event.rule.occursOn(date))
        .toList();
    if (candidates.isEmpty) return const [];

    final ids = candidates.map((e) => e.id).toList();

    final overrideRows = await (select(overrides)
          ..where((o) => o.date.equals(epochDay) & o.eventId.isIn(ids)))
        .get();
    final overrideByEvent = {
      for (final o in overrideRows) o.eventId: o,
    };

    final completionRows = await (select(completions)
          ..where((c) => c.date.equals(epochDay) & c.eventId.isIn(ids)))
        .get();
    final completionByEvent = {
      for (final c in completionRows) c.eventId: c,
    };

    final result = <Occurrence>[];
    for (final event in candidates) {
      final override = overrideByEvent[event.id];
      if (override?.type == OverrideType.skip) continue;

      final moved = override?.type == OverrideType.moved &&
          override?.newTimeOfDay != null;
      final completion = completionByEvent[event.id];

      result.add(Occurrence(
        event: event,
        date: date,
        effectiveTimeOfDay:
            moved ? override!.newTimeOfDay! : event.timeOfDay,
        isMoved: moved,
        status: completion?.status,
        completedAt: completion?.completedAt,
      ));
    }

    result.sort((a, b) {
      final byTime = a.effectiveTimeOfDay.compareTo(b.effectiveTimeOfDay);
      if (byTime != 0) return byTime;
      final byTitle = a.event.title.toLowerCase()
          .compareTo(b.event.title.toLowerCase());
      if (byTitle != 0) return byTitle;
      return a.eventId.compareTo(b.eventId);
    });
    return result;
  }

  /// [occurrencesForDate], re-run whenever anything it reads changes.
  ///
  /// See [liveQuery] for why this is not drift's own `.watch()`.
  Stream<List<Occurrence>> watchOccurrencesForDate(CalendarDate date) =>
      liveQuery(
        updates: attachedDatabase.tableUpdates(
          TableUpdateQuery.onAllTables([events, completions, overrides]),
        ),
        read: () => occurrencesForDate(date),
      );

  /// Every completion recorded against one rule, keyed by date.
  Future<Map<CalendarDate, CompletionStatus>> completionsFor(
    int eventId,
  ) async {
    final rows = await (select(completions)
          ..where((c) => c.eventId.equals(eventId)))
        .get();
    return {for (final row in rows) row.date: row.status};
  }

  /// Fires whenever anything about one rule's history changes.
  ///
  /// Emits the history itself rather than a bare signal, so a listener does
  /// not have to turn round and read it again.
  Stream<Map<CalendarDate, CompletionStatus>> watchCompletionsFor(
    int eventId,
  ) =>
      liveQuery(
        updates: attachedDatabase.tableUpdates(
          TableUpdateQuery.onAllTables([events, completions]),
        ),
        read: () => completionsFor(eventId),
      );

  Future<int> insertEvent(EventsCompanion event) =>
      into(events).insert(event);

  Future<bool> updateEvent(EventsCompanion event) =>
      update(events).replace(event);

  /// Removes the rule and, by cascade, everything recorded against it.
  Future<int> deleteEvent(int id) =>
      (delete(events)..where((e) => e.id.equals(id))).go();

  /// Deletes one occurrence, leaving the rest of the series alone.
  ///
  /// A recurring rule cannot lose a single day by deletion — there is no row
  /// to delete — so this records a SKIP override instead. A one-off has
  /// nothing left once its single occurrence goes, so the rule itself goes.
  Future<void> deleteOccurrence(int eventId, CalendarDate date) async {
    final event = await eventById(eventId);
    if (event == null) return;

    if (event.recurrence == Recurrence.once) {
      await deleteEvent(eventId);
      return;
    }

    await transaction(() async {
      await into(overrides).insertOnConflictUpdate(OverridesCompanion.insert(
        eventId: eventId,
        date: date,
        type: OverrideType.skip,
      ));
      // Whatever the user had recorded against this day is about a day that
      // no longer exists.
      await clearCompletion(eventId, date);
    });
  }

  /// Deletes this occurrence and every one after it, keeping the history.
  ///
  /// The series is closed by moving its end date back to the day before
  /// [date] rather than by deleting the rule, so days already lived through —
  /// and what the user recorded on them — survive. If [date] is at or before
  /// the start there is nothing left to keep, and the rule is deleted outright.
  Future<void> deleteOccurrencesFrom(int eventId, CalendarDate date) async {
    final event = await eventById(eventId);
    if (event == null) return;

    if (!date.isAfter(event.startDate)) {
      await deleteEvent(eventId);
      return;
    }

    final epochDay = date.epochDay;
    await transaction(() async {
      await (update(events)..where((e) => e.id.equals(eventId))).write(
        EventsCompanion(endDate: Value(date.addDays(-1))),
      );
      // Rows about occurrences that no longer exist.
      await (delete(completions)
            ..where((c) =>
                c.eventId.equals(eventId) &
                c.date.isBiggerOrEqualValue(epochDay)))
          .go();
      await (delete(overrides)
            ..where((o) =>
                o.eventId.equals(eventId) &
                o.date.isBiggerOrEqualValue(epochDay)))
          .go();
    });
  }

  Future<int> setActive(int id, bool active) =>
      (update(events)..where((e) => e.id.equals(id)))
          .write(EventsCompanion(isActive: Value(active)));

  /// Marks one occurrence done or skipped. Re-marking overwrites.
  Future<void> setCompletion({
    required int eventId,
    required CalendarDate date,
    required CompletionStatus status,
    DateTime? at,
  }) => into(completions).insertOnConflictUpdate(CompletionsCompanion.insert(
        eventId: eventId,
        date: date,
        status: status,
        completedAt: at ?? DateTime.now(),
      ));

  /// Undoes a done/skipped mark, returning the occurrence to pending.
  Future<int> clearCompletion(int eventId, CalendarDate date) =>
      (delete(completions)
            ..where((c) =>
                c.eventId.equals(eventId) & c.date.equals(date.epochDay)))
          .go();

  Future<void> setOverride(EventOverride override) =>
      into(overrides).insertOnConflictUpdate(OverridesCompanion.insert(
        eventId: override.eventId,
        date: override.date,
        type: override.type,
        newTimeOfDay: Value(override.newTimeOfDay),
      ));

  /// Every override falling in `[from, to]`, for the notification scheduler.
  ///
  /// A repeating trigger cannot know that one day was skipped or moved, so the
  /// scheduler needs these to decide which rules can use one and which have to
  /// be expanded.
  Future<List<OverrideRow>> overridesBetween(
    CalendarDate from,
    CalendarDate to,
  ) =>
      (select(overrides)
            ..where((o) =>
                o.date.isBiggerOrEqualValue(from.epochDay) &
                o.date.isSmallerOrEqualValue(to.epochDay)))
          .get();

  Future<int> clearOverride(int eventId, CalendarDate date) =>
      (delete(overrides)
            ..where((o) =>
                o.eventId.equals(eventId) & o.date.equals(date.epochDay)))
          .go();

  Event _toEvent(EventRow row) => Event(
        id: row.id,
        title: row.title,
        notes: row.notes,
        colorValue: row.colorValue,
        durationMin: row.durationMin,
        leadMinutes: row.leadMinutes,
        rule: EventRule(
          recurrence: row.recurrence,
          timeOfDay: row.timeOfDay,
          startDate: row.startDate,
          endDate: row.endDate,
          daysOfWeek: row.daysOfWeek,
          interval: row.interval,
          dayOfMonth: row.dayOfMonth,
          isActive: row.isActive,
        ),
      );
}
