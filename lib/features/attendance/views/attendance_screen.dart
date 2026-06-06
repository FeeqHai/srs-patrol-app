// File: lib/features/attendance/views/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

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
  bool _shiftActive = false;
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
        Navigator.pop(context);

        if (success) {
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
          
          _scannerController?.dispose();
          _scannerController = null;

        } else {
          
          if (provider.errorMessage!.contains('Sila aktifkan') || provider.errorMessage!.contains('kebenaran lokasi')) {
            // MODAL A: Hardware/Location Rejection
            showDialog(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, color: Colors.orange, size: 48),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Lokasi Diperlukan 📍',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Hai! Sistem perlukan akses lokasi (GPS) anda untuk mengesahkan kawasan rondaan. Sila aktifkan tetapan ini untuk memulakan shif.',
                        style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
                        textAlign: TextAlign.center, // DIRECTIVE EXECUTED: Reverted to Center
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                foregroundColor: Colors.white54,
                              ),
                              child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await Geolocator.openLocationSettings();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightBlueAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Buka Tetapan', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            // --- MODAL B UX INTERCEPTION ---
            String friendlyError = provider.errorMessage ?? "Ralat pelayan tidak diketahui.";
            
            // Translate backend strings into human UI
            if (friendlyError.contains('Shift Lockout') || friendlyError.contains('Temporal Lock')) {
              friendlyError = "Anda telah pun merekodkan checkpoint ini untuk shif yang sedang aktif. Anda tidak perlu mengimbasnya dua kali. Sila teruskan rondaan ke lokasi seterusnya.";
            } else if (friendlyError.contains('Unknown Checkpoint')) {
              friendlyError = "Kod QR tidak sah. Sila pastikan anda mengimbas kod QR KRT yang didaftarkan.";
            }

            // MODAL B: System/Temporal Lockout Rejection
            showDialog(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Imbasan Ditolak ⚠️',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        friendlyError, // Directly outputs the friendly translation
                        style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
                        textAlign: TextAlign.center, // DIRECTIVE EXECUTED: Reverted to Center
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Faham & Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          
          setState(() => _isProcessing = false);
          _scannerController?.start();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: Colors.black,
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