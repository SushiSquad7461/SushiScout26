import 'package:drift/drift.dart';

import 'tables.dart';
import 'connection/unsupported.dart'
    if (dart.library.io) 'connection/native.dart';

export 'tables.dart';

part 'app_database.g.dart';

/// The main database class for SushiScout
/// 
/// Uses Drift (formerly Moor) for type-safe SQLite operations.
/// Supports offline-first architecture with sync capabilities.
@DriftDatabase(tables: [LocalMatchReports, LocalEvents, SyncQueue, SyncConflicts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connect());
  
  AppDatabase.forTesting(DatabaseConnection connection) : super(connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Handle migrations here when schema changes
      if (from < 2) {
        // Migration logic for version 2
      }
    },
  );

  // Match Report Queries
  
  /// Get all non-deleted matches for an event
  Future<List<LocalMatchReport>> getMatchesForEvent(String eventId) {
    return (select(localMatchReports)
      ..where((m) => m.eventId.equals(eventId) & m.isDeleted.equals(false))
      ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
    .get();
  }

  /// Get all deleted matches (trash) for an event
  Future<List<LocalMatchReport>> getDeletedMatchesForEvent(String eventId) {
    return (select(localMatchReports)
      ..where((m) => m.eventId.equals(eventId) & m.isDeleted.equals(true))
      ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
    .get();
  }

  /// Get a specific match by ID
  Future<LocalMatchReport?> getMatch(String id) {
    return (select(localMatchReports)
      ..where((m) => m.id.equals(id)))
    .getSingleOrNull();
  }

  /// Insert or update a match
  Future<void> upsertMatch(LocalMatchReportsCompanion match) {
    return into(localMatchReports).insertOnConflictUpdate(match);
  }

  /// Soft delete a match
  Future<void> softDeleteMatch(String id) {
    return (update(localMatchReports)
      ..where((m) => m.id.equals(id)))
    .write(const LocalMatchReportsCompanion(isDeleted: Value(true)));
  }

  /// Restore a soft-deleted match
  Future<void> restoreMatch(String id) {
    return (update(localMatchReports)
      ..where((m) => m.id.equals(id)))
    .write(const LocalMatchReportsCompanion(isDeleted: Value(false)));
  }

  /// Permanently delete a match
  Future<void> permanentlyDeleteMatch(String id) {
    return (delete(localMatchReports)
      ..where((m) => m.id.equals(id)))
    .go();
  }

  /// Mark a match as synced
  Future<void> markMatchSynced(String id) {
    return (update(localMatchReports)
      ..where((m) => m.id.equals(id)))
    .write(LocalMatchReportsCompanion(
      isSynced: const Value(true),
      syncedAt: Value(DateTime.now()),
    ));
  }

  /// Get all unsynced matches
  Future<List<LocalMatchReport>> getUnsyncedMatches() {
    return (select(localMatchReports)
      ..where((m) => m.isSynced.equals(false) & m.isDeleted.equals(false)))
    .get();
  }

  // Event Queries

  /// Get all events
  Future<List<LocalEvent>> getAllEvents() {
    return select(localEvents).get();
  }

  /// Get a specific event
  Future<LocalEvent?> getEvent(String id) {
    return (select(localEvents)
      ..where((e) => e.id.equals(id)))
    .getSingleOrNull();
  }

  /// Insert or update an event
  Future<void> upsertEvent(LocalEventsCompanion event) {
    return into(localEvents).insertOnConflictUpdate(event);
  }

  // Sync Queue Queries

  /// Add an operation to the sync queue
  Future<int> addToSyncQueue(SyncQueueCompanion entry) {
    return into(syncQueue).insert(entry);
  }

  /// Get all pending sync operations
  Future<List<SyncQueueData>> getPendingSyncOperations() {
    return (select(syncQueue)
      ..where((s) => s.retryCount.isSmallerThanValue(10))
      ..orderBy([
        (s) => OrderingTerm.asc(s.priority),
        (s) => OrderingTerm.asc(s.createdAt),
      ]))
    .get();
  }

  /// Get operations for a specific entity
  Future<List<SyncQueueData>> getSyncOperationsForEntity(
    String entityType,
    String entityId,
  ) {
    return (select(syncQueue)
      ..where((s) => s.entityType.equals(entityType) & s.entityId.equals(entityId))
      ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
    .get();
  }

  /// Mark sync operation as completed (delete it)
  Future<void> completeSyncOperation(int id) {
    return (delete(syncQueue)
      ..where((s) => s.id.equals(id)))
    .go();
  }

  /// Update retry count and error for a sync operation
  Future<void> updateSyncOperationRetry(
    int id, {
    required int retryCount,
    String? errorMessage,
  }) {
    return (update(syncQueue)
      ..where((s) => s.id.equals(id)))
    .write(SyncQueueCompanion(
      retryCount: Value(retryCount),
      errorMessage: Value(errorMessage),
      lastAttempt: Value(DateTime.now()),
    ));
  }

  /// Clear completed sync operations
  Future<void> clearCompletedSyncOperations() {
    return delete(syncQueue).go();
  }

  // Conflict Resolution Queries

  /// Record a sync conflict
  Future<int> recordConflict(SyncConflictsCompanion conflict) {
    return into(syncConflicts).insert(conflict);
  }

  /// Get all unresolved conflicts
  Future<List<SyncConflict>> getUnresolvedConflicts() {
    return (select(syncConflicts)
      ..where((c) => c.isResolved.equals(false))
      ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
    .get();
  }

  /// Resolve a conflict
  Future<void> resolveConflict(int id, String resolution) {
    return (update(syncConflicts)
      ..where((c) => c.id.equals(id)))
    .write(SyncConflictsCompanion(
      isResolved: const Value(true),
      resolution: Value(resolution),
      resolvedAt: Value(DateTime.now()),
    ));
  }

  // Statistics

  /// Get count of unsynced items
  Future<int> getUnsyncedCount() async {
    final count = await (select(localMatchReports)
      ..where((m) => m.isSynced.equals(false)))
    .get();
    return count.length;
  }

  /// Get count of items in trash
  Future<int> getTrashCount(String eventId) async {
    final count = await (select(localMatchReports)
      ..where((m) => m.eventId.equals(eventId) & m.isDeleted.equals(true)))
    .get();
    return count.length;
  }

  /// Clear all data (for testing/logout)
  Future<void> clearAllData() async {
    await delete(localMatchReports).go();
    await delete(localEvents).go();
    await delete(syncQueue).go();
    await delete(syncConflicts).go();
  }
}

