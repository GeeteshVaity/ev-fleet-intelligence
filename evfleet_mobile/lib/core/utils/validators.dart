/// Reusable, framework-free form validators.
///
/// Every function returns `null` when the input is valid and a
/// user-presentable message otherwise, so they can be plugged directly into
/// `TextFormField.validator` and unit-tested without Flutter.
abstract final class Validators {
  static final RegExp _email = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@"
    r"[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
    r"(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  /// Accepts a syntactically valid email address.
  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required';
    if (!_email.hasMatch(text)) return 'Enter a valid email address';
    return null;
  }

  /// Passwords must be at least 8 characters and contain a letter + a digit.
  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (text.length < 8) return 'Use at least 8 characters';
    final hasLetter = text.contains(RegExp('[A-Za-z]'));
    final hasDigit = text.contains(RegExp('[0-9]'));
    if (!hasLetter || !hasDigit) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  /// Confirms the confirmation field matches the password.
  static String? confirmPassword(String? value, String password) {
    final text = value ?? '';
    if (text.isEmpty) return 'Please confirm your password';
    if (text != password) return 'Passwords do not match';
    return null;
  }

  /// Required text field with a minimum length.
  static String? text(
    String? value, {
    String label = 'This field',
    int min = 2,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '$label is required';
    if (text.length < min) {
      return '$label must be at least $min characters';
    }
    return null;
  }

  /// Full name: at least two characters and two words preferred.
  static String? fullName(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Full name is required';
    if (text.length < 2) return 'Enter your full name';
    if (!text.contains(' ')) return 'Enter first and last name';
    return null;
  }

  /// Required numeric value inside an inclusive range.
  static String? numberInRange(
    String? value, {
    required double min,
    required double max,
    required String label,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '$label is required';
    final parsed = num.tryParse(text.replaceAll(',', '.'));
    if (parsed == null) return '$label must be a number';
    if (parsed < min || parsed > max) {
      final minLabel = min == min.roundToDouble() ? min.round() : min;
      final maxLabel = max == max.roundToDouble() ? max.round() : max;
      return '$label must be between $minLabel and $maxLabel';
    }
    return null;
  }

  /// Optional numeric field, only validated when filled in.
  static String? optionalNumber(
    String? value, {
    required double min,
    required double max,
    required String label,
  }) {
    if ((value ?? '').trim().isEmpty) return null;
    return numberInRange(value, min: min, max: max, label: label);
  }

  /// Optional registration/plate number.
  static String? optionalRegistration(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (text.length < 4) return 'Registration number looks too short';
    return null;
  }

  /// Numeric verification code of a fixed length.
  static String? verificationCode(String? value, {int length = 6}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter the verification code';
    if (text.length != length || int.tryParse(text) == null) {
      return 'Enter the $length-digit code';
    }
    return null;
  }

  /// Required field that must match one of the allowed choices.
  static String? requiredChoice<T>(T? value, {required String label}) {
    if (value == null) return 'Select a $label';
    return null;
  }
}
