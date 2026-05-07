// lib/features/auth/services/auth_service.dart

import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';

class AuthService {
  // Instantiate the UUID generator
  final Uuid _uuid = const Uuid();

  /// Registers a new patroller.
  /// Returns null if successful, or an error message string if it fails.
  Future<String?> registerPatroller({
    required String fullName,
    required String email,
    required String password,
  }) async {

    // 1. Generate the secure v4 UUID locally
    final String newUserId = _uuid.v4();

    // 2. Construct the exact payload expected by the PHP $_POST array
    final Map<String, String> payload = {
      'id': newUserId,
      'full_name': fullName,
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

    } catch (e) {
      // Catch network timeouts or malformed JSON
      return "Network Exception: Unable to communicate with the server. $e";
    }
  }
}