// File: lib/features/incident/views/incident_report_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/incident_provider.dart';

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

  // Hardware bridge to open the phone's camera
  Future<void> _takePhoto() async {
    // We compress the image to 70% quality to save your Storage bandwidth
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (photo != null) {
      setState(() {
        _imageFile = File(photo.path);
      });
    }
  }

  Future<void> _submitReport() async {
    // 1. Validate the form
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evidence required: Please take a photo.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // 2. Get the Patroller's ID
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 3. Trigger the Provider
    final provider = context.read<IncidentProvider>();
    final success = await provider.createIncidentReport(
      userId: user.uid,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _selectedCategory,
      imageFile: _imageFile!,
    );

    if (!mounted) return;

    // 4. Handle the result
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('REPORT SECURED: Uploaded to KRT Command.'), backgroundColor: Colors.green),
      );
      // Reset the form after a successful upload
      setState(() {
        _titleController.clear();
        _descController.clear();
        _imageFile = null;
        _selectedCategory = 'Suspicious Activity';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('UPLOAD FAILED: ${provider.errorMessage}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // We watch the provider to show a loading spinner while the GPS/Upload happens
    final bool isUploading = context.watch<IncidentProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Incident', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent[700],
      ),
      body: isUploading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.redAccent),
            SizedBox(height: 16),
            Text('Acquiring GPS & Uploading Evidence...', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Evidence Photo Box ---
              GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_imageFile!, fit: BoxFit.cover),
                  )
                      : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Tap to capture evidence', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- Category Dropdown ---
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Incident Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((String category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // --- Title Input ---
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Short Title',
                  hintText: 'e.g., Broken Fence at Gate B',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),

              // --- Description Input ---
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Detailed Description',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please describe the incident' : null,
              ),
              const SizedBox(height: 32),

              // --- Submit Button ---
              ElevatedButton.icon(
                onPressed: _submitReport,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('SUBMIT REPORT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}