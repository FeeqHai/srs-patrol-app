import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../../core/constants/api_constants.dart';

class AddendumReportScreen extends StatefulWidget {
  final Map<String, dynamic> incident;
  const AddendumReportScreen({super.key, required this.incident});

  @override
  State<AddendumReportScreen> createState() => _AddendumReportScreenState();
}

class _AddendumReportScreenState extends State<AddendumReportScreen> {
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

  Future<void> _submitAddendum() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila pilih kategori insiden.'), backgroundColor: Colors.redAccent)
      );
      return;
    }

    if (_descController.text.trim().isEmpty && _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila masukkan nota atau gambar.'), backgroundColor: Colors.redAccent)
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.redAccent),
            const SizedBox(height: 16),
            Text('Memuat Naik...', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
          ],
        ),
      ),
    );

    try {
      var request = http.MultipartRequest('POST', Uri.parse('${ApiConstants.baseUrl}incidents/addendum.php'));
      request.fields['id'] = const Uuid().v4();
      request.fields['incident_id'] = widget.incident['id'];
      
      request.fields['text_content'] = _descController.text.trim();
      request.fields['category'] = _selectedCategory!;
      request.fields['title'] = _titleController.text.trim();

      for (var file in _images) {
        request.files.add(await http.MultipartFile.fromPath('images[]', file.path));
      }

      var response = await request.send();
      if (!mounted) return;
      Navigator.pop(context); // close dialog

      if (response.statusCode == 200) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Theme.of(context).dialogBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
                  const SizedBox(height: 20),
                  Text('Berjaya', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                  const SizedBox(height: 12),
                  Text('Catatan tambahan telah dihantar.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7), height: 1.5)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // close success dialog
                        if (Navigator.canPop(context)) Navigator.pop(context, true); // return to previous screen
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, 
                        foregroundColor: Colors.white, 
                        padding: const EdgeInsets.symmetric(vertical: 14)
                      ),
                      child: const Text('Kembali', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ralat memuat naik.'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ralat: $e'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Tambah Nota', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.appBarTheme.iconTheme,
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
                  color: theme.inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  children: [
                    ..._images.map((file) => Stack(
                      children: [
                        Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          right: 16,
                          top: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _images.remove(file)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    )),
                    GestureDetector(
                      onTap: _takePhoto,
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1), style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 32, color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text('Tambah', style: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5), fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('Kategori Insiden (Carian JPNIN)', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _jpninIncidentTypes;
                  }
                  return _jpninIncidentTypes.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  setState(() => _selectedCategory = selection);
                },
                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    onEditingComplete: onEditingComplete,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      hintText: 'Cari kategori (cth: Samun, Dadah)...',
                      hintStyle: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: theme.inputDecorationTheme.fillColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      suffixIcon: Icon(Icons.search, color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5)),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Sila pilih kategori insiden' : null,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250, maxWidth: 300),
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
                                child: Text(option, style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
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

              Text('Tajuk Ringkas', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: 'Cth: Pagar rosak di Lorong 4',
                  hintStyle: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Sila masukkan tajuk' : null,
              ),
              const SizedBox(height: 20),

              Text('Keterangan Lanjut', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: 'Terangkan butiran tambahan...',
                  hintStyle: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Penerangan tidak boleh dibiarkan kosong' : null,
              ),
              const SizedBox(height: 40),

              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _submitAddendum,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('HANTAR NOTA TAMBAHAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
