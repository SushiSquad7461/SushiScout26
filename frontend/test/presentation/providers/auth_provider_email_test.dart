import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/presentation/providers/auth_provider.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/data/repositories/auth_repository.dart';

import 'auth_provider_email_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<AuthService>(),
  MockSpec<AuthRepository>(),
])
void main() {
  late ProviderContainer container;
  late MockAuthService mockAuthService;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthService = MockAuthService();
    mockAuthRepository = MockAuthRepository();
    container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(mockAuthService),
      authRepositoryProvider.overrideWithValue(mockAuthRepository),
    ]);
    
    when(mockAuthRepository.authStateChanges).thenAnswer((_) => const Stream.empty());
    when(mockAuthRepository.currentUser).thenReturn(null);
  });

  tearDown(() {
    container.dispose();
  });

  group('AuthNotifier.signInWithEmailAndPassword', () {
    test('calls AuthService.signInWithEmailAndPassword', () async {
      when(mockAuthService.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => MockUserCredential());

      await container
          .read(authProvider.notifier)
          .signInWithEmailAndPassword('test@example.com', 'ValidPass1');

      verify(mockAuthService.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'ValidPass1',
      )).called(1);
    });
  });

  group('AuthNotifier.sendPasswordResetEmail', () {
    test('calls AuthService.sendPasswordResetEmail', () async {
      when(mockAuthService.sendPasswordResetEmail(any))
          .thenAnswer((_) async {});

      await container
          .read(authProvider.notifier)
          .sendPasswordResetEmail('test@example.com');

      verify(mockAuthService.sendPasswordResetEmail(any))
          .called(1);
    });
  });
}

class MockUserCredential implements UserCredential {
  @override
  User? get user => null;
  
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
