// File: lib/features/attendance/services/attendance_service.dart

import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';

class AttendanceService {
  final Uuid _uuid = const Uuid();

  Future<String?> clockIn(String userId, String qrPayload) async {
    try {
      // 1. Hardware Interrogation: Bounded Execution
      Position currentPos = await _determinePosition();

      // 2. Cryptographic Generation: Local Primary Key
      final String attendanceId = _uuid.v4();

      // 3. Payload Construction: Strict Backend Alignment
      final Map<String, String> payload = {
        'id': attendanceId,
        'user_id': userId,
        'checkpoint_id': qrPayload, // FIXED: Aligned with $_POST['checkpoint_id']
        'latitude': currentPos.latitude.toString(),
        'longitude': currentPos.longitude.toString(),
      };

      // 4. Network Transmission
      final response = await ApiClient.postData("attendance/clock_in.php", payload);

      // 5. Evaluation Phase
      if (response['status'] == 'success') {
        return null; // Pipeline successful
      } else {
        return response['message']; // Explicit failure output
      }
    } catch (e, stackTrace) {
      // Diagnostic Exposure
      print('=== ATTENDANCE HARDWARE/NETWORK EXCEPTION ===');
      print('Exception: $e');
      print('Stack Trace: $stackTrace');
      print('=============================================');
      return "System Exception: $e";
    }
  }

  // Hardware Authorization and Extraction
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please activate GPS hardware.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are restricted by the user.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently locked by the OS.');
    }

    // INJECTED: The hardware safety kill-switch (10-second absolute limit)
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }
}