import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/services/schedule_service.dart';

void main() {
  group('ScheduleService.callableConfigFor', () {
    test('returns FTC callable for FTC program', () {
      final config = ScheduleService.callableConfigFor('FTC');
      expect(config.functionName, 'fetch_ftc_schedule');
      expect(config.paramKey, 'eventCode');
    });

    test('returns FRC callable for FRC program', () {
      final config = ScheduleService.callableConfigFor('FRC');
      expect(config.functionName, 'fetch_event_schedule');
      expect(config.paramKey, 'eventKey');
    });

    test('falls back to FRC for unknown programs', () {
      final config = ScheduleService.callableConfigFor('UNKNOWN');
      expect(config.functionName, 'fetch_event_schedule');
      expect(config.paramKey, 'eventKey');
    });

    test('falls back to FRC for empty string', () {
      final config = ScheduleService.callableConfigFor('');
      expect(config.functionName, 'fetch_event_schedule');
      expect(config.paramKey, 'eventKey');
    });

    test('is case sensitive — lowercase ftc does not match', () {
      final config = ScheduleService.callableConfigFor('ftc');
      expect(config.functionName, 'fetch_event_schedule');
    });
  });
}
