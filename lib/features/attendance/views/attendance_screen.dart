// File: lib/features/attendance/views/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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
  DateTime? _shiftStartTime;

  @override
  void initState() {
    super.initState();
    _loadShiftData();
    _initializeScanner();
  }

  Future<void> _loadShiftData() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isActive = prefs.getBool('shiftActive') ?? false;
    
    if (isActive) {
      final String? startTimeStr = prefs.getString('shiftStartTime');
      if (startTimeStr != null) {
        final DateTime startTime = DateTime.parse(startTimeStr);
        final Duration diff = DateTime.now().difference(startTime);
        
        // Check if 4 hours have passed
        if (diff.inHours >= 4) {
          await _clearShiftData();
        } else {
          setState(() {
            _shiftActive = true;
            _activeCheckpoint = prefs.getString('activeCheckpoint') ?? "";
            _activeLocation = prefs.getString('activeLocation') ?? "";
            _shiftStartTime = startTime;
          });
        }
      }
    }
  }

  Future<void> _clearShiftData({bool callApi = true}) async {
    if (callApi) {
      final String? currentUserId = context.read<AuthProvider>().userId;
      if (currentUserId != null) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
        );
        await context.read<AttendanceProvider>().clockOut(currentUserId);
        if (mounted) Navigator.pop(context);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('shiftActive');
    await prefs.remove('activeCheckpoint');
    await prefs.remove('activeLocation');
    await prefs.remove('shiftStartTime');
    
    _initializeScanner(); // Reactivate the camera hardware

    setState(() {
      _shiftActive = false;
    });
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
          builder: (context) => AlertDialog(
            title: const Text('Authenticating...'),
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
          // Fetch equipment before showing dialog
          await provider.fetchEquipment();
          if (!mounted) return;
          
          await _showEquipmentSelectionDialog(provider);
        } else {
          
          if (provider.errorMessage!.contains('Sila aktifkan') || provider.errorMessage!.contains('kebenaran lokasi')) {
            // MODAL A: Hardware/Location Rejection
            showDialog(
              context: context,
              builder: (context) => Dialog(
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
                          color: Colors.orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, color: Colors.orange, size: 48),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Lokasi Diperlukan',
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
                              onPressed: () {
                                Navigator.pop(context);
                                setState(() => _isProcessing = false);
                                _scannerController?.start();
                              },
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
                                setState(() => _isProcessing = false);
                                _scannerController?.start();
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
            String modalTitle = 'Imbasan Ditolak';
            IconData modalIcon = Icons.error_outline;
            Color modalColor = Colors.redAccent;
            
            // Translate backend strings into human UI
            if (friendlyError.contains('Shift Lockout') || friendlyError.contains('Temporal Lock')) {
              friendlyError = "Anda telah pun merekodkan checkpoint ini untuk shif yang sedang aktif. Anda tidak perlu mengimbasnya dua kali. Sila teruskan rondaan ke lokasi seterusnya.";
              modalTitle = 'Peringatan Shif';
              modalIcon = Icons.info_outline;
              modalColor = Colors.orangeAccent;
            } else if (friendlyError.contains('Unknown Checkpoint')) {
              friendlyError = "Kod QR tidak sah. Sila pastikan anda mengimbas kod QR KRT yang didaftarkan.";
            } else if (friendlyError.contains('tamat tempoh')) {
              friendlyError = "Kod QR ini telah tamat tempoh pelindungan (60 saat). Sila minta Ketua memaparkan Kod QR yang baharu untuk mengelakkan penipuan tangkapan skrin.";
              modalTitle = 'QR Tamat Tempoh';
              modalIcon = Icons.timer_off;
              modalColor = Colors.orange;
            } else if (friendlyError.contains('terlalu jauh')) {
              // Extract the distance from the backend message if possible
              friendlyError = "${friendlyError.replaceAll('Clock-in ditolak: ', '')}\n\nSistem Anti-Penipuan mengesan anda tidak berada berdekatan dengan Ketua (Pos Utama).";
              modalTitle = 'Lokasi Tidak Sah';
              modalIcon = Icons.location_off;
              modalColor = Colors.redAccent;
            }

            // MODAL B: System/Temporal Lockout Rejection
            showDialog(
              context: context,
              builder: (context) => Dialog(
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
                          color: modalColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(modalIcon, color: modalColor, size: 48),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        modalTitle,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
      final String endTimeStr = _shiftStartTime != null 
          ? DateFormat('hh:mm a').format(_shiftStartTime!.add(const Duration(hours: 4)))
          : "TBA";

      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.greenAccent.withValues(alpha: 0.1),
                    ),
                    child: const Icon(Icons.verified_user, color: Colors.greenAccent, size: 90),
                  ),
                  const SizedBox(height: 32),
                  const Text('MULAKAN SHIF', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Text('Anggaran Tamat Shif: $endTimeStr', style: const TextStyle(fontSize: 16, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Card(
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
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: () => _clearShiftData(callApi: true),
                    icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
                    label: const Text('Tamatkan Shif Awal', style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  )
                ],
              ),
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
                border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.8), width: 3),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.65), spreadRadius: 10000)
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.flash_on, color: Colors.white),
                        onPressed: () => _scannerController?.toggleTorch(),
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      ),
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                        onPressed: () => _scannerController?.switchCamera(),
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
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
              Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showEquipmentSelectionDialog(AttendanceProvider provider) async {
    List<String> selectedEquipment = [];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: const Color(0xFF1E1E1E),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: Colors.lightBlueAccent, size: 48),
                    const SizedBox(height: 16),
                    const Text('Pilih Peralatan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text('Tandakan peralatan yang anda ambil dari Pos Utama.', 
                      style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    
                    if (provider.availableEquipment.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Tiada peralatan direkodkan.', style: TextStyle(color: Colors.white54)),
                      )
                    else
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: provider.availableEquipment.map((eq) {
                              final bool isSelected = selectedEquipment.contains(eq['id']);
                              final int available = int.parse(eq['available_quantity'].toString());
                              final bool outOfStock = available <= 0;
                              return CheckboxListTile(
                                title: Text(eq['item_name'], style: TextStyle(color: outOfStock ? Colors.white30 : Colors.white)),
                                subtitle: Text('Tinggal: $available', style: TextStyle(color: outOfStock ? Colors.redAccent : Colors.white54)),
                                value: isSelected,
                                activeColor: Colors.lightBlueAccent,
                                checkColor: Colors.black,
                                selectedTileColor: Colors.lightBlueAccent.withValues(alpha: 0.1),
                                onChanged: outOfStock ? null : (bool? val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selectedEquipment.add(eq['id']);
                                    } else {
                                      selectedEquipment.remove(eq['id']);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: provider.isLoading ? null : () async {
                          // Capture navigator to avoid use_build_context_synchronously
                          final navigator = Navigator.of(context);
                          
                          // Submit equipment
                          bool ok = await provider.submitEquipmentSelection(selectedEquipment);
                          if (ok && mounted) {
                            navigator.pop(); // Close dialog
                            _finalizeShiftStart();
                          }
                        },
                        child: provider.isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : const Text('Sahkan & Mula Shif', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _finalizeShiftStart() async {
    Position? position = await Geolocator.getLastKnownPosition();
    String locationString = "GPS Data Secured";
    
    if (position != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          locationString = '${place.locality}, ${place.administrativeArea}';
        } else {
          locationString = "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
        }
      } catch (e) {
        locationString = "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
      }
    }

    final DateTime now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shiftActive', true);
    await prefs.setString('activeCheckpoint', 'Pos Utama KRT');
    await prefs.setString('activeLocation', locationString);
    await prefs.setString('shiftStartTime', now.toIso8601String());

    if (mounted) {
      setState(() {
        _shiftActive = true;
        _activeCheckpoint = 'Pos Utama KRT';
        _activeLocation = locationString;
        _shiftStartTime = now;
        _isProcessing = false;
      });
    }
    
    _scannerController?.dispose();
    _scannerController = null;
  }
}