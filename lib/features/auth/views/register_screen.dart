// File: lib/features/auth/views/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../models/location_option.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _icController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isHoveringBtn = false;
  LocationOption? _selectedState;
  LocationOption? _selectedDistrict;
  LocationOption? _selectedZone;
  List<LocationOption> _states = const [];
  List<LocationOption> _districts = const [];
  List<LocationOption> _zones = const [];
  bool _isLoadingLocations = true;
  String? _locationLoadError;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // SRS/KRT Brand Colors
  final Color _royalBlue = const Color(0xFF0F3D87);
  final Color _goldenYellow = const Color(0xFFFFD100);
  final Color _charcoal = const Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
    _loadStates();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _icController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    FocusScope.of(context).unfocus();

    final bool isFormValid = _formKey.currentState?.validate() ?? false;

    if (!isFormValid ||
        _selectedState == null ||
        _selectedDistrict == null ||
        _selectedZone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<SettingsProvider>().t(
              'Borang tidak lengkap atau lokasi rondaan belum dipilih.',
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
      stateId: _selectedState!.id,
      districtId: _selectedDistrict!.id,
      zoneId: _selectedZone!.id,
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Colors.green,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.read<SettingsProvider>().t('Pendaftaran Berjaya'),
                    textAlign: TextAlign.center,
                    style: Theme.of(dialogContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.read<SettingsProvider>().t(
                      'Sila hubungi Ketua KRT untuk pengesahan akaun sebelum log masuk.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      dialogContext,
                    ).textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _royalBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        context.read<SettingsProvider>().t(
                          'Kembali ke Log Masuk',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  Future<void> _loadStates() async {
    setState(() {
      _isLoadingLocations = true;
      _locationLoadError = null;
    });

    try {
      final states = await _authService.fetchLocations(level: 'states');
      if (!mounted) return;
      setState(() {
        _states = states;
        _isLoadingLocations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocations = false;
        _locationLoadError = 'Tidak dapat memuatkan senarai negeri.';
      });
    }
  }

  Future<void> _selectState(LocationOption? state) async {
    setState(() {
      _selectedState = state;
      _selectedDistrict = null;
      _selectedZone = null;
      _districts = const [];
      _zones = const [];
      _locationLoadError = null;
    });
    if (state == null) return;

    try {
      final districts = await _authService.fetchLocations(
        level: 'districts',
        parentId: state.id,
      );
      if (!mounted || _selectedState?.id != state.id) return;
      setState(() => _districts = districts);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _locationLoadError = 'Tidak dapat memuatkan senarai daerah.',
      );
    }
  }

  Future<void> _selectDistrict(LocationOption? district) async {
    setState(() {
      _selectedDistrict = district;
      _selectedZone = null;
      _zones = const [];
      _locationLoadError = null;
    });
    if (district == null) return;

    try {
      final zones = await _authService.fetchLocations(
        level: 'zones',
        parentId: district.id,
      );
      if (!mounted || _selectedDistrict?.id != district.id) return;
      setState(() => _zones = zones);
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationLoadError = 'Tidak dapat memuatkan senarai zon.');
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
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 550),
                        child: _buildFormContent(isLargeScreen: true),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------
  // Branding Side (Web/Tablet Left Side)
  // ---------------------------------------------------------
  Widget _buildBrandSide() {
    final settings = context.watch<SettingsProvider>();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_royalBlue, const Color(0xFF0A295A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Image.asset('assets/icon.png', height: 90),
                ),
                const SizedBox(height: 48),
                Text(
                  settings.t('Sertai Rangkaian\nPeronda Kami.'),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 24),
                Container(width: 60, height: 4, color: _goldenYellow),
                const SizedBox(height: 24),
                Text(
                  settings.t(
                    'Daftar sebagai peronda SRS untuk membantu menjaga keselamatan dan keharmonian komuniti setempat.',
                  ),
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // Mobile Layout (Bottom Sheet style that slides up)
  // ---------------------------------------------------------
  Widget _buildMobileLayout() {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(bottom: keyboardInset + 24),
        child: Column(
          children: [
            _buildMobileHeader(),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildFormContent(isLargeScreen: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // Mobile Header (Top background for small screens)
  // ---------------------------------------------------------
  Widget _buildMobileHeader() {
    final settings = context.watch<SettingsProvider>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: 60.0,
        bottom: 40.0,
        left: 16.0,
        right: 16.0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_royalBlue, const Color(0xFF0A295A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    settings.t('PENDAFTARAN'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    settings.t('Daftar Peronda Baru'),
                    style: TextStyle(
                      fontSize: 13,
                      color: _goldenYellow,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48), // Balance for back button
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // Form Content
  // ---------------------------------------------------------
  Widget _buildFormContent({required bool isLargeScreen}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    final textColor = theme.textTheme.bodyLarge?.color ?? _charcoal;

    return Padding(
      padding: EdgeInsets.all(isLargeScreen ? 64.0 : 32.0),
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
                  icon: Icon(Icons.arrow_back, color: textColor),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.person_add, color: _royalBlue, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    settings.t('Pendaftaran Peronda'),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                settings.t('Lengkapkan butiran di bawah untuk mendaftar.'),
                style: TextStyle(
                  fontSize: 16,
                  color: textColor.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
            ],

            _buildSectionTitle(settings.t('Maklumat Identiti')),
            const SizedBox(height: 16),
            _buildTextField(
              _nameController,
              settings.t('Nama Penuh (Mengikut MyKad)'),
              Icons.person_outline,
              TextInputType.name,
              isDark,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              _icController,
              settings.t('No. Kad Pengenalan (Tanpa Sengkang)'),
              Icons.badge_outlined,
              TextInputType.number,
              isDark,
            ),
            const SizedBox(height: 32),

            _buildSectionTitle(settings.t('Maklumat Operasi')),
            const SizedBox(height: 16),
            _buildTextField(
              _phoneController,
              settings.t('No. Telefon (Kecemasan)'),
              Icons.phone_outlined,
              TextInputType.phone,
              isDark,
            ),
            const SizedBox(height: 16),

            _buildLocationDropdown(
              value: _selectedState,
              items: _states,
              hint: _isLoadingLocations
                  ? 'Memuatkan negeri...'
                  : 'Pilih Negeri',
              icon: Icons.map_outlined,
              enabled: !_isLoadingLocations,
              onChanged: _selectState,
              validator: (value) =>
                  value == null ? settings.t('Sila pilih negeri') : null,
              isDark: isDark,
              textColor: textColor,
            ),
            const SizedBox(height: 16),
            _buildLocationDropdown(
              value: _selectedDistrict,
              items: _districts,
              hint: 'Pilih Daerah',
              icon: Icons.account_tree_outlined,
              enabled: _selectedState != null && _districts.isNotEmpty,
              onChanged: _selectDistrict,
              validator: (value) =>
                  value == null ? settings.t('Sila pilih daerah') : null,
              isDark: isDark,
              textColor: textColor,
            ),
            const SizedBox(height: 16),
            _buildLocationDropdown(
              value: _selectedZone,
              items: _zones,
              hint: 'Pilih Zon Rondaan',
              icon: Icons.location_on_outlined,
              enabled: _selectedDistrict != null && _zones.isNotEmpty,
              onChanged: (value) => setState(() => _selectedZone = value),
              validator: (value) =>
                  value == null ? settings.t('Sila pilih zon') : null,
              isDark: isDark,
              textColor: textColor,
            ),
            if (_locationLoadError != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationLoadError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _selectedState == null
                        ? _loadStates
                        : () => _selectDistrict(_selectedDistrict),
                    child: const Text('Cuba lagi'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),

            /*
             * The dependent State -> District -> Zone selections above prevent
             * impossible combinations before submission; the PHP endpoint
             * validates the same path again on the server.
             */
            /*
            DropdownButtonFormField<String>(
              initialValue: _selectedZone,
              icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              dropdownColor: theme.cardColor,
              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
              decoration: _inputDecoration(
                hintText: settings.t('Pilih Zon Rondaan'),
                icon: Icons.map_outlined,
                isDark: isDark,
              ),
              items: _zones.map((zone) => DropdownMenuItem(value: zone, child: Text(zone))).toList(),
              onChanged: (val) => setState(() => _selectedZone = val),
              validator: (val) => val == null ? settings.t('Sila pilih zon') : null,
            ),
            const SizedBox(height: 32),
            */
            _buildSectionTitle(settings.t('Kredensial Sistem')),
            const SizedBox(height: 16),
            _buildTextField(
              _emailController,
              settings.t('E-mel'),
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
              style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
              decoration:
                  _inputDecoration(
                    hintText: settings.t('Kata Laluan'),
                    icon: Icons.lock_outline,
                    isDark: isDark,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
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

            // Register Button (Interactive)
            MouseRegion(
              onEnter: (_) => setState(() => _isHoveringBtn = true),
              onExit: (_) => setState(() => _isHoveringBtn = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                transform: Matrix4.diagonal3Values(
                  _isHoveringBtn ? 1.02 : 1.0,
                  _isHoveringBtn ? 1.02 : 1.0,
                  1.0,
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _royalBlue,
                    foregroundColor: Colors.white,
                    elevation: _isHoveringBtn ? 8 : 2,
                    shadowColor: _royalBlue.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_add_alt_1, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              settings.t('HANTAR PERMOHONAN'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: _royalBlue,
        fontWeight: FontWeight.w800,
        fontSize: 13,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildLocationDropdown({
    required LocationOption? value,
    required List<LocationOption> items,
    required String hint,
    required IconData icon,
    required bool enabled,
    required ValueChanged<LocationOption?> onChanged,
    required FormFieldValidator<LocationOption> validator,
    required bool isDark,
    required Color textColor,
  }) {
    return DropdownButtonFormField<LocationOption>(
      initialValue: value,
      icon: Icon(
        Icons.arrow_drop_down,
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      ),
      dropdownColor: Theme.of(context).cardColor,
      style: TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: _inputDecoration(hintText: hint, icon: icon, isDark: isDark),
      items: items
          .map(
            (item) => DropdownMenuItem<LocationOption>(
              value: item,
              child: Text(item.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
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
    final textColor = theme.textTheme.bodyLarge?.color ?? _charcoal;

    return TextFormField(
      controller: controller,
      keyboardType: type,
      style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
      decoration: _inputDecoration(hintText: hint, icon: icon, isDark: isDark),
      validator: (value) => value == null || value.isEmpty
          ? context.read<SettingsProvider>().t('Ruangan ini wajib diisi')
          : null,
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    required bool isDark,
  }) {
    final fillColor = isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade50;

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
        fontSize: 14,
      ),
      prefixIcon: Icon(
        icon,
        color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
      ),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _royalBlue, width: 2),
      ),
    );
  }
}
