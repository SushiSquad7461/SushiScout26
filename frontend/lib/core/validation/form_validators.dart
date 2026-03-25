/// Utility class for form validation
class FormValidators {
  /// Validates required fields
  static String? required(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  /// Validates number fields
  static String? number(String? value, {int? min, int? max, String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return null; // Allow empty if not required
    }
    
    final number = int.tryParse(value);
    if (number == null) {
      return '${fieldName ?? 'Value'} must be a number';
    }
    
    if (min != null && number < min) {
      return '${fieldName ?? 'Value'} must be at least $min';
    }
    
    if (max != null && number > max) {
      return '${fieldName ?? 'Value'} must be at most $max';
    }
    
    return null;
  }

  /// Validates match number format (e.g. 1-200)
  static String? matchNumber(String? value) {
    final requiredError = required(value, 'Match number');
    if (requiredError != null) return requiredError;
    
    return number(value, min: 1, max: 200, fieldName: 'Match number');
  }

  /// Validates team number format (e.g. 1-99999, supports FRC and FTC)
  static String? teamNumber(String? value) {
    final requiredError = required(value, 'Team number');
    if (requiredError != null) return requiredError;

    return number(value, min: 1, max: 99999, fieldName: 'Team number');
  }

  /// Combines multiple validators
  static String? Function(String?) compose(List<String? Function(String?)> validators) {
    return (value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }
}
