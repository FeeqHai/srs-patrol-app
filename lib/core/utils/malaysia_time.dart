class MalaysiaTime {
  static const Duration _utcOffset = Duration(hours: 8);
  static final RegExp _timezoneSuffix = RegExp(
    r'(Z|[+-]\d{2}:?\d{2})$',
    caseSensitive: false,
  );

  /// Parses incident timestamps for Malaysia calendar display.
  ///
  /// XAMPP/MySQL rows in this project are stored as local Malaysia timestamps
  /// without a timezone suffix. Only explicitly zoned timestamps are converted.
  static DateTime fromUtcDatabase(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      throw const FormatException('Missing timestamp');
    }

    final normalized = raw.replaceFirst(' ', 'T');
    if (!_timezoneSuffix.hasMatch(normalized)) {
      return DateTime.parse(normalized);
    }
    return DateTime.parse(normalized).toUtc().add(_utcOffset);
  }

  static DateTime now() => DateTime.now().toUtc().add(_utcOffset);

  static String dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
