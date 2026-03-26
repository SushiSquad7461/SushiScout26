import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'tables.dart';
import 'connection/unsupported.dart'
    if (dart.library.io) 'connection/native.dart'
    if (dart.library.js) 'connection/web.dart';

export 'tables.dart';

part 'app_database.g.dart';

/// The main database class for SushiScout
///
/// Uses Drift (formerly Moor) for type-safe SQLite operations.
/// Supports offline-first architecture with sync capabilities.
@DriftDatabase(tables: [LocalMatchReports, LocalEvents, SyncQueue, SyncConflicts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connect());

  AppDatabase.forTesting(super.connection);

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

  /// Get all non-deleted matches for a specific team number across all events
  Future<List<LocalMatchReport>> getMatchesByTeamNumber(int teamNumber) {
    return (select(localMatchReports)
      ..where((m) => m.teamNumber.equals(teamNumber) & m.isDeleted.equals(false))
      ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
    .get();
  }

  /// Get all non-deleted matches for a specific team number within an event
  Future<List<LocalMatchReport>> getMatchesByTeamNumberForEvent(
    String eventId,
    int teamNumber,
  ) {
    return (select(localMatchReports)
      ..where((m) =>
          m.eventId.equals(eventId) &
          m.teamNumber.equals(teamNumber) &
          m.isDeleted.equals(false))
      ..orderBy([(m) => OrderingTerm.asc(m.matchNumber)]))
    .get();
  }

  /// Search matches by team number, match number, or scouter name within an event
  Future<List<LocalMatchReport>> searchMatches(
    String eventId,
    String query,
  ) {
    final q = query.trim();
    if (q.isEmpty) return getMatchesForEvent(eventId);

    final asInt = int.tryParse(q);
    return (select(localMatchReports)
      ..where((m) {
        final base = m.eventId.equals(eventId) & m.isDeleted.equals(false);
        if (asInt != null) {
          // Numeric query: match against team number or match number
          return base &
              (m.teamNumber.equals(asInt) | m.matchNumber.equals(asInt));
        }
        // Text query: match against scouter name (case-insensitive via LIKE)
        return base & m.scouterName.like('%$q%');
      })
      ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
    .get();
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

  /// Delete an event and all its associated matches
  Future<void> deleteEvent(String id) {
    return transaction(() async {
      await (delete(localMatchReports)
        ..where((m) => m.eventId.equals(id)))
      .go();
      await (delete(syncQueue)
        ..where((s) => s.eventId.equals(id)))
      .go();
      await (delete(localEvents)
        ..where((e) => e.id.equals(id)))
      .go();
    });
  }

  // Sync Queue Queries

  /// Add an operation to the sync queue
  Future<int> addToSyncQueue(SyncQueueCompanion entry) {
    return into(syncQueue).insert(entry);
  }

  /// Get all pending sync operations (retry count below threshold)
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

  /// Clear all sync operations (use with caution)
  Future<void> clearAllSyncOperations() {
    return delete(syncQueue).go();
  }

  /// Clear only failed sync operations that have exceeded max retries
  Future<void> clearFailedSyncOperations({int maxRetries = 10}) {
    return (delete(syncQueue)
      ..where((s) => s.retryCount.isBiggerOrEqualValue(maxRetries)))
    .go();
  }

  /// Get sync operations that have exceeded retry threshold
  Future<List<SyncQueueData>> getFailedSyncOperations({int maxRetries = 10}) {
    return (select(syncQueue)
      ..where((s) => s.retryCount.isBiggerOrEqualValue(maxRetries))
      ..orderBy([(s) => OrderingTerm.desc(s.lastAttempt)]))
    .get();
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

  /// Clear resolved conflicts older than the given duration
  Future<void> clearResolvedConflicts({Duration olderThan = const Duration(days: 30)}) {
    final cutoff = DateTime.now().subtract(olderThan);
    return (delete(syncConflicts)
      ..where((c) => c.isResolved.equals(true) & c.resolvedAt.isSmallerThanValue(cutoff)))
    .go();
  }

  // Statistics

  /// Runs a COUNT(*) query on [table] with an optional [where] clause.
  Future<int> _countWhere<T extends HasResultSet>(
    ResultSetImplementation<T, dynamic> table, [
    Expression<bool>? where,
  ]) async {
    final countExpr = countAll();
    final query = selectOnly(table)..addColumns([countExpr]);
    if (where != null) query.where(where);
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Get total match count across all events (non-deleted)
  Future<int> getMatchCount() =>
      _countWhere(localMatchReports, localMatchReports.isDeleted.equals(false));

  /// Get match count for a specific event (non-deleted)
  Future<int> getMatchCountForEvent(String eventId) =>
      _countWhere(localMatchReports,
          localMatchReports.eventId.equals(eventId) &
          localMatchReports.isDeleted.equals(false));

  /// Get count of unsynced items
  Future<int> getUnsyncedCount() =>
      _countWhere(localMatchReports, localMatchReports.isSynced.equals(false));

  /// Get count of items in trash
  Future<int> getTrashCount(String eventId) =>
      _countWhere(localMatchReports,
          localMatchReports.eventId.equals(eventId) &
          localMatchReports.isDeleted.equals(true));

  /// Get sync queue statistics broken down by status
  Future<SyncQueueStats> getSyncQueueStats() async {
    final pending = await _countWhere(
        syncQueue, syncQueue.retryCount.isSmallerThanValue(10));
    final failed = await _countWhere(
        syncQueue, syncQueue.retryCount.isBiggerOrEqualValue(10));
    final total = await _countWhere(syncQueue);

    final oldestExpr = syncQueue.createdAt.min();
    final oldestQuery = selectOnly(syncQueue)
      ..where(syncQueue.retryCount.isSmallerThanValue(10))
      ..addColumns([oldestExpr]);
    final oldestRow = await oldestQuery.getSingle();

    return SyncQueueStats(
      totalOperations: total,
      pendingOperations: pending,
      failedOperations: failed,
      oldestPendingAt: oldestRow.read(oldestExpr),
    );
  }

  /// Purge soft-deleted matches older than the given duration
  Future<int> purgeOldDeletedMatches({Duration olderThan = const Duration(days: 30)}) {
    final cutoff = DateTime.now().subtract(olderThan);
    return (delete(localMatchReports)
      ..where((m) => m.isDeleted.equals(true) & m.updatedAt.isSmallerThanValue(cutoff)))
    .go();
  }

  /// Clear all data (for testing/logout)
  Future<void> clearAllData() {
    return transaction(() async {
      await delete(syncQueue).go();
      await delete(syncConflicts).go();
      await delete(localMatchReports).go();
      await delete(localEvents).go();
    });
  }
}

/// Statistics about the sync queue
class SyncQueueStats {
  final int totalOperations;
  final int pendingOperations;
  final int failedOperations;
  final DateTime? oldestPendingAt;

  const SyncQueueStats({
    required this.totalOperations,
    required this.pendingOperations,
    required this.failedOperations,
    this.oldestPendingAt,
  });

  bool get hasFailedOperations => failedOperations > 0;
  bool get hasPendingWork => pendingOperations > 0;
}

