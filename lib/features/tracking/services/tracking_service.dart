import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';

class TrackingService {
  final String _sosEndpoint = '${ApiConstants.baseUrl}tracking/sos_alert.php';

  Future<String?> sendSosAlert({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse(_sosEndpoint),
        headers: headers,
        body: json.encode({
          'user_id': userId,
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return null; // Null means success
        } else {
          return data['message'] ?? 'Ralat pelayan.';
        }
      } else {
        return 'Server Error: ${response.statusCode}';
      }
    } catch (e) {
      return 'Network Exception: Sila pastikan sambungan internet anda aktif.';
    }
  }
}
