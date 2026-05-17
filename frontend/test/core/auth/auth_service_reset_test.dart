import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/core/auth/auth_exceptions.dart';
import 'package:frontend/core/auth/auth_service.dart';

import 'auth_service_reset_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseAuth>(),
  MockSpec<FirebaseFirestore>(),
])
void main() {
  late AuthService authService;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    authService = AuthService(auth: mockAuth, firestore: mockFirestore);
  });

  group('AuthService.sendPasswordResetEmail', () {
    test('calls FirebaseAuth.sendPasswordResetEmail', () async {
      when(mockAuth.sendPasswordResetEmail(email: anyNamed('email')))
          .thenAnswer((_) async {});

      await authService.sendPasswordResetEmail('test@example.com');

      verify(mockAuth.sendPasswordResetEmail(email: 'test@example.com'))
          .called(1);
    });

    test('throws AuthExceptionInvalidEmail for malformed email', () async {
      expect(
        () => authService.sendPasswordResetEmail('not-an-email'),
        throwsA(isA<AuthExceptionInvalidEmail>()),
      );
      // Must not have hit Firebase.
      verifyNever(mockAuth.sendPasswordResetEmail(email: anyNamed('email')));
    });

    test('throws AuthExceptionInvalidEmail for empty string', () async {
      expect(
        () => authService.sendPasswordResetEmail(''),
        throwsA(isA<AuthExceptionInvalidEmail>()),
      );
    });

    test('maps FirebaseAuthException user-not-found to AuthException', () async {
      when(mockAuth.sendPasswordResetEmail(email: anyNamed('email')))
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));

      await expectLater(
        authService.sendPasswordResetEmail('test@example.com'),
        throwsA(isA<AuthException>()),
      );
    });

    test('wraps unknown errors as AuthExceptionNetworkError', () async {
      when(mockAuth.sendPasswordResetEmail(email: anyNamed('email')))
          .thenThrow(Exception('socket closed'));

      await expectLater(
        authService.sendPasswordResetEmail('test@example.com'),
        throwsA(isA<AuthExceptionNetworkError>()),
      );
    });
  });
}
