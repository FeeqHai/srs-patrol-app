// lib/features/auth/services/auth_service.dart

import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/logger.dart';
import '../models/location_option.dart';

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
}
