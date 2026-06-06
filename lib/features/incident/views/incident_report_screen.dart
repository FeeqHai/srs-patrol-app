// File: lib/features/incident/views/incident_report_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/incident_provider.dart';
import '../../auth/providers/auth_provider.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _selectedCategory = 'Suspicious Activity';
  final List<String> _categories = [
    'Suspicious Activity',
    'Vandalism/Damage',
    'Trespassing',
    'Medical Emergency',
    'Other'
  ];

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70, 
    );

    if (photo != null) {
      setState(() => _imageFile = File(photo.path));
    }
  }

Future<void> _submitReport() async {
    // 1. HARDWARE LOCK: Force the keyboard to collapse before state changes
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    
    if (_imageFile == null) {
      _showSnackBar('Bahan bukti diperlukan: Sila ambil gambar insiden.', Colors.redAccent);
      return;
    }

    final String? currentUserId = context.read<AuthProvider>().userId;
    if (currentUserId == null) {
      _showSnackBar('Ralat Sesi: Sila log masuk semula.', Colors.redAccent);
      return;
    }

    // 2. LOADING OVERLAY
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.redAccent),
            SizedBox(height: 16),
            Text('Menyambung ke GPS & Memuat Naik...', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
          ],
        ),
      ),
    );

    final provider = context.read<IncidentProvider>();
    final bool success = await provider.createIncidentReport(
      userId: currentUserId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _selectedCategory,
      imageFile: _imageFile!,
    );

    if (!mounted) return;

    // 3. Purge the loading overlay safely
    Navigator.pop(context);

    // 4. THE SAFEGUARDED STATE ROUTING
    if (success) {
      // INTERFACE UPGRADE: A blocking success modal instead of a passive snackbar
      showDialog(
        context: context,
        barrierDismissible: false, // Force them to acknowledge it
        builder: (context) => Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 10,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 64),
                const SizedBox(height: 20),
                const Text('Laporan Berjaya', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                const Text(
                  'Data insiden, gambar bukti, dan kordinat GPS telah selamat dihantar ke pelayan utama.', 
                  textAlign: TextAlign.center, 
                  style: TextStyle(color: Colors.white70, height: 1.5)
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // 1. Dismiss this success dialog
                      
                      // 2. THE SAFEGUARD: Only pop the screen if there is an actual feed behind it
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        // If testing directly via main.dart, reset the form instead of committing suicide
                        setState(() {
                          _titleController.clear();
                          _descController.clear();
                          _imageFile = null;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Kembali ke Menu', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      _showSnackBar('RALAT MUAT NAIK: ${provider.errorMessage}', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Note: We no longer watch the provider state to destroy the UI here.
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Lapor Insiden', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Evidence Capture Area
              GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 48, color: Colors.white54),
                            SizedBox(height: 8),
                            Text('Ketuk untuk ambil gambar bukti', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              const Text('Kategori Insiden', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                dropdownColor: const Color(0xFF1E1E1E),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 20),

              const Text('Tajuk Ringkas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Cth: Pagar rosak di Lorong 4',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Sila masukkan tajuk' : null,
              ),
              const SizedBox(height: 20),

              const Text('Keterangan Lanjut', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Terangkan butiran kejadian...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Penerangan tidak boleh dibiarkan kosong' : null,
              ),
              const SizedBox(height: 40),

              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _submitReport,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('HANTAR LAPORAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}