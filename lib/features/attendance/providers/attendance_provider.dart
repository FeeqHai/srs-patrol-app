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
      final String? errorResult = await _service.clockIn(userId, qrPayload);

      if (errorResult == null) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = errorResult;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      // Differentiate the error type
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
