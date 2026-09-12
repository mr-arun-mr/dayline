import 'package:drift/drift.dart';

import 'database.dart';
import 'live_query.dart';
import 'tables.dart';

part 'settings_dao.g.dart';

/// App-level flags and preferences.
@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<DaylineDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// Set once the user has been shown the battery-optimisation explanation.
  static const batteryCardDismissed = 'onboarding.batteryCardDismissed';

  /// 'system', 'light' or 'dark'.
  static const themeMode = 'appearance.themeMode';

  Future<String?> read(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> write(String key, String value) =>
      into(settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: value),
      );

  Future<bool> flag(String key) async => await read(key) == 'true';

  Future<void> setFlag(String key, {required bool value}) =>
      write(key, value.toString());

  /// See [liveQuery] for why this is not drift's own `.watch()`.
  Stream<bool> watchFlag(String key) => liveQuery(
    updates: attachedDatabase.tableUpdates(
      TableUpdateQuery.onTable(settings),
    ),
    read: () => flag(key),
  );

  Stream<String?> watchValue(String key) => liveQuery(
    updates: attachedDatabase.tableUpdates(
      TableUpdateQuery.onTable(settings),
    ),
    read: () => read(key),
  );
}
