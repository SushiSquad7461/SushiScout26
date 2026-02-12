// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalMatchReportsTable extends LocalMatchReports
    with TableInfo<$LocalMatchReportsTable, LocalMatchReport> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMatchReportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
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
  static const VerificationMeta _gameDataJsonMeta = const VerificationMeta(
    'gameDataJson',
  );
  @override
  late final GeneratedColumn<String> gameDataJson = GeneratedColumn<String>(
    'game_data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventId,
    matchId,
    matchNumber,
    teamNumber,
    alliance,
    scouterName,
    gameDataJson,
    robotDied,
    comments,
    isSynced,
    isDeleted,
    createdAt,
    updatedAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_match_reports';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMatchReport> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
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
    if (data.containsKey('game_data_json')) {
      context.handle(
        _gameDataJsonMeta,
        gameDataJson.isAcceptableOrUnknown(
          data['game_data_json']!,
          _gameDataJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_gameDataJsonMeta);
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
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMatchReport map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMatchReport(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
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
      gameDataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_data_json'],
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
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $LocalMatchReportsTable createAlias(String alias) {
    return $LocalMatchReportsTable(attachedDatabase, alias);
  }
}

class LocalMatchReport extends DataClass
    implements Insertable<LocalMatchReport> {
  final String id;
  final String eventId;
  final String matchId;
  final int matchNumber;
  final int teamNumber;
  final String alliance;
  final String scouterName;
  final String gameDataJson;
  final bool robotDied;
  final String comments;
  final bool isSynced;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;
  const LocalMatchReport({
    required this.id,
    required this.eventId,
    required this.matchId,
    required this.matchNumber,
    required this.teamNumber,
    required this.alliance,
    required this.scouterName,
    required this.gameDataJson,
    required this.robotDied,
    required this.comments,
    required this.isSynced,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_id'] = Variable<String>(eventId);
    map['match_id'] = Variable<String>(matchId);
    map['match_number'] = Variable<int>(matchNumber);
    map['team_number'] = Variable<int>(teamNumber);
    map['alliance'] = Variable<String>(alliance);
    map['scouter_name'] = Variable<String>(scouterName);
    map['game_data_json'] = Variable<String>(gameDataJson);
    map['robot_died'] = Variable<bool>(robotDied);
    map['comments'] = Variable<String>(comments);
    map['is_synced'] = Variable<bool>(isSynced);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  LocalMatchReportsCompanion toCompanion(bool nullToAbsent) {
    return LocalMatchReportsCompanion(
      id: Value(id),
      eventId: Value(eventId),
      matchId: Value(matchId),
      matchNumber: Value(matchNumber),
      teamNumber: Value(teamNumber),
      alliance: Value(alliance),
      scouterName: Value(scouterName),
      gameDataJson: Value(gameDataJson),
      robotDied: Value(robotDied),
      comments: Value(comments),
      isSynced: Value(isSynced),
      isDeleted: Value(isDeleted),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory LocalMatchReport.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMatchReport(
      id: serializer.fromJson<String>(json['id']),
      eventId: serializer.fromJson<String>(json['eventId']),
      matchId: serializer.fromJson<String>(json['matchId']),
      matchNumber: serializer.fromJson<int>(json['matchNumber']),
      teamNumber: serializer.fromJson<int>(json['teamNumber']),
      alliance: serializer.fromJson<String>(json['alliance']),
      scouterName: serializer.fromJson<String>(json['scouterName']),
      gameDataJson: serializer.fromJson<String>(json['gameDataJson']),
      robotDied: serializer.fromJson<bool>(json['robotDied']),
      comments: serializer.fromJson<String>(json['comments']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventId': serializer.toJson<String>(eventId),
      'matchId': serializer.toJson<String>(matchId),
      'matchNumber': serializer.toJson<int>(matchNumber),
      'teamNumber': serializer.toJson<int>(teamNumber),
      'alliance': serializer.toJson<String>(alliance),
      'scouterName': serializer.toJson<String>(scouterName),
      'gameDataJson': serializer.toJson<String>(gameDataJson),
      'robotDied': serializer.toJson<bool>(robotDied),
      'comments': serializer.toJson<String>(comments),
      'isSynced': serializer.toJson<bool>(isSynced),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  LocalMatchReport copyWith({
    String? id,
    String? eventId,
    String? matchId,
    int? matchNumber,
    int? teamNumber,
    String? alliance,
    String? scouterName,
    String? gameDataJson,
    bool? robotDied,
    String? comments,
    bool? isSynced,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => LocalMatchReport(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    matchId: matchId ?? this.matchId,
    matchNumber: matchNumber ?? this.matchNumber,
    teamNumber: teamNumber ?? this.teamNumber,
    alliance: alliance ?? this.alliance,
    scouterName: scouterName ?? this.scouterName,
    gameDataJson: gameDataJson ?? this.gameDataJson,
    robotDied: robotDied ?? this.robotDied,
    comments: comments ?? this.comments,
    isSynced: isSynced ?? this.isSynced,
    isDeleted: isDeleted ?? this.isDeleted,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  LocalMatchReport copyWithCompanion(LocalMatchReportsCompanion data) {
    return LocalMatchReport(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
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
      gameDataJson: data.gameDataJson.present
          ? data.gameDataJson.value
          : this.gameDataJson,
      robotDied: data.robotDied.present ? data.robotDied.value : this.robotDied,
      comments: data.comments.present ? data.comments.value : this.comments,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMatchReport(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('matchId: $matchId, ')
          ..write('matchNumber: $matchNumber, ')
          ..write('teamNumber: $teamNumber, ')
          ..write('alliance: $alliance, ')
          ..write('scouterName: $scouterName, ')
          ..write('gameDataJson: $gameDataJson, ')
          ..write('robotDied: $robotDied, ')
          ..write('comments: $comments, ')
          ..write('isSynced: $isSynced, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    matchId,
    matchNumber,
    teamNumber,
    alliance,
    scouterName,
    gameDataJson,
    robotDied,
    comments,
    isSynced,
    isDeleted,
    createdAt,
    updatedAt,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMatchReport &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.matchId == this.matchId &&
          other.matchNumber == this.matchNumber &&
          other.teamNumber == this.teamNumber &&
          other.alliance == this.alliance &&
          other.scouterName == this.scouterName &&
          other.gameDataJson == this.gameDataJson &&
          other.robotDied == this.robotDied &&
          other.comments == this.comments &&
          other.isSynced == this.isSynced &&
          other.isDeleted == this.isDeleted &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncedAt == this.syncedAt);
}

class LocalMatchReportsCompanion extends UpdateCompanion<LocalMatchReport> {
  final Value<String> id;
  final Value<String> eventId;
  final Value<String> matchId;
  final Value<int> matchNumber;
  final Value<int> teamNumber;
  final Value<String> alliance;
  final Value<String> scouterName;
  final Value<String> gameDataJson;
  final Value<bool> robotDied;
  final Value<String> comments;
  final Value<bool> isSynced;
  final Value<bool> isDeleted;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const LocalMatchReportsCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.matchId = const Value.absent(),
    this.matchNumber = const Value.absent(),
    this.teamNumber = const Value.absent(),
    this.alliance = const Value.absent(),
    this.scouterName = const Value.absent(),
    this.gameDataJson = const Value.absent(),
    this.robotDied = const Value.absent(),
    this.comments = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMatchReportsCompanion.insert({
    required String id,
    required String eventId,
    required String matchId,
    required int matchNumber,
    required int teamNumber,
    required String alliance,
    required String scouterName,
    required String gameDataJson,
    this.robotDied = const Value.absent(),
    this.comments = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.isDeleted = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventId = Value(eventId),
       matchId = Value(matchId),
       matchNumber = Value(matchNumber),
       teamNumber = Value(teamNumber),
       alliance = Value(alliance),
       scouterName = Value(scouterName),
       gameDataJson = Value(gameDataJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalMatchReport> custom({
    Expression<String>? id,
    Expression<String>? eventId,
    Expression<String>? matchId,
    Expression<int>? matchNumber,
    Expression<int>? teamNumber,
    Expression<String>? alliance,
    Expression<String>? scouterName,
    Expression<String>? gameDataJson,
    Expression<bool>? robotDied,
    Expression<String>? comments,
    Expression<bool>? isSynced,
    Expression<bool>? isDeleted,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (matchId != null) 'match_id': matchId,
      if (matchNumber != null) 'match_number': matchNumber,
      if (teamNumber != null) 'team_number': teamNumber,
      if (alliance != null) 'alliance': alliance,
      if (scouterName != null) 'scouter_name': scouterName,
      if (gameDataJson != null) 'game_data_json': gameDataJson,
      if (robotDied != null) 'robot_died': robotDied,
      if (comments != null) 'comments': comments,
      if (isSynced != null) 'is_synced': isSynced,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMatchReportsCompanion copyWith({
    Value<String>? id,
    Value<String>? eventId,
    Value<String>? matchId,
    Value<int>? matchNumber,
    Value<int>? teamNumber,
    Value<String>? alliance,
    Value<String>? scouterName,
    Value<String>? gameDataJson,
    Value<bool>? robotDied,
    Value<String>? comments,
    Value<bool>? isSynced,
    Value<bool>? isDeleted,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return LocalMatchReportsCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      matchId: matchId ?? this.matchId,
      matchNumber: matchNumber ?? this.matchNumber,
      teamNumber: teamNumber ?? this.teamNumber,
      alliance: alliance ?? this.alliance,
      scouterName: scouterName ?? this.scouterName,
      gameDataJson: gameDataJson ?? this.gameDataJson,
      robotDied: robotDied ?? this.robotDied,
      comments: comments ?? this.comments,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
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
    if (gameDataJson.present) {
      map['game_data_json'] = Variable<String>(gameDataJson.value);
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
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMatchReportsCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('matchId: $matchId, ')
          ..write('matchNumber: $matchNumber, ')
          ..write('teamNumber: $teamNumber, ')
          ..write('alliance: $alliance, ')
          ..write('scouterName: $scouterName, ')
          ..write('gameDataJson: $gameDataJson, ')
          ..write('robotDied: $robotDied, ')
          ..write('comments: $comments, ')
          ..write('isSynced: $isSynced, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalEventsTable extends LocalEvents
    with TableInfo<$LocalEventsTable, LocalEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _programTypeMeta = const VerificationMeta(
    'programType',
  );
  @override
  late final GeneratedColumn<String> programType = GeneratedColumn<String>(
    'program_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tbaKeyMeta = const VerificationMeta('tbaKey');
  @override
  late final GeneratedColumn<String> tbaKey = GeneratedColumn<String>(
    'tba_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
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
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    programType,
    tbaKey,
    startDate,
    isSynced,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('program_type')) {
      context.handle(
        _programTypeMeta,
        programType.isAcceptableOrUnknown(
          data['program_type']!,
          _programTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_programTypeMeta);
    }
    if (data.containsKey('tba_key')) {
      context.handle(
        _tbaKeyMeta,
        tbaKey.isAcceptableOrUnknown(data['tba_key']!, _tbaKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_tbaKeyMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      programType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}program_type'],
      )!,
      tbaKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tba_key'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $LocalEventsTable createAlias(String alias) {
    return $LocalEventsTable(attachedDatabase, alias);
  }
}

class LocalEvent extends DataClass implements Insertable<LocalEvent> {
  final String id;
  final String name;
  final String programType;
  final String tbaKey;
  final DateTime startDate;
  final bool isSynced;
  final DateTime? syncedAt;
  const LocalEvent({
    required this.id,
    required this.name,
    required this.programType,
    required this.tbaKey,
    required this.startDate,
    required this.isSynced,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['program_type'] = Variable<String>(programType);
    map['tba_key'] = Variable<String>(tbaKey);
    map['start_date'] = Variable<DateTime>(startDate);
    map['is_synced'] = Variable<bool>(isSynced);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  LocalEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalEventsCompanion(
      id: Value(id),
      name: Value(name),
      programType: Value(programType),
      tbaKey: Value(tbaKey),
      startDate: Value(startDate),
      isSynced: Value(isSynced),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory LocalEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalEvent(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      programType: serializer.fromJson<String>(json['programType']),
      tbaKey: serializer.fromJson<String>(json['tbaKey']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'programType': serializer.toJson<String>(programType),
      'tbaKey': serializer.toJson<String>(tbaKey),
      'startDate': serializer.toJson<DateTime>(startDate),
      'isSynced': serializer.toJson<bool>(isSynced),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  LocalEvent copyWith({
    String? id,
    String? name,
    String? programType,
    String? tbaKey,
    DateTime? startDate,
    bool? isSynced,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => LocalEvent(
    id: id ?? this.id,
    name: name ?? this.name,
    programType: programType ?? this.programType,
    tbaKey: tbaKey ?? this.tbaKey,
    startDate: startDate ?? this.startDate,
    isSynced: isSynced ?? this.isSynced,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  LocalEvent copyWithCompanion(LocalEventsCompanion data) {
    return LocalEvent(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      programType: data.programType.present
          ? data.programType.value
          : this.programType,
      tbaKey: data.tbaKey.present ? data.tbaKey.value : this.tbaKey,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalEvent(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('programType: $programType, ')
          ..write('tbaKey: $tbaKey, ')
          ..write('startDate: $startDate, ')
          ..write('isSynced: $isSynced, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, programType, tbaKey, startDate, isSynced, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalEvent &&
          other.id == this.id &&
          other.name == this.name &&
          other.programType == this.programType &&
          other.tbaKey == this.tbaKey &&
          other.startDate == this.startDate &&
          other.isSynced == this.isSynced &&
          other.syncedAt == this.syncedAt);
}

class LocalEventsCompanion extends UpdateCompanion<LocalEvent> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> programType;
  final Value<String> tbaKey;
  final Value<DateTime> startDate;
  final Value<bool> isSynced;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const LocalEventsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.programType = const Value.absent(),
    this.tbaKey = const Value.absent(),
    this.startDate = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEventsCompanion.insert({
    required String id,
    required String name,
    required String programType,
    required String tbaKey,
    required DateTime startDate,
    this.isSynced = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       programType = Value(programType),
       tbaKey = Value(tbaKey),
       startDate = Value(startDate);
  static Insertable<LocalEvent> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? programType,
    Expression<String>? tbaKey,
    Expression<DateTime>? startDate,
    Expression<bool>? isSynced,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (programType != null) 'program_type': programType,
      if (tbaKey != null) 'tba_key': tbaKey,
      if (startDate != null) 'start_date': startDate,
      if (isSynced != null) 'is_synced': isSynced,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? programType,
    Value<String>? tbaKey,
    Value<DateTime>? startDate,
    Value<bool>? isSynced,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return LocalEventsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      programType: programType ?? this.programType,
      tbaKey: tbaKey ?? this.tbaKey,
      startDate: startDate ?? this.startDate,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (programType.present) {
      map['program_type'] = Variable<String>(programType.value);
    }
    if (tbaKey.present) {
      map['tba_key'] = Variable<String>(tbaKey.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEventsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('programType: $programType, ')
          ..write('tbaKey: $tbaKey, ')
          ..write('startDate: $startDate, ')
          ..write('isSynced: $isSynced, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAttemptMeta = const VerificationMeta(
    'lastAttempt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttempt = GeneratedColumn<DateTime>(
    'last_attempt',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    eventId,
    operation,
    dataJson,
    retryCount,
    errorMessage,
    lastAttempt,
    createdAt,
    priority,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('last_attempt')) {
      context.handle(
        _lastAttemptMeta,
        lastAttempt.isAcceptableOrUnknown(
          data['last_attempt']!,
          _lastAttemptMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      ),
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      lastAttempt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final int id;
  final String entityType;
  final String entityId;
  final String? eventId;
  final String operation;
  final String dataJson;
  final int retryCount;
  final String? errorMessage;
  final DateTime? lastAttempt;
  final DateTime createdAt;
  final int priority;
  const SyncQueueData({
    required this.id,
    required this.entityType,
    required this.entityId,
    this.eventId,
    required this.operation,
    required this.dataJson,
    required this.retryCount,
    this.errorMessage,
    this.lastAttempt,
    required this.createdAt,
    required this.priority,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    map['operation'] = Variable<String>(operation);
    map['data_json'] = Variable<String>(dataJson);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || lastAttempt != null) {
      map['last_attempt'] = Variable<DateTime>(lastAttempt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['priority'] = Variable<int>(priority);
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      operation: Value(operation),
      dataJson: Value(dataJson),
      retryCount: Value(retryCount),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      lastAttempt: lastAttempt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttempt),
      createdAt: Value(createdAt),
      priority: Value(priority),
    );
  }

  factory SyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      eventId: serializer.fromJson<String?>(json['eventId']),
      operation: serializer.fromJson<String>(json['operation']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      lastAttempt: serializer.fromJson<DateTime?>(json['lastAttempt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      priority: serializer.fromJson<int>(json['priority']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'eventId': serializer.toJson<String?>(eventId),
      'operation': serializer.toJson<String>(operation),
      'dataJson': serializer.toJson<String>(dataJson),
      'retryCount': serializer.toJson<int>(retryCount),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'lastAttempt': serializer.toJson<DateTime?>(lastAttempt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'priority': serializer.toJson<int>(priority),
    };
  }

  SyncQueueData copyWith({
    int? id,
    String? entityType,
    String? entityId,
    Value<String?> eventId = const Value.absent(),
    String? operation,
    String? dataJson,
    int? retryCount,
    Value<String?> errorMessage = const Value.absent(),
    Value<DateTime?> lastAttempt = const Value.absent(),
    DateTime? createdAt,
    int? priority,
  }) => SyncQueueData(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    eventId: eventId.present ? eventId.value : this.eventId,
    operation: operation ?? this.operation,
    dataJson: dataJson ?? this.dataJson,
    retryCount: retryCount ?? this.retryCount,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    lastAttempt: lastAttempt.present ? lastAttempt.value : this.lastAttempt,
    createdAt: createdAt ?? this.createdAt,
    priority: priority ?? this.priority,
  );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      operation: data.operation.present ? data.operation.value : this.operation,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      lastAttempt: data.lastAttempt.present
          ? data.lastAttempt.value
          : this.lastAttempt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      priority: data.priority.present ? data.priority.value : this.priority,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('eventId: $eventId, ')
          ..write('operation: $operation, ')
          ..write('dataJson: $dataJson, ')
          ..write('retryCount: $retryCount, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('lastAttempt: $lastAttempt, ')
          ..write('createdAt: $createdAt, ')
          ..write('priority: $priority')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    entityId,
    eventId,
    operation,
    dataJson,
    retryCount,
    errorMessage,
    lastAttempt,
    createdAt,
    priority,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.eventId == this.eventId &&
          other.operation == this.operation &&
          other.dataJson == this.dataJson &&
          other.retryCount == this.retryCount &&
          other.errorMessage == this.errorMessage &&
          other.lastAttempt == this.lastAttempt &&
          other.createdAt == this.createdAt &&
          other.priority == this.priority);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String?> eventId;
  final Value<String> operation;
  final Value<String> dataJson;
  final Value<int> retryCount;
  final Value<String?> errorMessage;
  final Value<DateTime?> lastAttempt;
  final Value<DateTime> createdAt;
  final Value<int> priority;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.operation = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.lastAttempt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.priority = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required String entityId,
    this.eventId = const Value.absent(),
    required String operation,
    required String dataJson,
    this.retryCount = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.lastAttempt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.priority = const Value.absent(),
  }) : entityType = Value(entityType),
       entityId = Value(entityId),
       operation = Value(operation),
       dataJson = Value(dataJson);
  static Insertable<SyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? eventId,
    Expression<String>? operation,
    Expression<String>? dataJson,
    Expression<int>? retryCount,
    Expression<String>? errorMessage,
    Expression<DateTime>? lastAttempt,
    Expression<DateTime>? createdAt,
    Expression<int>? priority,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (eventId != null) 'event_id': eventId,
      if (operation != null) 'operation': operation,
      if (dataJson != null) 'data_json': dataJson,
      if (retryCount != null) 'retry_count': retryCount,
      if (errorMessage != null) 'error_message': errorMessage,
      if (lastAttempt != null) 'last_attempt': lastAttempt,
      if (createdAt != null) 'created_at': createdAt,
      if (priority != null) 'priority': priority,
    });
  }

  SyncQueueCompanion copyWith({
    Value<int>? id,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String?>? eventId,
    Value<String>? operation,
    Value<String>? dataJson,
    Value<int>? retryCount,
    Value<String?>? errorMessage,
    Value<DateTime?>? lastAttempt,
    Value<DateTime>? createdAt,
    Value<int>? priority,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      eventId: eventId ?? this.eventId,
      operation: operation ?? this.operation,
      dataJson: dataJson ?? this.dataJson,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      createdAt: createdAt ?? this.createdAt,
      priority: priority ?? this.priority,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (lastAttempt.present) {
      map['last_attempt'] = Variable<DateTime>(lastAttempt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('eventId: $eventId, ')
          ..write('operation: $operation, ')
          ..write('dataJson: $dataJson, ')
          ..write('retryCount: $retryCount, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('lastAttempt: $lastAttempt, ')
          ..write('createdAt: $createdAt, ')
          ..write('priority: $priority')
          ..write(')'))
        .toString();
  }
}

class $SyncConflictsTable extends SyncConflicts
    with TableInfo<$SyncConflictsTable, SyncConflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncConflictsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localDataJsonMeta = const VerificationMeta(
    'localDataJson',
  );
  @override
  late final GeneratedColumn<String> localDataJson = GeneratedColumn<String>(
    'local_data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverDataJsonMeta = const VerificationMeta(
    'serverDataJson',
  );
  @override
  late final GeneratedColumn<String> serverDataJson = GeneratedColumn<String>(
    'server_data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverTimestampMeta = const VerificationMeta(
    'serverTimestamp',
  );
  @override
  late final GeneratedColumn<DateTime> serverTimestamp =
      GeneratedColumn<DateTime>(
        'server_timestamp',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _isResolvedMeta = const VerificationMeta(
    'isResolved',
  );
  @override
  late final GeneratedColumn<bool> isResolved = GeneratedColumn<bool>(
    'is_resolved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_resolved" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _resolutionMeta = const VerificationMeta(
    'resolution',
  );
  @override
  late final GeneratedColumn<String> resolution = GeneratedColumn<String>(
    'resolution',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    eventId,
    localDataJson,
    serverDataJson,
    serverTimestamp,
    isResolved,
    resolution,
    resolvedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncConflict> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('local_data_json')) {
      context.handle(
        _localDataJsonMeta,
        localDataJson.isAcceptableOrUnknown(
          data['local_data_json']!,
          _localDataJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localDataJsonMeta);
    }
    if (data.containsKey('server_data_json')) {
      context.handle(
        _serverDataJsonMeta,
        serverDataJson.isAcceptableOrUnknown(
          data['server_data_json']!,
          _serverDataJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverDataJsonMeta);
    }
    if (data.containsKey('server_timestamp')) {
      context.handle(
        _serverTimestampMeta,
        serverTimestamp.isAcceptableOrUnknown(
          data['server_timestamp']!,
          _serverTimestampMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverTimestampMeta);
    }
    if (data.containsKey('is_resolved')) {
      context.handle(
        _isResolvedMeta,
        isResolved.isAcceptableOrUnknown(data['is_resolved']!, _isResolvedMeta),
      );
    }
    if (data.containsKey('resolution')) {
      context.handle(
        _resolutionMeta,
        resolution.isAcceptableOrUnknown(data['resolution']!, _resolutionMeta),
      );
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncConflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflict(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      ),
      localDataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_data_json'],
      )!,
      serverDataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_data_json'],
      )!,
      serverTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_timestamp'],
      )!,
      isResolved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_resolved'],
      )!,
      resolution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution'],
      ),
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SyncConflictsTable createAlias(String alias) {
    return $SyncConflictsTable(attachedDatabase, alias);
  }
}

class SyncConflict extends DataClass implements Insertable<SyncConflict> {
  final int id;
  final String entityType;
  final String entityId;
  final String? eventId;
  final String localDataJson;
  final String serverDataJson;
  final DateTime serverTimestamp;
  final bool isResolved;
  final String? resolution;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  const SyncConflict({
    required this.id,
    required this.entityType,
    required this.entityId,
    this.eventId,
    required this.localDataJson,
    required this.serverDataJson,
    required this.serverTimestamp,
    required this.isResolved,
    this.resolution,
    this.resolvedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    map['local_data_json'] = Variable<String>(localDataJson);
    map['server_data_json'] = Variable<String>(serverDataJson);
    map['server_timestamp'] = Variable<DateTime>(serverTimestamp);
    map['is_resolved'] = Variable<bool>(isResolved);
    if (!nullToAbsent || resolution != null) {
      map['resolution'] = Variable<String>(resolution);
    }
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SyncConflictsCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictsCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      localDataJson: Value(localDataJson),
      serverDataJson: Value(serverDataJson),
      serverTimestamp: Value(serverTimestamp),
      isResolved: Value(isResolved),
      resolution: resolution == null && nullToAbsent
          ? const Value.absent()
          : Value(resolution),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      createdAt: Value(createdAt),
    );
  }

  factory SyncConflict.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflict(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      eventId: serializer.fromJson<String?>(json['eventId']),
      localDataJson: serializer.fromJson<String>(json['localDataJson']),
      serverDataJson: serializer.fromJson<String>(json['serverDataJson']),
      serverTimestamp: serializer.fromJson<DateTime>(json['serverTimestamp']),
      isResolved: serializer.fromJson<bool>(json['isResolved']),
      resolution: serializer.fromJson<String?>(json['resolution']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'eventId': serializer.toJson<String?>(eventId),
      'localDataJson': serializer.toJson<String>(localDataJson),
      'serverDataJson': serializer.toJson<String>(serverDataJson),
      'serverTimestamp': serializer.toJson<DateTime>(serverTimestamp),
      'isResolved': serializer.toJson<bool>(isResolved),
      'resolution': serializer.toJson<String?>(resolution),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SyncConflict copyWith({
    int? id,
    String? entityType,
    String? entityId,
    Value<String?> eventId = const Value.absent(),
    String? localDataJson,
    String? serverDataJson,
    DateTime? serverTimestamp,
    bool? isResolved,
    Value<String?> resolution = const Value.absent(),
    Value<DateTime?> resolvedAt = const Value.absent(),
    DateTime? createdAt,
  }) => SyncConflict(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    eventId: eventId.present ? eventId.value : this.eventId,
    localDataJson: localDataJson ?? this.localDataJson,
    serverDataJson: serverDataJson ?? this.serverDataJson,
    serverTimestamp: serverTimestamp ?? this.serverTimestamp,
    isResolved: isResolved ?? this.isResolved,
    resolution: resolution.present ? resolution.value : this.resolution,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  SyncConflict copyWithCompanion(SyncConflictsCompanion data) {
    return SyncConflict(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      localDataJson: data.localDataJson.present
          ? data.localDataJson.value
          : this.localDataJson,
      serverDataJson: data.serverDataJson.present
          ? data.serverDataJson.value
          : this.serverDataJson,
      serverTimestamp: data.serverTimestamp.present
          ? data.serverTimestamp.value
          : this.serverTimestamp,
      isResolved: data.isResolved.present
          ? data.isResolved.value
          : this.isResolved,
      resolution: data.resolution.present
          ? data.resolution.value
          : this.resolution,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflict(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('eventId: $eventId, ')
          ..write('localDataJson: $localDataJson, ')
          ..write('serverDataJson: $serverDataJson, ')
          ..write('serverTimestamp: $serverTimestamp, ')
          ..write('isResolved: $isResolved, ')
          ..write('resolution: $resolution, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    entityId,
    eventId,
    localDataJson,
    serverDataJson,
    serverTimestamp,
    isResolved,
    resolution,
    resolvedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflict &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.eventId == this.eventId &&
          other.localDataJson == this.localDataJson &&
          other.serverDataJson == this.serverDataJson &&
          other.serverTimestamp == this.serverTimestamp &&
          other.isResolved == this.isResolved &&
          other.resolution == this.resolution &&
          other.resolvedAt == this.resolvedAt &&
          other.createdAt == this.createdAt);
}

class SyncConflictsCompanion extends UpdateCompanion<SyncConflict> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String?> eventId;
  final Value<String> localDataJson;
  final Value<String> serverDataJson;
  final Value<DateTime> serverTimestamp;
  final Value<bool> isResolved;
  final Value<String?> resolution;
  final Value<DateTime?> resolvedAt;
  final Value<DateTime> createdAt;
  const SyncConflictsCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.localDataJson = const Value.absent(),
    this.serverDataJson = const Value.absent(),
    this.serverTimestamp = const Value.absent(),
    this.isResolved = const Value.absent(),
    this.resolution = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SyncConflictsCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required String entityId,
    this.eventId = const Value.absent(),
    required String localDataJson,
    required String serverDataJson,
    required DateTime serverTimestamp,
    this.isResolved = const Value.absent(),
    this.resolution = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : entityType = Value(entityType),
       entityId = Value(entityId),
       localDataJson = Value(localDataJson),
       serverDataJson = Value(serverDataJson),
       serverTimestamp = Value(serverTimestamp);
  static Insertable<SyncConflict> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? eventId,
    Expression<String>? localDataJson,
    Expression<String>? serverDataJson,
    Expression<DateTime>? serverTimestamp,
    Expression<bool>? isResolved,
    Expression<String>? resolution,
    Expression<DateTime>? resolvedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (eventId != null) 'event_id': eventId,
      if (localDataJson != null) 'local_data_json': localDataJson,
      if (serverDataJson != null) 'server_data_json': serverDataJson,
      if (serverTimestamp != null) 'server_timestamp': serverTimestamp,
      if (isResolved != null) 'is_resolved': isResolved,
      if (resolution != null) 'resolution': resolution,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SyncConflictsCompanion copyWith({
    Value<int>? id,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String?>? eventId,
    Value<String>? localDataJson,
    Value<String>? serverDataJson,
    Value<DateTime>? serverTimestamp,
    Value<bool>? isResolved,
    Value<String?>? resolution,
    Value<DateTime?>? resolvedAt,
    Value<DateTime>? createdAt,
  }) {
    return SyncConflictsCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      eventId: eventId ?? this.eventId,
      localDataJson: localDataJson ?? this.localDataJson,
      serverDataJson: serverDataJson ?? this.serverDataJson,
      serverTimestamp: serverTimestamp ?? this.serverTimestamp,
      isResolved: isResolved ?? this.isResolved,
      resolution: resolution ?? this.resolution,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (localDataJson.present) {
      map['local_data_json'] = Variable<String>(localDataJson.value);
    }
    if (serverDataJson.present) {
      map['server_data_json'] = Variable<String>(serverDataJson.value);
    }
    if (serverTimestamp.present) {
      map['server_timestamp'] = Variable<DateTime>(serverTimestamp.value);
    }
    if (isResolved.present) {
      map['is_resolved'] = Variable<bool>(isResolved.value);
    }
    if (resolution.present) {
      map['resolution'] = Variable<String>(resolution.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('eventId: $eventId, ')
          ..write('localDataJson: $localDataJson, ')
          ..write('serverDataJson: $serverDataJson, ')
          ..write('serverTimestamp: $serverTimestamp, ')
          ..write('isResolved: $isResolved, ')
          ..write('resolution: $resolution, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalMatchReportsTable localMatchReports =
      $LocalMatchReportsTable(this);
  late final $LocalEventsTable localEvents = $LocalEventsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $SyncConflictsTable syncConflicts = $SyncConflictsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localMatchReports,
    localEvents,
    syncQueue,
    syncConflicts,
  ];
}

typedef $$LocalMatchReportsTableCreateCompanionBuilder =
    LocalMatchReportsCompanion Function({
      required String id,
      required String eventId,
      required String matchId,
      required int matchNumber,
      required int teamNumber,
      required String alliance,
      required String scouterName,
      required String gameDataJson,
      Value<bool> robotDied,
      Value<String> comments,
      Value<bool> isSynced,
      Value<bool> isDeleted,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$LocalMatchReportsTableUpdateCompanionBuilder =
    LocalMatchReportsCompanion Function({
      Value<String> id,
      Value<String> eventId,
      Value<String> matchId,
      Value<int> matchNumber,
      Value<int> teamNumber,
      Value<String> alliance,
      Value<String> scouterName,
      Value<String> gameDataJson,
      Value<bool> robotDied,
      Value<String> comments,
      Value<bool> isSynced,
      Value<bool> isDeleted,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$LocalMatchReportsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMatchReportsTable> {
  $$LocalMatchReportsTableFilterComposer({
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

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchId => $composableBuilder(
    column: $table.matchId,
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

  ColumnFilters<String> get gameDataJson => $composableBuilder(
    column: $table.gameDataJson,
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

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalMatchReportsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMatchReportsTable> {
  $$LocalMatchReportsTableOrderingComposer({
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

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchId => $composableBuilder(
    column: $table.matchId,
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

  ColumnOrderings<String> get gameDataJson => $composableBuilder(
    column: $table.gameDataJson,
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

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMatchReportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMatchReportsTable> {
  $$LocalMatchReportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get matchId =>
      $composableBuilder(column: $table.matchId, builder: (column) => column);

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

  GeneratedColumn<String> get gameDataJson => $composableBuilder(
    column: $table.gameDataJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get robotDied =>
      $composableBuilder(column: $table.robotDied, builder: (column) => column);

  GeneratedColumn<String> get comments =>
      $composableBuilder(column: $table.comments, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$LocalMatchReportsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMatchReportsTable,
          LocalMatchReport,
          $$LocalMatchReportsTableFilterComposer,
          $$LocalMatchReportsTableOrderingComposer,
          $$LocalMatchReportsTableAnnotationComposer,
          $$LocalMatchReportsTableCreateCompanionBuilder,
          $$LocalMatchReportsTableUpdateCompanionBuilder,
          (
            LocalMatchReport,
            BaseReferences<
              _$AppDatabase,
              $LocalMatchReportsTable,
              LocalMatchReport
            >,
          ),
          LocalMatchReport,
          PrefetchHooks Function()
        > {
  $$LocalMatchReportsTableTableManager(
    _$AppDatabase db,
    $LocalMatchReportsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMatchReportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMatchReportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMatchReportsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<int> matchNumber = const Value.absent(),
                Value<int> teamNumber = const Value.absent(),
                Value<String> alliance = const Value.absent(),
                Value<String> scouterName = const Value.absent(),
                Value<String> gameDataJson = const Value.absent(),
                Value<bool> robotDied = const Value.absent(),
                Value<String> comments = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMatchReportsCompanion(
                id: id,
                eventId: eventId,
                matchId: matchId,
                matchNumber: matchNumber,
                teamNumber: teamNumber,
                alliance: alliance,
                scouterName: scouterName,
                gameDataJson: gameDataJson,
                robotDied: robotDied,
                comments: comments,
                isSynced: isSynced,
                isDeleted: isDeleted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventId,
                required String matchId,
                required int matchNumber,
                required int teamNumber,
                required String alliance,
                required String scouterName,
                required String gameDataJson,
                Value<bool> robotDied = const Value.absent(),
                Value<String> comments = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMatchReportsCompanion.insert(
                id: id,
                eventId: eventId,
                matchId: matchId,
                matchNumber: matchNumber,
                teamNumber: teamNumber,
                alliance: alliance,
                scouterName: scouterName,
                gameDataJson: gameDataJson,
                robotDied: robotDied,
                comments: comments,
                isSynced: isSynced,
                isDeleted: isDeleted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalMatchReportsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMatchReportsTable,
      LocalMatchReport,
      $$LocalMatchReportsTableFilterComposer,
      $$LocalMatchReportsTableOrderingComposer,
      $$LocalMatchReportsTableAnnotationComposer,
      $$LocalMatchReportsTableCreateCompanionBuilder,
      $$LocalMatchReportsTableUpdateCompanionBuilder,
      (
        LocalMatchReport,
        BaseReferences<
          _$AppDatabase,
          $LocalMatchReportsTable,
          LocalMatchReport
        >,
      ),
      LocalMatchReport,
      PrefetchHooks Function()
    >;
typedef $$LocalEventsTableCreateCompanionBuilder =
    LocalEventsCompanion Function({
      required String id,
      required String name,
      required String programType,
      required String tbaKey,
      required DateTime startDate,
      Value<bool> isSynced,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$LocalEventsTableUpdateCompanionBuilder =
    LocalEventsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> programType,
      Value<String> tbaKey,
      Value<DateTime> startDate,
      Value<bool> isSynced,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$LocalEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalEventsTable> {
  $$LocalEventsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get programType => $composableBuilder(
    column: $table.programType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tbaKey => $composableBuilder(
    column: $table.tbaKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalEventsTable> {
  $$LocalEventsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get programType => $composableBuilder(
    column: $table.programType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tbaKey => $composableBuilder(
    column: $table.tbaKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalEventsTable> {
  $$LocalEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get programType => $composableBuilder(
    column: $table.programType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tbaKey =>
      $composableBuilder(column: $table.tbaKey, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$LocalEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalEventsTable,
          LocalEvent,
          $$LocalEventsTableFilterComposer,
          $$LocalEventsTableOrderingComposer,
          $$LocalEventsTableAnnotationComposer,
          $$LocalEventsTableCreateCompanionBuilder,
          $$LocalEventsTableUpdateCompanionBuilder,
          (
            LocalEvent,
            BaseReferences<_$AppDatabase, $LocalEventsTable, LocalEvent>,
          ),
          LocalEvent,
          PrefetchHooks Function()
        > {
  $$LocalEventsTableTableManager(_$AppDatabase db, $LocalEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> programType = const Value.absent(),
                Value<String> tbaKey = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEventsCompanion(
                id: id,
                name: name,
                programType: programType,
                tbaKey: tbaKey,
                startDate: startDate,
                isSynced: isSynced,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String programType,
                required String tbaKey,
                required DateTime startDate,
                Value<bool> isSynced = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEventsCompanion.insert(
                id: id,
                name: name,
                programType: programType,
                tbaKey: tbaKey,
                startDate: startDate,
                isSynced: isSynced,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalEventsTable,
      LocalEvent,
      $$LocalEventsTableFilterComposer,
      $$LocalEventsTableOrderingComposer,
      $$LocalEventsTableAnnotationComposer,
      $$LocalEventsTableCreateCompanionBuilder,
      $$LocalEventsTableUpdateCompanionBuilder,
      (
        LocalEvent,
        BaseReferences<_$AppDatabase, $LocalEventsTable, LocalEvent>,
      ),
      LocalEvent,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      required String entityType,
      required String entityId,
      Value<String?> eventId,
      required String operation,
      required String dataJson,
      Value<int> retryCount,
      Value<String?> errorMessage,
      Value<DateTime?> lastAttempt,
      Value<DateTime> createdAt,
      Value<int> priority,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      Value<String> entityType,
      Value<String> entityId,
      Value<String?> eventId,
      Value<String> operation,
      Value<String> dataJson,
      Value<int> retryCount,
      Value<String?> errorMessage,
      Value<DateTime?> lastAttempt,
      Value<DateTime> createdAt,
      Value<int> priority,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
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

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttempt => $composableBuilder(
    column: $table.lastAttempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
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

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttempt => $composableBuilder(
    column: $table.lastAttempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttempt => $composableBuilder(
    column: $table.lastAttempt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueData,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueData,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
          ),
          SyncQueueData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime?> lastAttempt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> priority = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                eventId: eventId,
                operation: operation,
                dataJson: dataJson,
                retryCount: retryCount,
                errorMessage: errorMessage,
                lastAttempt: lastAttempt,
                createdAt: createdAt,
                priority: priority,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityType,
                required String entityId,
                Value<String?> eventId = const Value.absent(),
                required String operation,
                required String dataJson,
                Value<int> retryCount = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime?> lastAttempt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> priority = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                eventId: eventId,
                operation: operation,
                dataJson: dataJson,
                retryCount: retryCount,
                errorMessage: errorMessage,
                lastAttempt: lastAttempt,
                createdAt: createdAt,
                priority: priority,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueData,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueData,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
      ),
      SyncQueueData,
      PrefetchHooks Function()
    >;
typedef $$SyncConflictsTableCreateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<int> id,
      required String entityType,
      required String entityId,
      Value<String?> eventId,
      required String localDataJson,
      required String serverDataJson,
      required DateTime serverTimestamp,
      Value<bool> isResolved,
      Value<String?> resolution,
      Value<DateTime?> resolvedAt,
      Value<DateTime> createdAt,
    });
typedef $$SyncConflictsTableUpdateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<int> id,
      Value<String> entityType,
      Value<String> entityId,
      Value<String?> eventId,
      Value<String> localDataJson,
      Value<String> serverDataJson,
      Value<DateTime> serverTimestamp,
      Value<bool> isResolved,
      Value<String?> resolution,
      Value<DateTime?> resolvedAt,
      Value<DateTime> createdAt,
    });

class $$SyncConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableFilterComposer({
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

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDataJson => $composableBuilder(
    column: $table.localDataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverDataJson => $composableBuilder(
    column: $table.serverDataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverTimestamp => $composableBuilder(
    column: $table.serverTimestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isResolved => $composableBuilder(
    column: $table.isResolved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableOrderingComposer({
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

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDataJson => $composableBuilder(
    column: $table.localDataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverDataJson => $composableBuilder(
    column: $table.serverDataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverTimestamp => $composableBuilder(
    column: $table.serverTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isResolved => $composableBuilder(
    column: $table.isResolved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get localDataJson => $composableBuilder(
    column: $table.localDataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverDataJson => $composableBuilder(
    column: $table.serverDataJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverTimestamp => $composableBuilder(
    column: $table.serverTimestamp,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isResolved => $composableBuilder(
    column: $table.isResolved,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncConflictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncConflictsTable,
          SyncConflict,
          $$SyncConflictsTableFilterComposer,
          $$SyncConflictsTableOrderingComposer,
          $$SyncConflictsTableAnnotationComposer,
          $$SyncConflictsTableCreateCompanionBuilder,
          $$SyncConflictsTableUpdateCompanionBuilder,
          (
            SyncConflict,
            BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflict>,
          ),
          SyncConflict,
          PrefetchHooks Function()
        > {
  $$SyncConflictsTableTableManager(_$AppDatabase db, $SyncConflictsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String> localDataJson = const Value.absent(),
                Value<String> serverDataJson = const Value.absent(),
                Value<DateTime> serverTimestamp = const Value.absent(),
                Value<bool> isResolved = const Value.absent(),
                Value<String?> resolution = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SyncConflictsCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                eventId: eventId,
                localDataJson: localDataJson,
                serverDataJson: serverDataJson,
                serverTimestamp: serverTimestamp,
                isResolved: isResolved,
                resolution: resolution,
                resolvedAt: resolvedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityType,
                required String entityId,
                Value<String?> eventId = const Value.absent(),
                required String localDataJson,
                required String serverDataJson,
                required DateTime serverTimestamp,
                Value<bool> isResolved = const Value.absent(),
                Value<String?> resolution = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SyncConflictsCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                eventId: eventId,
                localDataJson: localDataJson,
                serverDataJson: serverDataJson,
                serverTimestamp: serverTimestamp,
                isResolved: isResolved,
                resolution: resolution,
                resolvedAt: resolvedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncConflictsTable,
      SyncConflict,
      $$SyncConflictsTableFilterComposer,
      $$SyncConflictsTableOrderingComposer,
      $$SyncConflictsTableAnnotationComposer,
      $$SyncConflictsTableCreateCompanionBuilder,
      $$SyncConflictsTableUpdateCompanionBuilder,
      (
        SyncConflict,
        BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflict>,
      ),
      SyncConflict,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalMatchReportsTableTableManager get localMatchReports =>
      $$LocalMatchReportsTableTableManager(_db, _db.localMatchReports);
  $$LocalEventsTableTableManager get localEvents =>
      $$LocalEventsTableTableManager(_db, _db.localEvents);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db, _db.syncConflicts);
}
