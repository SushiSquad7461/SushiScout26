import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logger.dart';

final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  return ScheduleService();
});

/// Callable function name + parameter key for a program type.
class ScheduleCallableConfig {
  final String functionName;
  final String paramKey;

  const ScheduleCallableConfig({
    required this.functionName,
    required this.paramKey,
  });
}

/// Wraps callable Cloud Functions for FRC and FTC schedule fetching.
class ScheduleService {
  final FirebaseFunctions _functions;
  final Logger _logger = const Logger('SCHEDULE');

  ScheduleService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Resolve the callable function name and param key for a program type.
  /// FTC uses the FIRST Events API (`eventCode`); everything else uses TBA
  /// (`eventKey`).
  static ScheduleCallableConfig callableConfigFor(String programType) {
    final isFtc = programType == 'FTC';
    return ScheduleCallableConfig(
      functionName: isFtc ? 'fetch_ftc_schedule' : 'fetch_event_schedule',
      paramKey: isFtc ? 'eventCode' : 'eventKey',
    );
  }

  /// Fetch match schedule for the given event.
  /// Returns `{success, count, cached}` on success, or throws.
  Future<Map<String, dynamic>> fetchSchedule({
    required String eventCode,
    required String programType,
  }) async {
    final config = callableConfigFor(programType);

    _logger.i('Fetching $programType schedule for $eventCode');

    try {
      final callable = _functions.httpsCallable(config.functionName);
      final result = await callable
          .call<Map<String, dynamic>>({config.paramKey: eventCode});
      final data = Map<String, dynamic>.from(result.data);
      _logger.i('Schedule fetch result: $data');
      return data;
    } on FirebaseFunctionsException catch (e) {
      _logger.e('Schedule fetch failed', error: e);
      rethrow;
    }
  }
}
