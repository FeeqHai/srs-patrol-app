class ApiConstants {
  // Production/demo API on DigitalOcean. Override only when explicitly testing
  // another backend, for example local XAMPP:
  // flutter run --dart-define=SRS_API_BASE_URL=http://<laptop-ip>/srs_api/
  static const String _defaultBaseUrl = "http://157.245.53.82/srs_api/";
  static const String _configuredBaseUrl = String.fromEnvironment(
    'SRS_API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static String get baseUrl {
    final trimmed = _configuredBaseUrl.trim();
    final normalized = trimmed.isEmpty ? _defaultBaseUrl : trimmed;
    return '${normalized.replaceFirst(RegExp(r'/+$'), '')}/';
  }

  /// Joins the configured API base and an endpoint with exactly one slash.
  static String buildApiUrl(String endpoint) {
    final rawEndpoint = endpoint.trim();
    final queryIndex = rawEndpoint.indexOf('?');
    final path = queryIndex == -1
        ? rawEndpoint
        : rawEndpoint.substring(0, queryIndex);
    final query = queryIndex == -1 ? '' : rawEndpoint.substring(queryIndex);
    final normalizedPath = path
        .replaceAll(RegExp(r'/+'), '/')
        .replaceFirst(RegExp(r'^/+'), '');
    return '$baseUrl$normalizedPath$query';
  }

  /// Resolves portable upload paths and legacy upload URLs against the
  /// configured API host, keeping images valid after backend deployment.
  static String? resolveUploadUrl(String? rawPath) {
    final value = rawPath?.trim() ?? '';
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      final uploadIndex = uri.path.indexOf('/uploads/');
      if (uploadIndex == -1) return value;
      return buildApiUrl(uri.path.substring(uploadIndex + 1));
    }

    return buildApiUrl(value);
  }

  static const String loginEndpoint = "auth/login.php";
  static const String registerEndpoint = "auth/register.php";
  static const String locationsEndpoint = "auth/get_locations.php";
  static const String getIncidentsEndpoint = "incidents/get_incidents.php";
  static const String uploadIncidentEndpoint = "incidents/upload_incident.php";
}
