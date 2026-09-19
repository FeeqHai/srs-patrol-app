import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart'; // INJECTED: The centralized network layer
import '../../../core/utils/logger.dart';
import '../../../core/utils/account_validation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  String? _userId;
  String? _fullName;
  String? _email;
  String? _profileImageUrl;
  String? _role;
  String? _stateId;
  String? _districtId;
  String? _zoneId;
  String? _stateName;
  String? _districtName;
  String? _zoneName;
  bool _mustChangePassword = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get userId => _userId;
  String? get fullName => _fullName;
  String? get email => _email;
  String? get profileImageUrl => _profileImageUrl;
  String? get role => _role;
  String? get stateId => _stateId;
  String? get districtId => _districtId;
  String? get zoneId => _zoneId;
  String? get stateName => _stateName;
  String? get districtName => _districtName;
  String? get zoneName => _zoneName;
  bool get mustChangePassword => _mustChangePassword;
  bool get isAuthenticated => _userId != null;

  AuthProvider() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    _fullName = prefs.getString('user_full_name');
    _email = prefs.getString('user_email');
    _profileImageUrl = prefs.getString('user_profile_image_url');
    _role = prefs.getString('user_role');
    _stateId = prefs.getString('user_state_id');
    _districtId = prefs.getString('user_district_id');
    _zoneId = prefs.getString('user_zone_id');
    _stateName = prefs.getString('user_state_name');
    _districtName = prefs.getString('user_district_name');
    _zoneName = prefs.getString('user_zone_name');
    _mustChangePassword = prefs.getBool('must_change_password') ?? false;
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
        _fullName = data['data']['full_name'] as String?;
        _email = data['data']['email'] as String?;
        _profileImageUrl =
            (data['data']['profile_image_url'] ??
                    data['data']['profileImageUrl'] ??
                    data['data']['profile_image_path'])
                as String?;
        _role = data['data']['role'];
        _stateId = data['data']['state_id'] as String?;
        _districtId = data['data']['district_id'] as String?;
        _zoneId = data['data']['zone_id'] as String?;
        _stateName = data['data']['state_name'] as String?;
        _districtName = data['data']['district_name'] as String?;
        _zoneName = data['data']['zone_name'] as String?;
        _mustChangePassword = _parseMustChangePassword(
          data['data']['must_change_password'],
        );
        final String? token = data['token'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', _userId!);
        await _saveOptionalString(prefs, 'user_full_name', _fullName);
        await _saveOptionalString(prefs, 'user_email', _email);
        await _saveOptionalString(
          prefs,
          'user_profile_image_url',
          _profileImageUrl,
        );
        await prefs.setString('user_role', _role!);
        await _saveOptionalString(prefs, 'user_state_id', _stateId);
        await _saveOptionalString(prefs, 'user_district_id', _districtId);
        await _saveOptionalString(prefs, 'user_zone_id', _zoneId);
        await _saveOptionalString(prefs, 'user_state_name', _stateName);
        await _saveOptionalString(prefs, 'user_district_name', _districtName);
        await _saveOptionalString(prefs, 'user_zone_name', _zoneName);
        await prefs.setBool('must_change_password', _mustChangePassword);
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

      _errorMessage = e is ApiException && e.isUserFacing
          ? e.message
          : 'Tidak dapat menghubungi pelayan. Sila cuba lagi.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_full_name');
    await prefs.remove('user_email');
    await prefs.remove('user_profile_image_url');
    await prefs.remove('user_role');
    await prefs.remove('jwt_token');
    await prefs.remove('user_state_id');
    await prefs.remove('user_district_id');
    await prefs.remove('user_zone_id');
    await prefs.remove('user_state_name');
    await prefs.remove('user_district_name');
    await prefs.remove('user_zone_name');
    await prefs.remove('must_change_password');
    _userId = null;
    _fullName = null;
    _email = null;
    _profileImageUrl = null;
    _role = null;
    _stateId = null;
    _districtId = null;
    _zoneId = null;
    _stateName = null;
    _districtName = null;
    _zoneName = null;
    _mustChangePassword = false;
    notifyListeners();
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final validationError =
        AccountValidation.required(currentPassword) ??
        AccountValidation.password(newPassword);
    if (validationError != null) {
      _errorMessage = validationError;
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await ApiClient.postData('auth/change_password.php', {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
      if (data['status'] == 'success') {
        _mustChangePassword = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('must_change_password', false);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = data['message'] ?? 'Password change failed.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e, stackTrace) {
      appLogger.e(
        '=== PASSWORD CHANGE EXCEPTION ===\nException: $e',
        error: e,
        stackTrace: stackTrace,
      );
      _errorMessage = e is ApiException && e.isUserFacing
          ? e.message
          : 'Tidak dapat menghubungi pelayan. Sila cuba lagi.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfilePhoto(XFile imageFile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final imageUrl = await _authService.uploadProfilePhoto(imageFile);
      _profileImageUrl = imageUrl;
      final prefs = await SharedPreferences.getInstance();
      await _saveOptionalString(
        prefs,
        'user_profile_image_url',
        _profileImageUrl,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      appLogger.e(
        '=== PROFILE PHOTO PROVIDER EXCEPTION ===\nException: $e',
        error: e,
        stackTrace: stackTrace,
      );
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeProfilePhoto() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.removeProfilePhoto();
      _profileImageUrl = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_profile_image_url');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      appLogger.e(
        '=== PROFILE PHOTO REMOVE PROVIDER EXCEPTION ===\nException: $e',
        error: e,
        stackTrace: stackTrace,
      );
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateCurrentUserProfile(UserModel user) async {
    _userId = user.id;
    _fullName = user.fullName;
    _email = user.email;
    _profileImageUrl = user.effectiveProfileImageUrl;
    _role = user.role;
    _stateId = user.stateId;
    _districtId = user.districtId;
    _zoneId = user.zoneId;
    _stateName = user.stateName;
    _districtName = user.districtName;
    _zoneName = user.zoneName;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.id);
    await _saveOptionalString(prefs, 'user_full_name', _fullName);
    await _saveOptionalString(prefs, 'user_email', _email);
    await _saveOptionalString(
      prefs,
      'user_profile_image_url',
      _profileImageUrl,
    );
    await prefs.setString('user_role', _role!);
    await _saveOptionalString(prefs, 'user_state_id', _stateId);
    await _saveOptionalString(prefs, 'user_district_id', _districtId);
    await _saveOptionalString(prefs, 'user_zone_id', _zoneId);
    await _saveOptionalString(prefs, 'user_state_name', _stateName);
    await _saveOptionalString(prefs, 'user_district_name', _districtName);
    await _saveOptionalString(prefs, 'user_zone_name', _zoneName);
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

  bool _parseMustChangePassword(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == '1' || normalized == 'true' || normalized == 'yes';
    }
    return false;
  }
}
