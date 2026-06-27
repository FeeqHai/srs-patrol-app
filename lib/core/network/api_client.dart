import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../utils/logger.dart';

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
      // 1. INJECT THIS DEBUG LINE:
      appLogger.d(
        '=== RAW HTTP NETWORK DATA ===\nTarget URI Hit: ${response.request?.url}\nHTTP Status Code: ${response.statusCode}\nRaw Body Response: "${response.body}"\n=============================',
      );
      // Prevent the crash if the server returns a blank response
      if (response.body.isEmpty) {
        throw Exception(
          "Server returned a completely blank response. Status Code: ${response.statusCode}",
        );
      }
      // 200 means "OK" from the server
      if (response.statusCode == 200) {
        // We expect our PHP scripts to always return JSON (e.g., {"status": "success", "message": "..."})
        return json.decode(response.body);
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e, stackTrace) {
      appLogger.e(
        '=== CRITICAL NETWORK EXCEPTION ===\nException: $e\nTarget URI: $url\n==================================',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception("Network connection failed: $e");
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

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e, stackTrace) {
      appLogger.e(
        '=== CRITICAL NETWORK EXCEPTION ===\nException: $e\nTarget URI: $url\n==================================',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception("Network connection failed: $e");
    }
  }
}
