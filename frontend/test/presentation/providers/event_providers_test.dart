import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/providers/event_providers.dart';

void main() {
  group('composeEventId', () {
    test('combines team id and event code with an underscore', () {
      expect(composeEventId('aB3kZx9Q', '2026casf'), 'aB3kZx9Q_2026casf');
    });

    test('falls back to bare code when team id is null', () {
      expect(composeEventId(null, '2026casf'), '2026casf');
    });

    test('falls back to bare code when team id is empty', () {
      expect(composeEventId('', '2026casf'), '2026casf');
    });
  });
}
