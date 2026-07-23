import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';
import 'package:frontend/data/repositories/providers.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;

void main() {
  test('firestoreRepositoryProvider throws until it is overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Riverpod 3 wraps a provider's synchronous throw in a ProviderException;
    // unwrap it to assert on the underlying error.
    expect(
      () => container.read(firestoreRepositoryProvider),
      throwsA(
        isA<ProviderException>().having(
          (e) => e.exception,
          'exception',
          isA<UnimplementedError>(),
        ),
      ),
    );
  });

  test('the main.dart override wiring produces a team-scoped repository', () {
    final fake = FakeFirebaseFirestore();
    final container = ProviderContainer(
      overrides: [
        activeTeamIdProvider.overrideWith((ref) => 'teamA'),
        firestoreRepositoryProvider.overrideWith((ref) {
          final teamId = ref.watch(activeTeamIdProvider);
          return FirestoreRepository(fake, teamId: teamId);
        }),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(firestoreRepositoryProvider).teamId, 'teamA');
  });
}
