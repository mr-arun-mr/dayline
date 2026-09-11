import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'db/events_dao.dart';
import 'model/calendar_date.dart';
import 'model/occurrence.dart';

/// Overridden in `main` with the opened database, so widget tests can hand in
/// an in-memory one instead.
final databaseProvider = Provider<DaylineDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final eventsDaoProvider =
    Provider<EventsDao>((ref) => ref.watch(databaseProvider).eventsDao);

/// Where "now" comes from.
///
/// Behind a provider rather than called inline so that the screen can be
/// rendered at a chosen moment — for screenshots, and for the tests that check
/// what falls either side of the now line.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The real current date, which changes while the app is open.
///
/// An app whose whole job is "today" cannot afford to still say Thursday at
/// 00:05 on Friday, so this reschedules itself onto each local midnight rather
/// than polling. Built from a local [DateTime], so the DST night where
/// midnight is 23 or 25 hours away still lands correctly.
class TodayNotifier extends Notifier<CalendarDate> {
  Timer? _timer;

  @override
  CalendarDate build() {
    ref.onDispose(() => _timer?.cancel());
    _scheduleRollover();
    return CalendarDate.fromDateTime(ref.read(clockProvider)());
  }

  void _scheduleRollover() {
    final now = ref.read(clockProvider)();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _timer?.cancel();
    _timer = Timer(
      // A second past the hour, so we are never racing the clock itself.
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        state = CalendarDate.fromDateTime(ref.read(clockProvider)());
        _scheduleRollover();
      },
    );
  }
}

final todayProvider =
    NotifierProvider<TodayNotifier, CalendarDate>(TodayNotifier.new);

/// The day being looked at. Starts on today and follows it across midnight
/// unless the user has scrubbed somewhere else.
class SelectedDateNotifier extends Notifier<CalendarDate> {
  CalendarDate? _pinned;

  @override
  CalendarDate build() {
    final today = ref.watch(todayProvider);
    final pinned = _pinned;
    // Deliberately drop a pin that midnight has turned into the past.
    if (pinned != null && !pinned.isBefore(today)) return pinned;
    _pinned = null;
    return today;
  }

  void select(CalendarDate date) {
    _pinned = date;
    state = date;
  }

  void goToToday() {
    _pinned = null;
    state = ref.read(todayProvider);
  }
}

final selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, CalendarDate>(
  SelectedDateNotifier.new,
);

/// Everything happening on one date, kept live.
final occurrencesProvider =
    StreamProvider.family<List<Occurrence>, CalendarDate>(
  (ref, date) => ref.watch(eventsDaoProvider).watchOccurrencesForDate(date),
);

/// A one-second tick, for the "next up" countdown only.
///
/// Kept behind its own provider so that exactly one widget rebuilds per
/// second instead of the whole screen.
final secondTickProvider = StreamProvider<DateTime>(
  (ref) => Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  ).map((now) => now),
);
