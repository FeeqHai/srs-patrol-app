// File: lib/features/attendance/providers/attendance_provider.dart
import 'package:flutter/material.dart';
import '../services/attendance_service.dart';
import '../../../core/network/api_client.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _service = AttendanceService();
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastAttendanceId;
  List<dynamic> _availableEquipment = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get lastAttendanceId => _lastAttendanceId;
  List<dynamic> get availableEquipment => _availableEquipment;

  Future<bool> processQrScan(String userId, String qrPayload) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> result = await _service.clockIn(userId, qrPayload);

      if (result['success'] == true) {
        _lastAttendanceId = result['attendance_id'];
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Differentiate the error type
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchEquipment() async {
    try {
      final response = await ApiClient.getData('equipment/get_inventory.php');
      if (response['success'] == true) {
        _availableEquipment = response['data'] ?? [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching equipment: $e");
    }
  }

  Future<bool> submitEquipmentSelection(List<String> equipmentIds) async {
    if (_lastAttendanceId == null) return false;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final String? errorResult = await _service.logEquipment(_lastAttendanceId!, equipmentIds);
      
      _isLoading = false;
      notifyListeners();
      return errorResult == null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> clockOut(String userId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final String? errorResult = await _service.clockOut(userId);
      _isLoading = false;
      notifyListeners();
      return errorResult == null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
