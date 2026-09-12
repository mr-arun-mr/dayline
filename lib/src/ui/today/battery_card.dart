import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/settings_dao.dart';
import '../../providers.dart';
import '../theme.dart';

/// The one-time warning that some Android phones kill alarms.
///
/// Xiaomi, Oppo, Huawei, Vivo and Samsung all ship aggressive battery managers
/// that stop background alarms without telling anyone, and the usual symptom is
/// a user deciding the app is broken. Saying so once, up front, is cheaper than
/// the support thread.
///
/// Shown on Android only, and only until dismissed — the flag lives in the
/// database, so it survives reinstall of state but not of the app itself.
class BatteryOptimisationCard extends ConsumerWidget {
  const BatteryOptimisationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }

    final dismissed = ref.watch(batteryCardDismissedProvider).value ?? true;
    if (dismissed) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        8,
        DaylineTheme.gutter,
        4,
      ),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.battery_alert_outlined, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Keep reminders working',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Some phones — Xiaomi, Oppo, Huawei, Vivo and Samsung in '
                'particular — stop background alarms to save battery, without '
                'telling you. If reminders stop arriving, find Dayline in '
                'Settings › Apps, and set battery usage to Unrestricted.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => ref
                      .read(settingsDaoProvider)
                      .setFlag(SettingsDao.batteryCardDismissed, value: true),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
