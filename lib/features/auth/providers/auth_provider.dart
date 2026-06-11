import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart'; // INJECTED: The centralized network layer

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  String? _userId;
  String? _role;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get userId => _userId;
  String? get role => _role;
  bool get isAuthenticated => _userId != null;

  AuthProvider() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    _role = prefs.getString('user_role');
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', _userId!);
        await prefs.setString('user_role', _role!);

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
      print('=== LOGIN NETWORK EXCEPTION ===');
      print('Exception: $e');
      print('Stack Trace: $stackTrace');
      
      _errorMessage = "Network Exception: Unable to communicate with the server.";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_role');
    _userId = null;
    _role = null;
    notifyListeners();
  }
}