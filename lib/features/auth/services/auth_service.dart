// lib/features/auth/services/auth_service.dart

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/logger.dart';
import '../models/location_option.dart';
import '../models/user_model.dart';

class AuthService {
  // Instantiate the UUID generator
  final Uuid _uuid = const Uuid();

  /// Registers a new patroller.
  /// Returns null if successful, or an error message string if it fails.
  Future<String?> registerPatroller({
    required String fullName,
    required String icNumber, // NEW DATA
    required String phoneNumber, // NEW DATA
    required String stateId,
    required String districtId,
    required String zoneId,
    required String email,
    required String password,
  }) async {
    // 1. Generate the secure v4 UUID locally
    final String newUserId = _uuid.v4();

    // 2. Construct the exact payload expected by the PHP $_POST array
    final Map<String, String> payload = {
      'id': newUserId,
      'full_name': fullName,
      'ic_number': icNumber, // NEW DATA
      'phone_number': phoneNumber, // NEW DATA
      'state_id': stateId,
      'district_id': districtId,
      'zone_id': zoneId,
      'email': email,
      'password': password,
    };

    try {
      // 3. Transmit data via the ApiClient
      final response = await ApiClient.postData(
        ApiConstants.registerEndpoint,
        payload,
      );

      // 4. Evaluate the server's JSON response
      if (response['status'] == 'success') {
        return null; // Registration successful, no errors to report
      } else {
        return response['message']; // Return the specific error from PHP (e.g., duplicate email)
      }
    } catch (e, stackTrace) {
      // 1. Print the exact exception token
      appLogger.e(
        '=== CRITICAL NETWORK EXCEPTION ===\nException: $e\nTarget URI: ${ApiConstants.registerEndpoint}\n==================================',
        error: e,
        stackTrace: stackTrace,
      );

      return "Network Exception: Unable to communicate with the server.";
    }
  }

  Future<List<LocationOption>> fetchLocations({
    required String level,
    String? parentId,
  }) async {
    final endpoint = parentId == null
        ? '${ApiConstants.locationsEndpoint}?level=$level'
        : '${ApiConstants.locationsEndpoint}?level=$level&parent_id=$parentId';
    final response = await ApiClient.getData(endpoint) as Map<String, dynamic>;

    if (response['status'] != 'success') {
      throw Exception(response['message'] ?? 'Unable to load location data.');
    }

    final data = response['data'] as List<dynamic>? ?? const [];
    return data
        .map((item) => LocationOption.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserModel> fetchProfile() async {
    final response = await ApiClient.getData('auth/get_profile.php');
    if (response['status'] != 'success') {
      throw Exception(response['message'] ?? 'Unable to load profile.');
    }

    return UserModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<String> uploadProfilePhoto(XFile imageFile) async {
    final url = Uri.parse(
      ApiConstants.buildApiUrl('auth/update_profile_photo.php'),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final request = http.MultipartRequest('POST', url);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          await imageFile.readAsBytes(),
          filename: imageFile.name,
        ),
      );

      final response = await http.Response.fromStream(await request.send());
      if (response.body.isEmpty) {
        throw Exception(
          'Server returned an empty response. Status Code: ${response.statusCode}',
        );
      }

      final Map<String, dynamic> body;
      try {
        body = json.decode(response.body) as Map<String, dynamic>;
      } on FormatException {
        throw Exception('Server returned an invalid upload response.');
      }

      if (response.statusCode != 200 || body['status'] != 'success') {
        throw Exception(body['message'] ?? 'Profile photo upload failed.');
      }

      final data = body['data'];
      final imageUrl = data is Map<String, dynamic>
          ? data['profile_image_url'] as String?
          : body['profile_image_url'] as String?;
      if (imageUrl == null || imageUrl.trim().isEmpty) {
        throw Exception('Server did not return the profile photo URL.');
      }

      return imageUrl;
    } catch (e, stackTrace) {
      appLogger.e(
        '=== PROFILE PHOTO UPLOAD EXCEPTION ===\nException: $e\nTarget URI: $url',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> removeProfilePhoto() async {
    try {
      final response = await ApiClient.postData(
        'auth/remove_profile_photo.php',
        const {},
      );
      if (response['status'] != 'success') {
        throw Exception(response['message'] ?? 'Profile photo remove failed.');
      }
    } catch (e, stackTrace) {
      appLogger.e(
        '=== PROFILE PHOTO REMOVE EXCEPTION ===\nException: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
