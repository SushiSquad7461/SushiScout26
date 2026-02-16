import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart'; // Needed for Value
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/logger.dart';
import '../../../core/network/retry.dart';
import '../../../core/result/result.dart';
import '../../models/match_report.dart';
import '../database/app_database.dart';
import '../../repositories/firestore_repository.dart';

/// Provider for sync manager
final syncManagerProvider = Provider<SyncManager>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final firestore = ref.watch(firestoreRepositoryProvider);
  return SyncManager(db, firestore);
});

/// Provider for app database
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

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
    error: (_, __) => false,
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
  final AppDatabase _db;
  final FirestoreRepository _firestore;
  final Logger _logger = const Logger('SYNC');
  
  final _retryConfig = const RetryConfig(
    maxAttempts: 5,
    baseDelay: Duration(seconds: 2),
    maxDelay: Duration(minutes: 5),
  );
  
  Timer? _syncTimer;
  bool _isSyncing = false;
  final _syncController = StreamController<SyncStatus>.broadcast();
  final _pendingCountController = StreamController<int>.broadcast();
  
  Stream<SyncStatus> get syncStream => _syncController.stream;
  Stream<int> get pendingCountStream => _pendingCountController.stream;
  
  SyncManager(this._db, this._firestore);

  /// Initialize sync manager
  void initialize() {
    _logger.i('Initializing sync manager');
    
    // Reset retry counts for stuck operations on startup
    _db.getPendingSyncOperations().then((ops) {
      for (final op in ops) {
        if (op.retryCount >= 5) {
          _db.updateSyncOperationRetry(op.id, retryCount: 0, errorMessage: 'Resetting stuck operation');
        }
      }
    });
    
    // Initial pending count update
    _updatePendingCount();

    // Start periodic sync
    _syncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncPendingChanges(),
    );
    
    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((results) {
      final result = results.first;
      if (result != ConnectivityResult.none) {
        _logger.i('Connectivity restored, triggering sync');
        syncPendingChanges();
      }
    });
  }

  /// Dispose sync manager
  void dispose() {
    _syncTimer?.cancel();
    _syncController.close();
    _pendingCountController.close();
  }

  /// Update the pending count stream
  Future<void> _updatePendingCount() async {
    final pendingOps = await _db.getPendingSyncOperations();
    _pendingCountController.add(pendingOps.length);
  }

  /// Queue a create operation
  Future<void> queueCreate(String eventId, MatchReport match) async {
    _logger.d('Queueing create operation', data: {
      'eventId': eventId,
      'matchId': match.id,
    });
    
    await _db.addToSyncQueue(SyncQueueCompanion.insert(
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
    _logger.d('Queueing update operation', data: {
      'eventId': eventId,
      'matchId': match.id,
    });
    
    await _db.addToSyncQueue(SyncQueueCompanion.insert(
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

  /// Queue a delete operation
  Future<void> queueDelete(String eventId, String matchId) async {
    _logger.d('Queueing delete operation', data: {
      'eventId': eventId,
      'matchId': matchId,
    });
    
    await _db.addToSyncQueue(SyncQueueCompanion.insert(
      entityType: 'match',
      entityId: matchId,
      eventId: Value(eventId),
      operation: 'delete',
      dataJson: jsonEncode({'isDeleted': true}),
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
    
    final pendingOps = await _db.getPendingSyncOperations();
    
    if (pendingOps.isEmpty) {
      _logger.i('No pending sync operations');
      _isSyncing = false;
      _syncController.add(const SyncStatus.completed(success: 0, failed: 0));
      return const SyncResult.success(count: 0);
    }

    _logger.i('Starting sync', data: {'pendingCount': pendingOps.length});
    
    int successCount = 0;
    int failCount = 0;
    final errors = <AppError>[];

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
        
        // Update retry count
        await _db.updateSyncOperationRetry(
          op.id,
          retryCount: op.retryCount + 1,
          errorMessage: e.message,
        );
        
        // Check if we should stop syncing
        if (failCount >= 5) {
          _logger.w('Too many failures, stopping sync batch');
          break;
        }
      } catch (e, stackTrace) {
        _logger.e('Unexpected sync error', error: e, stackTrace: stackTrace);
        failCount++;
        
        await _db.updateSyncOperationRetry(
          op.id,
          retryCount: op.retryCount + 1,
          errorMessage: e.toString(),
        );
      }
    }

    _isSyncing = false;
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
          case 'delete':
            _logger.d('Deleting match from Firestore', data: {
              'eventId': op.eventId,
              'matchId': op.entityId,
            });
            await _firestore.trashMatch(op.eventId!, op.entityId);
            _logger.d('Match deleted successfully from Firestore');
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
      await _db.completeSyncOperation(op.id);
      _logger.d('Sync operation marked as complete', data: {
        'operationId': op.id,
      });
      
      // Mark local entity as synced
      if (op.entityType == 'match') {
        await _db.markMatchSynced(op.entityId);
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
    final pendingCount = (await _db.getPendingSyncOperations()).length;
    final unsyncedCount = await _db.getUnsyncedCount();
    final unresolvedConflicts = (await _db.getUnresolvedConflicts()).length;
    
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


