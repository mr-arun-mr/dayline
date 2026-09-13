import 'dart:convert';

import '../model/calendar_date.dart';
import '../model/event.dart';
import '../model/place.dart';
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
    this.places = const [],
    this.visits = const [],
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
      places: _list(parsed['places']).map(BackupPlace.fromJson).toList(),
      visits: _list(parsed['visits']).map(BackupVisit.fromJson).toList(),
    );
  }

  /// Bumped to 2 when places and visits were added, and to 3 for
  /// auto-completion on arrival. Older files still restore: every field added
  /// since is optional and reads back as off.
  static const formatVersion = 3;
  static const _appName = 'dayline';

  final List<BackupEvent> events;
  final List<BackupCompletion> completions;
  final List<BackupOverride> overrides;
  final List<BackupPlace> places;
  final List<BackupVisit> visits;

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
    'places': places.map((p) => p.toJson()).toList(),
    'visits': visits.map((v) => v.toJson()).toList(),
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
    this.placeId,
    this.autoCompleteOnArrival = false,
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
    placeId: _optionalInt(json['placeId']),
    autoCompleteOnArrival: json['autoCompleteOnArrival'] as bool? ?? false,
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
  final int? placeId;
  final bool autoCompleteOnArrival;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (notes != null) 'notes': notes,
    'colorValue': colorValue,
    'timeOfDay': timeOfDay,
    if (placeId != null) 'placeId': placeId,
    if (durationMin != null) 'durationMin': durationMin,
    'recurrence': recurrence.name,
    if (daysOfWeek != Weekdays.none) 'daysOfWeek': daysOfWeek,
    if (interval != 1) 'interval': interval,
    if (dayOfMonth != null) 'dayOfMonth': dayOfMonth,
    'startDate': startDate.toString(),
    if (endDate != null) 'endDate': endDate.toString(),
    if (leadMinutes.isNotEmpty) 'leadMinutes': leadMinutes,
    if (!isActive) 'isActive': false,
    if (autoCompleteOnArrival) 'autoCompleteOnArrival': true,
  };
}

class BackupCompletion {
  const BackupCompletion({
    required this.eventId,
    required this.date,
    required this.status,
    required this.completedAt,
    this.isAutomatic = false,
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
        isAutomatic: json['auto'] as bool? ?? false,
      );

  final int eventId;
  final CalendarDate date;
  final CompletionStatus status;
  final DateTime completedAt;

  /// Whether the app ticked this off on arrival rather than the user. Written
  /// as `auto` because it reads as a note on the row rather than a field name.
  final bool isAutomatic;

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'date': date.toString(),
    'status': status.name,
    'completedAt': completedAt.toIso8601String(),
    if (isAutomatic) 'auto': true,
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

class BackupPlace {
  const BackupPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.colorValue,
    required this.kind,
    this.isActive = true,
  });

  factory BackupPlace.fromJson(Map<String, dynamic> json) => BackupPlace(
    id: _int(json, 'id'),
    name: _string(json, 'name'),
    latitude: _double(json, 'latitude'),
    longitude: _double(json, 'longitude'),
    radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 150,
    colorValue: _int(json, 'colorValue'),
    kind: _placeKind(json['kind']),
    isActive: json['isActive'] as bool? ?? true,
  );

  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final int colorValue;
  final PlaceKind kind;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'colorValue': colorValue,
    'kind': kind.name,
    if (!isActive) 'isActive': false,
  };
}

/// A recorded stay.
///
/// Unlike everything else in a backup these are real instants, because a visit
/// is something that happened at a moment rather than something scheduled for
/// a time. They are written as ISO-8601 with an offset so a restore in another
/// timezone still points at the same moment.
class BackupVisit {
  const BackupVisit({
    required this.placeId,
    required this.arrivedAt,
    this.departedAt,
  });

  factory BackupVisit.fromJson(Map<String, dynamic> json) => BackupVisit(
    placeId: _int(json, 'placeId'),
    arrivedAt: _instant(json, 'arrivedAt'),
    departedAt: DateTime.tryParse(json['departedAt'] as String? ?? ''),
  );

  final int placeId;
  final DateTime arrivedAt;
  final DateTime? departedAt;

  Map<String, dynamic> toJson() => {
    'placeId': placeId,
    'arrivedAt': arrivedAt.toIso8601String(),
    if (departedAt != null) 'departedAt': departedAt!.toIso8601String(),
  };
}

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw BackupFormatException('An entry is missing its $key.');
}

int? _optionalInt(Object? value) => value is num ? value.toInt() : null;

double _double(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw BackupFormatException('An entry is missing its $key.');
}

DateTime _instant(Map<String, dynamic> json, String key) {
  final parsed = DateTime.tryParse(json[key] as String? ?? '');
  if (parsed == null) {
    throw BackupFormatException('An entry is missing its $key.');
  }
  return parsed;
}

PlaceKind _placeKind(Object? value) {
  for (final kind in PlaceKind.values) {
    if (kind.name == value) return kind;
  }
  return PlaceKind.other;
}

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
