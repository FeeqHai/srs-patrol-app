import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
        Uri.parse('${ApiConstants.baseUrl}auth/get_profile.php'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        if (body['status'] == 'success') {
          setState(() {
            _user = UserModel.fromJson(body['data']);
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = body['message'] ?? settings.t('Gagal memuat turun profil.');
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
      appLogger.e("=== CRITICAL NETWORK EXCEPTION ===\nException: $e\nTarget URI: ${ApiConstants.baseUrl}auth/get_profile.php\n==================================", error: e, stackTrace: stackTrace);
      setState(() {
        _error = settings.t('Ralat Rangkaian');
        _isLoading = false;
      });
    }
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
            )
          ],
        ),
      );
    }

    if (_user == null) {
      return Center(child: Text(settings.t("Tiada data profil"), style: const TextStyle(fontSize: 16)));
    }

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
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
              boxShadow: [
                 BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 5))
              ]
            ),
            child: Column(
               children: [
                   CircleAvatar(radius: 48, backgroundColor: Theme.of(context).primaryColor, child: const Icon(Icons.person, size: 48, color: Colors.white)),
                   const SizedBox(height: 16),
                    Text(_user!.fullName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final theme = Theme.of(context);
                        String roleDisplay = _user!.role;
                        if (roleDisplay == 'peronda') {
                          roleDisplay = settings.t('Peronda');
                        } else if (roleDisplay == 'ketua_peronda') {
                          roleDisplay = settings.t('Ketua Peronda');
                        } else if (roleDisplay == 'ketua_krt' || roleDisplay == 'ketua') {
                          roleDisplay = settings.t('Ketua KRT');
                        }
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            roleDisplay.toUpperCase(),
                            style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        );
                      },
                    ),
               ]
            )
          ),
          const SizedBox(height: 32),
          Text(settings.t('Maklumat Peribadi'), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, letterSpacing: 1)),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
               children: [
                  _buildInfoRow(settings.t('No. Kad Pengenalan'), _user!.icNumber ?? settings.t('Tiada'), Icons.credit_card),
                  const Divider(height: 1),
                  _buildInfoRow(settings.t('Zon Rondaan'), _user!.districtZone ?? settings.t('Tiada'), Icons.map),
                  const Divider(height: 1),
                  _buildInfoRow(settings.t('No. Telefon'), _user!.phoneNumber ?? settings.t('Tiada'), Icons.phone),
                  const Divider(height: 1),
                  _buildInfoRow(settings.t('E-mel'), _user!.email ?? settings.t('Tiada'), Icons.email_outlined),
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
                        valueColor: _user!.accountStatus == 'active' ? Colors.green : Colors.orange,
                      );
                    },
                  ),
               ]
            )
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, IconData icon, {Color? valueColor}) {
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
                Text(title, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6), fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: valueColor ?? Theme.of(context).textTheme.bodyLarge?.color, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
