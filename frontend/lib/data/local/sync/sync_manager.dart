import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart'; // Needed for Value
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/logger.dart';
import '../../../core/network/retry.dart';
import '../../models/match_report.dart';
import '../database/app_database.dart';
import '../../repositories/firestore_repository.dart';

final _logger = Logger('SyncManager');

/// Provider for sync manager. When firestoreRepositoryProvider rebuilds
/// (e.g., on team switch), Riverpod tears down the old SyncManager — we
/// register an onDispose so its Timer and connectivity subscription are
/// cancelled instead of leaking.
final syncManagerProvider = Provider<SyncManager>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final firestore = ref.watch(firestoreRepositoryProvider);
  final manager = SyncManager(db, firestore);
  ref.onDispose(manager.dispose);
  return manager;
});

/// Provider for app database - returns null on web where local DB is not supported
final appDatabaseProvider = Provider<AppDatabase?>((ref) {
  if (kIsWeb) {
    _logger.i('Local database not supported on web, using Firebase only');
    return null;
  }
  return AppDatabase();
});

/// Provider for whether local database is available
final isLocalDbAvailableProvider = Provider<bool>((ref) {
  return ref.watch(appDatabaseProvider) != null;
});

/// Provider for the active team ID — overridden from auth state in main.dart
final activeTeamIdProvider = Provider<String?>((ref) => null);

/// Provider for Firestore repository
final firestoreRepositoryProvider = Provider<FirestoreRepository>((ref) {
  // This should be initialized with proper Firebase instance
  throw UnimplementedError('Initialize with proper Firebase instance');
});

/// Provider for connectivity status
final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  return Connectivity().onConnectivityChanged.map((results) => results.first);
});

/// Provider for online status
final isOnlineProvider = Provider<bool>((ref) {
  final connectivityAsync = ref.watch(connectivityProvider);
  return connectivityAsync.when(
    data: (result) => result != ConnectivityResult.none,
    loading: () => true, // Assume online while loading
    error: (_, _) => false,
  );
});

/// Manages synchronization between local database and Firestore
/// 
/// Features:
/// - Automatic sync when connectivity is restored
/// - Retry logic with exponential backoff
/// - Conflict detection and resolution
/// - Sync queue management
class SyncManager {
  final AppDatabase? _db;
  final FirestoreRepository _firestore;
  final Logger _logger = const Logger('SYNC');
  
  final _retryConfig = const RetryConfig(
    maxAttempts: 5,
    baseDelay: Duration(seconds: 2),
    maxDelay: Duration(minutes: 5),
  );
  
  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;
  bool _initialized = false;
  final _syncController = StreamController<SyncStatus>.broadcast();
  final _pendingCountController = StreamController<int>.broadcast();
  
  Stream<SyncStatus> get syncStream => _syncController.stream;
  Stream<int> get pendingCountStream => _pendingCountController.stream;
  
  bool get isLocalDbAvailable => _db != null;
  
  AppDatabase get db {
    if (_db == null) {
      throw StateError('Local database not available on this platform');
    }
    return _db;
  }
  
  SyncManager(this._db, this._firestore);

  /// Initialize sync manager. Safe to call multiple times — only the first
  /// call sets up the periodic Timer and connectivity subscription.
  void initialize() {
    if (_initialized) {
      _logger.d('SyncManager already initialized, skipping');
      return;
    }
    _logger.i('Initializing sync manager');

    if (_db == null) {
      _logger.i('Local DB not available, sync manager will use Firebase only');
      _initialized = true;
      return;
    }

    // Reset retry counts for stuck operations on startup
    db.getPendingSyncOperations().then((ops) {
      for (final op in ops) {
        if (op.retryCount >= _retryConfig.maxAttempts) {
          db.updateSyncOperationRetry(op.id, retryCount: 0, errorMessage: 'Resetting stuck operation');
        }
      }
    });

    // Queue any unsynced matches from local DB that aren't in sync queue
    _queueExistingUnsyncedMatches();

    // Initial pending count update
    _updatePendingCount();

    // Start periodic sync
    _syncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncPendingChanges(),
    );

    // Listen to connectivity changes — store subscription so dispose() can
    // cancel it. Without this, the closure keeps the disposed SyncManager
    // alive and may write to closed StreamControllers.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final result = results.first;
      if (result != ConnectivityResult.none) {
        _logger.i('Connectivity restored, triggering sync');
        syncPendingChanges();
      }
    });

    _initialized = true;
  }

  /// Queue existing unsynced matches from local DB that aren't in sync queue
  Future<void> _queueExistingUnsyncedMatches() async {
    try {
      final unsyncedMatches = await db.getUnsyncedMatches();
      final pendingOps = await db.getPendingSyncOperations();

      // Get set of match IDs already in sync queue
      final queuedMatchIds = pendingOps
          .where((op) => op.entityType == 'match')
          .map((op) => op.entityId)
          .toSet();

      int queuedCount = 0;
      int skippedCount = 0;
      for (final match in unsyncedMatches) {
        // Skip if already in sync queue
        if (queuedMatchIds.contains(match.id)) {
          continue;
        }

        // Skip if eventId is empty (old matches may not have eventId stored)
        if (match.eventId.isEmpty) {
          _logger.w('Skipping unsynced match with empty eventId', data: {
            'matchId': match.id,
            'reason': 'EventId is required for sync',
          });
          skippedCount++;
          continue;
        }

        _logger.d('Queueing existing unsynced match', data: {
          'matchId': match.id,
          'eventId': match.eventId,
        });

        // Convert LocalMatchReport to MatchReport and queue it
        final matchReport = MatchReport(
          id: match.id,
          matchId: match.matchId,
          matchNumber: match.matchNumber,
          teamNumber: match.teamNumber,
          alliance: match.alliance,
          scouterName: match.scouterName,
          gameData: (jsonDecode(match.gameDataJson) as Map<String, dynamic>)..['robot_died'] = match.robotDied,
          comments: match.comments,
          createdAt: match.createdAt,
          isSynced: false,
          isDeleted: match.isDeleted,
          teamId: match.teamId,
        );

        await queueCreate(match.eventId, matchReport);
        queuedCount++;
      }

      if (skippedCount > 0) {
        _logger.w('Skipped $skippedCount matches with empty eventId - these cannot be synced');
      }

      if (queuedCount > 0) {
        _logger.i('Queued existing unsynced matches for sync', data: {
          'count': queuedCount,
        });
      }
    } catch (e, stackTrace) {
      _logger.e('Error queueing existing unsynced matches', 
        error: e, 
        stackTrace: stackTrace
      );
    }
  }

  /// Dispose sync manager
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySub?.cancel();
    _syncController.close();
    _pendingCountController.close();
    _initialized = false;
  }

  /// Update the pending count stream
  Future<void> _updatePendingCount() async {
    if (_db == null) return;
    final pendingOps = await db.getPendingSyncOperations();
    _pendingCountController.add(pendingOps.length);
  }

  /// Queue a create operation
  Future<void> queueCreate(String eventId, MatchReport match) async {
    if (eventId.isEmpty) {
      throw ValidationError('EventId cannot be empty when queuing match for sync');
    }

    _logger.d('Queueing create operation', data: {
      'eventId': eventId,
      'matchId': match.id,
    });
    
    await db.addToSyncQueue(SyncQueueCompanion.insert(
      entityType: 'match',
      entityId: match.id,
      eventId: Value(eventId),
      operation: 'create',
      dataJson: jsonEncode(match.toJson()),
      priority: const Value(0), // High priority for creates
    ));
    
    await _updatePendingCount();
    
    // Try to sync immediately if online
    await _attemptImmediateSync();
  }

  /// Queue an update operation
  Future<void> queueUpdate(String eventId, MatchReport match) async {
    if (eventId.isEmpty) {
      throw ValidationError('EventId cannot be empty when queuing match for sync');
    }

    _logger.d('Queueing update operation', data: {
      'eventId': eventId,
      'matchId': match.id,
    });
    
    await db.addToSyncQueue(SyncQueueCompanion.insert(
      entityType: 'match',
      entityId: match.id,
      eventId: Value(eventId),
      operation: 'update',
      dataJson: jsonEncode(match.toJson()),
      priority: const Value(1),
    ));
    
    await _updatePendingCount();

    await _attemptImmediateSync();
  }

  /// Queue a soft delete operation (move to trash)
  Future<void> queueDelete(String eventId, String matchId) async {
    _logger.d('Queueing soft delete operation', data: {
      'eventId': eventId,
      'matchId': matchId,
    });

    await db.addToSyncQueue(SyncQueueCompanion.insert(
      entityType: 'match',
      entityId: matchId,
      eventId: Value(eventId),
      operation: 'soft_delete',
      dataJson: jsonEncode({'isDeleted': true}),
      priority: const Value(2),
    ));

    await _updatePendingCount();

    await _attemptImmediateSync();
  }

  /// Queue a hard delete operation (permanent deletion)
  Future<void> queueHardDelete(String eventId, String matchId) async {
    _logger.d('Queueing hard delete operation', data: {
      'eventId': eventId,
      'matchId': matchId,
    });

    await db.addToSyncQueue(SyncQueueCompanion.insert(
      entityType: 'match',
      entityId: matchId,
      eventId: Value(eventId),
      operation: 'delete',
      dataJson: jsonEncode({'permanentlyDeleted': true}),
      priority: const Value(2),
    ));

    await _updatePendingCount();

    await _attemptImmediateSync();
  }

  /// Attempt to sync immediately if online
  Future<void> _attemptImmediateSync() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.first != ConnectivityResult.none && !_isSyncing) {
      syncPendingChanges();
    }
  }

  /// Sync all pending changes
  Future<SyncResult> syncPendingChanges() async {
    if (_isSyncing) {
      _logger.d('Sync already in progress, skipping');
      return const SyncResult.alreadySyncing();
    }

    _isSyncing = true;
    _syncController.add(const SyncStatus.inProgress());

    int successCount = 0;
    int failCount = 0;
    final errors = <AppError>[];

    try {
      final pendingOps = await db.getPendingSyncOperations();

      if (pendingOps.isEmpty) {
        _logger.i('No pending sync operations');
        _syncController.add(const SyncStatus.completed(success: 0, failed: 0));
        return const SyncResult.success(count: 0);
      }

      _logger.i('Starting sync', data: {'pendingCount': pendingOps.length});

      for (final op in pendingOps) {
        debugPrint('Processing sync op: ${op.operation} for ${op.entityId} (Event: ${op.eventId})');
        try {
          await _processSyncOperation(op);
          successCount++;
        } on AppError catch (e) {
          _logger.w('Sync operation failed', error: e, data: {
            'operationId': op.id,
            'entityId': op.entityId,
          });

          failCount++;
          errors.add(e);

          await db.updateSyncOperationRetry(
            op.id,
            retryCount: op.retryCount + 1,
            errorMessage: e.message,
          );

          if (failCount >= _retryConfig.maxAttempts) {
            _logger.w('Too many failures, stopping sync batch');
            break;
          }
        } catch (e, stackTrace) {
          _logger.e('Unexpected sync error', error: e, stackTrace: stackTrace);
          failCount++;

          await db.updateSyncOperationRetry(
            op.id,
            retryCount: op.retryCount + 1,
            errorMessage: e.toString(),
          );
        }
      }

      _syncController.add(SyncStatus.completed(
        success: successCount,
        failed: failCount,
      ));

      await _updatePendingCount();

      if (failCount == 0) {
        _logger.i('Sync completed successfully', data: {'synced': successCount});
        return SyncResult.success(count: successCount);
      } else if (successCount > 0) {
        _logger.w('Sync completed with partial success', data: {
          'success': successCount,
          'failed': failCount,
        });
        return SyncResult.partial(success: successCount, failed: failCount, errors: errors);
      } else {
        _logger.e('Sync failed completely', data: {'failed': failCount});
        return SyncResult.failure(errors: errors);
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Process a single sync operation with retry logic
  Future<void> _processSyncOperation(SyncQueueData op) async {
    _logger.d('Processing sync operation', data: {
      'operation': op.operation,
      'entityType': op.entityType,
      'entityId': op.entityId,
      'eventId': op.eventId,
    });

    try {
      await _retryConfig.execute(() async {
        switch (op.operation) {
          case 'create':
            _logger.d('Creating match in Firestore', data: {
              'eventId': op.eventId,
              'matchId': op.entityId,
            });
            await _firestore.createMatch(
              op.eventId!,
              MatchReport.fromJson(jsonDecode(op.dataJson)),
            );
            _logger.d('Match created successfully in Firestore');
            break;
          case 'update':
            _logger.d('Updating match in Firestore', data: {
              'eventId': op.eventId,
              'matchId': op.entityId,
            });
            await _firestore.updateMatch(
              op.eventId!,
              MatchReport.fromJson(jsonDecode(op.dataJson)),
            );
            _logger.d('Match updated successfully in Firestore');
            break;
          case 'soft_delete':
            _logger.d('Soft deleting match in Firestore', data: {
              'eventId': op.eventId,
              'matchId': op.entityId,
            });
            await _firestore.trashMatch(op.eventId!, op.entityId);
            _logger.d('Match soft deleted in Firestore');
            break;
          case 'delete':
            _logger.d('Permanently deleting match from Firestore', data: {
              'eventId': op.eventId,
              'matchId': op.entityId,
            });
            await _firestore.deleteMatch(op.eventId!, op.entityId);
            _logger.d('Match permanently deleted from Firestore');
            break;
          default:
            throw UnknownError('Unknown operation: ${op.operation}');
        }
      }, onRetry: (attempt, error, stackTrace) {
        _logger.w('Retrying sync operation', data: {
          'attempt': attempt,
          'operation': op.operation,
          'error': error.toString(),
        });
      });

      // Mark operation as complete
      await db.completeSyncOperation(op.id);
      _logger.d('Sync operation marked as complete', data: {
        'operationId': op.id,
      });
      
      // Mark local entity as synced. Skip for hard delete — the local row
      // was already permanently removed by HybridRepository.deleteMatch before
      // queuing this op, so the update is a no-op that just wastes a query.
      if (op.entityType == 'match' && op.operation != 'delete') {
        await db.markMatchSynced(op.entityId);
        _logger.d('Local match marked as synced', data: {
          'matchId': op.entityId,
        });
      }
    } catch (e, stackTrace) {
      _logger.e('Sync operation failed after all retries', 
        error: e, 
        stackTrace: stackTrace,
        data: {
          'operation': op.operation,
          'entityId': op.entityId,
          'eventId': op.eventId,
        }
      );
      rethrow;
    }
  }

  /// Force sync all unsynced items immediately
  Future<SyncResult> forceSync() async {
    _logger.i('Force sync requested');
    return syncPendingChanges();
  }

  /// Get sync statistics
  Future<SyncStats> getSyncStats() async {
    final pendingCount = (await db.getPendingSyncOperations()).length;
    final unsyncedCount = await db.getUnsyncedCount();
    final unresolvedConflicts = (await db.getUnresolvedConflicts()).length;
    
    return SyncStats(
      pendingOperations: pendingCount,
      unsyncedItems: unsyncedCount,
      unresolvedConflicts: unresolvedConflicts,
      lastSyncTime: null, // Could track this if needed
    );
  }
}

/// Status of a sync operation
sealed class SyncStatus {
  const SyncStatus();
  
  const factory SyncStatus.inProgress() = SyncInProgress;
  const factory SyncStatus.completed({required int success, required int failed}) = SyncCompleted;
  const factory SyncStatus.error(AppError error) = SyncErrorStatus;
}

class SyncInProgress extends SyncStatus {
  const SyncInProgress();
}

class SyncCompleted extends SyncStatus {
  final int success;
  final int failed;
  
  const SyncCompleted({required this.success, required this.failed});
}

class SyncErrorStatus extends SyncStatus {
  final AppError error;
  
  const SyncErrorStatus(this.error);
}

/// Result of a sync operation
sealed class SyncResult {
  const SyncResult();
  
  const factory SyncResult.success({required int count}) = SyncSuccess;
  const factory SyncResult.partial({required int success, required int failed, required List<AppError> errors}) = SyncPartial;
  const factory SyncResult.failure({required List<AppError> errors}) = SyncFailure;
  const factory SyncResult.alreadySyncing() = SyncAlreadySyncing;
}

class SyncSuccess extends SyncResult {
  final int count;
  const SyncSuccess({required this.count});
}

class SyncPartial extends SyncResult {
  final int success;
  final int failed;
  final List<AppError> errors;
  const SyncPartial({required this.success, required this.failed, required this.errors});
}

class SyncFailure extends SyncResult {
  final List<AppError> errors;
  const SyncFailure({required this.errors});
}

class SyncAlreadySyncing extends SyncResult {
  const SyncAlreadySyncing();
}

/// Statistics about sync state
class SyncStats {
  final int pendingOperations;
  final int unsyncedItems;
  final int unresolvedConflicts;
  final DateTime? lastSyncTime;
  
  const SyncStats({
    required this.pendingOperations,
    required this.unsyncedItems,
    required this.unresolvedConflicts,
    this.lastSyncTime,
  });
  
  bool get hasPendingWork => pendingOperations > 0 || unsyncedItems > 0;
  bool get hasConflicts => unresolvedConflicts > 0;
}


