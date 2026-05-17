import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/app_error.dart';
import 'package:frontend/core/errors/error_mapper.dart';

void main() {
  group('ErrorMapper.toUserMessage', () {
    test('returns the AppError message directly', () {
      expect(
        ErrorMapper.toUserMessage(NetworkError.timeout()),
        'Request timed out. Please try again.',
      );
    });

    test('maps generic "network" exception to friendly message', () {
      expect(
        ErrorMapper.toUserMessage(Exception('network failure')),
        contains('Network connection error'),
      );
    });

    test('maps "timeout" exception to friendly message', () {
      expect(
        ErrorMapper.toUserMessage(Exception('Operation timeout')),
        contains('timed out'),
      );
    });

    test('maps permission/unauthorized exception', () {
      expect(
        ErrorMapper.toUserMessage(Exception('permission denied')),
        contains("don't have permission"),
      );
    });

    test('maps validation/invalid to a check-input message', () {
      expect(
        ErrorMapper.toUserMessage(Exception('invalid token')),
        contains('check your input'),
      );
    });

    test('maps storage/disk to a storage error message', () {
      expect(
        ErrorMapper.toUserMessage(Exception('disk full')),
        contains('Storage error'),
      );
    });

    test('falls back to generic unexpected error', () {
      expect(
        ErrorMapper.toUserMessage(Exception('some random thing')),
        'An unexpected error occurred. Please try again.',
      );
    });
  });

  group('ErrorMapper.toActionTitle', () {
    test('Retry for retryable NetworkError', () {
      expect(ErrorMapper.toActionTitle(NetworkError.timeout()), 'Retry');
    });

    test('Dismiss for non-retryable NetworkError', () {
      expect(
        ErrorMapper.toActionTitle(
          const NetworkError('fatal', isRetryable: false),
        ),
        'Dismiss',
      );
    });

    test('Fix for ValidationError', () {
      expect(
        ErrorMapper.toActionTitle(const ValidationError('bad input')),
        'Fix',
      );
    });

    test('OK for unknown error types', () {
      expect(ErrorMapper.toActionTitle(Exception('whatever')), 'OK');
    });
  });

  group('ErrorMapper.isDestructiveAction', () {
    test('false for plain Exception (not an AppError)', () {
      expect(ErrorMapper.isDestructiveAction(Exception('x')), isFalse);
    });

    test('false for AppError without DELETE/REMOVE in code', () {
      expect(
        ErrorMapper.isDestructiveAction(NetworkError.timeout()),
        isFalse,
      );
    });

    test('true for AppError with DELETE in code', () {
      expect(
        ErrorMapper.isDestructiveAction(
          const NetworkError('boom', code: 'DELETE_FAILED'),
        ),
        isTrue,
      );
    });

    test('true for AppError with REMOVE in code', () {
      expect(
        ErrorMapper.isDestructiveAction(
          const NetworkError('boom', code: 'REMOVE_TEAM'),
        ),
        isTrue,
      );
    });
  });

  group('ErrorMapper.toIconName', () {
    test('wifi_off for NetworkError', () {
      expect(ErrorMapper.toIconName(NetworkError.timeout()), 'wifi_off');
    });

    test('error_outline for ValidationError', () {
      expect(
        ErrorMapper.toIconName(const ValidationError('x')),
        'error_outline',
      );
    });

    test('error for unknown types', () {
      expect(ErrorMapper.toIconName(Exception('x')), 'error');
    });
  });

  group('ErrorMapper.getSeverity', () {
    test('warning for retryable network errors', () {
      expect(
        ErrorMapper.getSeverity(NetworkError.timeout()),
        ErrorSeverity.warning,
      );
    });

    test('error for non-retryable network errors', () {
      expect(
        ErrorMapper.getSeverity(
          const NetworkError('fatal', isRetryable: false),
        ),
        ErrorSeverity.error,
      );
    });

    test('info for ValidationError', () {
      expect(
        ErrorMapper.getSeverity(const ValidationError('x')),
        ErrorSeverity.info,
      );
    });

    test('error for unknown AppError subclasses (default)', () {
      // A non-network, non-validation AppError → ErrorSeverity.error.
      expect(
        ErrorMapper.getSeverity(
          const NetworkError('boom', isRetryable: false),
        ),
        ErrorSeverity.error,
      );
    });
  });
}
