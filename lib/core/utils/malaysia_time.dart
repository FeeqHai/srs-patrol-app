class MalaysiaTime {
  static const Duration _utcOffset = Duration(hours: 8);
  static final RegExp _timezoneSuffix = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false);

  /// Parses MySQL incident timestamps as UTC, then exposes Malaysia's UTC+8 clock values.
  static DateTime fromUtcDatabase(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      throw const FormatException('Missing timestamp');
    }

    final normalized = raw.replaceFirst(' ', 'T');
    final utcValue = _timezoneSuffix.hasMatch(normalized)
        ? normalized
        : '${normalized}Z';
    return DateTime.parse(utcValue).toUtc().add(_utcOffset);
  }

  static DateTime now() => DateTime.now().toUtc().add(_utcOffset);

  static String dateKey(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
