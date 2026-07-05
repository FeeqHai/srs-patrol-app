// File: lib/features/attendance/providers/attendance_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/attendance_service.dart';
import '../../../core/network/api_client.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _service = AttendanceService();
  bool _isLoading = false;
  bool _isRequestingClockOut = false;
  String? _errorMessage;
  String? _lastAttendanceId;
  String _returnStatus = 'ready';
  DateTime? _clockInTime;
  String? _checkpointId;
  String? _pendingAcknowledgementMessage;
  List<dynamic> _availableEquipment = [];
  List<dynamic> _borrowedEquipment = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get lastAttendanceId => _lastAttendanceId;
  String get returnStatus => _returnStatus;
  DateTime? get clockInTime => _clockInTime;
  String? get checkpointId => _checkpointId;
  String? get pendingAcknowledgementMessage =>
      _normalizePendingMessage(_pendingAcknowledgementMessage);
  bool get hasServerShift =>
      _returnStatus == 'active' || _returnStatus == 'pending_acknowledgement';
  bool get isPendingAcknowledgement =>
      _returnStatus == 'pending_acknowledgement';
  List<dynamic> get availableEquipment => _availableEquipment;
  List<dynamic> get borrowedEquipment => _borrowedEquipment;
  List<String> get borrowedEquipmentNames => _borrowedEquipment
      .map((equipment) {
        if (equipment is Map) {
          return (equipment['item_name'] ?? equipment['name'] ?? '').toString();
        }
        return equipment.toString();
      })
      .where((name) => name.isNotEmpty)
      .toList();

  String? _normalizePendingMessage(String? message) {
    if (message == null) return null;
    if (message.contains('Ketua KRT') && !message.contains('Ketua Peronda')) {
      return 'Pemulangan anda telah dihantar. Sila tunggu Ketua Peronda atau Ketua KRT mengesahkan penerimaan peralatan.';
    }
    return message;
  }

  Future<void> syncActiveShiftFromServer() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _service.checkActiveShift();
      if (response['status'] != 'success') {
        _errorMessage = response['message'] ?? 'Unable to sync attendance.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final bool hasActiveShift = response['has_active_shift'] == true;
      if (!hasActiveShift) {
        await _clearShiftCache();
        _lastAttendanceId = null;
        _returnStatus = 'ready';
        _clockInTime = null;
        _checkpointId = null;
        _pendingAcknowledgementMessage = null;
        _borrowedEquipment = [];
      } else {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        _lastAttendanceId = data['attendance_id']?.toString();
        _returnStatus = data['return_status']?.toString() ?? 'active';
        _clockInTime = DateTime.tryParse(
          data['clock_in_time']?.toString() ?? '',
        );
        _checkpointId = data['checkpoint_id']?.toString();
        _pendingAcknowledgementMessage = data['pending_acknowledgement']
            ?.toString();
        _borrowedEquipment = _toEquipmentList(
          data['borrowed_equipment'] ?? data['equipment'] ?? [],
        );
        await _cacheServerShift();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> processQrScan(String userId, String qrPayload) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> result = await _service.clockIn(
        userId,
        qrPayload,
      );

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
      if (response['status'] == 'success') {
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
      final String? errorResult = await _service.logEquipment(
        _lastAttendanceId!,
        equipmentIds,
      );
      if (errorResult == null) {
        await syncActiveShiftFromServer();
        return true;
      }

      _errorMessage = errorResult;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> fetchBorrowedEquipment() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiClient.getData(
        'attendance/get_return_preview.php',
      );
      if (response['status'] == 'success') {
        _borrowedEquipment = response['equipment'] ?? [];
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage =
          response['message'] ?? 'Unable to load borrowed equipment.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> requestClockOut(
    String qrPayload,
    List<String> returnedEquipmentIds,
  ) async {
    if (_isRequestingClockOut) return false;

    _isRequestingClockOut = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.requestClockOut(
        qrPayload,
        returnedEquipmentIds,
      );
      if (result['success'] == true) {
        _returnStatus = 'pending_acknowledgement';
        _pendingAcknowledgementMessage =
            'Pemulangan anda telah dihantar. Sila tunggu Ketua Peronda atau Ketua KRT mengesahkan penerimaan peralatan.';
        await syncActiveShiftFromServer();
        _isRequestingClockOut = false;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = result['message'];
      _isRequestingClockOut = false;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isRequestingClockOut = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  List<dynamic> _toEquipmentList(dynamic value) {
    if (value is List) {
      return value;
    }
    return [];
  }

  String _cleanCheckpoint(String? checkpoint) {
    final rawCheckpoint = checkpoint ?? '';
    if (rawCheckpoint.isEmpty ||
        rawCheckpoint.startsWith('SRS_ATTENDANCE') ||
        rawCheckpoint.contains('|')) {
      return 'Pos Utama KRT';
    }
    return rawCheckpoint;
  }

  Future<void> _cacheServerShift() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shiftActive', hasServerShift);
    if (!hasServerShift) {
      await _clearShiftCache();
      return;
    }

    await prefs.setString('activeAttendanceId', _lastAttendanceId ?? '');
    await prefs.setString('attendanceReturnStatus', _returnStatus);
    await prefs.setString('activeCheckpoint', _cleanCheckpoint(_checkpointId));
    if (_clockInTime != null) {
      await prefs.setString('shiftStartTime', _clockInTime!.toIso8601String());
    }
    await prefs.setStringList('activeEquipment', borrowedEquipmentNames);
    final pendingMessage = pendingAcknowledgementMessage;
    if (pendingMessage != null) {
      await prefs.setString('pendingAcknowledgementMessage', pendingMessage);
    } else {
      await prefs.remove('pendingAcknowledgementMessage');
    }
  }

  Future<void> _clearShiftCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('shiftActive');
    await prefs.remove('activeAttendanceId');
    await prefs.remove('attendanceReturnStatus');
    await prefs.remove('activeCheckpoint');
    await prefs.remove('activeLocation');
    await prefs.remove('shiftStartTime');
    await prefs.remove('activeEquipment');
    await prefs.remove('pendingAcknowledgementMessage');
  }
}
