import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/app_error.dart';

void main() {
  group('AppError.toString', () {
    test('formats message and code', () {
      const err = NetworkError('Boom', code: 'X');
      expect(err.toString(), 'AppError: Boom (code: X)');
    });

    test('includes null code as "null"', () {
      const err = NetworkError('Boom');
      expect(err.toString(), 'AppError: Boom (code: null)');
    });
  });

  group('NetworkError factories', () {
    test('noConnection has expected code and isRetryable=true', () {
      final err = NetworkError.noConnection();
      expect(err.code, 'NETWORK_NO_CONNECTION');
      expect(err.isRetryable, isTrue);
      expect(err.message, contains('internet'));
    });

    test('timeout has expected code and isRetryable=true', () {
      final err = NetworkError.timeout();
      expect(err.code, 'NETWORK_TIMEOUT');
      expect(err.isRetryable, isTrue);
      expect(err.message, contains('timed out'));
    });

    test('serverError includes statusCode in details', () {
      final err = NetworkError.serverError(503);
      expect(err.code, 'NETWORK_SERVER_ERROR');
      expect(err.isRetryable, isTrue);
      expect((err.details as Map)['statusCode'], 503);
    });

    test('unknown attaches raw error to details', () {
      final raw = Exception('underlying');
      final err = NetworkError.unknown(raw);
      expect(err.code, 'NETWORK_UNKNOWN');
      expect(err.isRetryable, isTrue);
      expect(err.details, same(raw));
    });

    test('respects isRetryable override', () {
      const err = NetworkError('fatal', isRetryable: false);
      expect(err.isRetryable, isFalse);
    });
  });

  group('ValidationError factories', () {
    test('requiredField sets fieldErrors entry', () {
      final err = ValidationError.requiredField('email');
      expect(err.code, 'VALIDATION_REQUIRED');
      expect(err.message, 'email is required');
      expect(err.fieldErrors, {'email': 'This field is required'});
    });

    test('invalidFormat sets fieldErrors entry', () {
      final err = ValidationError.invalidFormat('email', 'foo@bar.com');
      expect(err.code, 'VALIDATION_INVALID_FORMAT');
      expect(err.message, contains('email'));
      expect(err.message, contains('foo@bar.com'));
      expect(err.fieldErrors, {'email': 'Invalid format'});
    });
  });

  group('SyncError factories', () {
    test('conflict carries entityId', () {
      final err = SyncError.conflict('match-1');
      expect(err.code, 'SYNC_CONFLICT');
      expect(err.entityId, 'match-1');
    });

    test('permissionDenied carries entityId and code', () {
      final err = SyncError.permissionDenied('match-2');
      expect(err.code, 'SYNC_PERMISSION_DENIED');
      expect(err.entityId, 'match-2');
    });

    test('quotaExceeded has no entityId', () {
      final err = SyncError.quotaExceeded();
      expect(err.code, 'SYNC_QUOTA_EXCEEDED');
      expect(err.entityId, isNull);
    });

    test('unknown wraps inner error in details', () {
      final raw = Exception('inner');
      final err = SyncError.unknown('match-3', raw);
      expect(err.code, 'SYNC_UNKNOWN');
      expect(err.entityId, 'match-3');
      expect(err.details, same(raw));
    });
  });

  group('StorageError factories', () {
    test('full has STORAGE_FULL code', () {
      expect(StorageError.full().code, 'STORAGE_FULL');
    });

    test('corrupted has STORAGE_CORRUPTED code', () {
      expect(StorageError.corrupted().code, 'STORAGE_CORRUPTED');
    });

    test('unknown attaches raw error to details', () {
      final raw = Exception('drift died');
      final err = StorageError.unknown(raw);
      expect(err.code, 'STORAGE_UNKNOWN');
      expect(err.details, same(raw));
    });
  });

  group('AuthError factories', () {
    test('unauthenticated', () {
      final err = AuthError.unauthenticated();
      expect(err.code, 'AUTH_UNAUTHENTICATED');
      expect(err.message, contains('sign in'));
    });

    test('unauthorized', () {
      final err = AuthError.unauthorized();
      expect(err.code, 'AUTH_UNAUTHORIZED');
      expect(err.message, contains('permission'));
    });

    test('invalidCredentials', () {
      final err = AuthError.invalidCredentials();
      expect(err.code, 'AUTH_INVALID_CREDENTIALS');
      expect(err.message, contains('Invalid credentials'));
    });
  });

  group('UnknownError', () {
    test('defaults code to UNKNOWN when not specified', () {
      const err = UnknownError('boom');
      expect(err.code, 'UNKNOWN');
    });

    test('respects explicit code override', () {
      const err = UnknownError('boom', code: 'CUSTOM');
      expect(err.code, 'CUSTOM');
    });

    test('fromException wires details and stackTrace', () {
      final raw = Exception('boom');
      final st = StackTrace.current;
      final err = UnknownError.fromException(raw, st);
      expect(err.code, 'UNKNOWN_EXCEPTION');
      expect(err.details, same(raw));
      expect(err.stackTrace, same(st));
    });
  });

  group('AppError implements Exception', () {
    test('can be caught as Exception', () {
      Object? caught;
      try {
        throw NetworkError.timeout();
      } on Exception catch (e) {
        caught = e;
      }
      expect(caught, isA<NetworkError>());
    });
  });
}
