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

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // SRS/KRT Brand Colors
  final Color _royalBlue = const Color(0xFF0F3D87);
  final Color _goldenYellow = const Color(0xFFFFD100);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  // ---------------------------------------------------------
  // Branding Side (Web/Tablet Left Side)
  // ---------------------------------------------------------
  Widget _buildBrandSide() {
    final settings = context.watch<SettingsProvider>();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _royalBlue,
            _royalBlue.withValues(alpha: 0.8),
          ],
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
                settings.t('Securing Our Community\nTogether.'),
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
                settings.t('Welcome to the SRS Patrol Portal. Access your dashboard to manage patrols, report incidents, and keep the neighborhood safe.'),
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

  // ---------------------------------------------------------
  // Mobile Header (Top background for small screens)
  // ---------------------------------------------------------
  Widget _buildMobileHeader() {
    final settings = context.watch<SettingsProvider>();
    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _royalBlue,
            _royalBlue.withValues(alpha: 0.8),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/icon.png', height: 60),
              const SizedBox(height: 16),
              Text(
                settings.t('SRS Patrol Portal'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                settings.t('Securing Our Community'),
                style: TextStyle(
                  fontSize: 14,
                  color: _goldenYellow,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // Form Side (Web Right Side / Mobile Bottom Card)
  // ---------------------------------------------------------
  Widget _buildFormSide({required bool isLargeScreen}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();

    Widget formContent = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 64.0 : 32.0,
        vertical: 40.0,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLargeScreen) ...[
            Image.asset('assets/icon.png', height: 60, alignment: Alignment.centerLeft),
            const SizedBox(height: 32),
          ],
          Text(
            settings.t('Welcome Back'),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            settings.t('Enter your credentials to access your account'),
            style: TextStyle(
              fontSize: 16,
              color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 48),

          // Email Field
          Text(
            settings.t('Email Address'),
            style: TextStyle(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration(
              hintText: 'hello@srs.gov.my',
              icon: Icons.email_outlined,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 24),

          // Password Field
          Text(
            settings.t('Password'),
            style: TextStyle(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: _inputDecoration(
              hintText: '••••••••',
              icon: Icons.lock_outline,
              isDark: isDark,
            ).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Forgot Password (Placeholder)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.blueAccent : _royalBlue,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
              ),
              child: Text(settings.t('Forgot password?')),
            ),
          ),
          const SizedBox(height: 32),

          // Error Message Display
          if (authProvider.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      authProvider.errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

          // Login Button
          SizedBox(
            height: 56,
            child: authProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _royalBlue,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: _royalBlue.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      settings.t('SECURE LOGIN'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
          ),
          const SizedBox(height: 32),

          // Register Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                settings.t("Don't have an account?"),
                style: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7)),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                style: TextButton.styleFrom(foregroundColor: isDark ? _goldenYellow : _royalBlue),
                child: Text(
                  settings.t('Register Here'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
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
        height: MediaQuery.of(context).size.height * 0.7,
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

  InputDecoration _inputDecoration({required String hintText, required IconData icon, required bool isDark}) {
    final fillColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
      prefixIcon: Icon(icon, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _royalBlue, width: 2),
      ),
    );
  }
}
