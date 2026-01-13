// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $MatchEntriesTable extends MatchEntries
    with TableInfo<$MatchEntriesTable, MatchEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventCodeMeta = const VerificationMeta(
    'eventCode',
  );
  @override
  late final GeneratedColumn<String> eventCode = GeneratedColumn<String>(
    'event_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchNumberMeta = const VerificationMeta(
    'matchNumber',
  );
  @override
  late final GeneratedColumn<int> matchNumber = GeneratedColumn<int>(
    'match_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _teamNumberMeta = const VerificationMeta(
    'teamNumber',
  );
  @override
  late final GeneratedColumn<int> teamNumber = GeneratedColumn<int>(
    'team_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _allianceMeta = const VerificationMeta(
    'alliance',
  );
  @override
  late final GeneratedColumn<String> alliance = GeneratedColumn<String>(
    'alliance',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scouterNameMeta = const VerificationMeta(
    'scouterName',
  );
  @override
  late final GeneratedColumn<String> scouterName = GeneratedColumn<String>(
    'scouter_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _autoFuelMeta = const VerificationMeta(
    'autoFuel',
  );
  @override
  late final GeneratedColumn<int> autoFuel = GeneratedColumn<int>(
    'auto_fuel',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _autoTowerL1Meta = const VerificationMeta(
    'autoTowerL1',
  );
  @override
  late final GeneratedColumn<bool> autoTowerL1 = GeneratedColumn<bool>(
    'auto_tower_l1',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_tower_l1" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _teleopFuelMeta = const VerificationMeta(
    'teleopFuel',
  );
  @override
  late final GeneratedColumn<int> teleopFuel = GeneratedColumn<int>(
    'teleop_fuel',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _teleopTowerLevelMeta = const VerificationMeta(
    'teleopTowerLevel',
  );
  @override
  late final GeneratedColumn<int> teleopTowerLevel = GeneratedColumn<int>(
    'teleop_tower_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _defenseRatingMeta = const VerificationMeta(
    'defenseRating',
  );
  @override
  late final GeneratedColumn<int> defenseRating = GeneratedColumn<int>(
    'defense_rating',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _driverSkillMeta = const VerificationMeta(
    'driverSkill',
  );
  @override
  late final GeneratedColumn<int> driverSkill = GeneratedColumn<int>(
    'driver_skill',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _robotDiedMeta = const VerificationMeta(
    'robotDied',
  );
  @override
  late final GeneratedColumn<bool> robotDied = GeneratedColumn<bool>(
    'robot_died',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("robot_died" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _commentsMeta = const VerificationMeta(
    'comments',
  );
  @override
  late final GeneratedColumn<String> comments = GeneratedColumn<String>(
    'comments',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
    'is_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventCode,
    matchNumber,
    teamNumber,
    alliance,
    scouterName,
    autoFuel,
    autoTowerL1,
    teleopFuel,
    teleopTowerLevel,
    defenseRating,
    driverSkill,
    robotDied,
    comments,
    isSynced,
    lastUpdated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_code')) {
      context.handle(
        _eventCodeMeta,
        eventCode.isAcceptableOrUnknown(data['event_code']!, _eventCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventCodeMeta);
    }
    if (data.containsKey('match_number')) {
      context.handle(
        _matchNumberMeta,
        matchNumber.isAcceptableOrUnknown(
          data['match_number']!,
          _matchNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_matchNumberMeta);
    }
    if (data.containsKey('team_number')) {
      context.handle(
        _teamNumberMeta,
        teamNumber.isAcceptableOrUnknown(data['team_number']!, _teamNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_teamNumberMeta);
    }
    if (data.containsKey('alliance')) {
      context.handle(
        _allianceMeta,
        alliance.isAcceptableOrUnknown(data['alliance']!, _allianceMeta),
      );
    } else if (isInserting) {
      context.missing(_allianceMeta);
    }
    if (data.containsKey('scouter_name')) {
      context.handle(
        _scouterNameMeta,
        scouterName.isAcceptableOrUnknown(
          data['scouter_name']!,
          _scouterNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scouterNameMeta);
    }
    if (data.containsKey('auto_fuel')) {
      context.handle(
        _autoFuelMeta,
        autoFuel.isAcceptableOrUnknown(data['auto_fuel']!, _autoFuelMeta),
      );
    }
    if (data.containsKey('auto_tower_l1')) {
      context.handle(
        _autoTowerL1Meta,
        autoTowerL1.isAcceptableOrUnknown(
          data['auto_tower_l1']!,
          _autoTowerL1Meta,
        ),
      );
    }
    if (data.containsKey('teleop_fuel')) {
      context.handle(
        _teleopFuelMeta,
        teleopFuel.isAcceptableOrUnknown(data['teleop_fuel']!, _teleopFuelMeta),
      );
    }
    if (data.containsKey('teleop_tower_level')) {
      context.handle(
        _teleopTowerLevelMeta,
        teleopTowerLevel.isAcceptableOrUnknown(
          data['teleop_tower_level']!,
          _teleopTowerLevelMeta,
        ),
      );
    }
    if (data.containsKey('defense_rating')) {
      context.handle(
        _defenseRatingMeta,
        defenseRating.isAcceptableOrUnknown(
          data['defense_rating']!,
          _defenseRatingMeta,
        ),
      );
    }
    if (data.containsKey('driver_skill')) {
      context.handle(
        _driverSkillMeta,
        driverSkill.isAcceptableOrUnknown(
          data['driver_skill']!,
          _driverSkillMeta,
        ),
      );
    }
    if (data.containsKey('robot_died')) {
      context.handle(
        _robotDiedMeta,
        robotDied.isAcceptableOrUnknown(data['robot_died']!, _robotDiedMeta),
      );
    }
    if (data.containsKey('comments')) {
      context.handle(
        _commentsMeta,
        comments.isAcceptableOrUnknown(data['comments']!, _commentsMeta),
      );
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MatchEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_code'],
      )!,
      matchNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}match_number'],
      )!,
      teamNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}team_number'],
      )!,
      alliance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alliance'],
      )!,
      scouterName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scouter_name'],
      )!,
      autoFuel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}auto_fuel'],
      )!,
      autoTowerL1: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_tower_l1'],
      )!,
      teleopFuel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}teleop_fuel'],
      )!,
      teleopTowerLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}teleop_tower_level'],
      )!,
      defenseRating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}defense_rating'],
      )!,
      driverSkill: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}driver_skill'],
      )!,
      robotDied: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}robot_died'],
      )!,
      comments: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comments'],
      )!,
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      )!,
    );
  }

  @override
  $MatchEntriesTable createAlias(String alias) {
    return $MatchEntriesTable(attachedDatabase, alias);
  }
}

class MatchEntry extends DataClass implements Insertable<MatchEntry> {
  final String id;
  final String eventCode;
  final int matchNumber;
  final int teamNumber;
  final String alliance;
  final String scouterName;
  final int autoFuel;
  final bool autoTowerL1;
  final int teleopFuel;
  final int teleopTowerLevel;
  final int defenseRating;
  final int driverSkill;
  final bool robotDied;
  final String comments;
  final bool isSynced;
  final DateTime lastUpdated;
  const MatchEntry({
    required this.id,
    required this.eventCode,
    required this.matchNumber,
    required this.teamNumber,
    required this.alliance,
    required this.scouterName,
    required this.autoFuel,
    required this.autoTowerL1,
    required this.teleopFuel,
    required this.teleopTowerLevel,
    required this.defenseRating,
    required this.driverSkill,
    required this.robotDied,
    required this.comments,
    required this.isSynced,
    required this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_code'] = Variable<String>(eventCode);
    map['match_number'] = Variable<int>(matchNumber);
    map['team_number'] = Variable<int>(teamNumber);
    map['alliance'] = Variable<String>(alliance);
    map['scouter_name'] = Variable<String>(scouterName);
    map['auto_fuel'] = Variable<int>(autoFuel);
    map['auto_tower_l1'] = Variable<bool>(autoTowerL1);
    map['teleop_fuel'] = Variable<int>(teleopFuel);
    map['teleop_tower_level'] = Variable<int>(teleopTowerLevel);
    map['defense_rating'] = Variable<int>(defenseRating);
    map['driver_skill'] = Variable<int>(driverSkill);
    map['robot_died'] = Variable<bool>(robotDied);
    map['comments'] = Variable<String>(comments);
    map['is_synced'] = Variable<bool>(isSynced);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  MatchEntriesCompanion toCompanion(bool nullToAbsent) {
    return MatchEntriesCompanion(
      id: Value(id),
      eventCode: Value(eventCode),
      matchNumber: Value(matchNumber),
      teamNumber: Value(teamNumber),
      alliance: Value(alliance),
      scouterName: Value(scouterName),
      autoFuel: Value(autoFuel),
      autoTowerL1: Value(autoTowerL1),
      teleopFuel: Value(teleopFuel),
      teleopTowerLevel: Value(teleopTowerLevel),
      defenseRating: Value(defenseRating),
      driverSkill: Value(driverSkill),
      robotDied: Value(robotDied),
      comments: Value(comments),
      isSynced: Value(isSynced),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory MatchEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchEntry(
      id: serializer.fromJson<String>(json['id']),
      eventCode: serializer.fromJson<String>(json['eventCode']),
      matchNumber: serializer.fromJson<int>(json['matchNumber']),
      teamNumber: serializer.fromJson<int>(json['teamNumber']),
      alliance: serializer.fromJson<String>(json['alliance']),
      scouterName: serializer.fromJson<String>(json['scouterName']),
      autoFuel: serializer.fromJson<int>(json['autoFuel']),
      autoTowerL1: serializer.fromJson<bool>(json['autoTowerL1']),
      teleopFuel: serializer.fromJson<int>(json['teleopFuel']),
      teleopTowerLevel: serializer.fromJson<int>(json['teleopTowerLevel']),
      defenseRating: serializer.fromJson<int>(json['defenseRating']),
      driverSkill: serializer.fromJson<int>(json['driverSkill']),
      robotDied: serializer.fromJson<bool>(json['robotDied']),
      comments: serializer.fromJson<String>(json['comments']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventCode': serializer.toJson<String>(eventCode),
      'matchNumber': serializer.toJson<int>(matchNumber),
      'teamNumber': serializer.toJson<int>(teamNumber),
      'alliance': serializer.toJson<String>(alliance),
      'scouterName': serializer.toJson<String>(scouterName),
      'autoFuel': serializer.toJson<int>(autoFuel),
      'autoTowerL1': serializer.toJson<bool>(autoTowerL1),
      'teleopFuel': serializer.toJson<int>(teleopFuel),
      'teleopTowerLevel': serializer.toJson<int>(teleopTowerLevel),
      'defenseRating': serializer.toJson<int>(defenseRating),
      'driverSkill': serializer.toJson<int>(driverSkill),
      'robotDied': serializer.toJson<bool>(robotDied),
      'comments': serializer.toJson<String>(comments),
      'isSynced': serializer.toJson<bool>(isSynced),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  MatchEntry copyWith({
    String? id,
    String? eventCode,
    int? matchNumber,
    int? teamNumber,
    String? alliance,
    String? scouterName,
    int? autoFuel,
    bool? autoTowerL1,
    int? teleopFuel,
    int? teleopTowerLevel,
    int? defenseRating,
    int? driverSkill,
    bool? robotDied,
    String? comments,
    bool? isSynced,
    DateTime? lastUpdated,
  }) => MatchEntry(
    id: id ?? this.id,
    eventCode: eventCode ?? this.eventCode,
    matchNumber: matchNumber ?? this.matchNumber,
    teamNumber: teamNumber ?? this.teamNumber,
    alliance: alliance ?? this.alliance,
    scouterName: scouterName ?? this.scouterName,
    autoFuel: autoFuel ?? this.autoFuel,
    autoTowerL1: autoTowerL1 ?? this.autoTowerL1,
    teleopFuel: teleopFuel ?? this.teleopFuel,
    teleopTowerLevel: teleopTowerLevel ?? this.teleopTowerLevel,
    defenseRating: defenseRating ?? this.defenseRating,
    driverSkill: driverSkill ?? this.driverSkill,
    robotDied: robotDied ?? this.robotDied,
    comments: comments ?? this.comments,
    isSynced: isSynced ?? this.isSynced,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );
  MatchEntry copyWithCompanion(MatchEntriesCompanion data) {
    return MatchEntry(
      id: data.id.present ? data.id.value : this.id,
      eventCode: data.eventCode.present ? data.eventCode.value : this.eventCode,
      matchNumber: data.matchNumber.present
          ? data.matchNumber.value
          : this.matchNumber,
      teamNumber: data.teamNumber.present
          ? data.teamNumber.value
          : this.teamNumber,
      alliance: data.alliance.present ? data.alliance.value : this.alliance,
      scouterName: data.scouterName.present
          ? data.scouterName.value
          : this.scouterName,
      autoFuel: data.autoFuel.present ? data.autoFuel.value : this.autoFuel,
      autoTowerL1: data.autoTowerL1.present
          ? data.autoTowerL1.value
          : this.autoTowerL1,
      teleopFuel: data.teleopFuel.present
          ? data.teleopFuel.value
          : this.teleopFuel,
      teleopTowerLevel: data.teleopTowerLevel.present
          ? data.teleopTowerLevel.value
          : this.teleopTowerLevel,
      defenseRating: data.defenseRating.present
          ? data.defenseRating.value
          : this.defenseRating,
      driverSkill: data.driverSkill.present
          ? data.driverSkill.value
          : this.driverSkill,
      robotDied: data.robotDied.present ? data.robotDied.value : this.robotDied,
      comments: data.comments.present ? data.comments.value : this.comments,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchEntry(')
          ..write('id: $id, ')
          ..write('eventCode: $eventCode, ')
          ..write('matchNumber: $matchNumber, ')
          ..write('teamNumber: $teamNumber, ')
          ..write('alliance: $alliance, ')
          ..write('scouterName: $scouterName, ')
          ..write('autoFuel: $autoFuel, ')
          ..write('autoTowerL1: $autoTowerL1, ')
          ..write('teleopFuel: $teleopFuel, ')
          ..write('teleopTowerLevel: $teleopTowerLevel, ')
          ..write('defenseRating: $defenseRating, ')
          ..write('driverSkill: $driverSkill, ')
          ..write('robotDied: $robotDied, ')
          ..write('comments: $comments, ')
          ..write('isSynced: $isSynced, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventCode,
    matchNumber,
    teamNumber,
    alliance,
    scouterName,
    autoFuel,
    autoTowerL1,
    teleopFuel,
    teleopTowerLevel,
    defenseRating,
    driverSkill,
    robotDied,
    comments,
    isSynced,
    lastUpdated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchEntry &&
          other.id == this.id &&
          other.eventCode == this.eventCode &&
          other.matchNumber == this.matchNumber &&
          other.teamNumber == this.teamNumber &&
          other.alliance == this.alliance &&
          other.scouterName == this.scouterName &&
          other.autoFuel == this.autoFuel &&
          other.autoTowerL1 == this.autoTowerL1 &&
          other.teleopFuel == this.teleopFuel &&
          other.teleopTowerLevel == this.teleopTowerLevel &&
          other.defenseRating == this.defenseRating &&
          other.driverSkill == this.driverSkill &&
          other.robotDied == this.robotDied &&
          other.comments == this.comments &&
          other.isSynced == this.isSynced &&
          other.lastUpdated == this.lastUpdated);
}

class MatchEntriesCompanion extends UpdateCompanion<MatchEntry> {
  final Value<String> id;
  final Value<String> eventCode;
  final Value<int> matchNumber;
  final Value<int> teamNumber;
  final Value<String> alliance;
  final Value<String> scouterName;
  final Value<int> autoFuel;
  final Value<bool> autoTowerL1;
  final Value<int> teleopFuel;
  final Value<int> teleopTowerLevel;
  final Value<int> defenseRating;
  final Value<int> driverSkill;
  final Value<bool> robotDied;
  final Value<String> comments;
  final Value<bool> isSynced;
  final Value<DateTime> lastUpdated;
  final Value<int> rowid;
  const MatchEntriesCompanion({
    this.id = const Value.absent(),
    this.eventCode = const Value.absent(),
    this.matchNumber = const Value.absent(),
    this.teamNumber = const Value.absent(),
    this.alliance = const Value.absent(),
    this.scouterName = const Value.absent(),
    this.autoFuel = const Value.absent(),
    this.autoTowerL1 = const Value.absent(),
    this.teleopFuel = const Value.absent(),
    this.teleopTowerLevel = const Value.absent(),
    this.defenseRating = const Value.absent(),
    this.driverSkill = const Value.absent(),
    this.robotDied = const Value.absent(),
    this.comments = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchEntriesCompanion.insert({
    required String id,
    required String eventCode,
    required int matchNumber,
    required int teamNumber,
    required String alliance,
    required String scouterName,
    this.autoFuel = const Value.absent(),
    this.autoTowerL1 = const Value.absent(),
    this.teleopFuel = const Value.absent(),
    this.teleopTowerLevel = const Value.absent(),
    this.defenseRating = const Value.absent(),
    this.driverSkill = const Value.absent(),
    this.robotDied = const Value.absent(),
    this.comments = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventCode = Value(eventCode),
       matchNumber = Value(matchNumber),
       teamNumber = Value(teamNumber),
       alliance = Value(alliance),
       scouterName = Value(scouterName);
  static Insertable<MatchEntry> custom({
    Expression<String>? id,
    Expression<String>? eventCode,
    Expression<int>? matchNumber,
    Expression<int>? teamNumber,
    Expression<String>? alliance,
    Expression<String>? scouterName,
    Expression<int>? autoFuel,
    Expression<bool>? autoTowerL1,
    Expression<int>? teleopFuel,
    Expression<int>? teleopTowerLevel,
    Expression<int>? defenseRating,
    Expression<int>? driverSkill,
    Expression<bool>? robotDied,
    Expression<String>? comments,
    Expression<bool>? isSynced,
    Expression<DateTime>? lastUpdated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventCode != null) 'event_code': eventCode,
      if (matchNumber != null) 'match_number': matchNumber,
      if (teamNumber != null) 'team_number': teamNumber,
      if (alliance != null) 'alliance': alliance,
      if (scouterName != null) 'scouter_name': scouterName,
      if (autoFuel != null) 'auto_fuel': autoFuel,
      if (autoTowerL1 != null) 'auto_tower_l1': autoTowerL1,
      if (teleopFuel != null) 'teleop_fuel': teleopFuel,
      if (teleopTowerLevel != null) 'teleop_tower_level': teleopTowerLevel,
      if (defenseRating != null) 'defense_rating': defenseRating,
      if (driverSkill != null) 'driver_skill': driverSkill,
      if (robotDied != null) 'robot_died': robotDied,
      if (comments != null) 'comments': comments,
      if (isSynced != null) 'is_synced': isSynced,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? eventCode,
    Value<int>? matchNumber,
    Value<int>? teamNumber,
    Value<String>? alliance,
    Value<String>? scouterName,
    Value<int>? autoFuel,
    Value<bool>? autoTowerL1,
    Value<int>? teleopFuel,
    Value<int>? teleopTowerLevel,
    Value<int>? defenseRating,
    Value<int>? driverSkill,
    Value<bool>? robotDied,
    Value<String>? comments,
    Value<bool>? isSynced,
    Value<DateTime>? lastUpdated,
    Value<int>? rowid,
  }) {
    return MatchEntriesCompanion(
      id: id ?? this.id,
      eventCode: eventCode ?? this.eventCode,
      matchNumber: matchNumber ?? this.matchNumber,
      teamNumber: teamNumber ?? this.teamNumber,
      alliance: alliance ?? this.alliance,
      scouterName: scouterName ?? this.scouterName,
      autoFuel: autoFuel ?? this.autoFuel,
      autoTowerL1: autoTowerL1 ?? this.autoTowerL1,
      teleopFuel: teleopFuel ?? this.teleopFuel,
      teleopTowerLevel: teleopTowerLevel ?? this.teleopTowerLevel,
      defenseRating: defenseRating ?? this.defenseRating,
      driverSkill: driverSkill ?? this.driverSkill,
      robotDied: robotDied ?? this.robotDied,
      comments: comments ?? this.comments,
      isSynced: isSynced ?? this.isSynced,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventCode.present) {
      map['event_code'] = Variable<String>(eventCode.value);
    }
    if (matchNumber.present) {
      map['match_number'] = Variable<int>(matchNumber.value);
    }
    if (teamNumber.present) {
      map['team_number'] = Variable<int>(teamNumber.value);
    }
    if (alliance.present) {
      map['alliance'] = Variable<String>(alliance.value);
    }
    if (scouterName.present) {
      map['scouter_name'] = Variable<String>(scouterName.value);
    }
    if (autoFuel.present) {
      map['auto_fuel'] = Variable<int>(autoFuel.value);
    }
    if (autoTowerL1.present) {
      map['auto_tower_l1'] = Variable<bool>(autoTowerL1.value);
    }
    if (teleopFuel.present) {
      map['teleop_fuel'] = Variable<int>(teleopFuel.value);
    }
    if (teleopTowerLevel.present) {
      map['teleop_tower_level'] = Variable<int>(teleopTowerLevel.value);
    }
    if (defenseRating.present) {
      map['defense_rating'] = Variable<int>(defenseRating.value);
    }
    if (driverSkill.present) {
      map['driver_skill'] = Variable<int>(driverSkill.value);
    }
    if (robotDied.present) {
      map['robot_died'] = Variable<bool>(robotDied.value);
    }
    if (comments.present) {
      map['comments'] = Variable<String>(comments.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchEntriesCompanion(')
          ..write('id: $id, ')
          ..write('eventCode: $eventCode, ')
          ..write('matchNumber: $matchNumber, ')
          ..write('teamNumber: $teamNumber, ')
          ..write('alliance: $alliance, ')
          ..write('scouterName: $scouterName, ')
          ..write('autoFuel: $autoFuel, ')
          ..write('autoTowerL1: $autoTowerL1, ')
          ..write('teleopFuel: $teleopFuel, ')
          ..write('teleopTowerLevel: $teleopTowerLevel, ')
          ..write('defenseRating: $defenseRating, ')
          ..write('driverSkill: $driverSkill, ')
          ..write('robotDied: $robotDied, ')
          ..write('comments: $comments, ')
          ..write('isSynced: $isSynced, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MatchEntriesTable matchEntries = $MatchEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [matchEntries];
}

typedef $$MatchEntriesTableCreateCompanionBuilder =
    MatchEntriesCompanion Function({
      required String id,
      required String eventCode,
      required int matchNumber,
      required int teamNumber,
      required String alliance,
      required String scouterName,
      Value<int> autoFuel,
      Value<bool> autoTowerL1,
      Value<int> teleopFuel,
      Value<int> teleopTowerLevel,
      Value<int> defenseRating,
      Value<int> driverSkill,
      Value<bool> robotDied,
      Value<String> comments,
      Value<bool> isSynced,
      Value<DateTime> lastUpdated,
      Value<int> rowid,
    });
typedef $$MatchEntriesTableUpdateCompanionBuilder =
    MatchEntriesCompanion Function({
      Value<String> id,
      Value<String> eventCode,
      Value<int> matchNumber,
      Value<int> teamNumber,
      Value<String> alliance,
      Value<String> scouterName,
      Value<int> autoFuel,
      Value<bool> autoTowerL1,
      Value<int> teleopFuel,
      Value<int> teleopTowerLevel,
      Value<int> defenseRating,
      Value<int> driverSkill,
      Value<bool> robotDied,
      Value<String> comments,
      Value<bool> isSynced,
      Value<DateTime> lastUpdated,
      Value<int> rowid,
    });

class $$MatchEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MatchEntriesTable> {
  $$MatchEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventCode => $composableBuilder(
    column: $table.eventCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get matchNumber => $composableBuilder(
    column: $table.matchNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get teamNumber => $composableBuilder(
    column: $table.teamNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alliance => $composableBuilder(
    column: $table.alliance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scouterName => $composableBuilder(
    column: $table.scouterName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get autoFuel => $composableBuilder(
    column: $table.autoFuel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoTowerL1 => $composableBuilder(
    column: $table.autoTowerL1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get teleopFuel => $composableBuilder(
    column: $table.teleopFuel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get teleopTowerLevel => $composableBuilder(
    column: $table.teleopTowerLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defenseRating => $composableBuilder(
    column: $table.defenseRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get driverSkill => $composableBuilder(
    column: $table.driverSkill,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get robotDied => $composableBuilder(
    column: $table.robotDied,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comments => $composableBuilder(
    column: $table.comments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MatchEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchEntriesTable> {
  $$MatchEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventCode => $composableBuilder(
    column: $table.eventCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get matchNumber => $composableBuilder(
    column: $table.matchNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get teamNumber => $composableBuilder(
    column: $table.teamNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alliance => $composableBuilder(
    column: $table.alliance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scouterName => $composableBuilder(
    column: $table.scouterName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get autoFuel => $composableBuilder(
    column: $table.autoFuel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoTowerL1 => $composableBuilder(
    column: $table.autoTowerL1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get teleopFuel => $composableBuilder(
    column: $table.teleopFuel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get teleopTowerLevel => $composableBuilder(
    column: $table.teleopTowerLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defenseRating => $composableBuilder(
    column: $table.defenseRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get driverSkill => $composableBuilder(
    column: $table.driverSkill,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get robotDied => $composableBuilder(
    column: $table.robotDied,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comments => $composableBuilder(
    column: $table.comments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MatchEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchEntriesTable> {
  $$MatchEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventCode =>
      $composableBuilder(column: $table.eventCode, builder: (column) => column);

  GeneratedColumn<int> get matchNumber => $composableBuilder(
    column: $table.matchNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get teamNumber => $composableBuilder(
    column: $table.teamNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alliance =>
      $composableBuilder(column: $table.alliance, builder: (column) => column);

  GeneratedColumn<String> get scouterName => $composableBuilder(
    column: $table.scouterName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get autoFuel =>
      $composableBuilder(column: $table.autoFuel, builder: (column) => column);

  GeneratedColumn<bool> get autoTowerL1 => $composableBuilder(
    column: $table.autoTowerL1,
    builder: (column) => column,
  );

  GeneratedColumn<int> get teleopFuel => $composableBuilder(
    column: $table.teleopFuel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get teleopTowerLevel => $composableBuilder(
    column: $table.teleopTowerLevel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defenseRating => $composableBuilder(
    column: $table.defenseRating,
    builder: (column) => column,
  );

  GeneratedColumn<int> get driverSkill => $composableBuilder(
    column: $table.driverSkill,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get robotDied =>
      $composableBuilder(column: $table.robotDied, builder: (column) => column);

  GeneratedColumn<String> get comments =>
      $composableBuilder(column: $table.comments, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$MatchEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchEntriesTable,
          MatchEntry,
          $$MatchEntriesTableFilterComposer,
          $$MatchEntriesTableOrderingComposer,
          $$MatchEntriesTableAnnotationComposer,
          $$MatchEntriesTableCreateCompanionBuilder,
          $$MatchEntriesTableUpdateCompanionBuilder,
          (
            MatchEntry,
            BaseReferences<_$AppDatabase, $MatchEntriesTable, MatchEntry>,
          ),
          MatchEntry,
          PrefetchHooks Function()
        > {
  $$MatchEntriesTableTableManager(_$AppDatabase db, $MatchEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventCode = const Value.absent(),
                Value<int> matchNumber = const Value.absent(),
                Value<int> teamNumber = const Value.absent(),
                Value<String> alliance = const Value.absent(),
                Value<String> scouterName = const Value.absent(),
                Value<int> autoFuel = const Value.absent(),
                Value<bool> autoTowerL1 = const Value.absent(),
                Value<int> teleopFuel = const Value.absent(),
                Value<int> teleopTowerLevel = const Value.absent(),
                Value<int> defenseRating = const Value.absent(),
                Value<int> driverSkill = const Value.absent(),
                Value<bool> robotDied = const Value.absent(),
                Value<String> comments = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<DateTime> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchEntriesCompanion(
                id: id,
                eventCode: eventCode,
                matchNumber: matchNumber,
                teamNumber: teamNumber,
                alliance: alliance,
                scouterName: scouterName,
                autoFuel: autoFuel,
                autoTowerL1: autoTowerL1,
                teleopFuel: teleopFuel,
                teleopTowerLevel: teleopTowerLevel,
                defenseRating: defenseRating,
                driverSkill: driverSkill,
                robotDied: robotDied,
                comments: comments,
                isSynced: isSynced,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventCode,
                required int matchNumber,
                required int teamNumber,
                required String alliance,
                required String scouterName,
                Value<int> autoFuel = const Value.absent(),
                Value<bool> autoTowerL1 = const Value.absent(),
                Value<int> teleopFuel = const Value.absent(),
                Value<int> teleopTowerLevel = const Value.absent(),
                Value<int> defenseRating = const Value.absent(),
                Value<int> driverSkill = const Value.absent(),
                Value<bool> robotDied = const Value.absent(),
                Value<String> comments = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<DateTime> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchEntriesCompanion.insert(
                id: id,
                eventCode: eventCode,
                matchNumber: matchNumber,
                teamNumber: teamNumber,
                alliance: alliance,
                scouterName: scouterName,
                autoFuel: autoFuel,
                autoTowerL1: autoTowerL1,
                teleopFuel: teleopFuel,
                teleopTowerLevel: teleopTowerLevel,
                defenseRating: defenseRating,
                driverSkill: driverSkill,
                robotDied: robotDied,
                comments: comments,
                isSynced: isSynced,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MatchEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchEntriesTable,
      MatchEntry,
      $$MatchEntriesTableFilterComposer,
      $$MatchEntriesTableOrderingComposer,
      $$MatchEntriesTableAnnotationComposer,
      $$MatchEntriesTableCreateCompanionBuilder,
      $$MatchEntriesTableUpdateCompanionBuilder,
      (
        MatchEntry,
        BaseReferences<_$AppDatabase, $MatchEntriesTable, MatchEntry>,
      ),
      MatchEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MatchEntriesTableTableManager get matchEntries =>
      $$MatchEntriesTableTableManager(_db, _db.matchEntries);
}
