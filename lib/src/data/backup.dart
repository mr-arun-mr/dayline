import 'dart:convert';

import '../model/calendar_date.dart';
import '../model/event.dart';
import '../model/recurrence.dart';

/// The on-disk backup format.
///
/// Human-readable on purpose: there is no server to restore from, so this file
/// is the only copy of a user's routines that can leave the device. Someone
/// reading it in a text editor should be able to tell what it is, and someone
/// rebuilding it by hand should stand a chance.
///
/// Dates are written as `yyyy-MM-dd` and times as minutes since midnight,
/// matching how they are stored. No timestamps anywhere in the schedule, so a
/// backup taken in one timezone restores unchanged in another.
class Backup {
  const Backup({
    required this.events,
    required this.completions,
    required this.overrides,
    this.exportedAt,
  });

  factory Backup.decode(String raw) {
    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException catch (error) {
      throw BackupFormatException('That is not a JSON file (${error.message}).');
    }
    if (parsed is! Map<String, dynamic>) {
      throw const BackupFormatException(
        'That file does not look like a Dayline backup.',
      );
    }
    if (parsed['app'] != _appName) {
      throw const BackupFormatException('That backup was not made by Dayline.');
    }
    final version = parsed['version'];
    if (version is! int || version > formatVersion) {
      throw BackupFormatException(
        'That backup was made by a newer version of Dayline '
        '(format $version, this build understands $formatVersion).',
      );
    }

    return Backup(
      events: _list(parsed['events']).map(BackupEvent.fromJson).toList(),
      completions:
          _list(parsed['completions']).map(BackupCompletion.fromJson).toList(),
      overrides:
          _list(parsed['overrides']).map(BackupOverride.fromJson).toList(),
    );
  }

  static const formatVersion = 1;
  static const _appName = 'dayline';

  final List<BackupEvent> events;
  final List<BackupCompletion> completions;
  final List<BackupOverride> overrides;

  /// Informational only — never read back, so a skewed clock cannot affect a
  /// restore.
  final DateTime? exportedAt;

  Map<String, dynamic> toJson() => {
    'app': _appName,
    'version': formatVersion,
    if (exportedAt != null) 'exportedAt': exportedAt!.toIso8601String(),
    'events': events.map((e) => e.toJson()).toList(),
    'completions': completions.map((c) => c.toJson()).toList(),
    'overrides': overrides.map((o) => o.toJson()).toList(),
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  static List<Map<String, dynamic>> _list(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw const BackupFormatException('A section of that backup is damaged.');
    }
    return value.whereType<Map<String, dynamic>>().toList();
  }
}

/// Thrown when a file cannot be read as a backup, carrying a message written
/// for the user rather than for a log.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupEvent {
  const BackupEvent({
    required this.id,
    required this.title,
    required this.colorValue,
    required this.timeOfDay,
    required this.recurrence,
    required this.startDate,
    this.notes,
    this.durationMin,
    this.daysOfWeek = Weekdays.none,
    this.interval = 1,
    this.dayOfMonth,
    this.endDate,
    this.leadMinutes = const [],
    this.isActive = true,
  });

  factory BackupEvent.fromJson(Map<String, dynamic> json) => BackupEvent(
    id: _int(json, 'id'),
    title: _string(json, 'title'),
    notes: json['notes'] as String?,
    colorValue: _int(json, 'colorValue'),
    timeOfDay: _int(json, 'timeOfDay'),
    durationMin: _optionalInt(json['durationMin']),
    recurrence: _recurrence(json['recurrence']),
    daysOfWeek: _optionalInt(json['daysOfWeek']) ?? Weekdays.none,
    interval: _optionalInt(json['interval']) ?? 1,
    dayOfMonth: _optionalInt(json['dayOfMonth']),
    startDate: _date(json, 'startDate'),
    endDate: _optionalDate(json['endDate']),
    leadMinutes: (json['leadMinutes'] as List? ?? const [])
        .whereType<num>()
        .map((n) => n.toInt())
        .toList(),
    isActive: json['isActive'] as bool? ?? true,
  );

  final int id;
  final String title;
  final String? notes;
  final int colorValue;
  final int timeOfDay;
  final int? durationMin;
  final Recurrence recurrence;
  final int daysOfWeek;
  final int interval;
  final int? dayOfMonth;
  final CalendarDate startDate;
  final CalendarDate? endDate;
  final List<int> leadMinutes;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (notes != null) 'notes': notes,
    'colorValue': colorValue,
    'timeOfDay': timeOfDay,
    if (durationMin != null) 'durationMin': durationMin,
    'recurrence': recurrence.name,
    if (daysOfWeek != Weekdays.none) 'daysOfWeek': daysOfWeek,
    if (interval != 1) 'interval': interval,
    if (dayOfMonth != null) 'dayOfMonth': dayOfMonth,
    'startDate': startDate.toString(),
    if (endDate != null) 'endDate': endDate.toString(),
    if (leadMinutes.isNotEmpty) 'leadMinutes': leadMinutes,
    if (!isActive) 'isActive': false,
  };
}

class BackupCompletion {
  const BackupCompletion({
    required this.eventId,
    required this.date,
    required this.status,
    required this.completedAt,
  });

  factory BackupCompletion.fromJson(Map<String, dynamic> json) =>
      BackupCompletion(
        eventId: _int(json, 'eventId'),
        date: _date(json, 'date'),
        status: json['status'] == 'skipped'
            ? CompletionStatus.skipped
            : CompletionStatus.done,
        completedAt:
            DateTime.tryParse(json['completedAt'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
      );

  final int eventId;
  final CalendarDate date;
  final CompletionStatus status;
  final DateTime completedAt;

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'date': date.toString(),
    'status': status.name,
    'completedAt': completedAt.toIso8601String(),
  };
}

class BackupOverride {
  const BackupOverride({
    required this.eventId,
    required this.date,
    required this.type,
    this.newTimeOfDay,
  });

  factory BackupOverride.fromJson(Map<String, dynamic> json) => BackupOverride(
    eventId: _int(json, 'eventId'),
    date: _date(json, 'date'),
    type: json['type'] == 'moved' ? OverrideType.moved : OverrideType.skip,
    newTimeOfDay: _optionalInt(json['newTimeOfDay']),
  );

  final int eventId;
  final CalendarDate date;
  final OverrideType type;
  final int? newTimeOfDay;

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'date': date.toString(),
    'type': type.name,
    if (newTimeOfDay != null) 'newTimeOfDay': newTimeOfDay,
  };
}

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw BackupFormatException('An entry is missing its $key.');
}

int? _optionalInt(Object? value) => value is num ? value.toInt() : null;

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw BackupFormatException('An entry is missing its $key.');
}

CalendarDate _date(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw BackupFormatException('An entry is missing its $key.');
  }
  try {
    return CalendarDate.parse(value);
  } on FormatException {
    throw BackupFormatException('"$value" is not a date Dayline understands.');
  }
}

CalendarDate? _optionalDate(Object? value) {
  if (value is! String) return null;
  try {
    return CalendarDate.parse(value);
  } on FormatException {
    return null;
  }
}

Recurrence _recurrence(Object? value) {
  for (final recurrence in Recurrence.values) {
    if (recurrence.name == value) return recurrence;
  }
  throw BackupFormatException('"$value" is not a recurrence Dayline knows.');
}
