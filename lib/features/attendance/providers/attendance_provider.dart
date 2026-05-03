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
      await _service.clockIn(userId, qrPayload);
      _isLoading = false;
      notifyListeners();
      return true; // Success
    } catch (e) {
      _isLoading = false;
      // Clean up the error message for the UI
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false; // Failed
    }
  }
}