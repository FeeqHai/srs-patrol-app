// File: lib/features/auth/views/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
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
  bool _obscurePassword = true;

  String? _selectedZone;
  bool _isLoading = false;

  final Color _royalBlue = const Color(0xFF0F3D87);
  final Color _goldenYellow = const Color(0xFFFFD100);

  final List<String> _zones = [
    'Zon Utara',
    'Zon Selatan',
    'Zon Timur',
    'Zon Barat',
    'Pusat Komersial',
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

    final bool isFormValid = _formKey.currentState?.validate() ?? false;

    if (!isFormValid || _selectedZone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<SettingsProvider>().t(
              'Pendaftaran ditolak: Borang tidak lengkap atau zon tidak dipilih.',
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

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
          title: Text(
            context.read<SettingsProvider>().t('Pendaftaran Selesai'),
          ),
          content: Text(
            context.read<SettingsProvider>().t(
              'Akaun peronda telah direkodkan. Sila hubungi Ketua KRT untuk pengesahan identiti sebelum log masuk.',
            ),
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(
                context.read<SettingsProvider>().t('Kembali ke Log Masuk'),
              ),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 800;
          if (isLargeScreen) {
            return Row(
              children: [
                Expanded(child: _buildBrandSide()),
                Expanded(child: _buildFormSide(isLargeScreen: true)),
              ],
            );
          } else {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                _buildMobileHeader(),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  child: _buildFormSide(isLargeScreen: false),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildBrandSide() {
    final settings = context.watch<SettingsProvider>();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_royalBlue, _royalBlue.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Image.asset('assets/icon.png', height: 80),
              ),
              const SizedBox(height: 40),
              Text(
                settings.t('Join Our Patrol\nNetwork.'),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                settings.t(
                  'Register as a patroller to start securing the neighborhood, tracking incidents, and contributing to a safer community.',
                ),
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    final settings = context.watch<SettingsProvider>();
    return Container(
      height:
          MediaQuery.of(context).size.height *
          0.35, // Shorter for register to give form more room
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_royalBlue, _royalBlue.withValues(alpha: 0.8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    children: [
                      Text(
                        settings.t('Pendaftaran'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settings.t('Daftar Peronda Baru'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFFFD100),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 48), // Balance for back button
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormSide({required bool isLargeScreen}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();

    Widget formContent = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 64.0 : 32.0,
        vertical: 40.0,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLargeScreen) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              settings.t('Create Account'),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              settings.t(
                'Fill in the details below to register as a patroller.',
              ),
              style: TextStyle(
                fontSize: 16,
                color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 40),

            _buildSectionTitle(settings.t('Maklumat Identiti'), theme),
            const SizedBox(height: 16),
            _buildTextField(
              _nameController,
              settings.t('Nama Penuh (Mengikut Kad Pengenalan)'),
              Icons.person,
              TextInputType.name,
              isDark,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              _icController,
              settings.t('No. Kad Pengenalan (Tanpa Sengkang)'),
              Icons.badge,
              TextInputType.number,
              isDark,
            ),
            const SizedBox(height: 32),

            _buildSectionTitle(settings.t('Maklumat Operasi'), theme),
            const SizedBox(height: 16),
            _buildTextField(
              _phoneController,
              settings.t('No. Telefon (Kecemasan)'),
              Icons.phone,
              TextInputType.phone,
              isDark,
            ),
            const SizedBox(height: 16),

            // Dropdown
            DropdownButtonFormField<String>(
              value: _selectedZone,
              icon: Icon(
                Icons.arrow_drop_down,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              dropdownColor: theme.cardColor,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: settings.t('Pilih Sektor / Zon Rondaan'),
                prefixIcon: Icon(
                  Icons.map_outlined,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              items: _zones
                  .map(
                    (zone) => DropdownMenuItem(value: zone, child: Text(zone)),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedZone = val),
              validator: (val) =>
                  val == null ? settings.t('Zon rondaan wajib dipilih') : null,
            ),
            const SizedBox(height: 32),

            _buildSectionTitle(settings.t('Kredensial Sistem'), theme),
            const SizedBox(height: 16),
            _buildTextField(
              _emailController,
              settings.t('Alamat E-mel'),
              Icons.email_outlined,
              TextInputType.emailAddress,
              isDark,
            ),
            const SizedBox(height: 16),

            // Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              keyboardType: TextInputType.visiblePassword,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: settings.t('Kata Laluan'),
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? settings.t('Ruangan ini wajib diisi')
                  : null,
            ),
            const SizedBox(height: 48),

            SizedBox(
              height: 56,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitRegistration,
                      child: Text(settings.t('HANTAR PERMOHONAN')),
                    ),
            ),
          ],
        ),
      ),
    );

    if (isLargeScreen) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: formContent,
        ),
      );
    } else {
      return Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: formContent,
      );
    }
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        color: _royalBlue,
        fontWeight: FontWeight.bold,
        fontSize: 14,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
    TextInputType type,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: type,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
      validator: (value) => value == null || value.isEmpty
          ? context.read<SettingsProvider>().t('Ruangan ini wajib diisi')
          : null,
    );
  }
}
