import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart'; // Needed for Value
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_error.dart';
import '../../core/logger.dart';
import '../models/event.dart';
import '../models/match_report.dart';
import '../repositories/scouting_repository.dart';
import '../repositories/firestore_repository.dart';
import '../local/database/app_database.dart';
import '../local/sync/sync_manager.dart';

/// Provider for the hybrid repository. When a dependency rebuilds (e.g.,
/// team switch), Riverpod tears down the old instance — register dispose()
/// so its stream controllers and Firestore subscriptions are cleaned up.
final hybridRepositoryProvider = Provider<HybridRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final firestore = ref.watch(firestoreRepositoryProvider);
  final syncManager = ref.watch(syncManagerProvider);
  final repo = HybridRepository(db, firestore, syncManager);
  ref.onDispose(repo.dispose);
  return repo;
});

/// A hybrid repository that combines local SQLite and Firestore
/// 
/// Implements offline-first architecture:
/// - Reads: Always from local DB (fast), background refresh from Firestore
/// - Writes: To local DB + queue for sync to Firestore
/// - Sync: Automatic when online, queued when offline
/// 
/// On web, uses Firebase directly (with its built-in offline persistence)
/// since SQLite/Drift is not available.

class HybridRepository implements ScoutingRepository {
  final AppDatabase? _db;
  final FirestoreRepository _firestore;
  final SyncManager _syncManager;
  final Logger _logger = const Logger('REPO');
  
  final _matchStreamControllers = <String, StreamController<List<MatchReport>>>{};
  final _trashStreamControllers = <String, StreamController<List<MatchReport>>>{};
  final _firestoreSubscriptions = <String, StreamSubscription<List<MatchReport>>>{};
  StreamSubscription<SyncStatus>? _syncStatusSub;

  bool get isLocalDbAvailable => _db != null;
  
  AppDatabase get db {
    if (_db == null) {
      throw StateError('Local database not available on this platform');
    }
    return _db;
  }
  
  HybridRepository(this._db, this._firestore, this._syncManager);

  bool get _isWeb => kIsWeb;

  void _initializeStreams() {
    // On web, we don't have a sync manager with streams, so skip
    if (_isWeb) return;

    // Only subscribe once. _watchMatchesNative calls this each time, so without
    // the guard each watched event piled up another syncStream listener and
    // every sync triggered N parallel refreshes.
    if (_syncStatusSub != null) return;

    _syncStatusSub = _syncManager.syncStream.listen((status) {
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
    
    // On web, use Firestore directly (has built-in offline persistence)
    if (_isWeb) {
      return _watchMatchesWeb(eventId);
    }
    
    // Native: use local DB + Firestore sync
    return _watchMatchesNative(eventId);
  }

  Stream<List<MatchReport>> _watchMatchesWeb(String eventId) {
    var controller = _matchStreamControllers[eventId];
    if (controller == null || controller.isClosed) {
      controller = StreamController<List<MatchReport>>.broadcast();
      _matchStreamControllers[eventId] = controller;
      
      // Load from Firestore directly
      _refreshMatchStreamWeb(eventId);
      
      // Setup real-time Firestore listener
      final subscription = _firestore.watchMatches(eventId).listen(
        (matches) async {
          await Future.microtask(() async {
            if (!controller!.isClosed) {
              controller.add(matches);
            }
          });
        },
        onError: (e) {
          _logger.w('Firestore stream error', error: e);
        },
      );
      _firestoreSubscriptions[eventId] = subscription;
    }
    
    return controller.stream;
  }

  Stream<List<MatchReport>> _watchMatchesNative(String eventId) {
    _initializeStreams();
    
    var controller = _matchStreamControllers[eventId];
    if (controller == null || controller.isClosed) {
      controller = StreamController<List<MatchReport>>.broadcast(
        onCancel: () {},
      );
      _matchStreamControllers[eventId] = controller;
      
      // Initial load from local DB
      _refreshMatchStream(eventId);

      // Setup real-time Firestore listener for this event. We also wire up
      // the trash subscription so that a remote trash (the match disappears
      // from watchMatches snapshots) actually propagates to the local row's
      // isDeleted flag — otherwise the trashed match would stay visible
      // until app restart on devices that never open the trash screen.
      _setupFirestoreSubscription(eventId);
      _setupFirestoreTrashSubscription(eventId);
    }

    return controller.stream;
  }

  void _setupFirestoreSubscription(String eventId) {
    if (_firestoreSubscriptions.containsKey(eventId)) return;

    _logger.d('Setting up Firestore subscription for event: $eventId');
    final subscription = _firestore.watchMatches(eventId).listen(
      (remoteMatches) async {
        await Future.microtask(() async {
          _logger.d('Received ${remoteMatches.length} matches from Firestore stream');
          try {
            final pendingIds = await _pendingMatchIdsForEvent(eventId);
            var skipped = 0;
            await db.batch((batch) {
              for (final match in remoteMatches) {
                // Skip matches with pending local sync ops — Firestore's
                // snapshot is stale until the queued write reaches it, and
                // insertOrReplace would otherwise clobber the user's edit
                // (e.g. visually un-trash a just-trashed match).
                if (pendingIds.contains(match.id)) {
                  skipped++;
                  continue;
                }
                batch.insert(
                  db.localMatchReports,
                  _toLocalMatchReport(match, eventId),
                  mode: InsertMode.insertOrReplace,
                );
              }
            });
            if (skipped > 0) {
              _logger.d('Skipped $skipped remote matches with pending local sync ops');
            }

            _refreshMatchStream(eventId);
            // Another device may have restored a match — refresh trash too.
            if (_trashStreamControllers.containsKey(eventId)) {
              _refreshTrashStream(eventId);
            }
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

  /// Returns the set of match IDs that have queued sync operations for this
  /// event. We filter incoming Firestore snapshots against this set so a
  /// stale remote read can't overwrite an unsynced local edit.
  Future<Set<String>> _pendingMatchIdsForEvent(String eventId) async {
    final pendingOps = await db.getPendingSyncOperations();
    return pendingOps
        .where((op) => op.entityType == 'match' && op.eventId == eventId)
        .map((op) => op.entityId)
        .toSet();
  }

  /// Set up a Firestore subscription for the trash view. Without this,
  /// native clients only see trash entries that exist on this device — a
  /// trash/restore from another device never propagates until app restart.
  void _setupFirestoreTrashSubscription(String eventId) {
    final key = 'trash_$eventId';
    if (_firestoreSubscriptions.containsKey(key)) return;

    final subscription = _firestore.watchTrash(eventId).listen(
      (remoteDeleted) async {
        await Future.microtask(() async {
          try {
            final pendingIds = await _pendingMatchIdsForEvent(eventId);
            await db.batch((batch) {
              for (final match in remoteDeleted) {
                if (pendingIds.contains(match.id)) continue;
                batch.insert(
                  db.localMatchReports,
                  _toLocalMatchReport(match, eventId),
                  mode: InsertMode.insertOrReplace,
                );
              }
            });
            _refreshTrashStream(eventId);
            if (_matchStreamControllers.containsKey(eventId)) {
              _refreshMatchStream(eventId);
            }
          } catch (e) {
            _logger.e('Error syncing remote trash to local DB', error: e);
          }
        });
      },
      onError: (e) {
        _logger.w('Firestore trash stream error', error: e);
      },
    );

    _firestoreSubscriptions[key] = subscription;
  }

  Future<void> _refreshMatchStreamWeb(String eventId) async {
    final controller = _matchStreamControllers[eventId];
    if (controller == null || controller.isClosed) return;
    
    try {
      final matches = await _firestore.getMatches(eventId);
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

  Future<void> _refreshMatchStream(String eventId) async {
    // On web, use different logic
    if (_isWeb) {
      await _refreshMatchStreamWeb(eventId);
      return;
    }
    
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

    // On web, use Firestore directly
    if (_isWeb) {
      return _watchTrashWeb(eventId);
    }
    
    return _watchTrashNative(eventId);
  }

  Stream<List<MatchReport>> _watchTrashWeb(String eventId) {
    var controller = _trashStreamControllers[eventId];
    if (controller == null || controller.isClosed) {
      controller = StreamController<List<MatchReport>>.broadcast();
      _trashStreamControllers[eventId] = controller;

      // Load from Firestore directly
      _refreshTrashStreamWeb(eventId);

      // Listen to Firestore for trash changes
      final subscription = _firestore.watchTrash(eventId).listen(
        (matches) async {
          await Future.microtask(() async {
            if (!controller!.isClosed) {
              controller.add(matches.where((m) => m.isDeleted).toList());
            }
          });
        },
        onError: (e) {
          _logger.w('Firestore trash stream error', error: e);
        },
      );
      _firestoreSubscriptions['trash_$eventId'] = subscription;
    }

    return controller.stream;
  }

  Stream<List<MatchReport>> _watchTrashNative(String eventId) {
    _initializeStreams();

    var controller = _trashStreamControllers[eventId];
    if (controller == null || controller.isClosed) {
      controller = StreamController<List<MatchReport>>.broadcast();
      _trashStreamControllers[eventId] = controller;

      // Initial load from local DB
      _refreshTrashStream(eventId);

      // Listen for remote trash changes so trashes/restores from other
      // devices show up without an app restart. Also keep the matches
      // subscription running so a remote restore (match leaves trash) gets
      // reflected in this device's local row.
      _setupFirestoreTrashSubscription(eventId);
      _setupFirestoreSubscription(eventId);
    }

    return controller.stream;
  }

  Future<void> _refreshTrashStreamWeb(String eventId) async {
    final controller = _trashStreamControllers[eventId];
    if (controller == null || controller.isClosed) return;

    try {
      final deleted = await _firestore.getDeletedMatches(eventId);
      if (!controller.isClosed) {
        controller.add(deleted);
      }
    } catch (e) {
      _logger.e('Error refreshing trash stream', error: e);
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  Future<void> _refreshTrashStream(String eventId) async {
    // On web, use different logic
    if (_isWeb) {
      await _refreshTrashStreamWeb(eventId);
      return;
    }
    
    final controller = _trashStreamControllers[eventId];
    if (controller == null || controller.isClosed) return;
    
    try {
      final deleted = await db.getDeletedMatchesForEvent(eventId);
      if (!controller.isClosed) {
        controller.add(_filterToActiveTeam(deleted).map(_toMatchReport).toList());
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

    // On web, use Firestore directly
    if (_isWeb) {
      return _firestore.getMatches(eventId);
    }

    // Native: read from local DB first
    final localMatches = await db.getMatchesForEvent(eventId);

    // Background refresh from Firestore (if online)
    _refreshFromFirestore(eventId).catchError((e) {
      _logger.w('Background refresh failed', error: e);
    });

    return _filterToActiveTeam(localMatches).map(_toMatchReport).toList();
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

      // Don't overwrite local rows that have pending sync ops — see
      // _setupFirestoreSubscription for why.
      final pendingIds = await _pendingMatchIdsForEvent(eventId);
      var skipped = 0;
      for (final match in firestoreMatches) {
        if (pendingIds.contains(match.id)) {
          skipped++;
          continue;
        }
        await db.upsertMatch(_toLocalMatchReport(match, eventId));
      }

      _logger.d('Refreshed ${firestoreMatches.length - skipped} matches from Firestore'
          '${skipped > 0 ? ' (skipped $skipped pending)' : ''}');
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
    
    // On web, write directly to Firestore (handles offline automatically)
    if (_isWeb) {
      try {
        await _firestore.createMatch(eventId, match);
        await _refreshMatchStreamWeb(eventId);
        _logger.i('Match created in Firestore');
      } catch (e, stackTrace) {
        _logger.e('Failed to create match', error: e, stackTrace: stackTrace);
        throw StorageError('Failed to create match: $e');
      }
      return;
    }
    
    try {
      // 1. Save to local DB immediately
      await db.upsertMatch(_toLocalMatchReport(match, eventId));
      
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
    
    // On web, write directly to Firestore
    if (_isWeb) {
      try {
        await _firestore.updateMatch(eventId, match);
        await _refreshMatchStreamWeb(eventId);
        _logger.i('Match updated in Firestore');
      } catch (e, stackTrace) {
        _logger.e('Failed to update match', error: e, stackTrace: stackTrace);
        throw StorageError('Failed to update match: $e');
      }
      return;
    }
    
    try {
      // 1. Save to local DB immediately
      await db.upsertMatch(_toLocalMatchReport(match, eventId));
      
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
    
    // On web, write directly to Firestore
    if (_isWeb) {
      try {
        await _firestore.trashMatch(eventId, matchId);
        await _refreshMatchStreamWeb(eventId);
        await _refreshTrashStreamWeb(eventId);
        _logger.i('Match trashed in Firestore');
      } catch (e, stackTrace) {
        _logger.e('Failed to trash match', error: e, stackTrace: stackTrace);
        throw StorageError('Failed to trash match: $e');
      }
      return;
    }
    
    try {
      // 1. Soft delete in local DB
      await db.softDeleteMatch(matchId);
      
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
    
  // On web, write directly to Firestore
  if (_isWeb) {
    try {
      await _firestore.restoreMatch(eventId, matchId);
      await _refreshMatchStreamWeb(eventId);
      await _refreshTrashStreamWeb(eventId);
      _logger.i('Match restored in Firestore');
    } catch (e, stackTrace) {
      _logger.e('Failed to restore match', error: e, stackTrace: stackTrace);
      throw StorageError('Failed to restore match: $e');
    }
    return;
  }
    
    try {
      // 1. Restore in local DB
      await db.restoreMatch(matchId);
      
      // 2. Get the restored match
      final localMatch = await db.getMatch(matchId);
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
    
    // On web, delete directly from Firestore
    if (_isWeb) {
      try {
        await _firestore.deleteMatch(eventId, matchId);
        await _refreshTrashStreamWeb(eventId);
        _logger.i('Match permanently deleted from Firestore');
      } catch (e, stackTrace) {
        _logger.e('Failed to delete match', error: e, stackTrace: stackTrace);
        throw StorageError('Failed to delete match: $e');
      }
      return;
    }
    
    try {
      // 1. Permanently delete from local DB
      await db.permanentlyDeleteMatch(matchId);
      
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
    
    // On web, use Firestore directly
    if (_isWeb) {
      try {
        return await _firestore.getEvent(eventId);
      } catch (e) {
        _logger.w('Failed to get event from Firestore', error: e);
        return null;
      }
    }
    
    // Try local first
    final localEvent = await db.getEvent(eventId);
    if (localEvent != null) {
      return _toEvent(localEvent);
    }
    
    // Fallback to Firestore
    try {
      final firestoreEvent = await _firestore.getEvent(eventId);
      if (firestoreEvent != null) {
        // Cache locally
        await db.upsertEvent(_toLocalEvent(firestoreEvent));
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
    
    // On web, use Firestore directly
    if (_isWeb) {
      try {
        return await _firestore.getEvents();
      } catch (e) {
        _logger.w('Failed to get events from Firestore', error: e);
        return [];
      }
    }
    
    // Get from local DB
    final localEvents = await db.getAllEvents();
    
    // Background refresh from Firestore
    _firestore.getEvents().then((firestoreEvents) async {
      for (final event in firestoreEvents) {
        await db.upsertEvent(_toLocalEvent(event));
      }
    }).catchError((e) {
      _logger.w('Failed to refresh events from Firestore', error: e);
    });
    
    return localEvents.map(_toEvent).toList();
  }

  /// Force sync all pending changes
  Future<void> forceSync() async {
    _logger.i('Force sync requested');
    
    // On web, Firebase handles offline automatically
    if (_isWeb) {
      _logger.i('Web platform - Firestore handles offline persistence automatically');
      return;
    }
    
    await _syncManager.forceSync();
  }

  /// Get sync statistics
  Future<SyncStats> getSyncStats() {
    // On web, no sync queue needed
    if (_isWeb) {
      return Future.value(const SyncStats(
        pendingOperations: 0,
        unsyncedItems: 0,
        unresolvedConflicts: 0,
        lastSyncTime: null,
      ));
    }
    
    return _syncManager.getSyncStats();
  }

  /// Clear all local data including matches, events, and sync queue
  Future<void> clearAllLocalData() async {
    _logger.i('Clearing all local data');
    
    // On web, nothing to clear
    if (_isWeb) {
      _logger.i('Web platform - no local data to clear');
      return;
    }
    
    await db.clearAllData();
    _logger.i('All local data cleared');
  }

  /// Dispose repository resources
  void dispose() {
    _syncStatusSub?.cancel();
    _syncStatusSub = null;
    _matchStreamControllers.forEach((_, controller) => controller.close());
    _trashStreamControllers.forEach((_, controller) => controller.close());
    _firestoreSubscriptions.forEach((_, subscription) => subscription.cancel());
    _matchStreamControllers.clear();
    _trashStreamControllers.clear();
    _firestoreSubscriptions.clear();
  }

  // Conversion helpers
  
  MatchReport _toMatchReport(LocalMatchReport local) {
    final gameData = (jsonDecode(local.gameDataJson) as Map<String, dynamic>)
      ..['robot_died'] = local.robotDied;
    // Detect program type from gameData keys if not stored
    final programType = gameData.containsKey('artifacts_auto') ? 'FTC' : 'FRC';
    return MatchReport(
      id: local.id,
      matchId: local.matchId,
      matchNumber: local.matchNumber,
      teamNumber: local.teamNumber,
      alliance: local.alliance,
      scouterName: local.scouterName,
      gameData: gameData,
      comments: local.comments,
      createdAt: local.createdAt,
      isSynced: local.isSynced,
      isDeleted: local.isDeleted,
      eventId: local.eventId,
      teamId: local.teamId,
      programType: programType,
    );
  }

  LocalMatchReportsCompanion _toLocalMatchReport(MatchReport match, String eventId) {
    // Stamp the active team's ID on local rows even if the caller (e.g. the
    // scouting form) didn't set one. Otherwise local-only writes land with
    // teamId='' and leak across team switches; see _filterToActiveTeam.
    final stamped = match.teamId.isNotEmpty
        ? match.teamId
        : (_firestore.teamId ?? '');
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
      teamId: Value(stamped),
      createdAt: Value(match.createdAt),
      updatedAt: Value(DateTime.now()),
    );
  }

  /// Drop matches that belong to other teams. The local SQLite cache is
  /// shared across team switches, so a stale row for Team A can otherwise
  /// surface while the user is signed in to Team B. We accept rows with an
  /// empty teamId for backwards compatibility with pre-team-stamping data.
  List<LocalMatchReport> _filterToActiveTeam(List<LocalMatchReport> rows) {
    final activeTeamId = _firestore.teamId;
    if (activeTeamId == null || activeTeamId.isEmpty) return rows;
    return rows
        .where((r) => r.teamId.isEmpty || r.teamId == activeTeamId)
        .toList();
  }

  Event _toEvent(LocalEvent local) {
    return Event(
      id: local.id,
      name: local.name,
      programType: local.programType,
      tbaKey: local.tbaKey,
      startDate: local.startDate,
      teamId: local.teamId,
    );
  }

  LocalEventsCompanion _toLocalEvent(Event event) {
    return LocalEventsCompanion(
      id: Value(event.id),
      name: Value(event.name),
      programType: Value(event.programType),
      tbaKey: Value(event.tbaKey),
      startDate: Value(event.startDate),
      teamId: Value(event.teamId),
    );
  }
}
