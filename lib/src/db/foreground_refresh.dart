import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';

import 'database.dart';
import 'live_query.dart';

/// Re-reads what the geofence isolate wrote while the app was not looking.
///
/// A crossing is handled in a background isolate with its own connection to
/// the same file (see `geofenceTriggered`). Its writes land on disk, but
/// drift's update notifications do not cross an isolate boundary, so nothing
/// in the running app's [liveQuery] streams ever hears about them. Without
/// this, walking into the gym ticks the row off in the database and leaves it
/// looking untouched on screen until the app is restarted — which reads as a
/// feature that does not work.
///
/// Resume is the only moment it can matter: to see the stale row the user has
/// to be looking at the app, and to have arrived somewhere they have to have
/// been doing something else.
class ForegroundRefresh with WidgetsBindingObserver {
  ForegroundRefresh(this.database);

  final DaylineDatabase database;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    // A cold start opens its streams after this runs, so there is nothing to
    // refresh yet; the first read is already current.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  /// Tells every live query over the tables the isolate can touch to read
  /// again. Cheap: these are small reads over a handful of rows, and a
  /// re-read that finds nothing changed emits an identical list.
  void refresh() => database.notifyUpdates({
    TableUpdate.onTable(database.visits),
    TableUpdate.onTable(database.completions),
  });

  void dispose() => WidgetsBinding.instance.removeObserver(this);
}
