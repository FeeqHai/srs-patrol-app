// File: lib/features/attendance/services/attendance_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';


class AttendanceService {
  final Uuid _uuid = const Uuid();

  // The primary clock-in function
  Future<String?> clockIn(String userId, String qrPayload) async {
    try {
      // 1. Get the live GPS coordinates
      Position currentPos = await _determinePosition();

      // 2. Generate local Primary Key
      final String attendanceId = _uuid.v4();

      // 3. Construct the Payload
      final Map<String, String> payload = {
        'id': attendanceId,
        'user_id': userId,
        'qr_data': qrPayload,
        'latitude': currentPos.latitude.toString(),
        'longitude': currentPos.longitude.toString(),
        // Note: PHP should generate the exact 'clock_in_time' timestamp upon receipt to prevent client-side time manipulation.
      };

      // 4. Transmit to Server via ApiClient
      // Ensure 'attendance/clock_in.php' is added to ApiConstants
      final response = await ApiClient.postData("attendance/clock_in.php", payload);

      if (response['status'] == 'success') {
        return null; // Clock-in successful
      } else {
        return response['message']; // Return specific PHP error
      }
    } catch (e) {
      return "Clock-In Exception: $e";
    }
  }

  // Standard boilerplate to request GPS permissions from the user
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services are disabled. Please turn on GPS.');

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
    );
  }
}