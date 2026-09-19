import 'dart:convert';

/// Shared account-field rules. Keep in sync with config/account_validation.php.
class AccountValidation {
  static const requiredMessage = 'Ruangan ini wajib diisi';
  static const passwordLengthMessage =
      'Kata laluan mesti sekurang-kurangnya 8 aksara.';
  static const passwordTooLongMessage =
      'Kata laluan terlalu panjang. Sila gunakan kurang aksara.';
  static const passwordControlMessage =
      'Kata laluan tidak boleh mengandungi aksara kawalan.';
  static const phoneMessage =
      'Masukkan nombor telefon yang sah bermula dengan 0 atau +60 (9 hingga 11 digit dalam format tempatan).';
  static const icFormatMessage = 'Nombor MyKad mesti mengandungi 12 digit.';
  static const icDateMessage = 'Tarikh lahir dalam nombor MyKad tidak sah.';
  static const confirmMessage = 'Kata laluan tidak sepadan';

  static String? required(String? value) =>
      value == null || value.trim().isEmpty ? requiredMessage : null;

  static String? password(String? value) {
    if (required(value) != null) return requiredMessage;
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(value!)) {
      return passwordControlMessage;
    }
    if (value.runes.length < 8) return passwordLengthMessage;
    // The API stores bcrypt hashes, which only cover the first 72 UTF-8 bytes.
    if (utf8.encode(value).length > 72) return passwordTooLongMessage;
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (required(value) != null) return requiredMessage;
    return value == password ? null : confirmMessage;
  }

  static String normalizePhone(String value) {
    final compact = value.trim().replaceAll(RegExp(r'[ -]'), '');
    if (compact.startsWith('+60')) return '0${compact.substring(3)}';
    if (compact.startsWith('60')) return '0${compact.substring(2)}';
    return compact;
  }

  static String? phone(String? value) {
    if (required(value) != null) return requiredMessage;
    if (!RegExp(r'^(?:\+?60|0)[0-9 -]+$').hasMatch(value!.trim()) ||
        !RegExp(r'^0[1-9][0-9]{7,9}$').hasMatch(normalizePhone(value))) {
      return phoneMessage;
    }
    return null;
  }

  static final _icFormat = RegExp(r'^[0-9]{6}[ -]?[0-9]{2}[ -]?[0-9]{4}$');

  static String normalizeIc(String value) {
    final trimmed = value.trim();
    // Do not silently turn letters or malformed input into a different ID.
    return _icFormat.hasMatch(trimmed)
        ? trimmed.replaceAll(RegExp(r'[ -]'), '')
        : trimmed;
  }

  static String? icNumber(String? value) {
    if (required(value) != null) return requiredMessage;
    final normalized = normalizeIc(value!);
    if (!RegExp(r'^[0-9]{12}$').hasMatch(normalized)) return icFormatMessage;
    // YY has no century: use 2000–2099 for calendar validation only, not age.
    final year = 2000 + int.parse(normalized.substring(0, 2));
    final month = int.parse(normalized.substring(2, 4));
    final day = int.parse(normalized.substring(4, 6));
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return icDateMessage;
    }
    return null;
  }
}
