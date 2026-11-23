/// Form validators and normalisers. Messages say what is wrong and how to
/// fix it.
abstract final class Validators {
  /// Normalises a Nigerian mobile number to E.164 (`+234XXXXXXXXXX`).
  ///
  /// Accepts `0803 123 4567`, `803 123 4567`, `2348031234567` and
  /// `+234 803 123 4567`. Nigerian mobile numbers have 10 digits after the
  /// country code and start with 7, 8 or 9. Returns null if invalid.
  static String? normaliseNigerianPhone(String input) {
    var digits = input.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('234')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (!RegExp(r'^[789]\d{9}$').hasMatch(digits)) return null;
    return '+234$digits';
  }

  /// `+2348031234567` → `+234 803 123 4567`.
  static String formatNigerianPhone(String e164) {
    final d = e164.replaceFirst('+234', '');
    if (d.length != 10) return e164;
    return '+234 ${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
  }

  /// `+2348031234567` → `+234 803 *** 4567` (for "we sent a code to…").
  static String maskNigerianPhone(String e164) {
    final d = e164.replaceFirst('+234', '');
    if (d.length != 10) return e164;
    return '+234 ${d.substring(0, 3)} *** ${d.substring(6)}';
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your phone number.';
    }
    if (normaliseNigerianPhone(value) == null) {
      return 'Enter a Nigerian mobile number, e.g. 0803 123 4567.';
    }
    return null;
  }

  static final _email = RegExp(r"^[\w.!#$%&'*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$");

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your email.';
    if (!_email.hasMatch(value.trim())) {
      return 'Enter a valid email, e.g. ada@example.com.';
    }
    return null;
  }

  static String? optionalEmail(String? value) =>
      (value == null || value.trim().isEmpty) ? null : email(value);

  static String? requiredPassword(String? value) =>
      (value == null || value.isEmpty) ? 'Enter your password.' : null;

  /// New passwords: at least 8 characters with a letter and a number.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Create a password.';
    if (value.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your full name.';
    if (v.split(RegExp(r'\s+')).length < 2) {
      return 'Enter your first and last name.';
    }
    if (v.length > 80) return 'Use 80 characters or fewer.';
    return null;
  }
}
