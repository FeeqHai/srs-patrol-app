// File: lib/features/attendance/providers/attendance_provider.dart
import 'package:flutter/material.dart';
import '../services/attendance_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _service = AttendanceService();
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> processQrScan(String userId, String qrPayload) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // The service returns a String error message if PHP fails, or null if successful.
      final String? errorResult = await _service.clockIn(userId, qrPayload);

      if (errorResult == null) {
        _isLoading = false;
        notifyListeners();
        return true; // Complete Success
      } else {
        _isLoading = false;
        _errorMessage =
            errorResult; // Extract the specific PHP error (e.g., parameter mismatch)
        notifyListeners();
        return false; // Logic Failure
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false; // Network Crash
    }
  }
}
