import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/widgets/connection_status.dart';

void main() {
  group('connectionStatusFrom', () {
    test('reports everything uploaded when online with no pending writes', () {
      final status = connectionStatusFrom(isFromCache: false, pendingCount: 0);

      expect(status.isOffline, isFalse);
      expect(status.pendingCount, 0);
      expect(status.isFullySynced, isTrue);
      expect(status.message, 'All reports uploaded');
    });

    test('reports uploading when online with pending writes', () {
      final status = connectionStatusFrom(isFromCache: false, pendingCount: 3);

      expect(status.isOffline, isFalse);
      expect(status.isFullySynced, isFalse);
      expect(status.message, 'Uploading 3 reports…');
    });

    test('singularises the count for a single pending report', () {
      final status = connectionStatusFrom(isFromCache: false, pendingCount: 1);

      expect(status.message, 'Uploading 1 report…');
    });

    test('reports offline with a saved count when unreachable', () {
      final status = connectionStatusFrom(isFromCache: true, pendingCount: 2);

      expect(status.isOffline, isTrue);
      expect(status.isFullySynced, isFalse);
      expect(status.message, 'Offline — 2 reports saved on this device');
    });

    test('reports offline without a count when nothing is pending', () {
      final status = connectionStatusFrom(isFromCache: true, pendingCount: 0);

      expect(status.isOffline, isTrue);
      expect(status.message, 'Offline — showing saved data');
    });

    test('a cache-served snapshot is offline even with nothing pending', () {
      // The captive-portal case: the device is associated with wifi, so
      // connectivity_plus would say "online", but no snapshot is reaching us.
      expect(connectionStatusFrom(isFromCache: true, pendingCount: 0).isOffline, isTrue);
    });
  });

  group('ConnectionStatus error state', () {
    test('is not fully synced when the stream errors', () {
      const status = ConnectionStatus(
        isOffline: false,
        pendingCount: 0,
        hasError: true,
      );

      expect(status.isFullySynced, isFalse);
      expect(
        status.message,
        "Can't reach the server — recent reports may not be uploaded",
      );
    });
  });
}
