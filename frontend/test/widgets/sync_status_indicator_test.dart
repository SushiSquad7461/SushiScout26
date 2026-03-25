import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/presentation/widgets/sync_status_indicator.dart';
import 'package:frontend/data/local/sync/sync_manager.dart' as manager;

// Mock SyncManager is hard because it's a concrete class with private members.
// But we can override the provider to return a FakeSyncManager.

class FakeSyncManager implements manager.SyncManager {
  final StreamController<int> _pendingCountController = StreamController<int>();
  final StreamController<manager.SyncStatus> _syncController = StreamController<manager.SyncStatus>();

  @override
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  @override
  Stream<manager.SyncStatus> get syncStream => _syncController.stream;

  void emitPendingCount(int count) {
    _pendingCountController.add(count);
  }

  void emitSyncStatus(manager.SyncStatus status) {
    _syncController.add(status);
  }

  @override
  Future<manager.SyncResult> forceSync() async {
    return const manager.SyncResult.success(count: 0);
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('SyncStatusIndicator shows pending count', (tester) async {
    final fakeSyncManager = FakeSyncManager();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          manager.syncManagerProvider.overrideWithValue(fakeSyncManager),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(compact: false),
          ),
        ),
      ),
    );
    
    // Initial state (AsyncLoading/null -> 0)
    expect(find.text('Synced'), findsOneWidget);

    // Update count
    fakeSyncManager.emitPendingCount(5);
    await tester.pumpAndSettle();

    expect(find.text('5 pending'), findsOneWidget);
  });

  testWidgets('SyncStatusIndicator shows syncing state', (tester) async {
    final fakeSyncManager = FakeSyncManager();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          manager.syncManagerProvider.overrideWithValue(fakeSyncManager),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(compact: false),
          ),
        ),
      ),
    );

    fakeSyncManager.emitSyncStatus(const manager.SyncStatus.inProgress());
    await tester.pumpAndSettle();

    expect(find.text('Syncing...'), findsOneWidget);
  });
}
