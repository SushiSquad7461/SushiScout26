import '../errors/app_error.dart';

/// A Result type that represents either success with a value of type [T]
/// or failure with an error of type [AppError].
///
/// This is inspired by Rust's Result type and functional programming patterns.
/// It forces explicit error handling and eliminates null checks.
///
/// Example usage:
/// ```dart
/// Result<MatchReport, AppError> result = await repository.getMatch(id);
/// 
/// result.when(
///   success: (match) => displayMatch(match),
///   failure: (error) => showErrorSnackbar(error.message),
/// );
/// ```
sealed class Result<T, E extends AppError> {
  const Result();

  /// Returns true if this is a success result
  bool get isSuccess => this is Success<T, E>;

  /// Returns true if this is a failure result
  bool get isFailure => this is Failure<T, E>;

  /// Gets the value if success, null otherwise
  T? get valueOrNull => isSuccess ? (this as Success<T, E>).value : null;

  /// Gets the error if failure, null otherwise
  E? get errorOrNull => isFailure ? (this as Failure<T, E>).error : null;

  /// Transforms the value if success, returns new result
  Result<R, E> map<R>(R Function(T) transform);

  /// Transforms the error if failure, returns new result
  Result<T, F> mapError<F extends AppError>(F Function(E) transform);

  /// Flat maps the result - useful for chaining async operations
  Future<Result<R, E>> flatMap<R>(Future<Result<R, E>> Function(T) transform);

  /// Executes one of two callbacks based on result type
  R when<R>({
    required R Function(T) success,
    required R Function(E) failure,
  });

  /// Gets the value or throws the error
  T getOrThrow() => when(
        success: (value) => value,
        failure: (error) => throw error,
      );

  /// Gets the value or returns a default
  T getOrElse(T defaultValue) => when(
        success: (value) => value,
        failure: (_) => defaultValue,
      );

  /// Gets the value or computes a default
  T getOrCompute(T Function(E) onFailure) => when(
        success: (value) => value,
        failure: (error) => onFailure(error),
      );

  /// Factory constructor for success
  factory Result.success(T value) = Success<T, E>;

  /// Factory constructor for failure
  factory Result.failure(E error) = Failure<T, E>;
}

/// Represents a successful result with a value
class Success<T, E extends AppError> extends Result<T, E> {
  final T value;

  const Success(this.value);

  @override
  Result<R, E> map<R>(R Function(T) transform) =>
      Result.success(transform(value));

  @override
  Result<T, F> mapError<F extends AppError>(F Function(E) transform) =>
      Result.success(value);

  @override
  Future<Result<R, E>> flatMap<R>(Future<Result<R, E>> Function(T) transform) =>
      transform(value);

  @override
  R when<R>({
    required R Function(T) success,
    required R Function(E) failure,
  }) =>
      success(value);

  @override
  String toString() => 'Success($value)';
}

/// Represents a failed result with an error
class Failure<T, E extends AppError> extends Result<T, E> {
  final E error;

  const Failure(this.error);

  @override
  Result<R, E> map<R>(R Function(T) transform) => Result.failure(error);

  @override
  Result<T, F> mapError<F extends AppError>(F Function(E) transform) =>
      Result.failure(transform(error));

  @override
  Future<Result<R, E>> flatMap<R>(Future<Result<R, E>> Function(T) transform) =>
      Future.value(Result.failure(error));

  @override
  R when<R>({
    required R Function(T) success,
    required R Function(E) failure,
  }) =>
      failure(error);

  @override
  String toString() => 'Failure($error)';
}

/// Extension methods for working with nullable values as Results
extension NullableResultExtensions<T> on T? {
  /// Converts a nullable value to a Result
  /// Returns success if not null, failure with given error if null
  Result<T, AppError> toResultOr(AppError Function() onNull) =>
      this != null ? Result.success(this as T) : Result.failure(onNull());
}

/// Extension methods for Futures that return Results
extension FutureResultExtensions<T, E extends AppError> on Future<Result<T, E>> {
  /// Recovers from failure by providing a fallback value
  Future<Result<T, E>> recover(T Function(E) onFailure) async {
    final result = await this;
    return result.when(
      success: (value) => Result.success(value),
      failure: (error) => Result.success(onFailure(error)),
    );
  }

  /// Recovers from failure by providing a fallback result
  Future<Result<T, E>> recoverWith(Future<Result<T, E>> Function(E) onFailure) async {
    final result = await this;
    return result.when(
      success: (value) => Result.success(value),
      failure: (error) => onFailure(error),
    );
  }
}

/// Extension methods for catching exceptions and converting to Results
extension FutureExceptionExtensions<T> on Future<T> {
  /// Catches exceptions and converts them to Result failures
  Future<Result<T, AppError>> toResult(AppError Function(dynamic, StackTrace) onError) async {
    try {
      final value = await this;
      return Result.success(value);
    } catch (error, stackTrace) {
      return Result.failure(onError(error, stackTrace));
    }
  }
}
