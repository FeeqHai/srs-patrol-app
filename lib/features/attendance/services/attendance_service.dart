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

// Standard boilerplate: Industry-Standard Native Request Flow
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if GPS is enabled at all
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Sila aktifkan perkhidmatan lokasi (GPS) pada peranti anda.');
    }

    // 2. Check permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // THIS is the standard Shopee/TikTok style prompt
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('SRS Patrol memerlukan kebenaran lokasi untuk pengesahan shif.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // This is the only time we mention settings, because the OS locked us out
      throw Exception('Lokasi disekat secara kekal. Sila beri kebenaran di dalam Settings.');
    }

    // 3. Return the position with the hardware kill-switch
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }
}