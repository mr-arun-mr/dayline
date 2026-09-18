import 'dart:async';

import 'package:drift/drift.dart';

import '../model/auto_complete.dart';
import '../model/calendar_date.dart';
import '../model/event.dart';
import '../model/occurrence.dart';
import '../model/place.dart';
import '../model/place_stats.dart';
import '../model/recurrence.dart';
import 'database.dart';
import 'live_query.dart';
import 'tables.dart';

part 'events_dao.g.dart';

@DriftAccessor(tables: [Events, Completions, Overrides, Visits, Holidays])
class EventsDao extends DatabaseAccessor<DaylineDatabase> with _$EventsDaoMixin {
  EventsDao(super.db);

  /// Every rule the user made, newest first. Backs the All Events screen.
  ///
  /// Rows the app wrote to record a visit are deliberately not here. All
  /// Events is a list of rules — things with a schedule and a streak — and a
  /// place you went last Tuesday is neither. They would also flood the
  /// dashboard's adherence, which reads this and would find a hundred
  /// one-offs that were, by construction, all attended.
  Future<List<Event>> allEvents() async {
    final rows = await (select(events)
          ..where((e) => e.fromVisitId.isNull())
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
  /// completions → sort by effective time → thread the day's stays onto it.
  ///
  /// SQL narrows the candidates to rules whose date window contains [date];
  /// the rule itself (weekday mask, every-N modulo, clamped month day) is
  /// applied in Dart, where the arithmetic is integer-exact and testable.
  ///
  /// [clock] is where "now" comes from, which only an open stay depends on:
  /// one that is still running has to be given an end before it can be asked
  /// which days it touches.
  Future<List<Occurrence>> occurrencesForDate(
    CalendarDate date, {
    DateTime Function()? clock,
  }) async {
    final epochDay = date.epochDay;

    final candidateRows = await (select(events)
          ..where((e) =>
              e.isActive.equals(true) &
              e.startDate.isSmallerOrEqualValue(epochDay) &
              (e.endDate.isNull() |
                  e.endDate.isBiggerOrEqualValue(epochDay))))
        .get();

    // A holiday removes a whole timetable from the day, so it is asked before
    // anything else is read: on a closed day there is usually nothing left to
    // join completions or visits to.
    final holidays = await attachedDatabase.holidaysDao.holidaysOnDate(date);

    final candidates = candidateRows
        .map(_toEvent)
        .where((event) =>
            event.rule.occursOn(date) && !event.isPausedOn(date, holidays))
        .toList();

    // Deliberately not an early return when there are no rules: a day with
    // nothing planned can still have been somewhere, and the stays are
    // threaded on at the end.
    final ids = candidates.map((e) => e.id).toList();

    final overrideRows = ids.isEmpty
        ? const <OverrideRow>[]
        : await (select(overrides)
              ..where((o) => o.date.equals(epochDay) & o.eventId.isIn(ids)))
            .get();
    final overrideByEvent = {
      for (final o in overrideRows) o.eventId: o,
    };

    final completionRows = ids.isEmpty
        ? const <CompletionRow>[]
        : await (select(completions)
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
        isAutomatic: completion?.isAutomatic ?? false,
      ));
    }

    result.sort(_byTimeThenTitle);

    // Planned, meet actual: anything tied to a place picks up the stay that
    // lines up with it, so the row can say both when it was meant to happen
    // and when the user was really there.
    final stays = await _visitsAround(date);
    final now = (clock ?? DateTime.now)();
    return _threadStaysOnto(withVisits(result, stays), date, stays, now);
  }

  /// Puts every stay that touches [date] in its place on the day's line.
  ///
  /// A stay is a fact about a day, not a rule that happens to fall on one, so
  /// where it belongs is decided by the visit rather than by the row's date:
  ///
  /// * a row whose stay began earlier — the night at home that ran into this
  ///   morning — is carried onto this day too, at the top, where the day found
  ///   it already in progress. It is one stay seen from two days, which is
  ///   what the dashboard has always shown and what the day line was missing.
  /// * a row is positioned by when the stay began rather than by the time
  ///   written on it, so a crossing the OS re-delivered hours later cannot
  ///   file last night's arrival under this morning.
  ///
  /// Nothing is written: the rows are already there, and this only decides
  /// which day draws them and where.
  Future<List<Occurrence>> _threadStaysOnto(
    List<Occurrence> occurrences,
    CalendarDate date,
    List<Visit> stays,
    DateTime now,
  ) async {
    final touching = visitsOnDay(stays, date, now: now);
    if (touching.isEmpty) return occurrences;

    final result = [
      for (final occurrence in occurrences)
        if (occurrence.isVisitRecord && occurrence.visit != null)
          occurrence.copyWith(
            effectiveTimeOfDay: _stayBeginsAt(occurrence.visit!, date),
          )
        else
          occurrence,
    ];

    result.addAll(await _staysCarriedInto(
      date,
      touching,
      {for (final occurrence in result) occurrence.eventId},
    ));

    result.sort(_byTimeThenTitle);
    return result;
  }

  /// Where on [date] a stay sits: when it began, or the top of the day when it
  /// began before the day did.
  static int _stayBeginsAt(Visit visit, CalendarDate date) =>
      CalendarDate.fromDateTime(visit.arrivedAt) == date
          ? visit.arrivedAt.hour * 60 + visit.arrivedAt.minute
          : 0;

  /// The rows for stays that touch [date] but are filed under another day.
  ///
  /// [already] is the ids [date] has expanded for itself, so a stay that began
  /// today is drawn once rather than twice.
  Future<List<Occurrence>> _staysCarriedInto(
    CalendarDate date,
    List<Visit> touching,
    Set<int> already,
  ) async {
    final byVisit = {for (final visit in touching) visit.id: visit};
    if (byVisit.isEmpty) return const [];

    final rows = await (select(events)
          ..where((e) => e.fromVisitId.isIn(byVisit.keys.toList())))
        .get();
    final carried = rows.where((row) => !already.contains(row.id)).toList();
    if (carried.isEmpty) return const [];

    // A stay's row is ticked off on the day it was written, which is not the
    // day being drawn — so the completion is read by event rather than by
    // date. There is only ever one: a stay happened once.
    final completionRows = await (select(completions)
          ..where((c) => c.eventId.isIn(carried.map((r) => r.id).toList())))
        .get();
    final completionByEvent = {for (final c in completionRows) c.eventId: c};

    return [
      for (final row in carried)
        () {
          final completion = completionByEvent[row.id];
          final visit = byVisit[row.fromVisitId]!;
          return Occurrence(
            event: _toEvent(row),
            date: date,
            effectiveTimeOfDay: _stayBeginsAt(visit, date),
            status: completion?.status,
            completedAt: completion?.completedAt,
            isAutomatic: completion?.isAutomatic ?? false,
            visit: visit,
          );
        }(),
    ];
  }

  static int _byTimeThenTitle(Occurrence a, Occurrence b) {
    final byTime = a.effectiveTimeOfDay.compareTo(b.effectiveTimeOfDay);
    if (byTime != 0) return byTime;
    final byTitle =
        a.event.title.toLowerCase().compareTo(b.event.title.toLowerCase());
    if (byTitle != 0) return byTitle;
    return a.eventId.compareTo(b.eventId);
  }

  /// The stays that could line up with something on [date].
  ///
  /// Widened by the grace either side, because an 07:00 event can be matched
  /// by a stay that began at 05:30 the same morning or — for something just
  /// before midnight — one that runs into the next day. Open visits are
  /// included however long ago they began: the device has been at home since
  /// yesterday, and that is still where it is now.
  Future<List<Visit>> _visitsAround(
    CalendarDate date, {
    Duration grace = arrivalGrace,
  }) async {
    final from = date.localDateTimeAt(0).subtract(grace);
    final to = date.addDays(1).localDateTimeAt(0).add(grace);

    final rows = await (select(visits)
          ..where((v) =>
              v.arrivedAt.isSmallerThanValue(to) &
              (v.departedAt.isNull() | v.departedAt.isBiggerThanValue(from)))
          ..orderBy([(v) => OrderingTerm(expression: v.arrivedAt)]))
        .get();

    return [
      for (final row in rows)
        Visit(
          id: row.id,
          placeId: row.placeId,
          arrivedAt: row.arrivedAt,
          departedAt: row.departedAt,
        ),
    ];
  }

  /// [occurrencesForDate], re-run whenever anything it reads changes.
  ///
  /// See [liveQuery] for why this is not drift's own `.watch()`.
  Stream<List<Occurrence>> watchOccurrencesForDate(
    CalendarDate date, {
    DateTime Function()? clock,
  }) =>
      liveQuery(
        updates: attachedDatabase.tableUpdates(
          TableUpdateQuery.onAllTables([
            events,
            completions,
            overrides,
            // Arriving somewhere changes the day without changing a rule.
            visits,
            // So does declaring the day a holiday.
            holidays,
          ]),
        ),
        read: () => occurrencesForDate(date, clock: clock),
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
  ///
  /// [automatic] records that the app decided this rather than the user, which
  /// is the difference between a tick and a tick with an explanation.
  Future<void> setCompletion({
    required int eventId,
    required CalendarDate date,
    required CompletionStatus status,
    DateTime? at,
    bool automatic = false,
  }) => into(completions).insertOnConflictUpdate(CompletionsCompanion.insert(
        eventId: eventId,
        date: date,
        status: status,
        completedAt: at ?? DateTime.now(),
        isAutomatic: Value(automatic),
      ));

  /// Ticks off whatever arriving at [placeId] at [at] counts as turning up for.
  ///
  /// Called from the geofence callback, which may be running in a background
  /// isolate with the app closed — so this is deliberately a plain database
  /// operation with nothing of the running app in it.
  ///
  /// Three rules, and they are the whole feature:
  ///
  /// * only rules tied to [placeId] that asked for this,
  /// * only occurrences within [grace] of their scheduled time, and
  /// * only occurrences the user has not already decided about. A day the user
  ///   marked done, or consciously skipped, is theirs; overwriting it would
  ///   turn "I let that one go" into "you went", which is a lie the dashboard
  ///   would then repeat.
  ///
  /// A skipped or moved day is handled for free, because the candidates come
  /// from [occurrencesForDate]: a SKIP override removes the day entirely, and a
  /// MOVED one is matched against the time it was moved to.
  ///
  /// Returns what it ticked off, so a caller in the foreground can say so.
  Future<List<Occurrence>> completeOnArrival({
    required int placeId,
    required DateTime at,
    Duration grace = arrivalGrace,
  }) async {
    final completed = <Occurrence>[];

    for (final date in datesInGraceOf(at, grace: grace)) {
      // The day as it stood when the crossing happened, not as it stands now:
      // an enter delivered late is still about the moment it names.
      for (final occurrence in await occurrencesForDate(date, clock: () => at)) {
        if (!occurrence.event.completesOnArrival) continue;
        if (occurrence.event.placeId != placeId) continue;
        // Idempotent by construction: a second enter for the same stay finds
        // the occurrence already done and leaves it alone.
        if (!occurrence.isPending) continue;
        if (!arrivalCountsFor(
          date: date,
          timeOfDay: occurrence.effectiveTimeOfDay,
          arrivedAt: at,
          grace: grace,
        )) {
          continue;
        }

        await setCompletion(
          eventId: occurrence.eventId,
          date: date,
          status: CompletionStatus.done,
          // The moment of arrival, not the moment the callback ran: the OS can
          // deliver a crossing minutes late, and the tick is about when the
          // user got there.
          at: at,
          automatic: true,
        );
        completed.add(occurrence.copyWith(
          status: CompletionStatus.done,
          completedAt: at,
          isAutomatic: true,
        ));
      }
    }
    return completed;
  }

  /// Writes a stay onto the day it happened, as an event of its own.
  ///
  /// The other half of arriving somewhere. [completeOnArrival] ticks off what
  /// was planned; this covers what was not — the hour at the office on a
  /// Saturday, the trip to the shop — so the day reads as what actually
  /// happened rather than only as what was intended.
  ///
  /// It writes nothing unless the place asked for it, and nothing when a plan
  /// on the day is already showing *this* stay: the 07:00 workout picks up the
  /// arrival at 07:04 and says so on its own row, and a second row an hour
  /// later saying "Gym" is the noise this exists to remove. Judged stay by
  /// stay, by the same matcher the row itself displays with — so going back in
  /// the afternoon, which no plan is showing, still gets a row of its own
  /// rather than being swallowed by the morning's.
  ///
  /// The day and the time come from the visit, never from when the crossing
  /// was reported. Both platforms re-deliver an enter for a place the device
  /// is already sitting in — on every app start — and [at] is then this
  /// morning while the stay itself began last night.
  ///
  /// Keyed on the visit, so however many times the OS re-delivers a crossing,
  /// one stay produces one row.
  ///
  /// Returns the occurrence it wrote, or null if it wrote nothing.
  Future<Occurrence?> recordVisitAsEvent({
    required Place place,
    required int visitId,
    required DateTime at,
  }) async {
    if (!place.addVisitsToDay) return null;

    final existing = await (select(events)
          ..where((e) => e.fromVisitId.equals(visitId))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return null;

    // When the stay began, which for a re-delivered crossing is not now.
    final stay = await attachedDatabase.placesDao.visitById(visitId);
    final arrivedAt = stay?.arrivedAt ?? at;

    final date = CalendarDate.fromDateTime(arrivedAt);
    final timeOfDay = arrivedAt.hour * 60 + arrivedAt.minute;

    final onTheDay = await occurrencesForDate(date, clock: () => at);
    final alreadyAccountedFor = onTheDay.any((occurrence) =>
        !occurrence.isVisitRecord && occurrence.visit?.id == visitId);
    if (alreadyAccountedFor) return null;

    final id = await insertEvent(EventsCompanion.insert(
      title: place.name,
      colorValue: place.colorValue,
      timeOfDay: timeOfDay,
      // A visit happened once, on one day. It is not a rule, and expanding it
      // beyond its own date would be inventing a routine nobody described.
      recurrence: Recurrence.once,
      startDate: date,
      placeId: Value(place.id),
      fromVisitId: Value(visitId),
      // Nothing to remind anyone of: it has already happened.
      leadMinutes: const Value([]),
    ));

    // Done, because it is: the row records something the user did, and leaving
    // it pending would file it under Overdue and ask them to confirm they went
    // where the phone watched them go.
    await setCompletion(
      eventId: id,
      date: date,
      status: CompletionStatus.done,
      at: arrivedAt,
      automatic: true,
    );

    final written = await occurrencesForDate(date, clock: () => at);
    for (final occurrence in written) {
      if (occurrence.eventId == id) return occurrence;
    }
    return null;
  }

  /// Puts stays already in the history onto the day they happened.
  ///
  /// Writing a stay onto the day at the moment of arrival is the fast path,
  /// and it is the only path a stay ever had — so a day could miss one for
  /// reasons that have nothing to do with the day itself: **Add visits to my
  /// day** was turned on afterwards, the crossing arrived while the place was
  /// still off, or the callback never ran. Nothing went back for them, and the
  /// dashboard went on listing stays the day line had never heard of.
  ///
  /// So the day is filled in from the visits themselves, which are the record.
  /// Only stays that *began* on [date] are written here: one that ran over
  /// from the night before belongs to the night before, and the day it ran
  /// into draws it without a row of its own.
  ///
  /// Idempotent, and it declines exactly what [recordVisitAsEvent] declines —
  /// a stay with a row already, and one a plan on the day is showing. Returns
  /// how many rows it wrote.
  Future<int> fillDayFromVisits(CalendarDate date) async {
    final stays = await _visitsAround(date);
    if (stays.isEmpty) return 0;

    final placesById = {
      for (final place in await attachedDatabase.placesDao.allPlaces())
        place.id: place,
    };

    var written = 0;
    for (final stay in stays) {
      if (CalendarDate.fromDateTime(stay.arrivedAt) != date) continue;
      final place = placesById[stay.placeId];
      if (place == null || !place.addVisitsToDay) continue;

      final recorded = await recordVisitAsEvent(
        place: place,
        visitId: stay.id,
        at: stay.arrivedAt,
      );
      if (recorded != null) written++;
    }
    return written;
  }

  /// Fills in how long a recorded stay lasted, once it is over.
  ///
  /// Only touches a row still linked to the visit. Once the user has opened
  /// one in the editor it is theirs — the link is gone — and a departure must
  /// not reach back in and overwrite what they made of it.
  Future<void> closeVisitEvent(Visit visit) async {
    final departed = visit.departedAt;
    if (departed == null) return;

    final minutes = departed.difference(visit.arrivedAt).inMinutes;
    if (minutes <= 0) return;

    await (update(events)..where((e) => e.fromVisitId.equals(visit.id)))
        .write(EventsCompanion(durationMin: Value(minutes)));
  }

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
        placeId: row.placeId,
        autoCompleteOnArrival: row.autoCompleteOnArrival,
        fromVisitId: row.fromVisitId,
        holidayScope: row.holidayScope,
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
