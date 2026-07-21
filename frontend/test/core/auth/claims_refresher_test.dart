import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/claims_refresher.dart';

void main() {
  group('waitForTeamClaim', () {
    test('returns true once the team appears in the teams claim', () async {
      var calls = 0;
      final result = await waitForTeamClaim(
        fetchClaims: () async {
          calls++;
          // Claim empty on first fetch, populated on the second.
          return calls >= 2 ? {'teams': {'teamA': 'admin'}} : {'teams': {}};
        },
        expectedTeamId: 'teamA',
        maxAttempts: 5,
        sleep: (_) async {}, // no real waiting in tests
      );
      expect(result, isTrue);
      expect(calls, 2);
    });

    test('returns false after exhausting attempts', () async {
      final result = await waitForTeamClaim(
        fetchClaims: () async => {'teams': {}},
        expectedTeamId: 'teamA',
        maxAttempts: 3,
        sleep: (_) async {},
      );
      expect(result, isFalse);
    });
  });
}
