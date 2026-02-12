import 'dart:async';
import 'dart:math';
import '../errors/app_error.dart';
import '../result/result.dart';

/// A class that provides retry logic with exponential backoff
/// for network operations and other retryable actions.
///
/// Example usage:
/// ```dart
/// final retryConfig = RetryConfig(
///   maxAttempts: 3,
///   baseDelay: Duration(seconds: 1),
///   maxDelay: Duration(seconds: 10),
/// );
///
/// final result = await retryConfig.execute(
///   () async => await api.fetchData(),
///   onRetry: (attempt, error) => logger.w('Retry $attempt: $error'),
/// );
/// ```
class RetryConfig {
  /// Maximum number of retry attempts (default: 3)
  final int maxAttempts;

  /// Initial delay between retries (default: 1 second)
  final Duration baseDelay;

  /// Maximum delay between retries (default: 30 seconds)
  final Duration maxDelay;

  /// Multiplier for exponential backoff (default: 2.0)
  final double backoffMultiplier;

  /// Jitter factor to avoid thundering herd (default: 0.1)
  /// Adds random variation to delay: delay * (1 ± jitter)
  final double jitter;

  /// Predicate to determine if an error is retryable
  final bool Function(dynamic error)? isRetryableError;

  const RetryConfig({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.jitter = 0.1,
    this.isRetryableError,
  });

  /// Default retry configuration for network operations
  static const RetryConfig network = RetryConfig(
    maxAttempts: 3,
    baseDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 30),
  );

  /// Aggressive retry configuration for critical operations
  static const RetryConfig aggressive = RetryConfig(
    maxAttempts: 5,
    baseDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 60),
  );

  /// Conservative retry configuration for background sync
  static const RetryConfig background = RetryConfig(
    maxAttempts: 10,
    baseDelay: Duration(seconds: 5),
    maxDelay: Duration(minutes: 5),
  );

  /// Executes an operation with retry logic
  Future<T> execute<T>(
    Future<T> Function() operation, {
    void Function(int attempt, dynamic error, StackTrace? stackTrace)? onRetry,
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempt = 0;
    dynamic lastError;
    StackTrace? lastStackTrace;

    while (attempt < maxAttempts) {
      try {
        return await operation();
      } catch (error, stackTrace) {
        attempt++;
        lastError = error;
        lastStackTrace = stackTrace;

        // Check if we should retry this error
        final retryPredicate = shouldRetry ?? isRetryableError ?? _defaultIsRetryable;
        if (attempt >= maxAttempts || !retryPredicate(error)) {
          break;
        }

        // Notify listener about retry
        onRetry?.call(attempt, error, stackTrace);

        // Wait before next attempt with exponential backoff
        final delay = _calculateDelay(attempt);
        await Future.delayed(delay);
      }
    }

    // All attempts exhausted
    Error.throwWithStackTrace(lastError, lastStackTrace ?? StackTrace.current);
  }

  /// Executes an operation and returns a Result type
  Future<Result<T, AppError>> executeWithResult<T>(
    Future<T> Function() operation, {
    required AppError Function(dynamic error, StackTrace? stackTrace) onError,
    void Function(int attempt, AppError error)? onRetry,
  }) async {
    try {
      final result = await execute(
        operation,
        onRetry: (attempt, error, stackTrace) {
          final appError = onError(error, stackTrace);
          onRetry?.call(attempt, appError);
        },
      );
      return Result.success(result);
    } catch (error, stackTrace) {
      return Result.failure(onError(error, stackTrace));
    }
  }

  /// Calculates delay for a given attempt using exponential backoff with jitter
  Duration _calculateDelay(int attempt) {
    // Calculate base delay with exponential backoff
    final exponentialDelay = baseDelay.inMilliseconds * pow(backoffMultiplier, attempt - 1);
    
    // Cap at max delay
    final cappedDelay = min(exponentialDelay, maxDelay.inMilliseconds);
    
    // Add jitter to avoid thundering herd
    final jitterAmount = cappedDelay * jitter;
    final jitteredDelay = cappedDelay + (Random().nextDouble() * 2 - 1) * jitterAmount;
    
    return Duration(milliseconds: jitteredDelay.round());
  }

  /// Default predicate to determine if an error is retryable
  bool _defaultIsRetryable(dynamic error) {
    if (error is NetworkError) {
      return error.isRetryable;
    }
    // Retry on common transient errors
    final errorString = error.toString().toLowerCase();
    return errorString.contains('timeout') ||
           errorString.contains('connection') ||
           errorString.contains('socket') ||
           errorString.contains('network');
  }
}

/// Circuit breaker pattern to prevent cascading failures
/// 
/// When a service is failing, the circuit breaker opens and
/// subsequent calls fail fast without attempting the operation.
class CircuitBreaker {
  /// Number of failures before opening the circuit
  final int failureThreshold;

  /// Time to wait before attempting to close the circuit
  final Duration timeout;

  int _failureCount = 0;
  DateTime? _lastFailureTime;
  CircuitState _state = CircuitState.closed;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.timeout = const Duration(seconds: 30),
  });

  CircuitState get state => _state;
  bool get isOpen => _state == CircuitState.open;
  bool get isClosed => _state == CircuitState.closed;
  bool get isHalfOpen => _state == CircuitState.halfOpen;

  /// Executes an operation with circuit breaker protection
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (_state == CircuitState.open) {
      // Check if timeout has elapsed
      if (_lastFailureTime != null &&
          DateTime.now().difference(_lastFailureTime!) > timeout) {
        _state = CircuitState.halfOpen;
      } else {
        throw NetworkError(
          'Service temporarily unavailable. Please try again later.',
          code: 'CIRCUIT_OPEN',
          isRetryable: true,
        );
      }
    }

    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (error) {
      _onFailure();
      rethrow;
    }
  }

  void _onSuccess() {
    _failureCount = 0;
    _state = CircuitState.closed;
  }

  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= failureThreshold) {
      _state = CircuitState.open;
    }
  }

  /// Manually reset the circuit breaker
  void reset() {
    _failureCount = 0;
    _lastFailureTime = null;
    _state = CircuitState.closed;
  }
}

enum CircuitState { closed, open, halfOpen }
