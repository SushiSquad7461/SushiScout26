import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/validation/form_validators.dart';

void main() {
  group('FormValidators.required', () {
    test('returns error for null', () {
      expect(FormValidators.required(null), 'This field is required');
    });

    test('returns error for empty string', () {
      expect(FormValidators.required(''), 'This field is required');
    });

    test('returns error for whitespace-only string', () {
      expect(FormValidators.required('   '), 'This field is required');
    });

    test('returns null for valid value', () {
      expect(FormValidators.required('hello'), isNull);
    });

    test('uses custom field name in error message', () {
      expect(FormValidators.required(null, 'Email'), 'Email is required');
    });
  });

  group('FormValidators.number', () {
    test('returns null for empty value (not required)', () {
      expect(FormValidators.number(null), isNull);
      expect(FormValidators.number(''), isNull);
      expect(FormValidators.number('  '), isNull);
    });

    test('returns error for non-numeric value', () {
      expect(FormValidators.number('abc'), 'Value must be a number');
    });

    test('returns error for value below min', () {
      expect(FormValidators.number('5', min: 10), 'Value must be at least 10');
    });

    test('returns error for value above max', () {
      expect(FormValidators.number('15', max: 10), 'Value must be at most 10');
    });

    test('returns null for value within range', () {
      expect(FormValidators.number('5', min: 1, max: 10), isNull);
    });

    test('returns null for value at min boundary', () {
      expect(FormValidators.number('1', min: 1, max: 10), isNull);
    });

    test('returns null for value at max boundary', () {
      expect(FormValidators.number('10', min: 1, max: 10), isNull);
    });

    test('rejects floating-point input as non-integer', () {
      expect(FormValidators.number('5.5'), 'Value must be a number');
    });

    test('uses custom field name in error messages', () {
      expect(
        FormValidators.number('abc', fieldName: 'Score'),
        'Score must be a number',
      );
      expect(
        FormValidators.number('0', min: 1, fieldName: 'Score'),
        'Score must be at least 1',
      );
    });
  });

  group('FormValidators.matchNumber', () {
    test('returns error for null/empty', () {
      expect(FormValidators.matchNumber(null), 'Match number is required');
      expect(FormValidators.matchNumber(''), 'Match number is required');
    });

    test('returns error for non-numeric value', () {
      expect(FormValidators.matchNumber('abc'), 'Match number must be a number');
    });

    test('returns error for 0', () {
      expect(
        FormValidators.matchNumber('0'),
        'Match number must be at least 1',
      );
    });

    test('returns error for value above 200', () {
      expect(
        FormValidators.matchNumber('201'),
        'Match number must be at most 200',
      );
    });

    test('returns null for valid match numbers', () {
      expect(FormValidators.matchNumber('1'), isNull);
      expect(FormValidators.matchNumber('100'), isNull);
      expect(FormValidators.matchNumber('200'), isNull);
    });
  });

  group('FormValidators.teamNumber', () {
    test('returns error for null/empty', () {
      expect(FormValidators.teamNumber(null), 'Team number is required');
      expect(FormValidators.teamNumber(''), 'Team number is required');
    });

    test('returns error for non-numeric value', () {
      expect(FormValidators.teamNumber('abc'), 'Team number must be a number');
    });

    test('returns error for 0', () {
      expect(FormValidators.teamNumber('0'), 'Team number must be at least 1');
    });

    test('returns error for value above 99999', () {
      expect(
        FormValidators.teamNumber('100000'),
        'Team number must be at most 99999',
      );
    });

    test('returns null for valid FRC team numbers', () {
      expect(FormValidators.teamNumber('1'), isNull);
      expect(FormValidators.teamNumber('7461'), isNull);
      expect(FormValidators.teamNumber('9999'), isNull);
    });

    test('returns null for valid FTC team numbers up to 99999', () {
      expect(FormValidators.teamNumber('12345'), isNull);
      expect(FormValidators.teamNumber('99999'), isNull);
    });
  });

  group('FormValidators.eventCode', () {
    test('returns error for null/empty', () {
      expect(FormValidators.eventCode(null), 'Event code is required');
      expect(FormValidators.eventCode(''), 'Event code is required');
      expect(FormValidators.eventCode('   '), 'Event code is required');
    });

    test('returns error for too-short codes', () {
      expect(
        FormValidators.eventCode('abc'),
        'Event code must be 4-20 characters',
      );
    });

    test('returns error for too-long codes', () {
      expect(
        FormValidators.eventCode('a' * 21),
        'Event code must be 4-20 characters',
      );
    });

    test('returns error for non-alphanumeric characters', () {
      expect(
        FormValidators.eventCode('event-2026'),
        'Event code must be letters and digits only',
      );
      expect(
        FormValidators.eventCode('event 2026'),
        'Event code must be letters and digits only',
      );
      expect(
        FormValidators.eventCode('event_2026'),
        'Event code must be letters and digits only',
      );
    });

    test('returns null for valid event codes', () {
      expect(FormValidators.eventCode('2026wila'), isNull);
      expect(FormValidators.eventCode('MICAR'), isNull);
      expect(FormValidators.eventCode('FRC2026'), isNull);
      expect(FormValidators.eventCode('a' * 4), isNull);
      expect(FormValidators.eventCode('a' * 20), isNull);
    });

    test('trims whitespace before validation', () {
      expect(FormValidators.eventCode('  2026wila  '), isNull);
    });
  });

  group('FormValidators.compose', () {
    test('returns first validator error when failing', () {
      final composite = FormValidators.compose([
        (v) => FormValidators.required(v, 'Field'),
        (v) => FormValidators.number(v, min: 1, fieldName: 'Field'),
      ]);
      expect(composite(null), 'Field is required');
    });

    test('returns second validator error when first passes', () {
      final composite = FormValidators.compose([
        (v) => FormValidators.required(v, 'Field'),
        (v) => FormValidators.number(v, min: 10, fieldName: 'Field'),
      ]);
      expect(composite('5'), 'Field must be at least 10');
    });

    test('returns null when all validators pass', () {
      final composite = FormValidators.compose([
        (v) => FormValidators.required(v, 'Field'),
        (v) => FormValidators.number(v, min: 1, max: 100, fieldName: 'Field'),
      ]);
      expect(composite('50'), isNull);
    });

    test('handles empty validator list', () {
      final composite = FormValidators.compose([]);
      expect(composite('anything'), isNull);
    });
  });
}
