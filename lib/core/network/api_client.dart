import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ApiClient {
  /// Sends a POST request to your PHP server.
  /// Used for Logging in, Registering, and sending text data.
  static Future<Map<String, dynamic>> postData(
    String endpoint,
    Map<String, String> body,
  ) async {
    final url = Uri.parse(ApiConstants.baseUrl + endpoint);

    try {
      // http.post automatically encodes Map<String, String> so PHP's $_POST can read it
      final response = await http.post(url, body: body);
      // 1. INJECT THIS DEBUG LINE:
      print('=== RAW HTTP NETWORK DATA ===');
      print('Target URI Hit: ${response.request?.url}');
      print('HTTP Status Code: ${response.statusCode}');
      print('Raw Body Response: "${response.body}"');
      print('=============================');
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
    } catch (e) {
      throw Exception("Network connection failed: $e");
    }
  }

  /// Sends a GET request.
  /// Used for pulling the feed of incidents.
  static Future<dynamic> getData(String endpoint) async {
    final url = Uri.parse(ApiConstants.baseUrl + endpoint);

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Network connection failed: $e");
    }
  }
}
