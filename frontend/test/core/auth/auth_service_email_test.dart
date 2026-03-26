import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/core/auth/auth_exceptions.dart';

import 'auth_service_email_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseAuth>(),
  MockSpec<UserCredential>(),
  MockSpec<User>(),
  MockSpec<FirebaseFirestore>(),
  MockSpec<DocumentSnapshot<Map<String, dynamic>>>(),
  MockSpec<DocumentReference<Map<String, dynamic>>>(),
  MockSpec<CollectionReference<Map<String, dynamic>>>(),
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

  group('AuthService.signInWithEmailAndPassword', () {
    test('throws AuthExceptionWeakPassword for invalid password', () async {
      expect(
        () => authService.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'weak',
        ),
        throwsA(isA<AuthExceptionWeakPassword>()),
      );
    });

    test('throws AuthExceptionInvalidEmail for invalid email format', () async {
      expect(
        () => authService.signInWithEmailAndPassword(
          email: 'not-an-email',
          password: 'ValidPass1',
        ),
        throwsA(isA<AuthExceptionInvalidEmail>()),
      );
    });

    test('calls FirebaseAuth.signInWithEmailAndPassword', () async {
      final mockCredential = MockUserCredential();
      final mockUser = MockUser();
      final mockDocSnapshot = MockDocumentSnapshot();
      final mockDocRef = MockDocumentReference();
      final mockCollectionRef = MockCollectionReference();

      when(mockCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('test-uid');
      when(mockUser.email).thenReturn('test@example.com');
      when(mockFirestore.collection(any)).thenReturn(mockCollectionRef);
      when(mockCollectionRef.doc(any)).thenReturn(mockDocRef);
      when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      when(mockDocSnapshot.exists).thenReturn(true);

      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCredential);

      await authService.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'ValidPass1',
      );

      verify(mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'ValidPass1',
      )).called(1);
    });
  });
}
