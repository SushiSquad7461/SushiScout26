/// Base class for all application errors
/// 
/// All custom errors should extend this class and provide
/// a user-friendly message and optional technical details.
abstract class AppError implements Exception {
  final String message;
  final String? code;
  final dynamic details;
  final StackTrace? stackTrace;

  const AppError(
    this.message, {
    this.code,
    this.details,
    this.stackTrace,
  });

  @override
  String toString() => 'AppError: $message (code: $code)';
}

/// Error for network-related issues
class NetworkError extends AppError {
  final bool isRetryable;

  const NetworkError(
    super.message, {
    super.code,
    super.details,
    super.stackTrace,
    this.isRetryable = true,
  });

  factory NetworkError.noConnection() => const NetworkError(
        'No internet connection. Please check your network and try again.',
        code: 'NETWORK_NO_CONNECTION',
        isRetryable: true,
      );

  factory NetworkError.timeout() => const NetworkError(
        'Request timed out. Please try again.',
        code: 'NETWORK_TIMEOUT',
        isRetryable: true,
      );

  factory NetworkError.serverError(int statusCode) => NetworkError(
        'Server error occurred. Please try again later.',
        code: 'NETWORK_SERVER_ERROR',
        details: {'statusCode': statusCode},
        isRetryable: true,
      );

  factory NetworkError.unknown(dynamic error) => NetworkError(
        'An unexpected network error occurred.',
        code: 'NETWORK_UNKNOWN',
        details: error,
        isRetryable: true,
      );
}

/// Error for data validation failures
class ValidationError extends AppError {
  final Map<String, String>? fieldErrors;

  const ValidationError(
    super.message, {
    super.code,
    this.fieldErrors,
    super.details,
    super.stackTrace,
  });

  factory ValidationError.requiredField(String field) => ValidationError(
        '$field is required',
        code: 'VALIDATION_REQUIRED',
        fieldErrors: {field: 'This field is required'},
      );

  factory ValidationError.invalidFormat(String field, String expected) =>
      ValidationError(
        '$field has invalid format. Expected: $expected',
        code: 'VALIDATION_INVALID_FORMAT',
        fieldErrors: {field: 'Invalid format'},
      );

  factory ValidationError.range(String field, num min, num max) =>
      ValidationError(
        '$field must be between $min and $max',
        code: 'VALIDATION_RANGE',
        fieldErrors: {field: 'Value out of range'},
      );
}

/// Error for data synchronization issues
class SyncError extends AppError {
  final String? entityId;
  final int? retryCount;

  const SyncError(
    super.message, {
    super.code,
    this.entityId,
    this.retryCount,
    super.details,
    super.stackTrace,
  });

  factory SyncError.conflict(String entityId) => SyncError(
        'Data conflict detected. Your changes will be queued for manual review.',
        code: 'SYNC_CONFLICT',
        entityId: entityId,
      );

  factory SyncError.permissionDenied(String entityId) => SyncError(
        'Permission denied. You may not have access to modify this data.',
        code: 'SYNC_PERMISSION_DENIED',
        entityId: entityId,
      );

  factory SyncError.quotaExceeded() => const SyncError(
        'Sync quota exceeded. Please try again later.',
        code: 'SYNC_QUOTA_EXCEEDED',
      );

  factory SyncError.unknown(String entityId, dynamic error) => SyncError(
        'Failed to sync data. It will be retried automatically.',
        code: 'SYNC_UNKNOWN',
        entityId: entityId,
        details: error,
      );
}

/// Error for storage/local database issues
class StorageError extends AppError {
  const StorageError(
    super.message, {
    super.code,
    super.details,
    super.stackTrace,
  });

  factory StorageError.full() => const StorageError(
        'Storage is full. Please free up space and try again.',
        code: 'STORAGE_FULL',
      );

  factory StorageError.corrupted() => const StorageError(
        'Data appears to be corrupted. Please restart the app.',
        code: 'STORAGE_CORRUPTED',
      );

  factory StorageError.unknown(dynamic error) => StorageError(
        'An unexpected storage error occurred.',
        code: 'STORAGE_UNKNOWN',
        details: error,
      );
}

/// Error for authentication/authorization issues
class AuthError extends AppError {
  const AuthError(
    super.message, {
    super.code,
    super.details,
    super.stackTrace,
  });

  factory AuthError.unauthenticated() => const AuthError(
        'Please sign in to continue.',
        code: 'AUTH_UNAUTHENTICATED',
      );

  factory AuthError.unauthorized() => const AuthError(
        'You do not have permission to perform this action.',
        code: 'AUTH_UNAUTHORIZED',
      );

  factory AuthError.invalidCredentials() => const AuthError(
        'Invalid credentials. Please check and try again.',
        code: 'AUTH_INVALID_CREDENTIALS',
      );
}

/// Error for unexpected/unknown issues
class UnknownError extends AppError {
  const UnknownError(
    super.message, {
    String? code,
    super.details,
    super.stackTrace,
  }) : super(
          code: code ?? 'UNKNOWN',
        );

  factory UnknownError.fromException(dynamic error, StackTrace? stackTrace) =>
      UnknownError(
        'An unexpected error occurred. Please try again.',
        code: 'UNKNOWN_EXCEPTION',
        details: error,
        stackTrace: stackTrace,
      );
}
