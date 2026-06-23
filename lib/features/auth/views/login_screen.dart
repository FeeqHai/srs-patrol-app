// File: lib/features/auth/views/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  
  bool _obscurePassword = true;
  bool _isHoveringBtn = false;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // SRS/KRT Brand Colors (Formal Government Style)
  final Color _royalBlue = const Color(0xFF0F3D87);
  final Color _goldenYellow = const Color(0xFFFFD100);
  final Color _charcoal = const Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    // Interactive focus listeners
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));

    // Entrance Animation
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
      final bool success = await context.read<AuthProvider>().login(
        _emailController.text,
        _passwordController.text,
      );

      if (success && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  void _showForgotPasswordDialog() {
    final settings = context.read<SettingsProvider>();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.support_agent_outlined, color: _royalBlue, size: 40),
        title: Text(settings.t('Password Assistance')),
        content: Text(settings.t(
          'Please contact Ketua KRT to reset your password or reactivate your account.',
        )),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: _royalBlue),
            child: Text(settings.t('Tutup')),
          ),
        ],
      ),
    );
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
                        constraints: const BoxConstraints(maxWidth: 500),
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Image.asset('assets/icon.png', height: 90),
                ),
                const SizedBox(height: 48),
                Text(
                  settings.t('Portal Rasmi\nSkim Rondaan Sukarela.'),
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
                  settings.t('Akses kawalan keselamatan khas untuk peronda berdaftar.'),
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
      padding: const EdgeInsets.only(top: 70.0, bottom: 50.0, left: 24.0, right: 24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_royalBlue, const Color(0xFF0A295A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset('assets/icon.png', height: 65),
          const SizedBox(height: 20),
          Text(
            settings.t('PORTAL RASMI SRS'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _goldenYellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _goldenYellow.withValues(alpha: 0.5)),
            ),
            child: Text(
              settings.t('Akses Keselamatan Terhad'),
              style: TextStyle(
                fontSize: 12,
                color: _goldenYellow,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Form Content (Used in both Web and Mobile)
  // ---------------------------------------------------------
  Widget _buildFormContent({required bool isLargeScreen}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final textColor = theme.textTheme.bodyLarge?.color ?? _charcoal;

    return Padding(
      padding: EdgeInsets.all(isLargeScreen ? 64.0 : 36.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLargeScreen) ...[
            Image.asset('assets/icon.png', height: 70, alignment: Alignment.centerLeft),
            const SizedBox(height: 32),
          ],
          Row(
            mainAxisAlignment: isLargeScreen ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(Icons.shield, color: _royalBlue, size: 28),
              const SizedBox(width: 12),
              Text(
                settings.t('Log Masuk Sistem'),
                style: TextStyle(
                  fontSize: isLargeScreen ? 32 : 26,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Email Field
          Text(
            settings.t('E-mel'),
            style: TextStyle(fontWeight: FontWeight.w700, color: textColor, fontSize: 13, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: _emailFocus.hasFocus ? [BoxShadow(color: _royalBlue.withValues(alpha: 0.15), blurRadius: 10, spreadRadius: 2)] : [],
            ),
            child: TextField(
              controller: _emailController,
              focusNode: _emailFocus,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
              decoration: _inputDecoration(
                hintText: 'pengguna@srs.gov.my',
                icon: Icons.email_outlined,
                isDark: isDark,
                isFocused: _emailFocus.hasFocus,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Password Field
          Text(
            settings.t('Kata Laluan'),
            style: TextStyle(fontWeight: FontWeight.w700, color: textColor, fontSize: 13, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: _passwordFocus.hasFocus ? [BoxShadow(color: _royalBlue.withValues(alpha: 0.15), blurRadius: 10, spreadRadius: 2)] : [],
            ),
            child: TextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              obscureText: _obscurePassword,
              style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
              decoration: _inputDecoration(
                hintText: '••••••••',
                icon: Icons.lock_outline,
                isDark: isDark,
                isFocused: _passwordFocus.hasFocus,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: _passwordFocus.hasFocus ? _royalBlue : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Forgot Password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              style: TextButton.styleFrom(
                foregroundColor: isDark ? _goldenYellow : _royalBlue,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text(settings.t('Forgot password?'), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 32),

          // Error Message Display
          if (authProvider.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
                boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.05), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Icon(Icons.gpp_bad, color: Colors.red.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      authProvider.errorMessage!,
                      style: TextStyle(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Login Button (Interactive)
          MouseRegion(
            onEnter: (_) => setState(() => _isHoveringBtn = true),
            onExit: (_) => setState(() => _isHoveringBtn = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              transform: Matrix4.diagonal3Values(_isHoveringBtn ? 1.02 : 1.0, _isHoveringBtn ? 1.02 : 1.0, 1.0),
              child: ElevatedButton(
                onPressed: authProvider.isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _royalBlue,
                  foregroundColor: Colors.white,
                  elevation: _isHoveringBtn ? 8 : 2,
                  shadowColor: _royalBlue.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: authProvider.isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.fingerprint, size: 22),
                          const SizedBox(width: 12),
                          Text(
                            settings.t('LOG MASUK'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Register Link
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  settings.t("Belum mendaftar?"),
                  style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  style: TextButton.styleFrom(foregroundColor: isDark ? _goldenYellow : _royalBlue),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: Text(
                    settings.t('Daftar Peronda Baru'),
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText, required IconData icon, required bool isDark, required bool isFocused}) {
    final fillColor = isDark ? const Color(0xFF1A1A1A) : (isFocused ? Colors.white : Colors.grey.shade50);
    final borderColor = isFocused 
        ? _royalBlue 
        : (isDark ? Colors.white24 : Colors.grey.shade300);

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
      prefixIcon: Icon(
        icon, 
        color: isFocused ? _royalBlue : (isDark ? Colors.grey.shade500 : Colors.grey.shade400)
      ),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _royalBlue, width: 2),
      ),
    );
  }
}
