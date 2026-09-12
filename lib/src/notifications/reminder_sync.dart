import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';

import '../db/database.dart';
import 'notification_service.dart';
import 'reminder_plan.dart';

/// Keeps the OS's pending notifications in step with the rules.
///
/// The four moments the schedule can go stale are app start, app resume (which
/// is also when the rolling window needs topping up and when a timezone change
/// surfaces), any change to an event, and a reboot — that last one handled by
/// the Android boot receiver rather than here.
///
/// Event changes are picked up from the database rather than by calling
/// reconcile at every save site, so a path that forgets to call it cannot
/// exist.
class ReminderSync with WidgetsBindingObserver {
  ReminderSync({required this.database, required this.service});

  final DaylineDatabase database;
  final NotificationService service;

  StreamSubscription<void>? _changes;
  Timer? _debounce;
  ReminderPlan? _lastPlan;

  /// What the most recent reconcile scheduled. Surfaced in Settings.
  ReminderPlan? get lastPlan => _lastPlan;

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);

    _changes = database
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            database.events,
            database.overrides,
          ]),
        )
        .listen((_) => _scheduleReconcile());

    await _reconcile();
  }

  /// Coalesces a burst of writes — saving an event touches the table several
  /// times — into a single reconcile.
  void _scheduleReconcile() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reconcile);
  }

  Future<void> _reconcile() async {
    try {
      _lastPlan = await service.reconcile();
    } on Object catch (error, stackTrace) {
      // A failure here must not take the app down: the user can still see
      // their day, they just will not be reminded of it.
      debugPrint('Dayline: reconcile failed — $error\n$stackTrace');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_reconcile());
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    await _changes?.cancel();
  }
}
