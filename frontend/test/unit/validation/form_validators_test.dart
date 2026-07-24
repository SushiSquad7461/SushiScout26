import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/validation/form_validators.dart';

void main() {
  group('FormValidators.teamName', () {
    test('accepts 1-5 digit team numbers', () {
      expect(FormValidators.teamName('1'), isNull);
      expect(FormValidators.teamName('254'), isNull);
      expect(FormValidators.teamName('1114'), isNull);
      expect(FormValidators.teamName('99999'), isNull);
      expect(FormValidators.teamName('  254  '), isNull); // trimmed
    });

    test('rejects empty / whitespace with the required message', () {
      expect(FormValidators.teamName(''), 'Team number is required');
      expect(FormValidators.teamName(null), 'Team number is required');
      expect(FormValidators.teamName('   '), 'Team number is required');
    });

    test('rejects non-numeric, too-long, zero, and leading-zero values', () {
      expect(FormValidators.teamName('abc'), 'Team number must be 1-5 digits');
      expect(FormValidators.teamName('12a'), 'Team number must be 1-5 digits');
      expect(FormValidators.teamName('0'), 'Team number must be 1-5 digits');
      expect(FormValidators.teamName('00042'), 'Team number must be 1-5 digits');
      expect(FormValidators.teamName('123456'), 'Team number must be 1-5 digits');
    });
  });
}
