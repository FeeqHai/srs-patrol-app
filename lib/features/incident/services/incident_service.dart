import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/api_constants.dart';

class IncidentService {
  final String _uploadEndpoint = ApiConstants.baseUrl + 'incidents/upload_incident.php';

  Future<String?> submitReport({
    required String reporterId,
    required String title,
    required String description,
    required String category,
    required File imageFile,
    required Position location,
  }) async {
    try {
      var uri = Uri.parse(_uploadEndpoint);
      var request = http.MultipartRequest('POST', uri);

      // 1. Generate unique ID for the report
      String incidentId = const Uuid().v4();

      // 2. Attach String Fields
      request.fields['id'] = incidentId;
      request.fields['reported_by'] = reporterId;
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['category'] = category;
      request.fields['latitude'] = location.latitude.toString();
      request.fields['longitude'] = location.longitude.toString();

      // 3. Attach Binary Image
      var pic = await http.MultipartFile.fromPath('image', imageFile.path);
      request.files.add(pic);

      // 4. Send and evaluate response
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

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
    } catch (e) {
      return "Network Exception: Could not reach the command center.";
    }
  }
}