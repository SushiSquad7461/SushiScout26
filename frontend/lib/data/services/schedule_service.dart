import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logger.dart';

final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  return ScheduleService();
});

/// Wraps callable Cloud Functions for FRC and FTC schedule fetching.
class ScheduleService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final Logger _logger = const Logger('SCHEDULE');

  /// Fetch match schedule for the given event.
  /// Returns `{success, count, cached}` on success, or throws.
  Future<Map<String, dynamic>> fetchSchedule({
    required String eventCode,
    required String programType,
  }) async {
    final functionName =
        programType == 'FTC' ? 'fetch_ftc_schedule' : 'fetch_event_schedule';
    final paramKey = programType == 'FTC' ? 'eventCode' : 'eventKey';

    _logger.i('Fetching $programType schedule for $eventCode');

    try {
      final callable = _functions.httpsCallable(functionName);
      final result = await callable.call<Map<String, dynamic>>({paramKey: eventCode});
      final data = Map<String, dynamic>.from(result.data);
      _logger.i('Schedule fetch result: $data');
      return data;
    } on FirebaseFunctionsException catch (e) {
      _logger.e('Schedule fetch failed', error: e);
      rethrow;
    }
  }
}
