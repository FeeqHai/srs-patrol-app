class ApiConstants {
  // Current development server address for the physical Android device.
  // Override this at run/build time when the laptop changes Wi-Fi networks:
  // flutter run --dart-define=SRS_API_BASE_URL=http://<laptop-ip>/srs_api/
  static const String _defaultBaseUrl = "http://10.131.73.229/srs_api/";
  static const String _configuredBaseUrl = String.fromEnvironment(
    'SRS_API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static String get baseUrl {
    final trimmed = _configuredBaseUrl.trim();
    final normalized = trimmed.isEmpty ? _defaultBaseUrl : trimmed;
    return normalized.endsWith('/') ? normalized : '$normalized/';
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
      return '$baseUrl${uri.path.substring(uploadIndex + 1)}';
    }

    return '$baseUrl${value.replaceFirst(RegExp(r'^/+'), '')}';
  }

  static const String loginEndpoint = "auth/login.php";
  static const String registerEndpoint = "auth/register.php";
  static const String locationsEndpoint = "auth/get_locations.php";
  static const String getIncidentsEndpoint = "incidents/get_incidents.php";
  static const String uploadIncidentEndpoint = "incidents/upload_incident.php";
}
