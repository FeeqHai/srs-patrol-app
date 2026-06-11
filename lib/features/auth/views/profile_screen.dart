import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';

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

    if (userId == null) {
      setState(() {
        _error = "Sesi tamat. Sila log masuk semula.";
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}auth/get_profile.php?user_id=$userId'));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        if (body['status'] == 'success') {
          setState(() {
            _user = UserModel.fromJson(body['data']);
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = body['message'] ?? 'Gagal memuat turun profil.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Ralat Pelayan: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      print("=== CRITICAL NETWORK EXCEPTION ===");
      print("Exception: $e");
      print("Target URI: ${ApiConstants.baseUrl}auth/get_profile.php");
      print("==================================");
      setState(() {
        _error = 'Ralat Rangkaian: Tidak dapat menyambung ke pelayan.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchProfile,
              child: const Text('Cuba Semula'),
            )
          ],
        ),
      );
    }

    if (_user == null) {
      return const Center(child: Text("Tiada data profil", style: TextStyle(color: Colors.white70)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.indigoAccent,
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard('Nama Penuh', _user!.fullName, Icons.badge),
          _buildInfoCard('No. Kad Pengenalan', _user!.icNumber ?? 'Tiada', Icons.credit_card),
          _buildInfoCard('Zon Rondaan', _user!.districtZone ?? 'Tiada', Icons.map),
          _buildInfoCard('No. Telefon', _user!.phoneNumber ?? 'Tiada', Icons.phone),
          _buildInfoCard('E-mel', _user!.email ?? 'Tiada', Icons.email),
          _buildInfoCard('Peranan', _user!.role.toUpperCase(), Icons.security),
          _buildInfoCard('Status Akaun', _user!.accountStatus?.toUpperCase() ?? 'PENDING', Icons.verified_user, 
            valueColor: _user!.accountStatus == 'active' ? Colors.greenAccent : Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, {Color valueColor = Colors.white}) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.indigoAccent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
