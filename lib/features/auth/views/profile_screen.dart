import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../../../core/utils/logger.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  bool _isLoading = true;
  String? _error;
  bool _isUploadingImage = false;
  String? _profileImagePath;
  int _profileImageVersion = 0;
  String? _lastLoggedProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;

    final settings = context.read<SettingsProvider>();

    if (userId == null) {
      setState(() {
        _error = settings.t("Sesi tamat. Sila log masuk semula.");
        _isLoading = false;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final Map<String, String> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse(ApiConstants.buildApiUrl('auth/get_profile.php')),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        if (body['status'] == 'success') {
          setState(() {
            _user = UserModel.fromJson(body['data']);
            final fetchedImagePath = _user!.profileImagePath;
            if (fetchedImagePath != null && fetchedImagePath.isNotEmpty) {
              _profileImagePath = fetchedImagePath;
            }
            _isLoading = false;
          });
        } else {
          setState(() {
            _error =
                body['message'] ?? settings.t('Gagal memuat turun profil.');
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = '${settings.t('Ralat Pelayan')}: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      appLogger.e(
        "=== CRITICAL NETWORK EXCEPTION ===\nException: $e\nTarget URI: ${ApiConstants.buildApiUrl('auth/get_profile.php')}\n==================================",
        error: e,
        stackTrace: stackTrace,
      );
      setState(() {
        _error = settings.t('Ralat Rangkaian');
        _isLoading = false;
      });
    }
  }

  Future<void> _chooseProfileImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil gambar'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (image == null || !mounted) return;

    setState(() => _isUploadingImage = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.buildApiUrl('auth/upload_profile_image.php')),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          await image.readAsBytes(),
          filename: image.name,
        ),
      );

      final response = await http.Response.fromStream(await request.send());
      final body = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['status'] != 'success') {
        throw Exception(body['message'] ?? 'Gagal memuat naik gambar profil.');
      }
      final updatedPath = body['profile_image_path'] as String?;
      if (updatedPath == null || updatedPath.isEmpty) {
        throw Exception('Pelayan tidak memulangkan gambar profil.');
      }
      setState(() {
        _profileImagePath = updatedPath;
        _profileImageVersion = DateTime.now().millisecondsSinceEpoch;
      });
      await _fetchProfile();
    } catch (error, stackTrace) {
      appLogger.e(
        'Profile image upload failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memuat naik gambar profil. Sila cuba semula.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  String? _resolvedProfileImageUrl() {
    final imageUrl = ApiConstants.resolveUploadUrl(
      _profileImagePath ?? _user?.profileImagePath,
    );
    if (imageUrl == null) return null;

    final displayUrl = '$imageUrl?v=$_profileImageVersion';
    if (displayUrl != _lastLoggedProfileImageUrl) {
      _lastLoggedProfileImageUrl = displayUrl;
      debugPrint('Loading profile image: $displayUrl');
    }
    return displayUrl;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchProfile,
              child: Text(settings.t('Cuba Semula')),
            ),
          ],
        ),
      );
    }

    if (_user == null) {
      return Center(
        child: Text(
          settings.t("Tiada data profil"),
          style: const TextStyle(fontSize: 16),
        ),
      );
    }

    final profileImageUrl = _resolvedProfileImageUrl();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: profileImageUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 52,
                              color: Colors.white,
                            )
                          : ClipOval(
                              child: Image.network(
                                profileImageUrl,
                                width: 104,
                                height: 104,
                                fit: BoxFit.cover,
                                errorBuilder: (_, error, _) {
                                  debugPrint(
                                    'Profile image failed to load: $error',
                                  );
                                  return const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text(
                                          'Gambar profil tidak dapat dimuatkan.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Material(
                        color: Theme.of(context).colorScheme.secondary,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Tukar gambar profil',
                          onPressed: _isUploadingImage
                              ? null
                              : _chooseProfileImage,
                          icon: _isUploadingImage
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.camera_alt_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _user!.fullName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    String roleDisplay = _user!.role;
                    if (roleDisplay == 'peronda') {
                      roleDisplay = settings.t('Peronda');
                    } else if (roleDisplay == 'ketua_peronda') {
                      roleDisplay = settings.t('Ketua Peronda');
                    } else if (roleDisplay == 'ketua_krt' ||
                        roleDisplay == 'ketua') {
                      roleDisplay = settings.t('Ketua KRT');
                    } else if (roleDisplay == 'super_admin') {
                      roleDisplay = settings.t('Super Admin');
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        roleDisplay.toUpperCase(),
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            settings.t('Maklumat Peribadi'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  settings.t('No. Kad Pengenalan'),
                  _user!.icNumber ?? settings.t('Tiada'),
                  Icons.credit_card,
                ),
                const Divider(height: 1),
                _buildInfoRow(
                  settings.t('Zon Rondaan'),
                  _user!.districtZone ?? settings.t('Tiada'),
                  Icons.map,
                ),
                const Divider(height: 1),
                _buildInfoRow(
                  settings.t('No. Telefon'),
                  _user!.phoneNumber ?? settings.t('Tiada'),
                  Icons.phone,
                ),
                const Divider(height: 1),
                _buildInfoRow(
                  settings.t('E-mel'),
                  _user!.email ?? settings.t('Tiada'),
                  Icons.email_outlined,
                ),
                const Divider(height: 1),
                Builder(
                  builder: (context) {
                    String statusDisplay = _user!.accountStatus ?? 'pending';
                    if (statusDisplay == 'active') {
                      statusDisplay = settings.t('Aktif');
                    } else if (statusDisplay == 'inactive') {
                      statusDisplay = settings.t('Nyahaktif');
                    } else {
                      statusDisplay = settings.t('Menunggu');
                    }

                    return _buildInfoRow(
                      settings.t('Status Akaun'),
                      statusDisplay.toUpperCase(),
                      Icons.verified_user_outlined,
                      valueColor: _user!.accountStatus == 'active'
                          ? Colors.green
                          : Colors.orange,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String title,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color:
                        valueColor ??
                        Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
