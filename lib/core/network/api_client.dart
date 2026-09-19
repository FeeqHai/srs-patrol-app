import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../utils/logger.dart';

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.isUserFacing = false,
  });

  final String message;
  final int? statusCode;
  final bool isUserFacing;

  @override
  String toString() => message;
}

class ApiClient {
  /// Sends a POST request to your PHP server.
  /// Used for Logging in, Registering, and sending text data.
  static Future<Map<String, dynamic>> postData(
    String endpoint,
    Map<String, String> body,
  ) async {
    final url = Uri.parse(ApiConstants.buildApiUrl(endpoint));

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final Map<String, String> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // http.post automatically encodes Map<String, String> so PHP's $_POST can read it
      final response = await http.post(url, headers: headers, body: body);
      // Never log request/response bodies here. Authentication responses can
      // contain JWTs and registration responses can contain one-time tokens.
      appLogger.d('HTTP POST completed: ${url.path} (${response.statusCode})');
      return _handleMapResponse(response);
    } on ApiException catch (e, stackTrace) {
      appLogger.e(
        '=== CRITICAL NETWORK EXCEPTION ===\nException: $e\nTarget URI: $url\n==================================',
        error: e,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(e, stackTrace);
    } catch (e, stackTrace) {
      appLogger.e(
        '=== CRITICAL NETWORK EXCEPTION ===\nException: $e\nTarget URI: $url\n==================================',
        error: e,
        stackTrace: stackTrace,
      );
      throw ApiException("Network connection failed: $e");
    }
  }

  /// Sends a GET request.
  /// Used for pulling the feed of incidents.
  static Future<dynamic> getData(String endpoint) async {
    final url = Uri.parse(ApiConstants.buildApiUrl(endpoint));

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final Map<String, String> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(url, headers: headers);

      return _handleJsonResponse(response);
    } on ApiException catch (e, stackTrace) {
      appLogger.e(
        '=== CRITICAL NETWORK EXCEPTION ===\nException: $e\nTarget URI: $url\n==================================',
        error: e,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(e, stackTrace);
    } catch (e, stackTrace) {
      appLogger.e(
        '=== CRITICAL NETWORK EXCEPTION ===\nException: $e\nTarget URI: $url\n==================================',
        error: e,
        stackTrace: stackTrace,
      );
      throw ApiException("Network connection failed: $e");
    }
  }

  static Map<String, dynamic> _handleMapResponse(http.Response response) {
    _throwIfBlankResponse(response);
    if (_isSuccessfulStatus(response.statusCode)) {
      final decoded = _decodeJsonBody(
        response.body,
        statusCode: response.statusCode,
      );
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      throw ApiException(
        _cleanNonJsonResponse(response.body),
        statusCode: response.statusCode,
      );
    }

    throw _responseException(response);
  }

  static dynamic _handleJsonResponse(http.Response response) {
    _throwIfBlankResponse(response);
    if (_isSuccessfulStatus(response.statusCode)) {
      return _decodeJsonBody(response.body, statusCode: response.statusCode);
    }

    throw _responseException(response);
  }

  static ApiException _responseException(http.Response response) {
    // Only structured client errors are safe to display as form feedback.
    // HTML error pages, transport failures and server errors stay generic.
    if (response.statusCode >= 400 && response.statusCode < 500) {
      try {
        final decoded = json.decode(response.body);
        final message = decoded is Map
            ? decoded['message'] ?? decoded['error']
            : null;
        if (message is String && message.trim().isNotEmpty) {
          return ApiException(
            message.trim(),
            statusCode: response.statusCode,
            isUserFacing: true,
          );
        }
      } on FormatException {
        // Fall through to the diagnostic message for logs.
      }
    }
    return ApiException(
      _extractServerMessage(response),
      statusCode: response.statusCode,
    );
  }

  static bool _isSuccessfulStatus(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  static void _throwIfBlankResponse(http.Response response) {
    if (response.body.isNotEmpty) return;
    throw ApiException(
      'Server returned a completely blank response. Status Code: ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  static dynamic _decodeJsonBody(String body, {int? statusCode}) {
    try {
      return json.decode(body);
    } on FormatException {
      throw ApiException(_cleanNonJsonResponse(body), statusCode: statusCode);
    }
  }

  static String _extractServerMessage(http.Response response) {
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map) {
        final message = decoded['message'] ?? decoded['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString().trim();
        }
      }
    } on FormatException {
      return _cleanNonJsonResponse(response.body);
    }

    return 'Server Error: ${response.statusCode}';
  }

  static String _cleanNonJsonResponse(String body) {
    final withoutTags = body
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (withoutTags.isEmpty) {
      return 'Server returned an invalid non-JSON response.';
    }
    return 'Server returned an invalid response: $withoutTags';
  }
}
