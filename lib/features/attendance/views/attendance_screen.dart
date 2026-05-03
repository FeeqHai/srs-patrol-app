// File: lib/features/attendance/views/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/attendance_provider.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? qrData = barcodes.first.rawValue;
      if (qrData != null) {
        setState(() => _isProcessing = true);
        _scannerController.stop();

        // 1. Show the authenticating UI
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            title: Text('Authenticating...'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Acquiring GPS Satellite Lock...'),
              ],
            ),
          ),
        );

        // 2. Get the current logged-in patroller's ID
        final User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CRITICAL ERROR: User session lost.'), backgroundColor: Colors.red),
          );
          setState(() => _isProcessing = false);
          return;
        }

        // 3. Trigger the Anti-Cheat Engine (This will prompt for GPS permissions!)
        final provider = context.read<AttendanceProvider>();
        final bool success = await provider.processQrScan(currentUser.uid, qrData);

        if (!mounted) return;
        Navigator.pop(context); // Close dialog

        // 4. Handle the exact response from Firebase
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SHIFT SECURED: Clock-in verified.', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          // If they are too far away, or the code is fake, show the error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('SCAN REJECTED: ${provider.errorMessage}'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
            ),
          );
        }

        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.amber),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.lightBlueAccent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blueGrey[900],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      _isProcessing ? Icons.gps_fixed : Icons.qr_code_scanner,
                      size: 40,
                      color: _isProcessing ? Colors.orange : Colors.lightBlueAccent
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isProcessing
                        ? 'System Validating Anti-Cheat...'
                        : 'Align KRT QR Code within the frame',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (!_isProcessing)
                    ElevatedButton(
                      onPressed: () => _scannerController.start(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey[700],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('RESTART SCANNER'),
                    )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}