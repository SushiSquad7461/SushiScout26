import 'dart:developer' as developer;

/// Severity levels for logging
enum LogLevel { verbose, debug, info, warning, error, fatal }

/// A structured logging utility for the app
/// 
/// Provides consistent logging format with support for:
/// - Different log levels
/// - Structured data (JSON-like)
/// - Source location tracking
/// - Automatic error reporting integration
class Logger {
  final String name;

  const Logger(this.name);

  /// Log a verbose message (detailed debugging)
  void v(String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.verbose, message, data: data);
  }

  /// Log a debug message
  void d(String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.debug, message, data: data);
  }

  /// Log an info message
  void i(String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.info, message, data: data);
  }

  /// Log a warning
  void w(String message, {dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _log(LogLevel.warning, message, error: error, stackTrace: stackTrace, data: data);
  }

  /// Log an error
  void e(String message, {dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _log(LogLevel.error, message, error: error, stackTrace: stackTrace, data: data);
  }

  /// Log a fatal error
  void f(String message, {dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _log(LogLevel.fatal, message, error: error, stackTrace: stackTrace, data: data);
  }

  void _log(
    LogLevel level,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    // Only log in debug mode for verbose and debug levels
    if ((level == LogLevel.verbose || level == LogLevel.debug)) {
      assert(() {
        _printLog(level, message, error: error, stackTrace: stackTrace, data: data);
        return true;
      }());
      return;
    }

    _printLog(level, message, error: error, stackTrace: stackTrace, data: data);

    // Report errors and fatals to crash reporting service
    if (level == LogLevel.error || level == LogLevel.fatal) {
      _reportToCrashReporting(level, message, error: error, stackTrace: stackTrace, data: data);
    }
  }

  void _printLog(
    LogLevel level,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    final emoji = _getEmoji(level);
    final levelString = level.name.toUpperCase();
    final timestamp = DateTime.now().toIso8601String();
    
    final buffer = StringBuffer();
    buffer.writeln('$emoji [$levelString] $name: $message');
    buffer.writeln('   📅 $timestamp');
    
    if (data != null && data.isNotEmpty) {
      buffer.writeln('   📦 ${data.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
    }
    
    if (error != null) {
      buffer.writeln('   ❌ Error: $error');
    }
    
    if (stackTrace != null) {
      buffer.writeln('   📍 Stack trace:\n$stackTrace');
    }

    // Use developer.log for better IDE integration
    developer.log(
      buffer.toString(),
      name: name,
      error: error,
      stackTrace: stackTrace,
      level: _getLogLevelValue(level),
    );
  }

  String _getEmoji(LogLevel level) {
    return switch (level) {
      LogLevel.verbose => '💬',
      LogLevel.debug => '🐛',
      LogLevel.info => 'ℹ️',
      LogLevel.warning => '⚠️',
      LogLevel.error => '❌',
      LogLevel.fatal => '💥',
    };
  }

  int _getLogLevelValue(LogLevel level) {
    return switch (level) {
      LogLevel.verbose => 500,
      LogLevel.debug => 700,
      LogLevel.info => 800,
      LogLevel.warning => 900,
      LogLevel.error => 1000,
      LogLevel.fatal => 1200,
    };
  }

  void _reportToCrashReporting(
    LogLevel level,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    // TODO: Integrate with Firebase Crashlytics or similar
    // For now, just log that we would report it
    developer.log(
      '📤 Would report to crash tracking: $message',
      name: 'CrashReporting',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Global logger instances for different components
class Loggers {
  static const Logger api = Logger('API');
  static const Logger database = Logger('DB');
  static const Logger sync = Logger('SYNC');
  static const Logger ui = Logger('UI');
  static const Logger repository = Logger('REPO');
  static const Logger auth = Logger('AUTH');
}
