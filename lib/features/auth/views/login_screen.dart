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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isHoveringBtn = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // iRonda Brand Colors
  final Color _navyStart = const Color(0xFF07193F);
  final Color _royalBlue = const Color(0xFF0F3D87);
  final Color _goldenYellow = const Color(0xFFFFD100);
  final Color _charcoal = const Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    // Focus listeners for dynamic borders
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));

    // Bouncy slide-up entrance animation for the login form card
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.70, curve: Curves.easeOut),
    ));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOutBack),
    ));

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
    if (_emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty) {
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
        content: Text(
          settings.t(
            'Please contact Ketua KRT to reset your password or reactivate your account.',
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F192E) : const Color(0xFFF3F6FA),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 800;
          if (isLargeScreen) {
            return Row(
              children: [
                Expanded(child: _buildBrandSide()),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0E1624) : const Color(0xFFF8FAFC),
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: _buildFormContent(isLargeScreen: true),
                        ),
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

  // ────────────────────────────────────────────────────────
  // Branding Side (Web/Tablet Left Side)
  // ────────────────────────────────────────────────────────
  Widget _buildBrandSide() {
    final settings = context.watch<SettingsProvider>();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_navyStart, _royalBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Subtle radar background pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(
                painter: _BrandRadarPainter(),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(56.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _goldenYellow.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: Image.asset('assets/icon.png', height: 95),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    settings.t('Portal Rasmi\nSkim Rondaan Sukarela.'),
                    style: const TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.15,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(width: 80, height: 4, color: _goldenYellow),
                  const SizedBox(height: 28),
                  Text(
                    settings.t(
                      'Akses kawalan keselamatan khas untuk peronda berdaftar.',
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
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // Mobile Layout (Bottom Card slides up from bottom)
  // ────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [_navyStart, const Color(0xFF0A152D)]
              : [_navyStart, _royalBlue],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Column(
            children: [
              // ── Top header bar (Language Switcher) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildLanguageSelector(settings),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Hero Logo ──
              Hero(
                tag: 'app_logo',
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Image.asset(
                      'assets/icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── App Name ──
              Text(
                'iRonda',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                settings.t('Akses Keselamatan Terhad').toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: _goldenYellow,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // ── Sliding Form Card ──
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height * 0.62,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F1826).withValues(alpha: 0.92)
                          : Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                          blurRadius: 30,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 28,
                        right: 28,
                        top: 32,
                        bottom: 36,
                      ),
                      child: _buildFormContent(isLargeScreen: false),
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

  // ────────────────────────────────────────────────────────
  // Language Selector button (Modern Glassmorphic toggle)
  // ────────────────────────────────────────────────────────
  Widget _buildLanguageSelector(SettingsProvider settings) {
    final isEn = settings.isEnglish;
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      borderOnForeground: false,
      child: InkWell(
        onTap: () {
          settings.setLanguage(isEn ? 'ms' : 'en');
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.translate, size: 14, color: _goldenYellow),
              const SizedBox(width: 8),
              Text(
                isEn ? 'EN' : 'BM',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // Form Content (Used in both Web and Mobile)
  // ────────────────────────────────────────────────────────
  Widget _buildFormContent({required bool isLargeScreen}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final textColor = theme.textTheme.bodyLarge?.color ?? _charcoal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLargeScreen) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                settings.t('iRonda'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : _royalBlue,
                  letterSpacing: 1.5,
                ),
              ),
              _buildLanguageSelector(settings),
            ],
          ),
          const SizedBox(height: 48),
        ],

        Row(
          mainAxisAlignment: isLargeScreen ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, color: _royalBlue, size: 26),
            const SizedBox(width: 12),
            Text(
              settings.t('Log Masuk Sistem'),
              style: TextStyle(
                fontSize: isLargeScreen ? 30 : 22,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Email Label & Field
        Text(
          settings.t('E-mel'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor.withValues(alpha: 0.8),
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _emailFocus.hasFocus
                ? [
                    BoxShadow(
                      color: _royalBlue.withValues(alpha: 0.12),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
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
        const SizedBox(height: 20),

        // Password Label & Field
        Text(
          settings.t('Kata Laluan'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor.withValues(alpha: 0.8),
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _passwordFocus.hasFocus
                ? [
                    BoxShadow(
                      color: _royalBlue.withValues(alpha: 0.12),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
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
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _passwordFocus.hasFocus
                      ? _royalBlue
                      : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Forgot Password Action Link
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _showForgotPasswordDialog,
            style: TextButton.styleFrom(
              foregroundColor: isDark ? _goldenYellow : _royalBlue,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: Text(
              settings.t('Forgot password?'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Error message notification
        if (authProvider.errorMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.gpp_bad_outlined, color: Colors.redAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    authProvider.errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Sign In Button
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
              onPressed: authProvider.isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: _royalBlue,
                foregroundColor: Colors.white,
                elevation: _isHoveringBtn ? 8 : 2,
                shadowColor: _royalBlue.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: authProvider.isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.fingerprint, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          settings.t('LOG MASUK'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Register new patroller section
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              Text(
                settings.t("Belum mendaftar?"),
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.55),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? _goldenYellow : _royalBlue,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: Text(
                  settings.t('Daftar Peronda Baru'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    required bool isDark,
    required bool isFocused,
  }) {
    final fillColor = isDark
        ? const Color(0xFF1E2838)
        : (isFocused ? Colors.white : Colors.grey.shade50);
    final borderColor = isFocused
        ? _royalBlue
        : (isDark ? Colors.white12 : Colors.grey.shade200);

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(
        icon,
        color: isFocused
            ? _royalBlue
            : (isDark ? Colors.grey.shade400 : Colors.grey.shade400),
      ),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _royalBlue, width: 2),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────
// Concentric circles radar decoration
// ────────────────────────────────────────────────────────
class _BrandRadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height * 0.25);

    canvas.drawCircle(center, 90, paint);
    canvas.drawCircle(center, 180, paint);
    canvas.drawCircle(center, 280, paint);

    final diagonalPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), diagonalPaint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), diagonalPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
