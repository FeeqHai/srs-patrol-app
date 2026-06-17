import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  static String? _savedQrData;
  static String _savedLocation = 'Sila jana kod QR.';
  static DateTime? _savedTime;
  static bool _hasBeenGenerated = false;

  String? _qrData;
  String _currentLocation = 'Sila jana kod QR.';
  bool _isLoading = false;
  Timer? _timer;
  int _timeLeft = 60;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _restoreSavedQrState();
  }

  void _restoreSavedQrState() {
    if (_savedQrData != null && _savedTime != null) {
      final elapsed = DateTime.now().difference(_savedTime!).inSeconds;
      if (elapsed < 60) {
        _qrData = _savedQrData;
        _currentLocation = _savedLocation;
        _timeLeft = 60 - elapsed;
        _isLoading = false;
        _startTimer(_timeLeft);
        return;
      }
    }
    // Expired or first load: do not auto-generate, let admin trigger via button
    _qrData = null;
    _currentLocation = _hasBeenGenerated ? _savedLocation : 'Sila jana kod QR.';
    _isLoading = false;
  }

  void _startTimer(int duration) {
    _timeLeft = duration;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _qrData = null;
          _savedQrData = null;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _fetchLocationAndGenerateQR() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      );

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          _currentLocation = '${place.locality}, ${place.administrativeArea}';
        }
      } catch (e) {
        _currentLocation = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      // Generate secure payload
      final timestamp = DateTime.now().toUtc().toIso8601String();
      _qrData = 'SRS_ATTENDANCE|${position.latitude}|${position.longitude}|$timestamp';

      // Save state to static variables
      _savedQrData = _qrData;
      _savedLocation = _currentLocation;
      _savedTime = DateTime.now();
      _hasBeenGenerated = true;

      _startTimer(60);

    } catch (e) {
      if (!mounted) return;
      _currentLocation = '${context.read<SettingsProvider>().t('Gagal mengesan lokasi')}: $e';
      _qrData = null;
      _savedQrData = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.read<SettingsProvider>().t('Ralat GPS:')} $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Premium high-contrast colors for expired warning container
    final errorBg = isDark ? const Color(0xFF3F1919) : const Color(0xFFFEEBEE);
    final errorText = isDark ? const Color(0xFFFFB4AB) : const Color(0xFFC00010);
    final errorSubtext = isDark ? const Color(0xFFF5C2C2) : const Color(0xFF7A1C1C);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header section
          Icon(
            Icons.qr_code_2_rounded,
            size: 48,
            color: theme.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            settings.t('Jana QR Kehadiran'),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: theme.textTheme.headlineMedium?.color,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              settings.t('Papar kod QR ini kepada peronda untuk merekod kehadiran.'),
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 36),

          // Main QR Code Card State
          if (_isLoading)
            SizedBox(
              height: 320,
              child: Center(
                child: CircularProgressIndicator(
                  color: theme.primaryColor,
                  strokeWidth: 3,
                ),
              ),
            )
          else if (_qrData != null)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  )
                ],
              ),
              child: Column(
                children: [
                  // QR Frame wrapper for aesthetics
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: QrImageView(
                      data: _qrData!,
                      version: QrVersions.auto,
                      size: 240.0,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Countdown Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: _timeLeft / 60.0,
                      minHeight: 6,
                      backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _timeLeft > 15 ? theme.primaryColor : Colors.redAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: _timeLeft > 15 ? theme.primaryColor : Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${settings.t('Tamat Tempoh:')} $_timeLeft ${settings.t('saat')}',
                        style: TextStyle(
                          color: _timeLeft > 15 ? theme.primaryColor : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else if (!_isLoading && _qrData == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: errorBg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: errorText.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: errorText.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.timer_off_rounded,
                      color: errorText,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    settings.t('Kod QR Telah Tamat Tempoh'),
                    style: TextStyle(
                      color: errorText,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.t('Sila jana semula kod QR untuk peronda seterusnya.'),
                    style: TextStyle(
                      color: errorSubtext,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Location Info Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Colors.green, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.t('Lokasi Semasa (Pos Utama)'),
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentLocation,
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Regenerate Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: _fetchLocationAndGenerateQR,
              icon: const Icon(Icons.refresh_rounded, size: 22),
              label: Text(
                settings.t('Jana Semula QR'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
