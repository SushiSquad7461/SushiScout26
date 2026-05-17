import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/app_error.dart';
import 'package:frontend/core/network/retry.dart';

void main() {
  group('RetryConfig.execute', () {
    test('returns result without retrying on first success', () async {
      const config = RetryConfig(
        maxAttempts: 3,
        baseDelay: Duration(milliseconds: 1),
        maxDelay: Duration(milliseconds: 1),
      );

      var calls = 0;
      final result = await config.execute<int>(() async {
        calls++;
        return 42;
      });

      expect(result, 42);
      expect(calls, 1);
    });

    test('retries on retryable error and eventually succeeds', () async {
      const config = RetryConfig(
        maxAttempts: 3,
        baseDelay: Duration(milliseconds: 1),
        maxDelay: Duration(milliseconds: 1),
        jitter: 0,
      );

      var calls = 0;
      final result = await config.execute<int>(() async {
        calls++;
        if (calls < 3) {
          throw NetworkError.timeout();
        }
        return 7;
      });

      expect(result, 7);
      expect(calls, 3);
    });

    test('stops retrying once maxAttempts reached and rethrows last error',
        () async {
      const config = RetryConfig(
        maxAttempts: 2,
        baseDelay: Duration(milliseconds: 1),
        maxDelay: Duration(milliseconds: 1),
        jitter: 0,
      );

      var calls = 0;
      Object? thrown;
      try {
        await config.execute<int>(() async {
          calls++;
          throw NetworkError.timeout();
        });
      } catch (e) {
        thrown = e;
      }

      expect(calls, 2);
      expect(thrown, isA<NetworkError>());
    });

    test('does not retry when error is not retryable', () async {
      const config = RetryConfig(
        maxAttempts: 5,
        baseDelay: Duration(milliseconds: 1),
        maxDelay: Duration(milliseconds: 1),
        jitter: 0,
      );

      var calls = 0;
      Object? thrown;
      try {
        await config.execute<int>(
          () async {
            calls++;
            throw ArgumentError('not retryable');
          },
          shouldRetry: (e) => false,
        );
      } catch (e) {
        thrown = e;
      }

      expect(calls, 1);
      expect(thrown, isA<ArgumentError>());
    });

    test('uses custom shouldRetry over isRetryableError', () async {
      const config = RetryConfig(
        maxAttempts: 3,
        baseDelay: Duration(milliseconds: 1),
        maxDelay: Duration(milliseconds: 1),
        jitter: 0,
      );

      var calls = 0;
      try {
        await config.execute<int>(
          () async {
            calls++;
            throw NetworkError.timeout();
          },
          // Override: don't retry network errors here.
          shouldRetry: (e) => false,
        );
      } catch (_) {
        // Expected to throw.
      }

      expect(calls, 1);
    });

    test('invokes onRetry callback with attempt count and error', () async {
      const config = RetryConfig(
        maxAttempts: 3,
        baseDelay: Duration(milliseconds: 1),
        maxDelay: Duration(milliseconds: 1),
        jitter: 0,
      );

      final attempts = <int>[];
      final errors = <Object>[];
      try {
        await config.execute<int>(
          () async => throw NetworkError.timeout(),
          onRetry: (attempt, error, _) {
            attempts.add(attempt);
            errors.add(error);
          },
        );
      } catch (_) {}

      // onRetry fires for each failure that leads to another attempt.
      // With maxAttempts=3, we get 3 total executions and 2 retries before
      // the final failure exits the loop.
      expect(attempts, [1, 2]);
      expect(errors.length, 2);
    });

    test('respects NetworkError.isRetryable in default predicate', () async {
      const config = RetryConfig(
        maxAttempts: 3,
        baseDelay: Duration(milliseconds: 1),
        maxDelay: Duration(milliseconds: 1),
        jitter: 0,
      );

      var calls = 0;
      try {
        await config.execute<int>(() async {
          calls++;
          // isRetryable: false → default predicate should refuse.
          throw const NetworkError('boom', isRetryable: false);
        });
      } catch (_) {}

      expect(calls, 1);
    });
  });

  group('RetryConfig presets', () {
    test('network preset has 3 attempts', () {
      expect(RetryConfig.network.maxAttempts, 3);
    });

    test('aggressive preset has 5 attempts and short base delay', () {
      expect(RetryConfig.aggressive.maxAttempts, 5);
      expect(RetryConfig.aggressive.baseDelay,
          const Duration(milliseconds: 500));
    });

    test('background preset has 10 attempts and 5-minute max delay', () {
      expect(RetryConfig.background.maxAttempts, 10);
      expect(RetryConfig.background.maxDelay, const Duration(minutes: 5));
    });
  });

  group('RetryConfig.executeWithResult', () {
    test('returns success Result on first try', () async {
      const config = RetryConfig(
        maxAttempts: 2,
        baseDelay: Duration(milliseconds: 1),
        maxDelay: Duration(milliseconds: 1),
        jitter: 0,
      );

      final result = await config.executeWithResult<int>(
        () async => 99,
        onError: (e, st) => NetworkError.unknown(e),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 99);
    });

    test('returns failure Result after exhausting retries', () async {
      const config = RetryConfig(
        maxAttempts: 2,
        baseDelay: Duration(milliseconds: 1),
        maxDelay: Duration(milliseconds: 1),
        jitter: 0,
      );

      final result = await config.executeWithResult<int>(
        () async => throw NetworkError.timeout(),
        onError: (e, st) => NetworkError.unknown(e),
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<NetworkError>());
    });
  });
}
