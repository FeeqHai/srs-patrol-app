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

  String? _selectedCategory;
  final List<String> _jpninIncidentTypes = [
    'Jenayah Kekerasan - Pembunuhan',
    'Jenayah Kekerasan - Rogol',
    'Jenayah Kekerasan - Cabul Kehormatan',
    'Jenayah Kekerasan - Samun',
    'Jenayah Kekerasan - Peras Ugut',
    'Jenayah Kekerasan - Merusuh',
    'Jenayah Kekerasan - Mencedera / Penderaan',
    'Jenayah Harta Benda - Curi Kenderaan',
    'Jenayah Harta Benda - Curi Harta Benda',
    'Jenayah Harta Benda - Pecah Rumah',
    'Jenayah Narkotik - Pengedaran Dadah',
    'Jenayah Narkotik - Memiliki Dadah',
    'Gejala Sosial - Pertengkaran',
    'Gejala Sosial - Lepak',
    'Gejala Sosial - Vandalisme',
    'Gejala Sosial - Khalwat / Maksiat',
    'Gejala Sosial - Pergaduhan',
    'Gejala Sosial - Pendatang Tanpa Izin',
    'Gejala Sosial - Lumba Haram',
    'Gejala Sosial - Penagihan Dadah',
    'Gejala Sosial - Masalah Rumah Tangga',
    'Gejala Sosial - Ponteng',
    'Gejala Sosial - Kutu Rayau',
    'Gejala Sosial - Buang Bayi',
    'Lain-lain',
  ];

  final List<File> _images = [];
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
      setState(() => _images.add(File(photo.path)));
    }
  }

  Future<void> _submitReport() async {
    // 1. HARDWARE LOCK: Force the keyboard to collapse before state changes
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      _showSnackBar('Sila pilih kategori insiden.', Colors.redAccent);
      return;
    }

    if (_images.isEmpty) {
      _showSnackBar(
        'Bahan bukti diperlukan: Sila ambil gambar insiden.',
        Colors.redAccent,
      );
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
            Text(
              'Menyambung ke GPS & Memuat Naik...',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );

    final provider = context.read<IncidentProvider>();
    final bool success = await provider.createIncidentReport(
      userId: currentUserId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _selectedCategory!,
      imageFiles: _images,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.greenAccent,
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Laporan Berjaya',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Data insiden, gambar bukti, dan kordinat GPS telah selamat dihantar ke pelayan utama.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.5),
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
                          _images.clear();
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Kembali ke Menu',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Note: We no longer watch the provider state to destroy the UI here.
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Lapor Insiden',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
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
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  children: [
                    ..._images.map(
                      (file) => Stack(
                        children: [
                          Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: FileImage(file),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 16,
                            top: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _images.remove(file)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _takePhoto,
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white24,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 32,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tambah',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Kategori Insiden (Carian JPNIN)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _jpninIncidentTypes;
                  }
                  return _jpninIncidentTypes.where((String option) {
                    return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                  });
                },
                onSelected: (String selection) {
                  setState(() => _selectedCategory = selection);
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        onEditingComplete: onEditingComplete,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Cari kategori (cth: Samun, Dadah)...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: const Icon(
                            Icons.search,
                            color: Colors.white54,
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Sila pilih kategori insiden'
                            : null,
                      );
                    },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 250,
                          maxWidth: 300,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return InkWell(
                              onTap: () {
                                onSelected(option);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  option,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              const Text(
                'Tajuk Ringkas',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Cth: Pagar rosak di Lorong 4',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Sila masukkan tajuk'
                    : null,
              ),
              const SizedBox(height: 20),

              const Text(
                'Keterangan Lanjut',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Penerangan tidak boleh dibiarkan kosong'
                    : null,
              ),
              const SizedBox(height: 40),

              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _submitReport,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text(
                    'HANTAR LAPORAN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
