import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_exceptions.dart';

void main() {
  group('AuthException', () {
    test('AuthExceptionWeakPassword has correct message', () {
      const exception = AuthExceptionWeakPassword();
      expect(exception.message, contains('8 characters'));
      expect(exception.message, contains('uppercase'));
      expect(exception.message, contains('lowercase'));
      expect(exception.message, contains('number'));
    });

    test('AuthExceptionInvalidEmail has correct message', () {
      const exception = AuthExceptionInvalidEmail();
      expect(exception.message, contains('valid email'));
    });

    test('AuthExceptionWrongPassword has correct message', () {
      const exception = AuthExceptionWrongPassword();
      expect(exception.message, contains('incorrect'));
    });

    test('AuthExceptionTooManyAttempts has correct message', () {
      const exception = AuthExceptionTooManyAttempts();
      expect(exception.message, contains('too many'));
    });

    test('AuthExceptionUserNotFound has correct message', () {
      const exception = AuthExceptionUserNotFound();
      expect(exception.message, contains('not found'));
    });
  });
}
