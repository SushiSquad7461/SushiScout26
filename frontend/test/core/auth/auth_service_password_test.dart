import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_service.dart';

void main() {
  group('AuthService.isValidPassword', () {
    test('rejects password shorter than 8 characters', () {
      expect(AuthService.isValidPassword('Abc123'), isFalse);
    });

    test('rejects password without uppercase', () {
      expect(AuthService.isValidPassword('abcdefgh1'), isFalse);
    });

    test('rejects password without lowercase', () {
      expect(AuthService.isValidPassword('ABCDEFGH1'), isFalse);
    });

    test('rejects password without number', () {
      expect(AuthService.isValidPassword('Abcdefgh'), isFalse);
    });

    test('accepts valid password', () {
      expect(AuthService.isValidPassword('Password1'), isTrue);
    });

    test('accepts complex valid password', () {
      expect(AuthService.isValidPassword('MySecure123'), isTrue);
    });
  });
}
