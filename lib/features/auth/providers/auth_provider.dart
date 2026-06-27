import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart'; // INJECTED: The centralized network layer
import '../../../core/utils/logger.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  String? _userId;
  String? _role;
  String? _stateName;
  String? _districtName;
  String? _zoneName;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get userId => _userId;
  String? get role => _role;
  String? get stateName => _stateName;
  String? get districtName => _districtName;
  String? get zoneName => _zoneName;
  bool get isAuthenticated => _userId != null;

  AuthProvider() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    _role = prefs.getString('user_role');
    _stateName = prefs.getString('user_state_name');
    _districtName = prefs.getString('user_district_name');
    _zoneName = prefs.getString('user_zone_name');
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Construct the POST payload
      final Map<String, String> payload = {
        'email': email,
        'password': password,
      };

      // 2. Transmit via ApiClient (This prevents the malformed URL crash)
      final data = await ApiClient.postData(
        ApiConstants.loginEndpoint,
        payload,
      );

      // 3. Evaluate the validated JSON response
      if (data['status'] == 'success') {
        _userId = data['data']['id'];
        _role = data['data']['role'];
        _stateName = data['data']['state_name'] as String?;
        _districtName = data['data']['district_name'] as String?;
        _zoneName = data['data']['zone_name'] as String?;
        final String? token = data['token'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', _userId!);
        await prefs.setString('user_role', _role!);
        await _saveOptionalString(prefs, 'user_state_name', _stateName);
        await _saveOptionalString(prefs, 'user_district_name', _districtName);
        await _saveOptionalString(prefs, 'user_zone_name', _zoneName);
        if (token != null) {
          await prefs.setString('jwt_token', token);
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'Authentication failed.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e, stackTrace) {
      // 4. Expose the raw exception to the IDE console for engineering review
      appLogger.e(
        '=== LOGIN NETWORK EXCEPTION ===\nException: $e',
        error: e,
        stackTrace: stackTrace,
      );

      _errorMessage =
          "Network Exception: Unable to communicate with the server.";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.remove('jwt_token');
    await prefs.remove('user_state_name');
    await prefs.remove('user_district_name');
    await prefs.remove('user_zone_name');
    _userId = null;
    _role = null;
    _stateName = null;
    _districtName = null;
    _zoneName = null;
    notifyListeners();
  }

  Future<void> _saveOptionalString(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null || value.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }
}
