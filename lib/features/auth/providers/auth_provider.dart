// File: lib/features/auth/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Tells the UI to show a loading spinner

    try {
      String? currentUserId;
      _isLoading = false;
      notifyListeners();
      return true; // Login success
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners(); // Tells the UI to stop loading and show error
      return false; // Login failed
    }
  }

  Future<void> logout() async {

  }
}