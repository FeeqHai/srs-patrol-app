// File: lib/features/attendance/services/attendance_service.dart

import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/logger.dart';

class AttendanceService {
  final Uuid _uuid = const Uuid();

  Future<Map<String, dynamic>> clockIn(String userId, String qrPayload) async {
    try {
      Position currentPos = await _determinePosition();
      final String attendanceId = _uuid.v4();
      final Map<String, String> payload = {
        'id': attendanceId,
        'user_id': userId,
        'checkpoint_id': qrPayload,
        'latitude': currentPos.latitude.toString(),
        'longitude': currentPos.longitude.toString(),
      };

      final response = await ApiClient.postData("attendance/clock_in.php", payload);

      if (response['status'] == 'success') {
        return {'success': true, 'attendance_id': response['attendance_id'] ?? attendanceId};
      } else {
        return {'success': false, 'message': response['message']};
      }
    } catch (e, stackTrace) {
      appLogger.e('=== ATTENDANCE HARDWARE/NETWORK EXCEPTION ===\nException: $e', error: e, stackTrace: stackTrace);
      return {'success': false, 'message': "System Exception: $e"};
    }
  }

  Future<Map<String, dynamic>> requestClockOut(
    String qrPayload,
    List<String> returnedEquipmentIds,
  ) async {
    try {
      Position currentPos = await _determinePosition();
      final Map<String, String> payload = {
        'checkpoint_id': qrPayload,
        'latitude': currentPos.latitude.toString(),
        'longitude': currentPos.longitude.toString(),
        'returned_equipment': json.encode(returnedEquipmentIds),
      };

      final response = await ApiClient.postData("attendance/clock_out.php", payload);
      if (response['status'] == 'success') {
        return {'success': true, 'message': response['message']};
      } else {
        return {'success': false, 'message': response['message']};
      }
    } catch (e, stackTrace) {
      appLogger.e('Clock Out Exception', error: e, stackTrace: stackTrace);
      return {'success': false, 'message': 'System Exception: $e'};
    }
  }

  Future<String?> logEquipment(String attendanceId, List<String> equipmentIds) async {
    try {
      final Map<String, String> payload = {
        'attendance_id': attendanceId,
        'equipment': json.encode(equipmentIds),
      };
      final response = await ApiClient.postData("attendance/log_equipment.php", payload);
      if (response['status'] == 'success') {
        return null;
      } else {
        return response['message'];
      }
    } catch (e, stackTrace) {
      appLogger.e('Log Equipment Exception', error: e, stackTrace: stackTrace);
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
