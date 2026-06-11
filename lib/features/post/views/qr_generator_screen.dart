import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

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
      _currentLocation = 'Gagal mengesan lokasi ($e). Sila semak GPS.';
      _qrData = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ralat GPS: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Jana QR Kehadiran',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Papar kod QR ini kepada peronda untuk merekod kehadiran.',
            style: TextStyle(color: Colors.white54, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          if (_isLoading)
            const CircularProgressIndicator(color: Colors.indigoAccent)
          else if (_qrData != null)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))
                ],
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: _qrData!,
                    version: QrVersions.auto,
                    size: 250.0,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Tamat Tempoh: $_timeLeft saat',
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
              child: const Column(
                children: [
                  Icon(Icons.timer_off, color: Colors.redAccent, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Kod QR Telah Tamat Tempoh',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sila jana semula kod QR untuk peronda seterusnya.',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lokasi Semasa (Pos Utama)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      Text(_currentLocation, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              label: const Text('Jana Semula QR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          )
        ],
      ),
    );
  }
}
