// File: lib/features/auth/views/register_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _icController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  String? _selectedZone;
  bool _isLoading = false;

  final List<String> _zones = [
    'Zon Utara',
    'Zon Selatan',
    'Zon Timur',
    'Zon Barat',
    'Pusat Komersial'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _icController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
Future<void> _submitRegistration() async {
    FocusScope.of(context).unfocus();
    
    // --- DIAGNOSTIC TRACERS INJECTED ---
    print("=== REGISTRATION PIPELINE INITIATED ===");

    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    print("[UI CHECK 1] Text Fields Valid: $isFormValid");
    print("[UI CHECK 2] Selected Zone Value: $_selectedZone");

    if (!isFormValid || _selectedZone == null) {
      print("=== FATAL: PIPELINE ABORTED BY UI VALIDATION ===");
      // Provide visual feedback instead of a silent crash
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pendaftaran ditolak: Borang tidak lengkap atau zon tidak dipilih.', style: TextStyle(fontWeight: FontWeight.bold)), 
          backgroundColor: Colors.orange
        )
      );
      return; 
    }

    print("=== UI VALIDATION SUCCESS: ROUTING TO NETWORK BRIDGE ===");
    // --- END DIAGNOSTIC ---

    setState(() => _isLoading = true);

    final error = await _authService.registerPatroller(
      fullName: _nameController.text.trim(),
      icNumber: _icController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      districtZone: _selectedZone!,
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Pendaftaran Selesai', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Akaun peronda telah direkodkan. Sila hubungi Ketua KRT untuk pengesahan identiti sebelum log masuk.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); 
                Navigator.pop(context); 
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlueAccent, foregroundColor: Colors.black),
              child: const Text('Kembali ke Log Masuk'),
            )
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.redAccent));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Daftar Peronda Baru', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.lightBlueAccent))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Maklumat Identiti', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _buildTextField(_nameController, 'Nama Penuh (Mengikut Kad Pengenalan)', Icons.person, TextInputType.name),
                  const SizedBox(height: 16),
                  _buildTextField(_icController, 'No. Kad Pengenalan (Tanpa Sengkang)', Icons.badge, TextInputType.number),
                  const SizedBox(height: 32),

                  const Text('Maklumat Operasi', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _buildTextField(_phoneController, 'No. Telefon (Kecemasan)', Icons.phone, TextInputType.phone),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedZone,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Sektor / Zon Rondaan',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.map, color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: _zones.map((zone) => DropdownMenuItem(value: zone, child: Text(zone))).toList(),
                    onChanged: (val) => setState(() => _selectedZone = val),
                    validator: (val) => val == null ? 'Zon rondaan wajib dipilih' : null,
                  ),
                  const SizedBox(height: 32),

                  const Text('Kredensial Sistem', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _buildTextField(_emailController, 'Alamat E-mel', Icons.email, TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildTextField(_passwordController, 'Kata Laluan', Icons.lock, TextInputType.visiblePassword, obscureText: true),
                  const SizedBox(height: 40),

                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _submitRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlueAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('HANTAR PERMOHONAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, TextInputType type, {bool obscureText = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (value) => value == null || value.isEmpty ? 'Ruangan ini wajib diisi' : null,
    );
  }
}