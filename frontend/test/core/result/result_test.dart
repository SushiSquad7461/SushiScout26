import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/app_error.dart';
import 'package:frontend/core/result/result.dart';

void main() {
  group('Result.success', () {
    test('isSuccess is true, isFailure is false', () {
      final Result<int, AppError> r = Result.success(42);
      expect(r.isSuccess, isTrue);
      expect(r.isFailure, isFalse);
    });

    test('valueOrNull returns the value', () {
      final Result<int, AppError> r = Result.success(42);
      expect(r.valueOrNull, 42);
    });

    test('errorOrNull returns null', () {
      final Result<int, AppError> r = Result.success(42);
      expect(r.errorOrNull, isNull);
    });

    test('toString includes value', () {
      final Result<int, AppError> r = Result.success(42);
      expect(r.toString(), 'Success(42)');
    });
  });

  group('Result.failure', () {
    final error = NetworkError.noConnection();

    test('isFailure is true, isSuccess is false', () {
      final Result<int, AppError> r = Result.failure(error);
      expect(r.isFailure, isTrue);
      expect(r.isSuccess, isFalse);
    });

    test('errorOrNull returns the error', () {
      final Result<int, AppError> r = Result.failure(error);
      expect(r.errorOrNull, same(error));
    });

    test('valueOrNull returns null', () {
      final Result<int, AppError> r = Result.failure(error);
      expect(r.valueOrNull, isNull);
    });

    test('toString includes error', () {
      final Result<int, AppError> r = Result.failure(error);
      expect(r.toString(), contains('Failure'));
    });
  });

  group('Result.map', () {
    test('transforms success value', () {
      final Result<int, AppError> r = Result.success(10);
      final mapped = r.map((v) => v * 2);
      expect(mapped.valueOrNull, 20);
    });

    test('preserves failure unchanged', () {
      final error = NetworkError.noConnection();
      final Result<int, AppError> r = Result.failure(error);
      final mapped = r.map((v) => v * 2);
      expect(mapped.isFailure, isTrue);
      expect(mapped.errorOrNull, same(error));
    });

    test('changes value type', () {
      final Result<int, AppError> r = Result.success(42);
      final Result<String, AppError> mapped = r.map((v) => 'value: $v');
      expect(mapped.valueOrNull, 'value: 42');
    });
  });

  group('Result.mapError', () {
    test('transforms failure error', () {
      final Result<int, NetworkError> r = Result.failure(NetworkError.timeout());
      final Result<int, ValidationError> mapped =
          r.mapError((e) => ValidationError(e.message));
      expect(mapped.isFailure, isTrue);
      expect(mapped.errorOrNull, isA<ValidationError>());
    });

    test('preserves success unchanged', () {
      final Result<int, NetworkError> r = Result.success(42);
      final Result<int, ValidationError> mapped =
          r.mapError((e) => ValidationError(e.message));
      expect(mapped.valueOrNull, 42);
    });
  });

  group('Result.flatMap', () {
    test('chains successful transformations', () async {
      final Result<int, AppError> r = Result.success(10);
      final chained = await r.flatMap<int>(
        (v) async => Result.success(v * 2),
      );
      expect(chained.valueOrNull, 20);
    });

    test('propagates initial failure without calling transform', () async {
      final error = NetworkError.noConnection();
      final Result<int, AppError> r = Result.failure(error);
      var called = false;
      final chained = await r.flatMap<int>((v) async {
        called = true;
        return Result.success(v * 2);
      });
      expect(called, isFalse);
      expect(chained.errorOrNull, same(error));
    });

    test('returns failure from transform when chained returns failure',
        () async {
      final Result<int, AppError> r = Result.success(10);
      final error = NetworkError.timeout();
      final chained = await r.flatMap<int>((v) async => Result.failure(error));
      expect(chained.errorOrNull, same(error));
    });
  });

  group('Result.when', () {
    test('runs success branch for Success', () {
      final Result<int, AppError> r = Result.success(7);
      final out = r.when(
        success: (v) => 'got $v',
        failure: (e) => 'err ${e.message}',
      );
      expect(out, 'got 7');
    });

    test('runs failure branch for Failure', () {
      final Result<int, AppError> r =
          Result.failure(NetworkError.noConnection());
      final out = r.when(
        success: (v) => 'got $v',
        failure: (e) => 'err ${e.message}',
      );
      expect(out, startsWith('err '));
    });
  });

  group('Result.getOrThrow', () {
    test('returns value on success', () {
      final Result<int, AppError> r = Result.success(42);
      expect(r.getOrThrow(), 42);
    });

    test('throws error on failure', () {
      final error = NetworkError.noConnection();
      final Result<int, AppError> r = Result.failure(error);
      expect(() => r.getOrThrow(), throwsA(same(error)));
    });
  });

  group('Result.getOrElse', () {
    test('returns value on success', () {
      final Result<int, AppError> r = Result.success(42);
      expect(r.getOrElse(0), 42);
    });

    test('returns default on failure', () {
      final Result<int, AppError> r =
          Result.failure(NetworkError.noConnection());
      expect(r.getOrElse(-1), -1);
    });
  });

  group('Result.getOrCompute', () {
    test('returns value on success without calling compute', () {
      final Result<int, AppError> r = Result.success(42);
      var called = false;
      final out = r.getOrCompute((e) {
        called = true;
        return -1;
      });
      expect(out, 42);
      expect(called, isFalse);
    });

    test('returns computed default on failure with access to error', () {
      final error = NetworkError.noConnection();
      final Result<int, AppError> r = Result.failure(error);
      final out = r.getOrCompute((e) => e.code == 'NETWORK_NO_CONNECTION' ? -2 : -1);
      expect(out, -2);
    });
  });

  group('NullableResultExtensions.toResultOr', () {
    test('returns success for non-null', () {
      // ignore: unnecessary_nullable_for_final_variable_declarations
      const String? value = 'hello';
      final r = value.toResultOr(() => NetworkError.noConnection());
      expect(r.valueOrNull, 'hello');
    });

    test('returns failure for null', () {
      const String? value = null;
      final r = value.toResultOr(() => NetworkError.noConnection());
      expect(r.isFailure, isTrue);
    });
  });

  group('FutureResultExtensions.recover', () {
    test('passes success through unchanged', () async {
      final Future<Result<int, AppError>> future =
          Future.value(Result.success(42));
      final recovered = await future.recover((_) => -1);
      expect(recovered.valueOrNull, 42);
    });

    test('converts failure to success with fallback value', () async {
      final Future<Result<int, AppError>> future =
          Future.value(Result.failure(NetworkError.noConnection()));
      final recovered = await future.recover((_) => -1);
      expect(recovered.isSuccess, isTrue);
      expect(recovered.valueOrNull, -1);
    });
  });

  group('FutureResultExtensions.recoverWith', () {
    test('passes success through unchanged', () async {
      final Future<Result<int, AppError>> future =
          Future.value(Result.success(42));
      final recovered = await future.recoverWith(
        (_) async => Result.success(-1),
      );
      expect(recovered.valueOrNull, 42);
    });

    test('can recover failure to success', () async {
      final Future<Result<int, AppError>> future =
          Future.value(Result.failure(NetworkError.noConnection()));
      final recovered = await future.recoverWith(
        (_) async => Result.success(-1),
      );
      expect(recovered.valueOrNull, -1);
    });

    test('can chain failure to a different failure', () async {
      final Future<Result<int, AppError>> future =
          Future.value(Result.failure(NetworkError.noConnection()));
      final replacement = NetworkError.timeout();
      final recovered = await future.recoverWith(
        (_) async => Result.failure(replacement),
      );
      expect(recovered.errorOrNull, same(replacement));
    });
  });

  group('FutureExceptionExtensions.toResult', () {
    test('returns success when future completes normally', () async {
      final Future<int> future = Future.value(42);
      final r = await future.toResult(
        (e, st) => NetworkError.unknown(e),
      );
      expect(r.valueOrNull, 42);
    });

    test('returns failure when future throws', () async {
      final Future<int> future = Future.error(Exception('boom'));
      final r = await future.toResult(
        (e, st) => NetworkError.unknown(e),
      );
      expect(r.isFailure, isTrue);
      expect(r.errorOrNull, isA<NetworkError>());
    });
  });
}
