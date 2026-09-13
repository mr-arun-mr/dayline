import 'dart:convert';

import '../model/calendar_date.dart';
import '../model/event.dart';
import '../model/holiday.dart';
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
    this.holidays = const [],
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
      holidays:
          _list(parsed['holidays']).map(BackupHoliday.fromJson).toList(),
    );
  }

  /// Bumped to 2 when places and visits were added, to 3 for auto-completion
  /// on arrival, to 4 for visits filed onto the day as events, and to 5 for
  /// holidays. Older files still restore: every field added since is optional
  /// and reads back as off.
  static const formatVersion = 5;
  static const _appName = 'dayline';

  final List<BackupEvent> events;
  final List<BackupCompletion> completions;
  final List<BackupOverride> overrides;
  final List<BackupPlace> places;
  final List<BackupVisit> visits;
  final List<BackupHoliday> holidays;

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
    'holidays': holidays.map((h) => h.toJson()).toList(),
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
    this.fromVisitId,
    this.holidayScope,
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
    fromVisitId: _optionalInt(json['fromVisitId']),
    holidayScope: _holidayScope(json['holidayScope']),
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

  /// The stay this event records, for a row the app wrote rather than the
  /// user. Remapped through the file's visit ids on the way back in.
  final int? fromVisitId;

  /// Which timetable this belongs to, and so which holidays pause it.
  final HolidayScope? holidayScope;

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
    if (fromVisitId != null) 'fromVisitId': fromVisitId,
    if (holidayScope != null) 'holidayScope': holidayScope!.name,
  };
}

class BackupHoliday {
  const BackupHoliday({
    required this.name,
    required this.startDate,
    required this.endDate,
    this.scopes = HolidayScopes.everything,
  });

  factory BackupHoliday.fromJson(Map<String, dynamic> json) => BackupHoliday(
    name: _string(json, 'name'),
    startDate: _date(json, 'startDate'),
    // A file written by hand may give only the one day, which is a range
    // whose ends are equal rather than a holiday that never ends.
    endDate: _optionalDate(json['endDate']) ?? _date(json, 'startDate'),
    scopes: _optionalInt(json['scopes']) ?? HolidayScopes.everything,
  );

  final String name;
  final CalendarDate startDate;
  final CalendarDate endDate;

  /// [HolidayScopes] mask. A plain integer in the file rather than a list of
  /// names, matching how the weekday mask is already written.
  final int scopes;

  Map<String, dynamic> toJson() => {
    'name': name,
    'startDate': startDate.toString(),
    if (endDate != startDate) 'endDate': endDate.toString(),
    if (scopes != HolidayScopes.everything) 'scopes': scopes,
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
    this.addVisitsToDay = false,
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
    addVisitsToDay: json['addVisitsToDay'] as bool? ?? false,
  );

  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final int colorValue;
  final PlaceKind kind;
  final bool isActive;
  final bool addVisitsToDay;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'colorValue': colorValue,
    'kind': kind.name,
    if (!isActive) 'isActive': false,
    if (addVisitsToDay) 'addVisitsToDay': true,
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
    this.id,
    this.departedAt,
  });

  factory BackupVisit.fromJson(Map<String, dynamic> json) => BackupVisit(
    id: _optionalInt(json['id']),
    placeId: _int(json, 'placeId'),
    arrivedAt: _instant(json, 'arrivedAt'),
    departedAt: DateTime.tryParse(json['departedAt'] as String? ?? ''),
  );

  /// Carried only so an event written to record this stay can find it again
  /// after ids are reassigned on import. Absent in files written before
  /// version 4, where nothing referred to a visit and nothing needs to.
  final int? id;

  final int placeId;
  final DateTime arrivedAt;
  final DateTime? departedAt;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
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

HolidayScope? _holidayScope(Object? value) {
  if (value == null) return null;
  for (final scope in HolidayScope.values) {
    if (scope.name == value) return scope;
  }
  // A scope this build does not know about. The event still restores; it just
  // stops pausing, which is the safe direction to fail in.
  return null;
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
