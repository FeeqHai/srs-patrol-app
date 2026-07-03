import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

/// A premium cinematic splash screen for iRonda.
/// Features:
///  1. Deep metallic background with a pulsing radial glow.
///  2. Logo rotates and scales up with an elastic deceleration.
///  3. A gloss/shimmer sweep runs diagonally across the logo.
///  4. App name ("iRonda") reveals with a cinematic letter-spacing contraction (focusing into place).
///  5. A golden accent line draws itself outward from the center.
///  6. Custom page transition that expands circular-wise.
class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controllers
  late final AnimationController _entranceCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _exitCtrl;

  // Logo animations
  late final Animation<double> _logoScale;
  late final Animation<double> _logoRotation;
  late final Animation<double> _logoOpacity;

  // Cinematic title animations
  late final Animation<double> _titleSpacing;
  late final Animation<double> _titleOpacity;

  // Golden underline animation
  late final Animation<double> _lineWidth;

  // Tagline animation
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _taglineScale;

  // Background glow pulse
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowOpacity;

  static const _navyStart = Color(0xFF07193F);
  static const _navyEnd = Color(0xFF0F3D87);
  static const _gold = Color(0xFFFFD100);

  @override
  void initState() {
    super.initState();

    // ── Entrance Timeline: 2000ms total ──
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // 1. Logo: Spin (1.5 turns) and scale up from 0 to 1
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOutBack),
      ),
    );
    _logoRotation = Tween<double>(begin: -1.5 * pi, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.25, curve: Curves.linear),
      ),
    );

    // 2. Cinematic Spacing: spacing starts wide (24.0) and contracts to (3.0)
    _titleSpacing = Tween<double>(begin: 24.0, end: 3.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.30, 0.65, curve: Curves.easeOutExpo),
      ),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.30, 0.55, curve: Curves.easeIn),
      ),
    );

    // 3. Golden Line: grows from 0px to 100px width
    _lineWidth = Tween<double>(begin: 0.0, end: 100.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOutQuad),
      ),
    );

    // 4. Tagline: fades and rises slightly
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
      ),
    );
    _taglineScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOutBack),
      ),
    );

    // ── Shimmer loop: sweeps across logo ──
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // ── Background Glow: pulses ambiently ──
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _glowOpacity = Tween<double>(begin: 0.3, end: 0.75).animate(
      CurvedAnimation(
        parent: _glowCtrl,
        curve: Curves.easeInOut,
      ),
    );
    _glowCtrl.repeat(reverse: true);

    // ── Exit Transition Timeline: Slide UP off-screen ──
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _playSplashSequence();
  }

  Future<void> _playSplashSequence() async {
    // Start main animations
    _entranceCtrl.forward();

    // Start logo shimmer sweep 800ms in
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      _shimmerCtrl.repeat();
    }

    // Keep displaying the fully resolved screen
    await Future.delayed(const Duration(milliseconds: 3200));
    
    // Play exit: slide the entire splash screen UP off the viewport
    if (mounted) {
      await _exitCtrl.forward();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
        ),
      );
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _shimmerCtrl.dispose();
    _glowCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    // Slide the entire splash upward when exit plays
    final exitSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -1.0),
    ).animate(CurvedAnimation(
      parent: _exitCtrl,
      curve: Curves.easeInCubic,
    ));

    return Scaffold(
      backgroundColor: _navyStart,
      body: SlideTransition(
        position: exitSlide,
        child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Animated background gradient & ambient radial glow
          AnimatedBuilder(
            animation: _glowOpacity,
            builder: (context, child) {
              return Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      _navyEnd.withValues(alpha: _glowOpacity.value),
                      _navyStart,
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Custom Painter for premium geometric background lines
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: CustomPaint(
                painter: _GeometricBackgroundPainter(),
              ),
            ),
          ),

          // 3. Main interactive content container
          AnimatedBuilder(
            animation: _entranceCtrl,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rotating & Scaling Logo with Shimmer Overlay
                  Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Transform.rotate(
                        angle: _logoRotation.value,
                        child: Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                          child: ClipOval(
                            child: Stack(
                              children: [
                                Hero(
                                  tag: 'app_logo',
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Image.asset(
                                      'assets/icon.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                // Diagonal shimmer sweep overlay
                                Positioned.fill(
                                  child: AnimatedBuilder(
                                    animation: _shimmerCtrl,
                                    builder: (context, child) {
                                      return FractionallySizedBox(
                                        widthFactor: 2.0,
                                        alignment: Alignment(
                                          -1.5 + (_shimmerCtrl.value * 3.0),
                                          0.0,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.white.withValues(alpha: 0.0),
                                                Colors.white.withValues(alpha: 0.0),
                                                Colors.white.withValues(alpha: 0.35),
                                                Colors.white.withValues(alpha: 0.0),
                                                Colors.white.withValues(alpha: 0.0),
                                              ],
                                              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 38),

                  // App Name with wide-to-contracting cinematic spacing
                  Opacity(
                    opacity: _titleOpacity.value,
                    child: Text(
                      settings.t('iRonda'),
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: _titleSpacing.value,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Golden horizontal line drawing outward
                  Container(
                    width: _lineWidth.value,
                    height: 2.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _gold.withValues(alpha: 0.1),
                          _gold,
                          _gold.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tagline fade and smooth scale up
                  Opacity(
                    opacity: _taglineOpacity.value,
                    child: Transform.scale(
                      scale: _taglineScale.value,
                      child: Text(
                        settings.t('SKIM RONDAAN SUKARELA'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.6),
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Bottom version signature
          Positioned(
            bottom: 40,
            child: AnimatedBuilder(
              animation: _entranceCtrl,
              builder: (context, child) {
                return Opacity(
                  opacity: _taglineOpacity.value,
                  child: Text(
                    settings.t('iRonda Security Platform'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.25),
                      letterSpacing: 1.2,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// Draws fine concentric circular reference lines to evoke a modern tech/radar grid.
class _GeometricBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw concentric circles
    canvas.drawCircle(center, 120, paint);
    canvas.drawCircle(center, 220, paint);
    canvas.drawCircle(center, 340, paint);

    // Draw subtle intersecting diagonal lines
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), linePaint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
