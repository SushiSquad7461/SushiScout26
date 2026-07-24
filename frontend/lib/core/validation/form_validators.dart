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

  /// Validates a team name for team CREATION: must be a team number,
  /// 1-5 digits, no leading zeros (1-99999). Stricter than [teamNumber]
  /// (which allows leading zeros for match-report entry) because a created
  /// team's number is canonical and will later be matched against the
  /// registered-team list.
  static String? teamName(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Team number is required';
    if (!RegExp(r'^[1-9]\d{0,4}$').hasMatch(trimmed)) {
      return 'Team number must be 1-5 digits';
    }
    return null;
  }

  /// Validates event code format (alphanumeric, 4-20 chars)
  static String? eventCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Event code is required';
    }

    final trimmed = value.trim();

    if (trimmed.length < 4 || trimmed.length > 20) {
      return 'Event code must be 4-20 characters';
    }

    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed)) {
      return 'Event code must be letters and digits only';
    }

    return null;
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
