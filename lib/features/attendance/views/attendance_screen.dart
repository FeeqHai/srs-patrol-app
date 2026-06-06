// File: lib/features/attendance/views/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart'; // Required to fetch the lock coordinates

import '../../auth/providers/auth_provider.dart';
import '../providers/attendance_provider.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  MobileScannerController? _scannerController;
  
  bool _isProcessing = false;
  bool _shiftActive = false; // The definitive state lock
  String _activeCheckpoint = "";
  String _activeLocation = "";

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  void _initializeScanner() {
    _scannerController = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _shiftActive) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? qrData = barcodes.first.rawValue;
      if (qrData != null) {
        setState(() => _isProcessing = true);
        _scannerController?.stop();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            backgroundColor: Color(0xFF1E1E1E),
            title: Text('Authenticating...', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.lightBlueAccent),
                SizedBox(height: 16),
                Text('Acquiring GPS Satellite Lock...', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        );

        final String? currentUserId = context.read<AuthProvider>().userId;

        if (currentUserId == null) {
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CRITICAL ERROR: User session lost.'), backgroundColor: Colors.red),
          );
          setState(() => _isProcessing = false);
          _scannerController?.start();
          return;
        }

        final provider = context.read<AttendanceProvider>();
        final bool success = await provider.processQrScan(currentUserId, qrData);

        if (!mounted) return;
        Navigator.pop(context); // Purge dialog

        if (success) {
          // Fetch the exact coordinates utilized for the lock to display on the UI
          Position? position = await Geolocator.getLastKnownPosition();
          String locationString = position != null 
              ? "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}"
              : "GPS Data Secured";

          setState(() {
            _shiftActive = true;
            _activeCheckpoint = qrData;
            _activeLocation = locationString;
            _isProcessing = false;
          });
          
          // Physically destroy the camera sensor to prevent memory leaks or ghost scans
          _scannerController?.dispose();
          _scannerController = null;

        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('SCAN REJECTED: ${provider.errorMessage}'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
            ),
          );
          setState(() => _isProcessing = false);
          _scannerController?.start();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // STATE B: The Shift Dashboard (Camera Unmounted)
    if (_shiftActive) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.greenAccent.withOpacity(0.1),
                  ),
                  child: const Icon(Icons.verified_user, color: Colors.greenAccent, size: 90),
                ),
                const SizedBox(height: 32),
                const Text('MULAKAN SHIF', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.flag, "Checkpoint", _activeCheckpoint),
                        const Divider(color: Colors.white24, height: 32),
                        _buildInfoRow(Icons.my_location, "GPS Koordinat", _activeLocation),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // STATE A: The Hardware Scanner
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Shift Scanner', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          if (_scannerController != null)
            MobileScanner(
              controller: _scannerController!,
              onDetect: _onDetect,
            ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.8), width: 3),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.65), spreadRadius: 10000)
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isProcessing ? Icons.gps_fixed : Icons.qr_code_scanner,
                        color: _isProcessing ? Colors.orange : Colors.lightBlueAccent,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          _isProcessing ? 'System Validating Anti-Cheat...' : 'Align KRT QR Code within the frame',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.lightBlueAccent, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}