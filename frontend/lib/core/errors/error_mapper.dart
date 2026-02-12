import 'app_error.dart';

/// Maps technical errors to user-friendly messages
/// 
/// This class centralizes all error messages to ensure consistency
/// across the app and make localization easier in the future.
class ErrorMapper {
  /// Maps an error to a user-friendly message
  static String toUserMessage(dynamic error) {
    if (error is AppError) {
      return error.message;
    }

    // Handle common Flutter/Firebase errors
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket')) {
      return 'Network connection error. Please check your internet and try again.';
    }

    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (errorString.contains('permission') ||
        errorString.contains('unauthorized')) {
      return 'You don\'t have permission to perform this action.';
    }

    if (errorString.contains('not found') || errorString.contains('404')) {
      return 'The requested item could not be found.';
    }

    if (errorString.contains('already exists') ||
        errorString.contains('duplicate')) {
      return 'This item already exists.';
    }

    if (errorString.contains('validation') ||
        errorString.contains('invalid')) {
      return 'Please check your input and try again.';
    }

    if (errorString.contains('storage') || errorString.contains('disk')) {
      return 'Storage error. Please free up space and try again.';
    }

    // Default fallback
    return 'An unexpected error occurred. Please try again.';
  }

  /// Maps an error to an appropriate action title
  static String toActionTitle(dynamic error) {
    if (error is NetworkError) {
      return error.isRetryable ? 'Retry' : 'Dismiss';
    }

    if (error is ValidationError) {
      return 'Fix';
    }

    if (error is SyncError) {
      return 'Sync Now';
    }

    return 'OK';
  }

  /// Determines if the error action is destructive
  static bool isDestructiveAction(dynamic error) {
    if (error is AppError) {
      return error.code?.contains('DELETE') == true ||
             error.code?.contains('REMOVE') == true;
    }
    return false;
  }

  /// Gets an icon name appropriate for the error type
  static String toIconName(dynamic error) {
    if (error is NetworkError) {
      return 'wifi_off';
    }

    if (error is ValidationError) {
      return 'error_outline';
    }

    if (error is SyncError) {
      return 'sync_problem';
    }

    if (error is StorageError) {
      return 'storage';
    }

    if (error is AuthError) {
      return 'lock';
    }

    return 'error';
  }

  /// Gets the severity level for analytics/logging
  static ErrorSeverity getSeverity(dynamic error) {
    if (error is NetworkError) {
      return error.isRetryable ? ErrorSeverity.warning : ErrorSeverity.error;
    }

    if (error is ValidationError) {
      return ErrorSeverity.info;
    }

    if (error is UnknownError) {
      return ErrorSeverity.critical;
    }

    return ErrorSeverity.error;
  }
}

enum ErrorSeverity { info, warning, error, critical }
