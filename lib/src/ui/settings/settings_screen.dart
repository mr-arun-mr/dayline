import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/backup.dart';
import '../../data/backup_service.dart';
import '../../db/settings_dao.dart';
import '../../model/holiday.dart';
import '../../providers.dart';
import '../holidays/holidays_screen.dart';
import '../places/places_screen.dart';
import '../theme.dart';

/// Permissions, appearance, and getting the data in and out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: const [
          _SectionLabel('Reminders'),
          _NotificationStatus(),
          _BatteryHelpCard(),
          Divider(height: 24),
          _SectionLabel('Places'),
          _LocationStatus(),
          Divider(height: 24),
          _SectionLabel('Appearance'),
          _ThemePicker(),
          Divider(height: 24),
          _SectionLabel('Your data'),
          _ExportTile(),
          _ImportTile(),
          _DataFootnote(),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      DaylineTheme.gutter,
      18,
      DaylineTheme.gutter,
      4,
    ),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _NotificationStatus extends ConsumerWidget {
  const _NotificationStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final granted = ref.watch(notificationPermissionProvider).value;
    final exact = ref.watch(exactAlarmPermissionProvider).value;

    return Column(
      children: [
        ListTile(
          minTileHeight: DaylineTheme.rowMinHeight,
          leading: Icon(
            granted == false
                ? Icons.notifications_off_outlined
                : Icons.notifications_active_outlined,
            color: granted == false ? scheme.error : scheme.primary,
          ),
          title: const Text('Notifications'),
          subtitle: Text(switch (granted) {
            true => 'Allowed',
            false => 'Blocked — reminders will not arrive',
            null => 'Checking…',
          }),
          trailing: granted == false
              ? FilledButton(
                  onPressed: () async {
                    await ref
                        .read(notificationServiceProvider)
                        .requestPermissions();
                    ref.invalidate(notificationPermissionProvider);
                    ref.invalidate(exactAlarmPermissionProvider);
                  },
                  child: const Text('Allow'),
                )
              : null,
        ),
        // Android only: iOS has no equivalent, and showing a row that always
        // reads "Allowed" would be noise.
        if (defaultTargetPlatform == TargetPlatform.android)
          ListTile(
            minTileHeight: DaylineTheme.rowMinHeight,
            leading: Icon(
              Icons.alarm,
              color: exact == false ? scheme.error : scheme.primary,
            ),
            title: const Text('Exact alarms'),
            subtitle: Text(switch (exact) {
              true => 'Reminders arrive on the minute',
              false => 'Off — reminders may arrive late by several minutes',
              null => 'Checking…',
            }),
          ),
      ],
    );
  }
}

/// Whether the OS will report arrivals while the app is closed.
class _LocationStatus extends ConsumerWidget {
  const _LocationStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final granted = ref.watch(backgroundLocationProvider).value;

    return Column(
      children: [
        ListTile(
          minTileHeight: DaylineTheme.rowMinHeight,
          leading: Icon(
            granted == true
                ? Icons.location_on_outlined
                : Icons.location_off_outlined,
            color: granted == true ? scheme.primary : scheme.onSurfaceVariant,
          ),
          title: const Text('Background location'),
          subtitle: Text(switch (granted) {
            true => 'Arrivals and departures are being recorded',
            false => 'Off — places will not notice you arriving',
            null => 'Checking…',
          }),
          trailing: granted == false
              ? FilledButton(
                  onPressed: () async {
                    await ref
                        .read(geofenceServiceProvider)
                        .requestPermission();
                    ref.invalidate(backgroundLocationProvider);
                    await ref.read(geofenceServiceProvider).reconcile();
                  },
                  child: const Text('Allow'),
                )
              : null,
        ),
        ListTile(
          minTileHeight: DaylineTheme.rowMinHeight,
          leading: const Icon(Icons.place_outlined),
          title: const Text('Manage places'),
          subtitle: const Text('Add, edit or remove the places you track'),
          onTap: () => PlacesScreen.open(context),
        ),
        const _HolidaysTile(),
        ListTile(
          minTileHeight: DaylineTheme.rowMinHeight,
          leading: Icon(Icons.delete_sweep_outlined, color: scheme.error),
          title: const Text('Forget visit history'),
          subtitle: const Text('Keeps your places, deletes where you have been'),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Forget visit history?'),
                content: const Text(
                  'Every arrival and departure ever recorded will be deleted. '
                  'Your places are kept. This cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Forget'),
                  ),
                ],
              ),
            );
            if (confirmed != true) return;
            final removed = await ref.read(placesDaoProvider).clearHistory();
            if (context.mounted) {
              _tell(context, 'Forgot $removed visit'
                  '${removed == 1 ? '' : 's'}.');
            }
          },
        ),
      ],
    );
  }
}

class _BatteryHelpCard extends StatelessWidget {
  const _BatteryHelpCard();

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        8,
        DaylineTheme.gutter,
        4,
      ),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.battery_alert_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Reminders not arriving?',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Xiaomi, Oppo, Huawei, Vivo and Samsung phones stop background '
                'alarms to save battery, usually without saying so. Open '
                'Settings › Apps › Dayline › Battery and choose Unrestricted. '
                'The wording differs by manufacturer — look for anything about '
                'background activity or app launch.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.system;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DaylineTheme.gutter,
        vertical: 8,
      ),
      child: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('System')),
          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
        ],
        selected: {mode},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => ref
            .read(settingsDaoProvider)
            .write(SettingsDao.themeMode, selection.single.name),
      ),
    );
  }
}

class _ExportTile extends ConsumerStatefulWidget {
  const _ExportTile();

  @override
  ConsumerState<_ExportTile> createState() => _ExportTileState();
}

class _ExportTileState extends ConsumerState<_ExportTile> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final json = await ref.read(backupServiceProvider).exportJson(at: now);

      // Written to a temp file and handed to the share sheet rather than
      // uploaded anywhere — where it goes next is the user's choice, and the
      // app has no network permission to make that choice for them.
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/${BackupService.suggestedFileName(now)}',
      );
      await file.writeAsString(json);

      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Dayline backup',
        ),
      );
    } on Object catch (error) {
      if (mounted) _tell(context, "Couldn't export: $error");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: DaylineTheme.rowMinHeight,
    leading: const Icon(Icons.ios_share),
    title: const Text('Export'),
    subtitle: const Text('Save everything as a JSON file'),
    trailing: _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null,
    onTap: _busy ? null : _export,
  );
}

class _ImportTile extends ConsumerStatefulWidget {
  const _ImportTile();

  @override
  ConsumerState<_ImportTile> createState() => _ImportTileState();
}

class _ImportTileState extends ConsumerState<_ImportTile> {
  bool _busy = false;

  Future<void> _import() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Choose a Dayline backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked == null || !mounted) return;

    final String raw;
    try {
      // Read through the picker rather than by path: on Android a picked file
      // often arrives as a content:// URI with no filesystem path at all.
      raw = utf8.decode(await picked.readAsBytes());
    } on Object catch (error) {
      if (mounted) _tell(context, "Couldn't read that file: $error");
      return;
    }

    final Backup backup;
    try {
      backup = Backup.decode(raw);
    } on BackupFormatException catch (error) {
      if (mounted) _tell(context, error.message);
      return;
    }

    if (!mounted) return;
    final mode = await _askMode(context, backup);
    if (mode == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final result =
          await ref.read(backupServiceProvider).import(backup, mode: mode);
      if (mounted) {
        _tell(
          context,
          'Restored ${result.events} '
          'event${result.events == 1 ? '' : 's'}.',
        );
      }
    } on Object catch (error) {
      if (mounted) _tell(context, "Couldn't import: $error");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Replacing throws away everything currently stored, so it is never the
  /// default and the dialog says what it will cost.
  Future<ImportMode?> _askMode(BuildContext context, Backup backup) =>
      showDialog<ImportMode>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import backup'),
          content: Text(
            'This file holds ${backup.events.length} '
            'event${backup.events.length == 1 ? '' : 's'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImportMode.merge),
              child: const Text('Add to mine'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(ImportMode.replace),
              child: const Text('Replace everything'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: DaylineTheme.rowMinHeight,
    leading: const Icon(Icons.file_download_outlined),
    title: const Text('Import'),
    subtitle: const Text('Restore from a Dayline JSON file'),
    trailing: _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null,
    onTap: _busy ? null : _import,
  );
}

class _DataFootnote extends StatelessWidget {
  const _DataFootnote();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      DaylineTheme.gutter,
      16,
      DaylineTheme.gutter,
      0,
    ),
    child: Text(
      'Dayline keeps everything on this device and asks for no internet '
      'permission at all. A backup file is the only copy that can leave it, '
      'and only when you send it somewhere yourself.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
    ),
  );
}

void _tell(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

/// The way in to holidays, with a count so the row says whether there are any.
class _HolidaysTile extends ConsumerWidget {
  const _HolidaysTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holidays = ref.watch(holidaysProvider).value ?? const <Holiday>[];
    final today = ref.watch(todayProvider);
    final onToday = holidaysOn(holidays, today);
    final upcoming =
        holidays.where((h) => !h.endDate.isBefore(today)).length;

    return ListTile(
      minTileHeight: DaylineTheme.rowMinHeight,
      leading: const Icon(Icons.beach_access_outlined),
      title: const Text('Holidays'),
      subtitle: Text(
        switch ((onToday.isNotEmpty, upcoming)) {
          (true, _) => 'Today is ${onToday.first.name}',
          (false, 0) => 'Days when work or school steps aside',
          (false, 1) => '1 coming up',
          (false, final count) => '$count coming up',
        },
      ),
      onTap: () => HolidaysScreen.open(context),
    );
  }
}

