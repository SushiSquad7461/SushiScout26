import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/presentation/widgets/sync_status_indicator.dart';

void main() {
  group('SyncStatusIndicator Providers', () {
    test('isOnlineProvider defaults to true and can be updated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isOnlineProvider), true);

      container.read(isOnlineProvider.notifier).setOnline(false);
      expect(container.read(isOnlineProvider), false);
    });

    test('syncStatusProvider defaults to idle and can be updated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(syncStatusProvider), isA<SyncStatusIdle>());

      container.read(syncStatusProvider.notifier).setStatus(const SyncStatus.syncing());
      expect(container.read(syncStatusProvider), isA<SyncStatusSyncing>());
    });

    test('pendingSyncCountProvider defaults to 0 and can be updated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(pendingSyncCountProvider), 0);

      container.read(pendingSyncCountProvider.notifier).setCount(5);
      expect(container.read(pendingSyncCountProvider), 5);

      container.read(pendingSyncCountProvider.notifier).increment();
      expect(container.read(pendingSyncCountProvider), 6);

      container.read(pendingSyncCountProvider.notifier).decrement();
      expect(container.read(pendingSyncCountProvider), 5);
    });
  });
}
