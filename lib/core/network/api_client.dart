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
      print("=== RAW SERVER RESPONSE ===");
      print(response.body);
      print("===========================");
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
