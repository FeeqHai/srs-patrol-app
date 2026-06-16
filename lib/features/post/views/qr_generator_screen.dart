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
  String? _qrData;
  String _currentLocation = 'Mengesan lokasi Pos Utama...';
  bool _isLoading = true;
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
    _fetchLocationAndGenerateQR();
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
        // Reverse geocoding failed (sometimes happens on emulators), but we still have coords
        _currentLocation = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      // Generate a secure payload for the QR code (Using UTC to prevent timezone mismatches with server)
      final timestamp = DateTime.now().toUtc().toIso8601String();
      _qrData = 'SRS_ATTENDANCE|${position.latitude}|${position.longitude}|$timestamp';

      // Start the 60-second expiration timer
      _timeLeft = 60;
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
            _qrData = null; // Expire the QR visually
            timer.cancel();
          }
        });
      });

    } catch (e) {
      if (!mounted) return;
      _currentLocation = '${context.read<SettingsProvider>().t('Gagal mengesan lokasi')}: $e';
      _qrData = null;
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            settings.t('Jana QR Kehadiran'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
          ),
          const SizedBox(height: 8),
          Text(
            settings.t('Papar kod QR ini kepada peronda untuk merekod kehadiran.'),
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6), fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          if (_isLoading)
            Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
          else if (_qrData != null)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: _qrData!,
                    version: QrVersions.auto,
                    size: 250.0,
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${settings.t('Tamat Tempoh:')} $_timeLeft ${settings.t('saat')}',
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else if (!_isLoading && _qrData == null)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.redAccent),
              ),
              child: Column(
                children: [
                  const Icon(Icons.timer_off, color: Colors.redAccent, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    settings.t('Kod QR Telah Tamat Tempoh'),
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.t('Sila jana semula kod QR untuk peronda seterusnya.'),
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(settings.t('Lokasi Semasa (Pos Utama)'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6), fontSize: 12)),
                      Text(_currentLocation, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _fetchLocationAndGenerateQR,
              icon: const Icon(Icons.refresh),
              label: Text(settings.t('Jana Semula QR'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          )
        ],
      ),
    );
  }
}
