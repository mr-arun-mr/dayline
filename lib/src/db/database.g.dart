// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PlacesTable extends Places with TableInfo<$PlacesTable, PlaceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _radiusMetersMeta = const VerificationMeta(
    'radiusMeters',
  );
  @override
  late final GeneratedColumn<double> radiusMeters = GeneratedColumn<double>(
    'radius_meters',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(150),
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PlaceKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<PlaceKind>($PlacesTable.$converterkind);
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _addVisitsToDayMeta = const VerificationMeta(
    'addVisitsToDay',
  );
  @override
  late final GeneratedColumn<bool> addVisitsToDay = GeneratedColumn<bool>(
    'add_visits_to_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("add_visits_to_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    latitude,
    longitude,
    radiusMeters,
    colorValue,
    kind,
    isActive,
    addVisitsToDay,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'places';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('radius_meters')) {
      context.handle(
        _radiusMetersMeta,
        radiusMeters.isAcceptableOrUnknown(
          data['radius_meters']!,
          _radiusMetersMeta,
        ),
      );
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('add_visits_to_day')) {
      context.handle(
        _addVisitsToDayMeta,
        addVisitsToDay.isAcceptableOrUnknown(
          data['add_visits_to_day']!,
          _addVisitsToDayMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      radiusMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}radius_meters'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      kind: $PlacesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      addVisitsToDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}add_visits_to_day'],
      )!,
    );
  }

  @override
  $PlacesTable createAlias(String alias) {
    return $PlacesTable(attachedDatabase, alias);
  }

  static TypeConverter<PlaceKind, int> $converterkind =
      const PlaceKindConverter();
}

class PlaceRow extends DataClass implements Insertable<PlaceRow> {
  final int id;
  final String name;
  final double latitude;
  final double longitude;

  /// How close counts as "here", in metres.
  final double radiusMeters;
  final int colorValue;
  final PlaceKind kind;
  final bool isActive;

  /// Put a stay at this place onto the day it happened, as an event.
  ///
  /// Off by default and per place, because it is the one setting that writes
  /// rows the user did not ask for. Sensible for the gym and the office;
  /// wrong for home, which would otherwise file an event every evening.
  final bool addVisitsToDay;
  const PlaceRow({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.colorValue,
    required this.kind,
    required this.isActive,
    required this.addVisitsToDay,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['radius_meters'] = Variable<double>(radiusMeters);
    map['color_value'] = Variable<int>(colorValue);
    {
      map['kind'] = Variable<int>($PlacesTable.$converterkind.toSql(kind));
    }
    map['is_active'] = Variable<bool>(isActive);
    map['add_visits_to_day'] = Variable<bool>(addVisitsToDay);
    return map;
  }

  PlacesCompanion toCompanion(bool nullToAbsent) {
    return PlacesCompanion(
      id: Value(id),
      name: Value(name),
      latitude: Value(latitude),
      longitude: Value(longitude),
      radiusMeters: Value(radiusMeters),
      colorValue: Value(colorValue),
      kind: Value(kind),
      isActive: Value(isActive),
      addVisitsToDay: Value(addVisitsToDay),
    );
  }

  factory PlaceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaceRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      radiusMeters: serializer.fromJson<double>(json['radiusMeters']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      kind: serializer.fromJson<PlaceKind>(json['kind']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      addVisitsToDay: serializer.fromJson<bool>(json['addVisitsToDay']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'radiusMeters': serializer.toJson<double>(radiusMeters),
      'colorValue': serializer.toJson<int>(colorValue),
      'kind': serializer.toJson<PlaceKind>(kind),
      'isActive': serializer.toJson<bool>(isActive),
      'addVisitsToDay': serializer.toJson<bool>(addVisitsToDay),
    };
  }

  PlaceRow copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    int? colorValue,
    PlaceKind? kind,
    bool? isActive,
    bool? addVisitsToDay,
  }) => PlaceRow(
    id: id ?? this.id,
    name: name ?? this.name,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    colorValue: colorValue ?? this.colorValue,
    kind: kind ?? this.kind,
    isActive: isActive ?? this.isActive,
    addVisitsToDay: addVisitsToDay ?? this.addVisitsToDay,
  );
  PlaceRow copyWithCompanion(PlacesCompanion data) {
    return PlaceRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      radiusMeters: data.radiusMeters.present
          ? data.radiusMeters.value
          : this.radiusMeters,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      kind: data.kind.present ? data.kind.value : this.kind,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      addVisitsToDay: data.addVisitsToDay.present
          ? data.addVisitsToDay.value
          : this.addVisitsToDay,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaceRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('colorValue: $colorValue, ')
          ..write('kind: $kind, ')
          ..write('isActive: $isActive, ')
          ..write('addVisitsToDay: $addVisitsToDay')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    latitude,
    longitude,
    radiusMeters,
    colorValue,
    kind,
    isActive,
    addVisitsToDay,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaceRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.radiusMeters == this.radiusMeters &&
          other.colorValue == this.colorValue &&
          other.kind == this.kind &&
          other.isActive == this.isActive &&
          other.addVisitsToDay == this.addVisitsToDay);
}

class PlacesCompanion extends UpdateCompanion<PlaceRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double> radiusMeters;
  final Value<int> colorValue;
  final Value<PlaceKind> kind;
  final Value<bool> isActive;
  final Value<bool> addVisitsToDay;
  const PlacesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.radiusMeters = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.kind = const Value.absent(),
    this.isActive = const Value.absent(),
    this.addVisitsToDay = const Value.absent(),
  });
  PlacesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required double latitude,
    required double longitude,
    this.radiusMeters = const Value.absent(),
    required int colorValue,
    required PlaceKind kind,
    this.isActive = const Value.absent(),
    this.addVisitsToDay = const Value.absent(),
  }) : name = Value(name),
       latitude = Value(latitude),
       longitude = Value(longitude),
       colorValue = Value(colorValue),
       kind = Value(kind);
  static Insertable<PlaceRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? radiusMeters,
    Expression<int>? colorValue,
    Expression<int>? kind,
    Expression<bool>? isActive,
    Expression<bool>? addVisitsToDay,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (radiusMeters != null) 'radius_meters': radiusMeters,
      if (colorValue != null) 'color_value': colorValue,
      if (kind != null) 'kind': kind,
      if (isActive != null) 'is_active': isActive,
      if (addVisitsToDay != null) 'add_visits_to_day': addVisitsToDay,
    });
  }

  PlacesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<double>? radiusMeters,
    Value<int>? colorValue,
    Value<PlaceKind>? kind,
    Value<bool>? isActive,
    Value<bool>? addVisitsToDay,
  }) {
    return PlacesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      colorValue: colorValue ?? this.colorValue,
      kind: kind ?? this.kind,
      isActive: isActive ?? this.isActive,
      addVisitsToDay: addVisitsToDay ?? this.addVisitsToDay,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (radiusMeters.present) {
      map['radius_meters'] = Variable<double>(radiusMeters.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $PlacesTable.$converterkind.toSql(kind.value),
      );
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (addVisitsToDay.present) {
      map['add_visits_to_day'] = Variable<bool>(addVisitsToDay.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlacesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('colorValue: $colorValue, ')
          ..write('kind: $kind, ')
          ..write('isActive: $isActive, ')
          ..write('addVisitsToDay: $addVisitsToDay')
          ..write(')'))
        .toString();
  }
}

class $VisitsTable extends Visits with TableInfo<$VisitsTable, VisitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _placeIdMeta = const VerificationMeta(
    'placeId',
  );
  @override
  late final GeneratedColumn<int> placeId = GeneratedColumn<int>(
    'place_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES places(id) ON DELETE CASCADE',
  );
  static const VerificationMeta _arrivedAtMeta = const VerificationMeta(
    'arrivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> arrivedAt = GeneratedColumn<DateTime>(
    'arrived_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _departedAtMeta = const VerificationMeta(
    'departedAt',
  );
  @override
  late final GeneratedColumn<DateTime> departedAt = GeneratedColumn<DateTime>(
    'departed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, placeId, arrivedAt, departedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visits';
  @override
  VerificationContext validateIntegrity(
    Insertable<VisitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('place_id')) {
      context.handle(
        _placeIdMeta,
        placeId.isAcceptableOrUnknown(data['place_id']!, _placeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_placeIdMeta);
    }
    if (data.containsKey('arrived_at')) {
      context.handle(
        _arrivedAtMeta,
        arrivedAt.isAcceptableOrUnknown(data['arrived_at']!, _arrivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_arrivedAtMeta);
    }
    if (data.containsKey('departed_at')) {
      context.handle(
        _departedAtMeta,
        departedAt.isAcceptableOrUnknown(data['departed_at']!, _departedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VisitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisitRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      placeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}place_id'],
      )!,
      arrivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}arrived_at'],
      )!,
      departedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}departed_at'],
      ),
    );
  }

  @override
  $VisitsTable createAlias(String alias) {
    return $VisitsTable(attachedDatabase, alias);
  }
}

class VisitRow extends DataClass implements Insertable<VisitRow> {
  final int id;
  final int placeId;

  /// Real instants, not wall clock: a visit is a thing that happened at a
  /// moment, unlike a schedule, which is a thing that happens at a time.
  final DateTime arrivedAt;

  /// Null while the device is still inside the geofence.
  final DateTime? departedAt;
  const VisitRow({
    required this.id,
    required this.placeId,
    required this.arrivedAt,
    this.departedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['place_id'] = Variable<int>(placeId);
    map['arrived_at'] = Variable<DateTime>(arrivedAt);
    if (!nullToAbsent || departedAt != null) {
      map['departed_at'] = Variable<DateTime>(departedAt);
    }
    return map;
  }

  VisitsCompanion toCompanion(bool nullToAbsent) {
    return VisitsCompanion(
      id: Value(id),
      placeId: Value(placeId),
      arrivedAt: Value(arrivedAt),
      departedAt: departedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(departedAt),
    );
  }

  factory VisitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VisitRow(
      id: serializer.fromJson<int>(json['id']),
      placeId: serializer.fromJson<int>(json['placeId']),
      arrivedAt: serializer.fromJson<DateTime>(json['arrivedAt']),
      departedAt: serializer.fromJson<DateTime?>(json['departedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'placeId': serializer.toJson<int>(placeId),
      'arrivedAt': serializer.toJson<DateTime>(arrivedAt),
      'departedAt': serializer.toJson<DateTime?>(departedAt),
    };
  }

  VisitRow copyWith({
    int? id,
    int? placeId,
    DateTime? arrivedAt,
    Value<DateTime?> departedAt = const Value.absent(),
  }) => VisitRow(
    id: id ?? this.id,
    placeId: placeId ?? this.placeId,
    arrivedAt: arrivedAt ?? this.arrivedAt,
    departedAt: departedAt.present ? departedAt.value : this.departedAt,
  );
  VisitRow copyWithCompanion(VisitsCompanion data) {
    return VisitRow(
      id: data.id.present ? data.id.value : this.id,
      placeId: data.placeId.present ? data.placeId.value : this.placeId,
      arrivedAt: data.arrivedAt.present ? data.arrivedAt.value : this.arrivedAt,
      departedAt: data.departedAt.present
          ? data.departedAt.value
          : this.departedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VisitRow(')
          ..write('id: $id, ')
          ..write('placeId: $placeId, ')
          ..write('arrivedAt: $arrivedAt, ')
          ..write('departedAt: $departedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, placeId, arrivedAt, departedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisitRow &&
          other.id == this.id &&
          other.placeId == this.placeId &&
          other.arrivedAt == this.arrivedAt &&
          other.departedAt == this.departedAt);
}

class VisitsCompanion extends UpdateCompanion<VisitRow> {
  final Value<int> id;
  final Value<int> placeId;
  final Value<DateTime> arrivedAt;
  final Value<DateTime?> departedAt;
  const VisitsCompanion({
    this.id = const Value.absent(),
    this.placeId = const Value.absent(),
    this.arrivedAt = const Value.absent(),
    this.departedAt = const Value.absent(),
  });
  VisitsCompanion.insert({
    this.id = const Value.absent(),
    required int placeId,
    required DateTime arrivedAt,
    this.departedAt = const Value.absent(),
  }) : placeId = Value(placeId),
       arrivedAt = Value(arrivedAt);
  static Insertable<VisitRow> custom({
    Expression<int>? id,
    Expression<int>? placeId,
    Expression<DateTime>? arrivedAt,
    Expression<DateTime>? departedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (placeId != null) 'place_id': placeId,
      if (arrivedAt != null) 'arrived_at': arrivedAt,
      if (departedAt != null) 'departed_at': departedAt,
    });
  }

  VisitsCompanion copyWith({
    Value<int>? id,
    Value<int>? placeId,
    Value<DateTime>? arrivedAt,
    Value<DateTime?>? departedAt,
  }) {
    return VisitsCompanion(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      departedAt: departedAt ?? this.departedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (placeId.present) {
      map['place_id'] = Variable<int>(placeId.value);
    }
    if (arrivedAt.present) {
      map['arrived_at'] = Variable<DateTime>(arrivedAt.value);
    }
    if (departedAt.present) {
      map['departed_at'] = Variable<DateTime>(departedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisitsCompanion(')
          ..write('id: $id, ')
          ..write('placeId: $placeId, ')
          ..write('arrivedAt: $arrivedAt, ')
          ..write('departedAt: $departedAt')
          ..write(')'))
        .toString();
  }
}

class $EventsTable extends Events with TableInfo<$EventsTable, EventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeOfDayMeta = const VerificationMeta(
    'timeOfDay',
  );
  @override
  late final GeneratedColumn<int> timeOfDay = GeneratedColumn<int>(
    'time_of_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMinMeta = const VerificationMeta(
    'durationMin',
  );
  @override
  late final GeneratedColumn<int> durationMin = GeneratedColumn<int>(
    'duration_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Recurrence, int> recurrence =
      GeneratedColumn<int>(
        'recurrence',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Recurrence>($EventsTable.$converterrecurrence);
  static const VerificationMeta _daysOfWeekMeta = const VerificationMeta(
    'daysOfWeek',
  );
  @override
  late final GeneratedColumn<int> daysOfWeek = GeneratedColumn<int>(
    'days_of_week',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _intervalMeta = const VerificationMeta(
    'interval',
  );
  @override
  late final GeneratedColumn<int> interval = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _dayOfMonthMeta = const VerificationMeta(
    'dayOfMonth',
  );
  @override
  late final GeneratedColumn<int> dayOfMonth = GeneratedColumn<int>(
    'day_of_month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CalendarDate, int> startDate =
      GeneratedColumn<int>(
        'start_date',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<CalendarDate>($EventsTable.$converterstartDate);
  @override
  late final GeneratedColumnWithTypeConverter<CalendarDate?, int> endDate =
      GeneratedColumn<int>(
        'end_date',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<CalendarDate?>($EventsTable.$converterendDaten);
  @override
  late final GeneratedColumnWithTypeConverter<List<int>, String> leadMinutes =
      GeneratedColumn<String>(
        'lead_minutes',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<int>>($EventsTable.$converterleadMinutes);
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _placeIdMeta = const VerificationMeta(
    'placeId',
  );
  @override
  late final GeneratedColumn<int> placeId = GeneratedColumn<int>(
    'place_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES places(id) ON DELETE SET NULL',
  );
  static const VerificationMeta _autoCompleteOnArrivalMeta =
      const VerificationMeta('autoCompleteOnArrival');
  @override
  late final GeneratedColumn<bool> autoCompleteOnArrival =
      GeneratedColumn<bool>(
        'auto_complete_on_arrival',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("auto_complete_on_arrival" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _fromVisitIdMeta = const VerificationMeta(
    'fromVisitId',
  );
  @override
  late final GeneratedColumn<int> fromVisitId = GeneratedColumn<int>(
    'from_visit_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES visits(id) ON DELETE CASCADE',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    notes,
    colorValue,
    timeOfDay,
    durationMin,
    recurrence,
    daysOfWeek,
    interval,
    dayOfMonth,
    startDate,
    endDate,
    leadMinutes,
    isActive,
    placeId,
    autoCompleteOnArrival,
    fromVisitId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('time_of_day')) {
      context.handle(
        _timeOfDayMeta,
        timeOfDay.isAcceptableOrUnknown(data['time_of_day']!, _timeOfDayMeta),
      );
    } else if (isInserting) {
      context.missing(_timeOfDayMeta);
    }
    if (data.containsKey('duration_min')) {
      context.handle(
        _durationMinMeta,
        durationMin.isAcceptableOrUnknown(
          data['duration_min']!,
          _durationMinMeta,
        ),
      );
    }
    if (data.containsKey('days_of_week')) {
      context.handle(
        _daysOfWeekMeta,
        daysOfWeek.isAcceptableOrUnknown(
          data['days_of_week']!,
          _daysOfWeekMeta,
        ),
      );
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalMeta,
        interval.isAcceptableOrUnknown(data['interval_days']!, _intervalMeta),
      );
    }
    if (data.containsKey('day_of_month')) {
      context.handle(
        _dayOfMonthMeta,
        dayOfMonth.isAcceptableOrUnknown(
          data['day_of_month']!,
          _dayOfMonthMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('place_id')) {
      context.handle(
        _placeIdMeta,
        placeId.isAcceptableOrUnknown(data['place_id']!, _placeIdMeta),
      );
    }
    if (data.containsKey('auto_complete_on_arrival')) {
      context.handle(
        _autoCompleteOnArrivalMeta,
        autoCompleteOnArrival.isAcceptableOrUnknown(
          data['auto_complete_on_arrival']!,
          _autoCompleteOnArrivalMeta,
        ),
      );
    }
    if (data.containsKey('from_visit_id')) {
      context.handle(
        _fromVisitIdMeta,
        fromVisitId.isAcceptableOrUnknown(
          data['from_visit_id']!,
          _fromVisitIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      timeOfDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_of_day'],
      )!,
      durationMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_min'],
      ),
      recurrence: $EventsTable.$converterrecurrence.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}recurrence'],
        )!,
      ),
      daysOfWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}days_of_week'],
      )!,
      interval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      )!,
      dayOfMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_month'],
      ),
      startDate: $EventsTable.$converterstartDate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}start_date'],
        )!,
      ),
      endDate: $EventsTable.$converterendDaten.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}end_date'],
        ),
      ),
      leadMinutes: $EventsTable.$converterleadMinutes.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}lead_minutes'],
        )!,
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      placeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}place_id'],
      ),
      autoCompleteOnArrival: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_complete_on_arrival'],
      )!,
      fromVisitId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}from_visit_id'],
      ),
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }

  static TypeConverter<Recurrence, int> $converterrecurrence =
      const RecurrenceConverter();
  static TypeConverter<CalendarDate, int> $converterstartDate =
      const CalendarDateConverter();
  static TypeConverter<CalendarDate, int> $converterendDate =
      const CalendarDateConverter();
  static TypeConverter<CalendarDate?, int?> $converterendDaten =
      NullAwareTypeConverter.wrap($converterendDate);
  static TypeConverter<List<int>, String> $converterleadMinutes =
      const LeadMinutesConverter();
}

class EventRow extends DataClass implements Insertable<EventRow> {
  final int id;
  final String title;
  final String? notes;

  /// ARGB.
  final int colorValue;

  /// Minutes since midnight, **wall clock**. 07:00 is 420 in Delhi in January
  /// and 420 in New York in July.
  final int timeOfDay;
  final int? durationMin;
  final Recurrence recurrence;

  /// 7-bit mask, see [Weekdays]. WEEKLY only.
  final int daysOfWeek;

  /// EVERY_N_DAYS only. Named `interval_days` because `interval` is a keyword
  /// in enough SQL dialects to be worth dodging.
  final int interval;

  /// MONTHLY only. Clamped into short months on read; -1 means last day.
  final int? dayOfMonth;
  final CalendarDate startDate;
  final CalendarDate? endDate;

  /// JSON list of minutes before the event, e.g. `[60,10]`.
  final List<int> leadMinutes;
  final bool isActive;

  /// Optionally ties this routine to a place, which is what makes "did you
  /// actually go to the gym when the reminder fired" answerable.
  final int? placeId;

  /// Tick this one off by itself when the device arrives at [placeId] around
  /// the time it is due.
  ///
  /// Meaningless without a place, and the editor only offers it once one is
  /// picked — but stored independently so that clearing the place cannot leave
  /// a rule quietly waiting for an arrival that can never come.
  final bool autoCompleteOnArrival;

  /// Set when the app wrote this rule itself to record a visit, rather than
  /// the user writing it to plan something.
  ///
  /// It is what separates "somewhere I went" from "something I meant to do",
  /// and the two must not be counted together: a visit is not an intention, so
  /// these stay out of All Events, out of the dashboard's adherence, and out
  /// of the progress ring — while still being on the day, which is the point
  /// of writing them at all.
  ///
  /// Also the idempotency key: one stay produces one row however many times
  /// the OS re-delivers the crossing. Cascades, because an event that is only
  /// a record of a visit has nothing left to say once the visit is forgotten
  /// — and clearing visit history is offered as exactly that. Editing one in
  /// the editor clears this, which adopts it as an ordinary event of the
  /// user's own.
  final int? fromVisitId;
  const EventRow({
    required this.id,
    required this.title,
    this.notes,
    required this.colorValue,
    required this.timeOfDay,
    this.durationMin,
    required this.recurrence,
    required this.daysOfWeek,
    required this.interval,
    this.dayOfMonth,
    required this.startDate,
    this.endDate,
    required this.leadMinutes,
    required this.isActive,
    this.placeId,
    required this.autoCompleteOnArrival,
    this.fromVisitId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['color_value'] = Variable<int>(colorValue);
    map['time_of_day'] = Variable<int>(timeOfDay);
    if (!nullToAbsent || durationMin != null) {
      map['duration_min'] = Variable<int>(durationMin);
    }
    {
      map['recurrence'] = Variable<int>(
        $EventsTable.$converterrecurrence.toSql(recurrence),
      );
    }
    map['days_of_week'] = Variable<int>(daysOfWeek);
    map['interval_days'] = Variable<int>(interval);
    if (!nullToAbsent || dayOfMonth != null) {
      map['day_of_month'] = Variable<int>(dayOfMonth);
    }
    {
      map['start_date'] = Variable<int>(
        $EventsTable.$converterstartDate.toSql(startDate),
      );
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<int>(
        $EventsTable.$converterendDaten.toSql(endDate),
      );
    }
    {
      map['lead_minutes'] = Variable<String>(
        $EventsTable.$converterleadMinutes.toSql(leadMinutes),
      );
    }
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || placeId != null) {
      map['place_id'] = Variable<int>(placeId);
    }
    map['auto_complete_on_arrival'] = Variable<bool>(autoCompleteOnArrival);
    if (!nullToAbsent || fromVisitId != null) {
      map['from_visit_id'] = Variable<int>(fromVisitId);
    }
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      colorValue: Value(colorValue),
      timeOfDay: Value(timeOfDay),
      durationMin: durationMin == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMin),
      recurrence: Value(recurrence),
      daysOfWeek: Value(daysOfWeek),
      interval: Value(interval),
      dayOfMonth: dayOfMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfMonth),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      leadMinutes: Value(leadMinutes),
      isActive: Value(isActive),
      placeId: placeId == null && nullToAbsent
          ? const Value.absent()
          : Value(placeId),
      autoCompleteOnArrival: Value(autoCompleteOnArrival),
      fromVisitId: fromVisitId == null && nullToAbsent
          ? const Value.absent()
          : Value(fromVisitId),
    );
  }

  factory EventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventRow(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      timeOfDay: serializer.fromJson<int>(json['timeOfDay']),
      durationMin: serializer.fromJson<int?>(json['durationMin']),
      recurrence: serializer.fromJson<Recurrence>(json['recurrence']),
      daysOfWeek: serializer.fromJson<int>(json['daysOfWeek']),
      interval: serializer.fromJson<int>(json['interval']),
      dayOfMonth: serializer.fromJson<int?>(json['dayOfMonth']),
      startDate: serializer.fromJson<CalendarDate>(json['startDate']),
      endDate: serializer.fromJson<CalendarDate?>(json['endDate']),
      leadMinutes: serializer.fromJson<List<int>>(json['leadMinutes']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      placeId: serializer.fromJson<int?>(json['placeId']),
      autoCompleteOnArrival: serializer.fromJson<bool>(
        json['autoCompleteOnArrival'],
      ),
      fromVisitId: serializer.fromJson<int?>(json['fromVisitId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'colorValue': serializer.toJson<int>(colorValue),
      'timeOfDay': serializer.toJson<int>(timeOfDay),
      'durationMin': serializer.toJson<int?>(durationMin),
      'recurrence': serializer.toJson<Recurrence>(recurrence),
      'daysOfWeek': serializer.toJson<int>(daysOfWeek),
      'interval': serializer.toJson<int>(interval),
      'dayOfMonth': serializer.toJson<int?>(dayOfMonth),
      'startDate': serializer.toJson<CalendarDate>(startDate),
      'endDate': serializer.toJson<CalendarDate?>(endDate),
      'leadMinutes': serializer.toJson<List<int>>(leadMinutes),
      'isActive': serializer.toJson<bool>(isActive),
      'placeId': serializer.toJson<int?>(placeId),
      'autoCompleteOnArrival': serializer.toJson<bool>(autoCompleteOnArrival),
      'fromVisitId': serializer.toJson<int?>(fromVisitId),
    };
  }

  EventRow copyWith({
    int? id,
    String? title,
    Value<String?> notes = const Value.absent(),
    int? colorValue,
    int? timeOfDay,
    Value<int?> durationMin = const Value.absent(),
    Recurrence? recurrence,
    int? daysOfWeek,
    int? interval,
    Value<int?> dayOfMonth = const Value.absent(),
    CalendarDate? startDate,
    Value<CalendarDate?> endDate = const Value.absent(),
    List<int>? leadMinutes,
    bool? isActive,
    Value<int?> placeId = const Value.absent(),
    bool? autoCompleteOnArrival,
    Value<int?> fromVisitId = const Value.absent(),
  }) => EventRow(
    id: id ?? this.id,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    colorValue: colorValue ?? this.colorValue,
    timeOfDay: timeOfDay ?? this.timeOfDay,
    durationMin: durationMin.present ? durationMin.value : this.durationMin,
    recurrence: recurrence ?? this.recurrence,
    daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    interval: interval ?? this.interval,
    dayOfMonth: dayOfMonth.present ? dayOfMonth.value : this.dayOfMonth,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    leadMinutes: leadMinutes ?? this.leadMinutes,
    isActive: isActive ?? this.isActive,
    placeId: placeId.present ? placeId.value : this.placeId,
    autoCompleteOnArrival: autoCompleteOnArrival ?? this.autoCompleteOnArrival,
    fromVisitId: fromVisitId.present ? fromVisitId.value : this.fromVisitId,
  );
  EventRow copyWithCompanion(EventsCompanion data) {
    return EventRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      timeOfDay: data.timeOfDay.present ? data.timeOfDay.value : this.timeOfDay,
      durationMin: data.durationMin.present
          ? data.durationMin.value
          : this.durationMin,
      recurrence: data.recurrence.present
          ? data.recurrence.value
          : this.recurrence,
      daysOfWeek: data.daysOfWeek.present
          ? data.daysOfWeek.value
          : this.daysOfWeek,
      interval: data.interval.present ? data.interval.value : this.interval,
      dayOfMonth: data.dayOfMonth.present
          ? data.dayOfMonth.value
          : this.dayOfMonth,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      leadMinutes: data.leadMinutes.present
          ? data.leadMinutes.value
          : this.leadMinutes,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      placeId: data.placeId.present ? data.placeId.value : this.placeId,
      autoCompleteOnArrival: data.autoCompleteOnArrival.present
          ? data.autoCompleteOnArrival.value
          : this.autoCompleteOnArrival,
      fromVisitId: data.fromVisitId.present
          ? data.fromVisitId.value
          : this.fromVisitId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('colorValue: $colorValue, ')
          ..write('timeOfDay: $timeOfDay, ')
          ..write('durationMin: $durationMin, ')
          ..write('recurrence: $recurrence, ')
          ..write('daysOfWeek: $daysOfWeek, ')
          ..write('interval: $interval, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('leadMinutes: $leadMinutes, ')
          ..write('isActive: $isActive, ')
          ..write('placeId: $placeId, ')
          ..write('autoCompleteOnArrival: $autoCompleteOnArrival, ')
          ..write('fromVisitId: $fromVisitId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    notes,
    colorValue,
    timeOfDay,
    durationMin,
    recurrence,
    daysOfWeek,
    interval,
    dayOfMonth,
    startDate,
    endDate,
    leadMinutes,
    isActive,
    placeId,
    autoCompleteOnArrival,
    fromVisitId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.colorValue == this.colorValue &&
          other.timeOfDay == this.timeOfDay &&
          other.durationMin == this.durationMin &&
          other.recurrence == this.recurrence &&
          other.daysOfWeek == this.daysOfWeek &&
          other.interval == this.interval &&
          other.dayOfMonth == this.dayOfMonth &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.leadMinutes == this.leadMinutes &&
          other.isActive == this.isActive &&
          other.placeId == this.placeId &&
          other.autoCompleteOnArrival == this.autoCompleteOnArrival &&
          other.fromVisitId == this.fromVisitId);
}

class EventsCompanion extends UpdateCompanion<EventRow> {
  final Value<int> id;
  final Value<String> title;
  final Value<String?> notes;
  final Value<int> colorValue;
  final Value<int> timeOfDay;
  final Value<int?> durationMin;
  final Value<Recurrence> recurrence;
  final Value<int> daysOfWeek;
  final Value<int> interval;
  final Value<int?> dayOfMonth;
  final Value<CalendarDate> startDate;
  final Value<CalendarDate?> endDate;
  final Value<List<int>> leadMinutes;
  final Value<bool> isActive;
  final Value<int?> placeId;
  final Value<bool> autoCompleteOnArrival;
  final Value<int?> fromVisitId;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.timeOfDay = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.daysOfWeek = const Value.absent(),
    this.interval = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.leadMinutes = const Value.absent(),
    this.isActive = const Value.absent(),
    this.placeId = const Value.absent(),
    this.autoCompleteOnArrival = const Value.absent(),
    this.fromVisitId = const Value.absent(),
  });
  EventsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.notes = const Value.absent(),
    required int colorValue,
    required int timeOfDay,
    this.durationMin = const Value.absent(),
    required Recurrence recurrence,
    this.daysOfWeek = const Value.absent(),
    this.interval = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    required CalendarDate startDate,
    this.endDate = const Value.absent(),
    this.leadMinutes = const Value.absent(),
    this.isActive = const Value.absent(),
    this.placeId = const Value.absent(),
    this.autoCompleteOnArrival = const Value.absent(),
    this.fromVisitId = const Value.absent(),
  }) : title = Value(title),
       colorValue = Value(colorValue),
       timeOfDay = Value(timeOfDay),
       recurrence = Value(recurrence),
       startDate = Value(startDate);
  static Insertable<EventRow> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<int>? colorValue,
    Expression<int>? timeOfDay,
    Expression<int>? durationMin,
    Expression<int>? recurrence,
    Expression<int>? daysOfWeek,
    Expression<int>? interval,
    Expression<int>? dayOfMonth,
    Expression<int>? startDate,
    Expression<int>? endDate,
    Expression<String>? leadMinutes,
    Expression<bool>? isActive,
    Expression<int>? placeId,
    Expression<bool>? autoCompleteOnArrival,
    Expression<int>? fromVisitId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (colorValue != null) 'color_value': colorValue,
      if (timeOfDay != null) 'time_of_day': timeOfDay,
      if (durationMin != null) 'duration_min': durationMin,
      if (recurrence != null) 'recurrence': recurrence,
      if (daysOfWeek != null) 'days_of_week': daysOfWeek,
      if (interval != null) 'interval_days': interval,
      if (dayOfMonth != null) 'day_of_month': dayOfMonth,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (leadMinutes != null) 'lead_minutes': leadMinutes,
      if (isActive != null) 'is_active': isActive,
      if (placeId != null) 'place_id': placeId,
      if (autoCompleteOnArrival != null)
        'auto_complete_on_arrival': autoCompleteOnArrival,
      if (fromVisitId != null) 'from_visit_id': fromVisitId,
    });
  }

  EventsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String?>? notes,
    Value<int>? colorValue,
    Value<int>? timeOfDay,
    Value<int?>? durationMin,
    Value<Recurrence>? recurrence,
    Value<int>? daysOfWeek,
    Value<int>? interval,
    Value<int?>? dayOfMonth,
    Value<CalendarDate>? startDate,
    Value<CalendarDate?>? endDate,
    Value<List<int>>? leadMinutes,
    Value<bool>? isActive,
    Value<int?>? placeId,
    Value<bool>? autoCompleteOnArrival,
    Value<int?>? fromVisitId,
  }) {
    return EventsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      colorValue: colorValue ?? this.colorValue,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      durationMin: durationMin ?? this.durationMin,
      recurrence: recurrence ?? this.recurrence,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      interval: interval ?? this.interval,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      leadMinutes: leadMinutes ?? this.leadMinutes,
      isActive: isActive ?? this.isActive,
      placeId: placeId ?? this.placeId,
      autoCompleteOnArrival:
          autoCompleteOnArrival ?? this.autoCompleteOnArrival,
      fromVisitId: fromVisitId ?? this.fromVisitId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (timeOfDay.present) {
      map['time_of_day'] = Variable<int>(timeOfDay.value);
    }
    if (durationMin.present) {
      map['duration_min'] = Variable<int>(durationMin.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<int>(
        $EventsTable.$converterrecurrence.toSql(recurrence.value),
      );
    }
    if (daysOfWeek.present) {
      map['days_of_week'] = Variable<int>(daysOfWeek.value);
    }
    if (interval.present) {
      map['interval_days'] = Variable<int>(interval.value);
    }
    if (dayOfMonth.present) {
      map['day_of_month'] = Variable<int>(dayOfMonth.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<int>(
        $EventsTable.$converterstartDate.toSql(startDate.value),
      );
    }
    if (endDate.present) {
      map['end_date'] = Variable<int>(
        $EventsTable.$converterendDaten.toSql(endDate.value),
      );
    }
    if (leadMinutes.present) {
      map['lead_minutes'] = Variable<String>(
        $EventsTable.$converterleadMinutes.toSql(leadMinutes.value),
      );
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (placeId.present) {
      map['place_id'] = Variable<int>(placeId.value);
    }
    if (autoCompleteOnArrival.present) {
      map['auto_complete_on_arrival'] = Variable<bool>(
        autoCompleteOnArrival.value,
      );
    }
    if (fromVisitId.present) {
      map['from_visit_id'] = Variable<int>(fromVisitId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('colorValue: $colorValue, ')
          ..write('timeOfDay: $timeOfDay, ')
          ..write('durationMin: $durationMin, ')
          ..write('recurrence: $recurrence, ')
          ..write('daysOfWeek: $daysOfWeek, ')
          ..write('interval: $interval, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('leadMinutes: $leadMinutes, ')
          ..write('isActive: $isActive, ')
          ..write('placeId: $placeId, ')
          ..write('autoCompleteOnArrival: $autoCompleteOnArrival, ')
          ..write('fromVisitId: $fromVisitId')
          ..write(')'))
        .toString();
  }
}

class $CompletionsTable extends Completions
    with TableInfo<$CompletionsTable, CompletionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES events(id) ON DELETE CASCADE',
  );
  @override
  late final GeneratedColumnWithTypeConverter<CalendarDate, int> date =
      GeneratedColumn<int>(
        'date',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<CalendarDate>($CompletionsTable.$converterdate);
  @override
  late final GeneratedColumnWithTypeConverter<CompletionStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<CompletionStatus>($CompletionsTable.$converterstatus);
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isAutomaticMeta = const VerificationMeta(
    'isAutomatic',
  );
  @override
  late final GeneratedColumn<bool> isAutomatic = GeneratedColumn<bool>(
    'is_automatic',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_automatic" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    date,
    status,
    completedAt,
    isAutomatic,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'completions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompletionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    if (data.containsKey('is_automatic')) {
      context.handle(
        _isAutomaticMeta,
        isAutomatic.isAcceptableOrUnknown(
          data['is_automatic']!,
          _isAutomaticMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId, date};
  @override
  CompletionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompletionRow(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_id'],
      )!,
      date: $CompletionsTable.$converterdate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}date'],
        )!,
      ),
      status: $CompletionsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
      isAutomatic: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_automatic'],
      )!,
    );
  }

  @override
  $CompletionsTable createAlias(String alias) {
    return $CompletionsTable(attachedDatabase, alias);
  }

  static TypeConverter<CalendarDate, int> $converterdate =
      const CalendarDateConverter();
  static TypeConverter<CompletionStatus, int> $converterstatus =
      const CompletionStatusConverter();
}

class CompletionRow extends DataClass implements Insertable<CompletionRow> {
  final int eventId;
  final CalendarDate date;
  final CompletionStatus status;
  final DateTime completedAt;

  /// True when the app ticked this off on arrival rather than the user. Kept
  /// so the row can say why it is ticked: a tick the user did not make and
  /// cannot account for is worse than no tick.
  final bool isAutomatic;
  const CompletionRow({
    required this.eventId,
    required this.date,
    required this.status,
    required this.completedAt,
    required this.isAutomatic,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<int>(eventId);
    {
      map['date'] = Variable<int>($CompletionsTable.$converterdate.toSql(date));
    }
    {
      map['status'] = Variable<int>(
        $CompletionsTable.$converterstatus.toSql(status),
      );
    }
    map['completed_at'] = Variable<DateTime>(completedAt);
    map['is_automatic'] = Variable<bool>(isAutomatic);
    return map;
  }

  CompletionsCompanion toCompanion(bool nullToAbsent) {
    return CompletionsCompanion(
      eventId: Value(eventId),
      date: Value(date),
      status: Value(status),
      completedAt: Value(completedAt),
      isAutomatic: Value(isAutomatic),
    );
  }

  factory CompletionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompletionRow(
      eventId: serializer.fromJson<int>(json['eventId']),
      date: serializer.fromJson<CalendarDate>(json['date']),
      status: serializer.fromJson<CompletionStatus>(json['status']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
      isAutomatic: serializer.fromJson<bool>(json['isAutomatic']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<int>(eventId),
      'date': serializer.toJson<CalendarDate>(date),
      'status': serializer.toJson<CompletionStatus>(status),
      'completedAt': serializer.toJson<DateTime>(completedAt),
      'isAutomatic': serializer.toJson<bool>(isAutomatic),
    };
  }

  CompletionRow copyWith({
    int? eventId,
    CalendarDate? date,
    CompletionStatus? status,
    DateTime? completedAt,
    bool? isAutomatic,
  }) => CompletionRow(
    eventId: eventId ?? this.eventId,
    date: date ?? this.date,
    status: status ?? this.status,
    completedAt: completedAt ?? this.completedAt,
    isAutomatic: isAutomatic ?? this.isAutomatic,
  );
  CompletionRow copyWithCompanion(CompletionsCompanion data) {
    return CompletionRow(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      date: data.date.present ? data.date.value : this.date,
      status: data.status.present ? data.status.value : this.status,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      isAutomatic: data.isAutomatic.present
          ? data.isAutomatic.value
          : this.isAutomatic,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompletionRow(')
          ..write('eventId: $eventId, ')
          ..write('date: $date, ')
          ..write('status: $status, ')
          ..write('completedAt: $completedAt, ')
          ..write('isAutomatic: $isAutomatic')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(eventId, date, status, completedAt, isAutomatic);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompletionRow &&
          other.eventId == this.eventId &&
          other.date == this.date &&
          other.status == this.status &&
          other.completedAt == this.completedAt &&
          other.isAutomatic == this.isAutomatic);
}

class CompletionsCompanion extends UpdateCompanion<CompletionRow> {
  final Value<int> eventId;
  final Value<CalendarDate> date;
  final Value<CompletionStatus> status;
  final Value<DateTime> completedAt;
  final Value<bool> isAutomatic;
  final Value<int> rowid;
  const CompletionsCompanion({
    this.eventId = const Value.absent(),
    this.date = const Value.absent(),
    this.status = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.isAutomatic = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompletionsCompanion.insert({
    required int eventId,
    required CalendarDate date,
    required CompletionStatus status,
    required DateTime completedAt,
    this.isAutomatic = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       date = Value(date),
       status = Value(status),
       completedAt = Value(completedAt);
  static Insertable<CompletionRow> custom({
    Expression<int>? eventId,
    Expression<int>? date,
    Expression<int>? status,
    Expression<DateTime>? completedAt,
    Expression<bool>? isAutomatic,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (date != null) 'date': date,
      if (status != null) 'status': status,
      if (completedAt != null) 'completed_at': completedAt,
      if (isAutomatic != null) 'is_automatic': isAutomatic,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompletionsCompanion copyWith({
    Value<int>? eventId,
    Value<CalendarDate>? date,
    Value<CompletionStatus>? status,
    Value<DateTime>? completedAt,
    Value<bool>? isAutomatic,
    Value<int>? rowid,
  }) {
    return CompletionsCompanion(
      eventId: eventId ?? this.eventId,
      date: date ?? this.date,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      isAutomatic: isAutomatic ?? this.isAutomatic,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (date.present) {
      map['date'] = Variable<int>(
        $CompletionsTable.$converterdate.toSql(date.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $CompletionsTable.$converterstatus.toSql(status.value),
      );
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (isAutomatic.present) {
      map['is_automatic'] = Variable<bool>(isAutomatic.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompletionsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('date: $date, ')
          ..write('status: $status, ')
          ..write('completedAt: $completedAt, ')
          ..write('isAutomatic: $isAutomatic, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OverridesTable extends Overrides
    with TableInfo<$OverridesTable, OverrideRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OverridesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES events(id) ON DELETE CASCADE',
  );
  @override
  late final GeneratedColumnWithTypeConverter<CalendarDate, int> date =
      GeneratedColumn<int>(
        'date',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<CalendarDate>($OverridesTable.$converterdate);
  @override
  late final GeneratedColumnWithTypeConverter<OverrideType, int> type =
      GeneratedColumn<int>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<OverrideType>($OverridesTable.$convertertype);
  static const VerificationMeta _newTimeOfDayMeta = const VerificationMeta(
    'newTimeOfDay',
  );
  @override
  late final GeneratedColumn<int> newTimeOfDay = GeneratedColumn<int>(
    'new_time_of_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [eventId, date, type, newTimeOfDay];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'overrides';
  @override
  VerificationContext validateIntegrity(
    Insertable<OverrideRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('new_time_of_day')) {
      context.handle(
        _newTimeOfDayMeta,
        newTimeOfDay.isAcceptableOrUnknown(
          data['new_time_of_day']!,
          _newTimeOfDayMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId, date};
  @override
  OverrideRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OverrideRow(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_id'],
      )!,
      date: $OverridesTable.$converterdate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}date'],
        )!,
      ),
      type: $OverridesTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}type'],
        )!,
      ),
      newTimeOfDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}new_time_of_day'],
      ),
    );
  }

  @override
  $OverridesTable createAlias(String alias) {
    return $OverridesTable(attachedDatabase, alias);
  }

  static TypeConverter<CalendarDate, int> $converterdate =
      const CalendarDateConverter();
  static TypeConverter<OverrideType, int> $convertertype =
      const OverrideTypeConverter();
}

class OverrideRow extends DataClass implements Insertable<OverrideRow> {
  final int eventId;
  final CalendarDate date;
  final OverrideType type;

  /// Minutes since midnight, wall clock. MOVED only.
  final int? newTimeOfDay;
  const OverrideRow({
    required this.eventId,
    required this.date,
    required this.type,
    this.newTimeOfDay,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<int>(eventId);
    {
      map['date'] = Variable<int>($OverridesTable.$converterdate.toSql(date));
    }
    {
      map['type'] = Variable<int>($OverridesTable.$convertertype.toSql(type));
    }
    if (!nullToAbsent || newTimeOfDay != null) {
      map['new_time_of_day'] = Variable<int>(newTimeOfDay);
    }
    return map;
  }

  OverridesCompanion toCompanion(bool nullToAbsent) {
    return OverridesCompanion(
      eventId: Value(eventId),
      date: Value(date),
      type: Value(type),
      newTimeOfDay: newTimeOfDay == null && nullToAbsent
          ? const Value.absent()
          : Value(newTimeOfDay),
    );
  }

  factory OverrideRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OverrideRow(
      eventId: serializer.fromJson<int>(json['eventId']),
      date: serializer.fromJson<CalendarDate>(json['date']),
      type: serializer.fromJson<OverrideType>(json['type']),
      newTimeOfDay: serializer.fromJson<int?>(json['newTimeOfDay']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<int>(eventId),
      'date': serializer.toJson<CalendarDate>(date),
      'type': serializer.toJson<OverrideType>(type),
      'newTimeOfDay': serializer.toJson<int?>(newTimeOfDay),
    };
  }

  OverrideRow copyWith({
    int? eventId,
    CalendarDate? date,
    OverrideType? type,
    Value<int?> newTimeOfDay = const Value.absent(),
  }) => OverrideRow(
    eventId: eventId ?? this.eventId,
    date: date ?? this.date,
    type: type ?? this.type,
    newTimeOfDay: newTimeOfDay.present ? newTimeOfDay.value : this.newTimeOfDay,
  );
  OverrideRow copyWithCompanion(OverridesCompanion data) {
    return OverrideRow(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      date: data.date.present ? data.date.value : this.date,
      type: data.type.present ? data.type.value : this.type,
      newTimeOfDay: data.newTimeOfDay.present
          ? data.newTimeOfDay.value
          : this.newTimeOfDay,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OverrideRow(')
          ..write('eventId: $eventId, ')
          ..write('date: $date, ')
          ..write('type: $type, ')
          ..write('newTimeOfDay: $newTimeOfDay')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(eventId, date, type, newTimeOfDay);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OverrideRow &&
          other.eventId == this.eventId &&
          other.date == this.date &&
          other.type == this.type &&
          other.newTimeOfDay == this.newTimeOfDay);
}

class OverridesCompanion extends UpdateCompanion<OverrideRow> {
  final Value<int> eventId;
  final Value<CalendarDate> date;
  final Value<OverrideType> type;
  final Value<int?> newTimeOfDay;
  final Value<int> rowid;
  const OverridesCompanion({
    this.eventId = const Value.absent(),
    this.date = const Value.absent(),
    this.type = const Value.absent(),
    this.newTimeOfDay = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OverridesCompanion.insert({
    required int eventId,
    required CalendarDate date,
    required OverrideType type,
    this.newTimeOfDay = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       date = Value(date),
       type = Value(type);
  static Insertable<OverrideRow> custom({
    Expression<int>? eventId,
    Expression<int>? date,
    Expression<int>? type,
    Expression<int>? newTimeOfDay,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (date != null) 'date': date,
      if (type != null) 'type': type,
      if (newTimeOfDay != null) 'new_time_of_day': newTimeOfDay,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OverridesCompanion copyWith({
    Value<int>? eventId,
    Value<CalendarDate>? date,
    Value<OverrideType>? type,
    Value<int?>? newTimeOfDay,
    Value<int>? rowid,
  }) {
    return OverridesCompanion(
      eventId: eventId ?? this.eventId,
      date: date ?? this.date,
      type: type ?? this.type,
      newTimeOfDay: newTimeOfDay ?? this.newTimeOfDay,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (date.present) {
      map['date'] = Variable<int>(
        $OverridesTable.$converterdate.toSql(date.value),
      );
    }
    if (type.present) {
      map['type'] = Variable<int>(
        $OverridesTable.$convertertype.toSql(type.value),
      );
    }
    if (newTimeOfDay.present) {
      map['new_time_of_day'] = Variable<int>(newTimeOfDay.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OverridesCompanion(')
          ..write('eventId: $eventId, ')
          ..write('date: $date, ')
          ..write('type: $type, ')
          ..write('newTimeOfDay: $newTimeOfDay, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DaylineDatabase extends GeneratedDatabase {
  _$DaylineDatabase(QueryExecutor e) : super(e);
  $DaylineDatabaseManager get managers => $DaylineDatabaseManager(this);
  late final $PlacesTable places = $PlacesTable(this);
  late final $VisitsTable visits = $VisitsTable(this);
  late final $EventsTable events = $EventsTable(this);
  late final $CompletionsTable completions = $CompletionsTable(this);
  late final $OverridesTable overrides = $OverridesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index idxCompletionsDate = Index(
    'idx_completions_date',
    'CREATE INDEX idx_completions_date ON completions (date)',
  );
  late final Index idxOverridesDate = Index(
    'idx_overrides_date',
    'CREATE INDEX idx_overrides_date ON overrides (date)',
  );
  late final Index idxVisitsPlace = Index(
    'idx_visits_place',
    'CREATE INDEX idx_visits_place ON visits (place_id)',
  );
  late final Index idxVisitsArrived = Index(
    'idx_visits_arrived',
    'CREATE INDEX idx_visits_arrived ON visits (arrived_at)',
  );
  late final EventsDao eventsDao = EventsDao(this as DaylineDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as DaylineDatabase);
  late final PlacesDao placesDao = PlacesDao(this as DaylineDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    places,
    visits,
    events,
    completions,
    overrides,
    settings,
    idxCompletionsDate,
    idxOverridesDate,
    idxVisitsPlace,
    idxVisitsArrived,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'places',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('visits', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'places',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('events', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'visits',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('completions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('overrides', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$PlacesTableCreateCompanionBuilder =
    PlacesCompanion Function({
      Value<int> id,
      required String name,
      required double latitude,
      required double longitude,
      Value<double> radiusMeters,
      required int colorValue,
      required PlaceKind kind,
      Value<bool> isActive,
      Value<bool> addVisitsToDay,
    });
typedef $$PlacesTableUpdateCompanionBuilder =
    PlacesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<double> latitude,
      Value<double> longitude,
      Value<double> radiusMeters,
      Value<int> colorValue,
      Value<PlaceKind> kind,
      Value<bool> isActive,
      Value<bool> addVisitsToDay,
    });

final class $$PlacesTableReferences
    extends BaseReferences<_$DaylineDatabase, $PlacesTable, PlaceRow> {
  $$PlacesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$VisitsTable, List<VisitRow>> _visitsRefsTable(
    _$DaylineDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.visits,
    aliasName: $_aliasNameGenerator(db.places.id, db.visits.placeId),
  );

  $$VisitsTableProcessedTableManager get visitsRefs {
    final manager = $$VisitsTableTableManager(
      $_db,
      $_db.visits,
    ).filter((f) => f.placeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_visitsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EventsTable, List<EventRow>> _eventsRefsTable(
    _$DaylineDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.events,
    aliasName: $_aliasNameGenerator(db.places.id, db.events.placeId),
  );

  $$EventsTableProcessedTableManager get eventsRefs {
    final manager = $$EventsTableTableManager(
      $_db,
      $_db.events,
    ).filter((f) => f.placeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_eventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlacesTableFilterComposer
    extends Composer<_$DaylineDatabase, $PlacesTable> {
  $$PlacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PlaceKind, PlaceKind, int> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get addVisitsToDay => $composableBuilder(
    column: $table.addVisitsToDay,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> visitsRefs(
    Expression<bool> Function($$VisitsTableFilterComposer f) f,
  ) {
    final $$VisitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.placeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableFilterComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> eventsRefs(
    Expression<bool> Function($$EventsTableFilterComposer f) f,
  ) {
    final $$EventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.placeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableFilterComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlacesTableOrderingComposer
    extends Composer<_$DaylineDatabase, $PlacesTable> {
  $$PlacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get addVisitsToDay => $composableBuilder(
    column: $table.addVisitsToDay,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlacesTableAnnotationComposer
    extends Composer<_$DaylineDatabase, $PlacesTable> {
  $$PlacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<PlaceKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get addVisitsToDay => $composableBuilder(
    column: $table.addVisitsToDay,
    builder: (column) => column,
  );

  Expression<T> visitsRefs<T extends Object>(
    Expression<T> Function($$VisitsTableAnnotationComposer a) f,
  ) {
    final $$VisitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.placeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableAnnotationComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> eventsRefs<T extends Object>(
    Expression<T> Function($$EventsTableAnnotationComposer a) f,
  ) {
    final $$EventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.placeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableAnnotationComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlacesTableTableManager
    extends
        RootTableManager<
          _$DaylineDatabase,
          $PlacesTable,
          PlaceRow,
          $$PlacesTableFilterComposer,
          $$PlacesTableOrderingComposer,
          $$PlacesTableAnnotationComposer,
          $$PlacesTableCreateCompanionBuilder,
          $$PlacesTableUpdateCompanionBuilder,
          (PlaceRow, $$PlacesTableReferences),
          PlaceRow,
          PrefetchHooks Function({bool visitsRefs, bool eventsRefs})
        > {
  $$PlacesTableTableManager(_$DaylineDatabase db, $PlacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<double> radiusMeters = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<PlaceKind> kind = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> addVisitsToDay = const Value.absent(),
              }) => PlacesCompanion(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radiusMeters,
                colorValue: colorValue,
                kind: kind,
                isActive: isActive,
                addVisitsToDay: addVisitsToDay,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required double latitude,
                required double longitude,
                Value<double> radiusMeters = const Value.absent(),
                required int colorValue,
                required PlaceKind kind,
                Value<bool> isActive = const Value.absent(),
                Value<bool> addVisitsToDay = const Value.absent(),
              }) => PlacesCompanion.insert(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radiusMeters,
                colorValue: colorValue,
                kind: kind,
                isActive: isActive,
                addVisitsToDay: addVisitsToDay,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PlacesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({visitsRefs = false, eventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (visitsRefs) db.visits,
                if (eventsRefs) db.events,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (visitsRefs)
                    await $_getPrefetchedData<PlaceRow, $PlacesTable, VisitRow>(
                      currentTable: table,
                      referencedTable: $$PlacesTableReferences._visitsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$PlacesTableReferences(db, table, p0).visitsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.placeId == item.id),
                      typedResults: items,
                    ),
                  if (eventsRefs)
                    await $_getPrefetchedData<PlaceRow, $PlacesTable, EventRow>(
                      currentTable: table,
                      referencedTable: $$PlacesTableReferences._eventsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$PlacesTableReferences(db, table, p0).eventsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.placeId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlacesTableProcessedTableManager =
    ProcessedTableManager<
      _$DaylineDatabase,
      $PlacesTable,
      PlaceRow,
      $$PlacesTableFilterComposer,
      $$PlacesTableOrderingComposer,
      $$PlacesTableAnnotationComposer,
      $$PlacesTableCreateCompanionBuilder,
      $$PlacesTableUpdateCompanionBuilder,
      (PlaceRow, $$PlacesTableReferences),
      PlaceRow,
      PrefetchHooks Function({bool visitsRefs, bool eventsRefs})
    >;
typedef $$VisitsTableCreateCompanionBuilder =
    VisitsCompanion Function({
      Value<int> id,
      required int placeId,
      required DateTime arrivedAt,
      Value<DateTime?> departedAt,
    });
typedef $$VisitsTableUpdateCompanionBuilder =
    VisitsCompanion Function({
      Value<int> id,
      Value<int> placeId,
      Value<DateTime> arrivedAt,
      Value<DateTime?> departedAt,
    });

final class $$VisitsTableReferences
    extends BaseReferences<_$DaylineDatabase, $VisitsTable, VisitRow> {
  $$VisitsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlacesTable _placeIdTable(_$DaylineDatabase db) => db.places
      .createAlias($_aliasNameGenerator(db.visits.placeId, db.places.id));

  $$PlacesTableProcessedTableManager get placeId {
    final $_column = $_itemColumn<int>('place_id')!;

    final manager = $$PlacesTableTableManager(
      $_db,
      $_db.places,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_placeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EventsTable, List<EventRow>> _eventsRefsTable(
    _$DaylineDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.events,
    aliasName: $_aliasNameGenerator(db.visits.id, db.events.fromVisitId),
  );

  $$EventsTableProcessedTableManager get eventsRefs {
    final manager = $$EventsTableTableManager(
      $_db,
      $_db.events,
    ).filter((f) => f.fromVisitId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_eventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VisitsTableFilterComposer
    extends Composer<_$DaylineDatabase, $VisitsTable> {
  $$VisitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get arrivedAt => $composableBuilder(
    column: $table.arrivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get departedAt => $composableBuilder(
    column: $table.departedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlacesTableFilterComposer get placeId {
    final $$PlacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeId,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableFilterComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> eventsRefs(
    Expression<bool> Function($$EventsTableFilterComposer f) f,
  ) {
    final $$EventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.fromVisitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableFilterComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VisitsTableOrderingComposer
    extends Composer<_$DaylineDatabase, $VisitsTable> {
  $$VisitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get arrivedAt => $composableBuilder(
    column: $table.arrivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get departedAt => $composableBuilder(
    column: $table.departedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlacesTableOrderingComposer get placeId {
    final $$PlacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeId,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableOrderingComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisitsTableAnnotationComposer
    extends Composer<_$DaylineDatabase, $VisitsTable> {
  $$VisitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get arrivedAt =>
      $composableBuilder(column: $table.arrivedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get departedAt => $composableBuilder(
    column: $table.departedAt,
    builder: (column) => column,
  );

  $$PlacesTableAnnotationComposer get placeId {
    final $$PlacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeId,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableAnnotationComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> eventsRefs<T extends Object>(
    Expression<T> Function($$EventsTableAnnotationComposer a) f,
  ) {
    final $$EventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.fromVisitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableAnnotationComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VisitsTableTableManager
    extends
        RootTableManager<
          _$DaylineDatabase,
          $VisitsTable,
          VisitRow,
          $$VisitsTableFilterComposer,
          $$VisitsTableOrderingComposer,
          $$VisitsTableAnnotationComposer,
          $$VisitsTableCreateCompanionBuilder,
          $$VisitsTableUpdateCompanionBuilder,
          (VisitRow, $$VisitsTableReferences),
          VisitRow,
          PrefetchHooks Function({bool placeId, bool eventsRefs})
        > {
  $$VisitsTableTableManager(_$DaylineDatabase db, $VisitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VisitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VisitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> placeId = const Value.absent(),
                Value<DateTime> arrivedAt = const Value.absent(),
                Value<DateTime?> departedAt = const Value.absent(),
              }) => VisitsCompanion(
                id: id,
                placeId: placeId,
                arrivedAt: arrivedAt,
                departedAt: departedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int placeId,
                required DateTime arrivedAt,
                Value<DateTime?> departedAt = const Value.absent(),
              }) => VisitsCompanion.insert(
                id: id,
                placeId: placeId,
                arrivedAt: arrivedAt,
                departedAt: departedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$VisitsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({placeId = false, eventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (eventsRefs) db.events],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (placeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.placeId,
                                referencedTable: $$VisitsTableReferences
                                    ._placeIdTable(db),
                                referencedColumn: $$VisitsTableReferences
                                    ._placeIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (eventsRefs)
                    await $_getPrefetchedData<VisitRow, $VisitsTable, EventRow>(
                      currentTable: table,
                      referencedTable: $$VisitsTableReferences._eventsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$VisitsTableReferences(db, table, p0).eventsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.fromVisitId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$VisitsTableProcessedTableManager =
    ProcessedTableManager<
      _$DaylineDatabase,
      $VisitsTable,
      VisitRow,
      $$VisitsTableFilterComposer,
      $$VisitsTableOrderingComposer,
      $$VisitsTableAnnotationComposer,
      $$VisitsTableCreateCompanionBuilder,
      $$VisitsTableUpdateCompanionBuilder,
      (VisitRow, $$VisitsTableReferences),
      VisitRow,
      PrefetchHooks Function({bool placeId, bool eventsRefs})
    >;
typedef $$EventsTableCreateCompanionBuilder =
    EventsCompanion Function({
      Value<int> id,
      required String title,
      Value<String?> notes,
      required int colorValue,
      required int timeOfDay,
      Value<int?> durationMin,
      required Recurrence recurrence,
      Value<int> daysOfWeek,
      Value<int> interval,
      Value<int?> dayOfMonth,
      required CalendarDate startDate,
      Value<CalendarDate?> endDate,
      Value<List<int>> leadMinutes,
      Value<bool> isActive,
      Value<int?> placeId,
      Value<bool> autoCompleteOnArrival,
      Value<int?> fromVisitId,
    });
typedef $$EventsTableUpdateCompanionBuilder =
    EventsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String?> notes,
      Value<int> colorValue,
      Value<int> timeOfDay,
      Value<int?> durationMin,
      Value<Recurrence> recurrence,
      Value<int> daysOfWeek,
      Value<int> interval,
      Value<int?> dayOfMonth,
      Value<CalendarDate> startDate,
      Value<CalendarDate?> endDate,
      Value<List<int>> leadMinutes,
      Value<bool> isActive,
      Value<int?> placeId,
      Value<bool> autoCompleteOnArrival,
      Value<int?> fromVisitId,
    });

final class $$EventsTableReferences
    extends BaseReferences<_$DaylineDatabase, $EventsTable, EventRow> {
  $$EventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlacesTable _placeIdTable(_$DaylineDatabase db) => db.places
      .createAlias($_aliasNameGenerator(db.events.placeId, db.places.id));

  $$PlacesTableProcessedTableManager? get placeId {
    final $_column = $_itemColumn<int>('place_id');
    if ($_column == null) return null;
    final manager = $$PlacesTableTableManager(
      $_db,
      $_db.places,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_placeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $VisitsTable _fromVisitIdTable(_$DaylineDatabase db) => db.visits
      .createAlias($_aliasNameGenerator(db.events.fromVisitId, db.visits.id));

  $$VisitsTableProcessedTableManager? get fromVisitId {
    final $_column = $_itemColumn<int>('from_visit_id');
    if ($_column == null) return null;
    final manager = $$VisitsTableTableManager(
      $_db,
      $_db.visits,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_fromVisitIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CompletionsTable, List<CompletionRow>>
  _completionsRefsTable(_$DaylineDatabase db) => MultiTypedResultKey.fromTable(
    db.completions,
    aliasName: $_aliasNameGenerator(db.events.id, db.completions.eventId),
  );

  $$CompletionsTableProcessedTableManager get completionsRefs {
    final manager = $$CompletionsTableTableManager(
      $_db,
      $_db.completions,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_completionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$OverridesTable, List<OverrideRow>>
  _overridesRefsTable(_$DaylineDatabase db) => MultiTypedResultKey.fromTable(
    db.overrides,
    aliasName: $_aliasNameGenerator(db.events.id, db.overrides.eventId),
  );

  $$OverridesTableProcessedTableManager get overridesRefs {
    final manager = $$OverridesTableTableManager(
      $_db,
      $_db.overrides,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_overridesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EventsTableFilterComposer
    extends Composer<_$DaylineDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeOfDay => $composableBuilder(
    column: $table.timeOfDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Recurrence, Recurrence, int> get recurrence =>
      $composableBuilder(
        column: $table.recurrence,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get daysOfWeek => $composableBuilder(
    column: $table.daysOfWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CalendarDate, CalendarDate, int>
  get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<CalendarDate?, CalendarDate, int>
  get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<int>, List<int>, String>
  get leadMinutes => $composableBuilder(
    column: $table.leadMinutes,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoCompleteOnArrival => $composableBuilder(
    column: $table.autoCompleteOnArrival,
    builder: (column) => ColumnFilters(column),
  );

  $$PlacesTableFilterComposer get placeId {
    final $$PlacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeId,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableFilterComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VisitsTableFilterComposer get fromVisitId {
    final $$VisitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromVisitId,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableFilterComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> completionsRefs(
    Expression<bool> Function($$CompletionsTableFilterComposer f) f,
  ) {
    final $$CompletionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.completions,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompletionsTableFilterComposer(
            $db: $db,
            $table: $db.completions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> overridesRefs(
    Expression<bool> Function($$OverridesTableFilterComposer f) f,
  ) {
    final $$OverridesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.overrides,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OverridesTableFilterComposer(
            $db: $db,
            $table: $db.overrides,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EventsTableOrderingComposer
    extends Composer<_$DaylineDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeOfDay => $composableBuilder(
    column: $table.timeOfDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get daysOfWeek => $composableBuilder(
    column: $table.daysOfWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leadMinutes => $composableBuilder(
    column: $table.leadMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoCompleteOnArrival => $composableBuilder(
    column: $table.autoCompleteOnArrival,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlacesTableOrderingComposer get placeId {
    final $$PlacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeId,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableOrderingComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VisitsTableOrderingComposer get fromVisitId {
    final $$VisitsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromVisitId,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableOrderingComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EventsTableAnnotationComposer
    extends Composer<_$DaylineDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timeOfDay =>
      $composableBuilder(column: $table.timeOfDay, builder: (column) => column);

  GeneratedColumn<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Recurrence, int> get recurrence =>
      $composableBuilder(
        column: $table.recurrence,
        builder: (column) => column,
      );

  GeneratedColumn<int> get daysOfWeek => $composableBuilder(
    column: $table.daysOfWeek,
    builder: (column) => column,
  );

  GeneratedColumn<int> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<CalendarDate, int> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CalendarDate?, int> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<int>, String> get leadMinutes =>
      $composableBuilder(
        column: $table.leadMinutes,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get autoCompleteOnArrival => $composableBuilder(
    column: $table.autoCompleteOnArrival,
    builder: (column) => column,
  );

  $$PlacesTableAnnotationComposer get placeId {
    final $$PlacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeId,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableAnnotationComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VisitsTableAnnotationComposer get fromVisitId {
    final $$VisitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromVisitId,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableAnnotationComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> completionsRefs<T extends Object>(
    Expression<T> Function($$CompletionsTableAnnotationComposer a) f,
  ) {
    final $$CompletionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.completions,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompletionsTableAnnotationComposer(
            $db: $db,
            $table: $db.completions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> overridesRefs<T extends Object>(
    Expression<T> Function($$OverridesTableAnnotationComposer a) f,
  ) {
    final $$OverridesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.overrides,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OverridesTableAnnotationComposer(
            $db: $db,
            $table: $db.overrides,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EventsTableTableManager
    extends
        RootTableManager<
          _$DaylineDatabase,
          $EventsTable,
          EventRow,
          $$EventsTableFilterComposer,
          $$EventsTableOrderingComposer,
          $$EventsTableAnnotationComposer,
          $$EventsTableCreateCompanionBuilder,
          $$EventsTableUpdateCompanionBuilder,
          (EventRow, $$EventsTableReferences),
          EventRow,
          PrefetchHooks Function({
            bool placeId,
            bool fromVisitId,
            bool completionsRefs,
            bool overridesRefs,
          })
        > {
  $$EventsTableTableManager(_$DaylineDatabase db, $EventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<int> timeOfDay = const Value.absent(),
                Value<int?> durationMin = const Value.absent(),
                Value<Recurrence> recurrence = const Value.absent(),
                Value<int> daysOfWeek = const Value.absent(),
                Value<int> interval = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                Value<CalendarDate> startDate = const Value.absent(),
                Value<CalendarDate?> endDate = const Value.absent(),
                Value<List<int>> leadMinutes = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int?> placeId = const Value.absent(),
                Value<bool> autoCompleteOnArrival = const Value.absent(),
                Value<int?> fromVisitId = const Value.absent(),
              }) => EventsCompanion(
                id: id,
                title: title,
                notes: notes,
                colorValue: colorValue,
                timeOfDay: timeOfDay,
                durationMin: durationMin,
                recurrence: recurrence,
                daysOfWeek: daysOfWeek,
                interval: interval,
                dayOfMonth: dayOfMonth,
                startDate: startDate,
                endDate: endDate,
                leadMinutes: leadMinutes,
                isActive: isActive,
                placeId: placeId,
                autoCompleteOnArrival: autoCompleteOnArrival,
                fromVisitId: fromVisitId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<String?> notes = const Value.absent(),
                required int colorValue,
                required int timeOfDay,
                Value<int?> durationMin = const Value.absent(),
                required Recurrence recurrence,
                Value<int> daysOfWeek = const Value.absent(),
                Value<int> interval = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                required CalendarDate startDate,
                Value<CalendarDate?> endDate = const Value.absent(),
                Value<List<int>> leadMinutes = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int?> placeId = const Value.absent(),
                Value<bool> autoCompleteOnArrival = const Value.absent(),
                Value<int?> fromVisitId = const Value.absent(),
              }) => EventsCompanion.insert(
                id: id,
                title: title,
                notes: notes,
                colorValue: colorValue,
                timeOfDay: timeOfDay,
                durationMin: durationMin,
                recurrence: recurrence,
                daysOfWeek: daysOfWeek,
                interval: interval,
                dayOfMonth: dayOfMonth,
                startDate: startDate,
                endDate: endDate,
                leadMinutes: leadMinutes,
                isActive: isActive,
                placeId: placeId,
                autoCompleteOnArrival: autoCompleteOnArrival,
                fromVisitId: fromVisitId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$EventsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                placeId = false,
                fromVisitId = false,
                completionsRefs = false,
                overridesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (completionsRefs) db.completions,
                    if (overridesRefs) db.overrides,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (placeId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.placeId,
                                    referencedTable: $$EventsTableReferences
                                        ._placeIdTable(db),
                                    referencedColumn: $$EventsTableReferences
                                        ._placeIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (fromVisitId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.fromVisitId,
                                    referencedTable: $$EventsTableReferences
                                        ._fromVisitIdTable(db),
                                    referencedColumn: $$EventsTableReferences
                                        ._fromVisitIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (completionsRefs)
                        await $_getPrefetchedData<
                          EventRow,
                          $EventsTable,
                          CompletionRow
                        >(
                          currentTable: table,
                          referencedTable: $$EventsTableReferences
                              ._completionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EventsTableReferences(
                                db,
                                table,
                                p0,
                              ).completionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.eventId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (overridesRefs)
                        await $_getPrefetchedData<
                          EventRow,
                          $EventsTable,
                          OverrideRow
                        >(
                          currentTable: table,
                          referencedTable: $$EventsTableReferences
                              ._overridesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EventsTableReferences(
                                db,
                                table,
                                p0,
                              ).overridesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.eventId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$EventsTableProcessedTableManager =
    ProcessedTableManager<
      _$DaylineDatabase,
      $EventsTable,
      EventRow,
      $$EventsTableFilterComposer,
      $$EventsTableOrderingComposer,
      $$EventsTableAnnotationComposer,
      $$EventsTableCreateCompanionBuilder,
      $$EventsTableUpdateCompanionBuilder,
      (EventRow, $$EventsTableReferences),
      EventRow,
      PrefetchHooks Function({
        bool placeId,
        bool fromVisitId,
        bool completionsRefs,
        bool overridesRefs,
      })
    >;
typedef $$CompletionsTableCreateCompanionBuilder =
    CompletionsCompanion Function({
      required int eventId,
      required CalendarDate date,
      required CompletionStatus status,
      required DateTime completedAt,
      Value<bool> isAutomatic,
      Value<int> rowid,
    });
typedef $$CompletionsTableUpdateCompanionBuilder =
    CompletionsCompanion Function({
      Value<int> eventId,
      Value<CalendarDate> date,
      Value<CompletionStatus> status,
      Value<DateTime> completedAt,
      Value<bool> isAutomatic,
      Value<int> rowid,
    });

final class $$CompletionsTableReferences
    extends
        BaseReferences<_$DaylineDatabase, $CompletionsTable, CompletionRow> {
  $$CompletionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EventsTable _eventIdTable(_$DaylineDatabase db) => db.events
      .createAlias($_aliasNameGenerator(db.completions.eventId, db.events.id));

  $$EventsTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<int>('event_id')!;

    final manager = $$EventsTableTableManager(
      $_db,
      $_db.events,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CompletionsTableFilterComposer
    extends Composer<_$DaylineDatabase, $CompletionsTable> {
  $$CompletionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<CalendarDate, CalendarDate, int> get date =>
      $composableBuilder(
        column: $table.date,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<CompletionStatus, CompletionStatus, int>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAutomatic => $composableBuilder(
    column: $table.isAutomatic,
    builder: (column) => ColumnFilters(column),
  );

  $$EventsTableFilterComposer get eventId {
    final $$EventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableFilterComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CompletionsTableOrderingComposer
    extends Composer<_$DaylineDatabase, $CompletionsTable> {
  $$CompletionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAutomatic => $composableBuilder(
    column: $table.isAutomatic,
    builder: (column) => ColumnOrderings(column),
  );

  $$EventsTableOrderingComposer get eventId {
    final $$EventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableOrderingComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CompletionsTableAnnotationComposer
    extends Composer<_$DaylineDatabase, $CompletionsTable> {
  $$CompletionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<CalendarDate, int> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CompletionStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isAutomatic => $composableBuilder(
    column: $table.isAutomatic,
    builder: (column) => column,
  );

  $$EventsTableAnnotationComposer get eventId {
    final $$EventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableAnnotationComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CompletionsTableTableManager
    extends
        RootTableManager<
          _$DaylineDatabase,
          $CompletionsTable,
          CompletionRow,
          $$CompletionsTableFilterComposer,
          $$CompletionsTableOrderingComposer,
          $$CompletionsTableAnnotationComposer,
          $$CompletionsTableCreateCompanionBuilder,
          $$CompletionsTableUpdateCompanionBuilder,
          (CompletionRow, $$CompletionsTableReferences),
          CompletionRow,
          PrefetchHooks Function({bool eventId})
        > {
  $$CompletionsTableTableManager(_$DaylineDatabase db, $CompletionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompletionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompletionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompletionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> eventId = const Value.absent(),
                Value<CalendarDate> date = const Value.absent(),
                Value<CompletionStatus> status = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<bool> isAutomatic = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompletionsCompanion(
                eventId: eventId,
                date: date,
                status: status,
                completedAt: completedAt,
                isAutomatic: isAutomatic,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int eventId,
                required CalendarDate date,
                required CompletionStatus status,
                required DateTime completedAt,
                Value<bool> isAutomatic = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompletionsCompanion.insert(
                eventId: eventId,
                date: date,
                status: status,
                completedAt: completedAt,
                isAutomatic: isAutomatic,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CompletionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (eventId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.eventId,
                                referencedTable: $$CompletionsTableReferences
                                    ._eventIdTable(db),
                                referencedColumn: $$CompletionsTableReferences
                                    ._eventIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CompletionsTableProcessedTableManager =
    ProcessedTableManager<
      _$DaylineDatabase,
      $CompletionsTable,
      CompletionRow,
      $$CompletionsTableFilterComposer,
      $$CompletionsTableOrderingComposer,
      $$CompletionsTableAnnotationComposer,
      $$CompletionsTableCreateCompanionBuilder,
      $$CompletionsTableUpdateCompanionBuilder,
      (CompletionRow, $$CompletionsTableReferences),
      CompletionRow,
      PrefetchHooks Function({bool eventId})
    >;
typedef $$OverridesTableCreateCompanionBuilder =
    OverridesCompanion Function({
      required int eventId,
      required CalendarDate date,
      required OverrideType type,
      Value<int?> newTimeOfDay,
      Value<int> rowid,
    });
typedef $$OverridesTableUpdateCompanionBuilder =
    OverridesCompanion Function({
      Value<int> eventId,
      Value<CalendarDate> date,
      Value<OverrideType> type,
      Value<int?> newTimeOfDay,
      Value<int> rowid,
    });

final class $$OverridesTableReferences
    extends BaseReferences<_$DaylineDatabase, $OverridesTable, OverrideRow> {
  $$OverridesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EventsTable _eventIdTable(_$DaylineDatabase db) => db.events
      .createAlias($_aliasNameGenerator(db.overrides.eventId, db.events.id));

  $$EventsTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<int>('event_id')!;

    final manager = $$EventsTableTableManager(
      $_db,
      $_db.events,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OverridesTableFilterComposer
    extends Composer<_$DaylineDatabase, $OverridesTable> {
  $$OverridesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<CalendarDate, CalendarDate, int> get date =>
      $composableBuilder(
        column: $table.date,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<OverrideType, OverrideType, int> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get newTimeOfDay => $composableBuilder(
    column: $table.newTimeOfDay,
    builder: (column) => ColumnFilters(column),
  );

  $$EventsTableFilterComposer get eventId {
    final $$EventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableFilterComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OverridesTableOrderingComposer
    extends Composer<_$DaylineDatabase, $OverridesTable> {
  $$OverridesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get newTimeOfDay => $composableBuilder(
    column: $table.newTimeOfDay,
    builder: (column) => ColumnOrderings(column),
  );

  $$EventsTableOrderingComposer get eventId {
    final $$EventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableOrderingComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OverridesTableAnnotationComposer
    extends Composer<_$DaylineDatabase, $OverridesTable> {
  $$OverridesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<CalendarDate, int> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OverrideType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get newTimeOfDay => $composableBuilder(
    column: $table.newTimeOfDay,
    builder: (column) => column,
  );

  $$EventsTableAnnotationComposer get eventId {
    final $$EventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableAnnotationComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OverridesTableTableManager
    extends
        RootTableManager<
          _$DaylineDatabase,
          $OverridesTable,
          OverrideRow,
          $$OverridesTableFilterComposer,
          $$OverridesTableOrderingComposer,
          $$OverridesTableAnnotationComposer,
          $$OverridesTableCreateCompanionBuilder,
          $$OverridesTableUpdateCompanionBuilder,
          (OverrideRow, $$OverridesTableReferences),
          OverrideRow,
          PrefetchHooks Function({bool eventId})
        > {
  $$OverridesTableTableManager(_$DaylineDatabase db, $OverridesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OverridesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OverridesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OverridesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> eventId = const Value.absent(),
                Value<CalendarDate> date = const Value.absent(),
                Value<OverrideType> type = const Value.absent(),
                Value<int?> newTimeOfDay = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OverridesCompanion(
                eventId: eventId,
                date: date,
                type: type,
                newTimeOfDay: newTimeOfDay,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int eventId,
                required CalendarDate date,
                required OverrideType type,
                Value<int?> newTimeOfDay = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OverridesCompanion.insert(
                eventId: eventId,
                date: date,
                type: type,
                newTimeOfDay: newTimeOfDay,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$OverridesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (eventId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.eventId,
                                referencedTable: $$OverridesTableReferences
                                    ._eventIdTable(db),
                                referencedColumn: $$OverridesTableReferences
                                    ._eventIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$OverridesTableProcessedTableManager =
    ProcessedTableManager<
      _$DaylineDatabase,
      $OverridesTable,
      OverrideRow,
      $$OverridesTableFilterComposer,
      $$OverridesTableOrderingComposer,
      $$OverridesTableAnnotationComposer,
      $$OverridesTableCreateCompanionBuilder,
      $$OverridesTableUpdateCompanionBuilder,
      (OverrideRow, $$OverridesTableReferences),
      OverrideRow,
      PrefetchHooks Function({bool eventId})
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$DaylineDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$DaylineDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$DaylineDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$DaylineDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$DaylineDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$DaylineDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$DaylineDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$DaylineDatabase, $SettingsTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;

class $DaylineDatabaseManager {
  final _$DaylineDatabase _db;
  $DaylineDatabaseManager(this._db);
  $$PlacesTableTableManager get places =>
      $$PlacesTableTableManager(_db, _db.places);
  $$VisitsTableTableManager get visits =>
      $$VisitsTableTableManager(_db, _db.visits);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$CompletionsTableTableManager get completions =>
      $$CompletionsTableTableManager(_db, _db.completions);
  $$OverridesTableTableManager get overrides =>
      $$OverridesTableTableManager(_db, _db.overrides);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
