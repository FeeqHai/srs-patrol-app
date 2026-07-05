import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/logger.dart';

class IncidentService {
  final String _uploadEndpoint = ApiConstants.buildApiUrl(
    'incidents/upload_incident.php',
  );

  Future<String?> submitReport({
    required String reporterId,
    required String title,
    required String description,
    required String category,
    required String locationName,
    required String reportedTo,
    required List<File> imageFiles,
    required Position? location,
  }) async {
    try {
      var uri = Uri.parse(_uploadEndpoint);
      var request = http.MultipartRequest('POST', uri);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // 1. Generate unique ID for the report
      String incidentId = const Uuid().v4();

      // 2. Attach String Fields
      request.fields['id'] = incidentId;
      request.fields['reported_by'] = reporterId;
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['category'] = category;
      request.fields['location_name'] = locationName;
      request.fields['reported_to'] = reportedTo;
      request.fields['latitude'] = (location?.latitude ?? 0.0).toString();
      request.fields['longitude'] = (location?.longitude ?? 0.0).toString();

      // 3. Attach Binary Images
      for (var file in imageFiles) {
        var pic = await http.MultipartFile.fromPath('images[]', file.path);
        request.files.add(pic);
      }

      appLogger.d(
        '=== MULTIPART INCIDENT REQUEST ===\n'
        'Target URI Hit: $uri\n'
        'Fields: ${request.fields}\n'
        'Image Count: ${request.files.length}\n'
        '=============================',
      );

      // 4. Send and evaluate response
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      appLogger.d(
        '=== RAW MULTIPART NETWORK DATA ===\n'
        'Target URI Hit: ${response.request?.url ?? uri}\n'
        'HTTP Status Code: ${response.statusCode}\n'
        'Raw Body Response: "${response.body}"\n'
        '=============================',
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          return null; // Null means no errors occurred
        } else {
          return responseData['message'];
        }
      } else {
        return "Server Protocol Error: ${response.statusCode}";
      }
    } catch (e, stackTrace) {
      appLogger.e(
        '=== CRITICAL NETWORK EXCEPTION ===\nException: $e\nTarget URI: $_uploadEndpoint\n==================================',
        error: e,
        stackTrace: stackTrace,
      );
      return "Network Exception: Could not reach the command center. Raw error: $e";
    }
  }

  // Fetch all incidents from the backend
  Future<List<dynamic>> fetchAllIncidents({String? patrollerId}) async {
    try {
      String url = ApiConstants.buildApiUrl('incidents/get_incidents.php');
      if (patrollerId != null && patrollerId.isNotEmpty) {
        url += '?user_id=$patrollerId';
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final Map<String, String> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data['data']; // Returns the list of incidents
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e, stackTrace) {
      appLogger.e(
        '=== CRITICAL NETWORK EXCEPTION ===\nException: $e\nTarget URI: ${ApiConstants.buildApiUrl('incidents/get_incidents.php')}\n==================================',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception("Network Exception: $e");
    }
  }
}
