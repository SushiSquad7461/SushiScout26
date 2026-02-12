import 'package:drift/drift.dart';

/// Table for storing match reports locally
class LocalMatchReports extends Table {
  // Primary key - matches Firestore document ID
  TextColumn get id => text()();
  
  // Match identification
  TextColumn get eventId => text()();
  TextColumn get matchId => text()();
  IntColumn get matchNumber => integer()();
  IntColumn get teamNumber => integer()();
  TextColumn get alliance => text()();
  TextColumn get scouterName => text()();
  
  // Game data stored as JSON
  TextColumn get gameDataJson => text()();
  
  // Status flags
  BoolColumn get robotDied => boolean().withDefault(const Constant(false))();
  TextColumn get comments => text().withDefault(const Constant(''))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  
  // Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<String> get customConstraints => [
    'UNIQUE(event_id, match_id, team_number)',
  ];
}

/// Table for storing events locally
class LocalEvents extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get programType => text()(); // 'FRC' or 'FTC'
  TextColumn get tbaKey => text()();
  DateTimeColumn get startDate => dateTime()();
  
  // Sync status
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}

/// Table for sync queue - tracks operations that need to be synced
class SyncQueue extends Table {
  // Auto-increment ID
  IntColumn get id => integer().autoIncrement()();
  
  // Entity being synced
  TextColumn get entityType => text()(); // 'match', 'event'
  TextColumn get entityId => text()();
  TextColumn get eventId => text().nullable()(); // For matches
  
  // Operation type
  TextColumn get operation => text()(); // 'create', 'update', 'delete'
  
  // Data stored as JSON
  TextColumn get dataJson => text()();
  
  // Status
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get lastAttempt => dateTime().nullable()();
  
  // Timestamps
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  // Priority (lower = higher priority)
  IntColumn get priority => integer().withDefault(const Constant(0))();
}

/// Table for tracking sync conflicts
class SyncConflicts extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get eventId => text().nullable()();
  
  // Local and server versions
  TextColumn get localDataJson => text()();
  TextColumn get serverDataJson => text()();
  DateTimeColumn get serverTimestamp => dateTime()();
  
  // Resolution
  BoolColumn get isResolved => boolean().withDefault(const Constant(false))();
  TextColumn get resolution => text().nullable()(); // 'local', 'server', 'merge'
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
