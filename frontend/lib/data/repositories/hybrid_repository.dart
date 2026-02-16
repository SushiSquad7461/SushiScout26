import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart'; // Needed for Value
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_error.dart';
import '../../core/logger.dart';
import '../models/event.dart';
import '../models/match_report.dart';
import '../repositories/scouting_repository.dart';
import '../repositories/firestore_repository.dart';
import '../local/database/app_database.dart';
import '../local/sync/sync_manager.dart';

/// Provider for the hybrid repository
final hybridRepositoryProvider = Provider<HybridRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final firestore = ref.watch(firestoreRepositoryProvider);
  final syncManager = ref.watch(syncManagerProvider);
  return HybridRepository(db, firestore, syncManager);
});

/// A hybrid repository that combines local SQLite and Firestore
/// 
/// Implements offline-first architecture:
/// - Reads: Always from local DB (fast), background refresh from Firestore
/// - Writes: To local DB + queue for sync to Firestore
/// - Sync: Automatic when online, queued when offline
/// 
/// This ensures the app works completely offline while maintaining
/// data consistency when connectivity is available.
class HybridRepository implements ScoutingRepository {
  final AppDatabase _db;
  final FirestoreRepository _firestore;
  final SyncManager _syncManager;
  final Logger _logger = const Logger('REPO');
  
  final _matchStreamControllers = <String, StreamController<List<MatchReport>>>{};
  final _trashStreamControllers = <String, StreamController<List<MatchReport>>>{};
  final _firestoreSubscriptions = <String, StreamSubscription<List<MatchReport>>>{};

  HybridRepository(this._db, this._firestore, this._syncManager) {
    _initializeStreams();
  }

  void _initializeStreams() {
    // Listen to sync status changes to refresh streams
    _syncManager.syncStream.listen((status) {
      if (status is SyncCompleted && status.success > 0) {
        _refreshAllStreams();
      }
    });
  }

  void _refreshAllStreams() {
    _matchStreamControllers.forEach((eventId, controller) {
      _refreshMatchStream(eventId);
    });
    _trashStreamControllers.forEach((eventId, controller) {
      _refreshTrashStream(eventId);
    });
  }

  @override
  Stream<List<MatchReport>> watchMatches(String eventId) {
    _logger.d('Watching matches for event: $eventId');
    
    // Create or get existing stream controller
    var controller = _matchStreamControllers[eventId];
    if (controller == null || controller.isClosed) {
      controller = StreamController<List<MatchReport>>.broadcast(
        onCancel: () {
          // Optional: Cancel firestore subscription when no listeners?
          // For now, we keep it alive to ensure background updates continue
        },
      );
      _matchStreamControllers[eventId] = controller;
      
      // Initial load from local DB
      _refreshMatchStream(eventId);
      
      // Listen to local DB changes
      _db.getMatchesForEvent(eventId).then((localMatches) {
        if (!controller!.isClosed) {
          controller.add(localMatches.map(_toMatchReport).toList());
        }
      });

      // Setup real-time Firestore listener for this event
      _setupFirestoreSubscription(eventId);
    }
    
    return controller.stream;
  }

  void _setupFirestoreSubscription(String eventId) {
    if (_firestoreSubscriptions.containsKey(eventId)) return;

    _logger.d('Setting up Firestore subscription for event: $eventId');
    final subscription = _firestore.watchMatches(eventId).listen(
      (remoteMatches) async {
        // Workaround for Windows: Ensure Firestore callbacks run on main thread
        await Future.microtask(() async {
          _logger.d('Received ${remoteMatches.length} matches from Firestore stream');
          try {
            // Use batch transaction for better performance and to reduce UI jitter
            await _db.batch((batch) {
              for (final match in remoteMatches) {
                batch.insert(
                  _db.localMatchReports,
                  _toLocalMatchReport(match, eventId),
                  mode: InsertMode.insertOrReplace,
                );
              }
            });
            
            // Refresh the stream to show new data
            _refreshMatchStream(eventId);
          } catch (e) {
            _logger.e('Error syncing remote matches to local DB', error: e);
          }
        });
      },
      onError: (e) {
        _logger.w('Firestore stream error', error: e);
      },
    );

    _firestoreSubscriptions[eventId] = subscription;
  }

  Future<void> _refreshMatchStream(String eventId) async {
    final controller = _matchStreamControllers[eventId];
    if (controller == null || controller.isClosed) return;
    
    try {
      final matches = await getMatches(eventId);
      if (!controller.isClosed) {
        controller.add(matches);
      }
    } catch (e) {
      _logger.e('Error refreshing match stream', error: e);
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  @override
  Stream<List<MatchReport>> watchTrash(String eventId) {
    _logger.d('Watching trash for event: $eventId');

    var controller = _trashStreamControllers[eventId];
    if (controller == null || controller.isClosed) {
      controller = StreamController<List<MatchReport>>.broadcast();
      _trashStreamControllers[eventId] = controller;

      // Initial load from local DB
      _refreshTrashStream(eventId);

      // Listen to local DB changes for immediate emission
      _db.getDeletedMatchesForEvent(eventId).then((deletedMatches) {
        if (!controller!.isClosed) {
          controller.add(deletedMatches.map(_toMatchReport).toList());
        }
      });
    }

    return controller.stream;
  }

  Future<void> _refreshTrashStream(String eventId) async {
    final controller = _trashStreamControllers[eventId];
    if (controller == null || controller.isClosed) return;
    
    try {
      final deleted = await _db.getDeletedMatchesForEvent(eventId);
      if (!controller.isClosed) {
        controller.add(deleted.map(_toMatchReport).toList());
      }
    } catch (e) {
      _logger.e('Error refreshing trash stream', error: e);
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  @override
  Future<List<MatchReport>> getMatches(String eventId) async {
    _logger.d('Getting matches for event: $eventId');
    
    // Always read from local DB first (fast, works offline)
    final localMatches = await _db.getMatchesForEvent(eventId);
    
    // Background refresh from Firestore (if online)
    _refreshFromFirestore(eventId).catchError((e) {
      _logger.w('Background refresh failed', error: e);
    });
    
    return localMatches.map(_toMatchReport).toList();
  }

  /// Background refresh from Firestore
  Future<void> _refreshFromFirestore(String eventId) async {
    try {
      final firestoreMatches = await _firestore.getMatches(eventId);

      if (firestoreMatches.isEmpty) {
        _logger.d('No matches found in Firestore for event: $eventId');
        return;
      }

      _logger.d('Found ${firestoreMatches.length} matches in Firestore, updating local DB');

      // Update local DB with firestore data
      // Note: We don't call _refreshMatchStream here to avoid infinite loops.
      // The stream will be updated through the Firestore subscription or next getMatches call.
      for (final match in firestoreMatches) {
        await _db.upsertMatch(_toLocalMatchReport(match, eventId));
      }

      _logger.d('Refreshed ${firestoreMatches.length} matches from Firestore');
    } catch (e) {
      // Firestore failures shouldn't block local reads
      _logger.w('Firestore refresh failed', error: e);
    }
  }

  @override
  Future<void> createMatch(String eventId, MatchReport match) async {
    _logger.i('Creating match', data: {
      'eventId': eventId,
      'matchId': match.id,
    });
    
    try {
      // 1. Save to local DB immediately
      await _db.upsertMatch(_toLocalMatchReport(match, eventId));
      
      // 2. Queue for sync to Firestore
      await _syncManager.queueCreate(eventId, match);
      
      // 3. Refresh stream
      await _refreshMatchStream(eventId);
      
      _logger.i('Match created locally and queued for sync');
    } catch (e, stackTrace) {
      _logger.e('Failed to create match', error: e, stackTrace: stackTrace);
      final errorMsg = e.toString();
      if (errorMsg.contains('UNIQUE constraint failed')) {
        throw StorageError('A match for this team and match number already exists. Please update the existing match instead.');
      }
      throw StorageError('Failed to save match locally: $errorMsg');
    }
  }

  @override
  Future<void> updateMatch(String eventId, MatchReport match) async {
    _logger.i('Updating match', data: {
      'eventId': eventId,
      'matchId': match.id,
    });
    
    try {
      // 1. Save to local DB immediately
      await _db.upsertMatch(_toLocalMatchReport(match, eventId));
      
      // 2. Queue for sync to Firestore
      await _syncManager.queueUpdate(eventId, match);
      
      // 3. Refresh stream
      await _refreshMatchStream(eventId);
      
      _logger.i('Match updated locally and queued for sync');
    } catch (e, stackTrace) {
      _logger.e('Failed to update match', error: e, stackTrace: stackTrace);
      final errorMsg = e.toString();
      if (errorMsg.contains('UNIQUE constraint failed')) {
        throw StorageError('A match for this team and match number already exists.');
      }
      throw StorageError('Failed to update match locally: $errorMsg');
    }
  }

  @override
  Future<void> trashMatch(String eventId, String matchId) async {
    _logger.i('Trashing match', data: {
      'eventId': eventId,
      'matchId': matchId,
    });
    
    try {
      // 1. Soft delete in local DB
      await _db.softDeleteMatch(matchId);
      
      // 2. Queue delete for sync
      await _syncManager.queueDelete(eventId, matchId);
      
      // 3. Refresh streams
      await _refreshMatchStream(eventId);
      await _refreshTrashStream(eventId);
      
      _logger.i('Match trashed locally and queued for sync');
    } catch (e, stackTrace) {
      _logger.e('Failed to trash match', error: e, stackTrace: stackTrace);
      throw StorageError('Failed to trash match: $e');
    }
  }

  @override
  Future<void> restoreMatch(String eventId, String matchId) async {
    _logger.i('Restoring match', data: {
      'eventId': eventId,
      'matchId': matchId,
    });
    
    try {
      // 1. Restore in local DB
      await _db.restoreMatch(matchId);
      
      // 2. Get the restored match
      final localMatch = await _db.getMatch(matchId);
      if (localMatch != null) {
        // 3. Queue update to restore in Firestore too
        final match = _toMatchReport(localMatch);
        await _syncManager.queueUpdate(eventId, match);
      }
      
      // 4. Refresh streams
      await _refreshMatchStream(eventId);
      await _refreshTrashStream(eventId);
      
      _logger.i('Match restored locally and queued for sync');
    } catch (e, stackTrace) {
      _logger.e('Failed to restore match', error: e, stackTrace: stackTrace);
      throw StorageError('Failed to restore match: $e');
    }
  }

  @override
  Future<void> deleteMatch(String eventId, String matchId) async {
    _logger.i('Permanently deleting match', data: {
      'eventId': eventId,
      'matchId': matchId,
    });
    
    try {
      // 1. Permanently delete from local DB
      await _db.permanentlyDeleteMatch(matchId);
      
      // 2. Queue hard delete for Firestore
      await _syncManager.queueHardDelete(eventId, matchId);
      
      // 3. Refresh trash stream
      await _refreshTrashStream(eventId);
      
      _logger.i('Match permanently deleted');
    } catch (e, stackTrace) {
      _logger.e('Failed to delete match', error: e, stackTrace: stackTrace);
      throw StorageError('Failed to delete match: $e');
    }
  }

  @override
  Future<Event?> getEvent(String eventId) async {
    _logger.d('Getting event: $eventId');
    
    // Try local first
    final localEvent = await _db.getEvent(eventId);
    if (localEvent != null) {
      return _toEvent(localEvent);
    }
    
    // Fallback to Firestore
    try {
      final firestoreEvent = await _firestore.getEvent(eventId);
      if (firestoreEvent != null) {
        // Cache locally
        await _db.upsertEvent(_toLocalEvent(firestoreEvent));
        return firestoreEvent;
      }
    } catch (e) {
      _logger.w('Failed to get event from Firestore', error: e);
    }
    
    return null;
  }

  @override
  Future<List<Event>> getEvents() async {
    _logger.d('Getting all events');
    
    // Get from local DB
    final localEvents = await _db.getAllEvents();
    
    // Background refresh from Firestore
    _firestore.getEvents().then((firestoreEvents) async {
      for (final event in firestoreEvents) {
        await _db.upsertEvent(_toLocalEvent(event));
      }
    }).catchError((e) {
      _logger.w('Failed to refresh events from Firestore', error: e);
    });
    
    return localEvents.map(_toEvent).toList();
  }

  /// Force sync all pending changes
  Future<void> forceSync() async {
    _logger.i('Force sync requested');
    await _syncManager.forceSync();
  }

  /// Get sync statistics
  Future<SyncStats> getSyncStats() {
    return _syncManager.getSyncStats();
  }

  /// Clear all local data including matches, events, and sync queue
  Future<void> clearAllLocalData() async {
    _logger.i('Clearing all local data');
    await _db.clearAllData();
    _logger.i('All local data cleared');
  }

  /// Dispose repository resources
  void dispose() {
    _matchStreamControllers.forEach((_, controller) => controller.close());
    _trashStreamControllers.forEach((_, controller) => controller.close());
    _firestoreSubscriptions.forEach((_, subscription) => subscription.cancel());
    _matchStreamControllers.clear();
    _trashStreamControllers.clear();
    _firestoreSubscriptions.clear();
  }

  // Conversion helpers
  
  MatchReport _toMatchReport(LocalMatchReport local) {
    return MatchReport(
      id: local.id,
      matchId: local.matchId,
      matchNumber: local.matchNumber,
      teamNumber: local.teamNumber,
      alliance: local.alliance,
      scouterName: local.scouterName,
      gameData: jsonDecode(local.gameDataJson),
      robotDied: local.robotDied,
      comments: local.comments,
      images: [], // Local table might not have images column yet?
      createdAt: local.createdAt,
      isSynced: local.isSynced,
      isDeleted: local.isDeleted,
    );
  }

  LocalMatchReportsCompanion _toLocalMatchReport(MatchReport match, String eventId) {
    return LocalMatchReportsCompanion(
      id: Value(match.id),
      eventId: Value(eventId),
      matchId: Value(match.matchId),
      matchNumber: Value(match.matchNumber),
      teamNumber: Value(match.teamNumber),
      alliance: Value(match.alliance),
      scouterName: Value(match.scouterName),
      gameDataJson: Value(jsonEncode(match.gameData)),
      robotDied: Value(match.robotDied),
      comments: Value(match.comments),
      isSynced: Value(match.isSynced),
      isDeleted: Value(match.isDeleted),
      createdAt: Value(match.createdAt),
      updatedAt: Value(DateTime.now()),
    );
  }

  Event _toEvent(LocalEvent local) {
    return Event(
      id: local.id,
      name: local.name,
      programType: local.programType,
      tbaKey: local.tbaKey,
      startDate: local.startDate,
    );
  }

  LocalEventsCompanion _toLocalEvent(Event event) {
    return LocalEventsCompanion(
      id: Value(event.id),
      name: Value(event.name),
      programType: Value(event.programType),
      tbaKey: Value(event.tbaKey),
      startDate: Value(event.startDate),
    );
  }
}
