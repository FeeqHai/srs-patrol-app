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
import '../../../core/providers/settings_provider.dart';

class AttendanceScreen extends StatefulWidget {
  final VoidCallback onNavigateToDashboard;

  const AttendanceScreen({super.key, required this.onNavigateToDashboard});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  SettingsProvider get settings => Provider.of<SettingsProvider>(context, listen: false);
  MobileScannerController? _scannerController;
  
  bool _isProcessing = false;
  bool _shiftActive = false;
  String _activeCheckpoint = "";
  String _activeLocation = "";
  DateTime? _shiftStartTime;
  List<String> _activeEquipment = [];
  List<dynamic> _inventory = [];
  bool _showEquipmentRecord = true;

  @override
  void initState() {
    super.initState();
    _loadShiftData();
    _initializeScanner();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isActive = prefs.getBool('shiftActive') ?? false;
    if (isActive) return;
    
    if (!mounted) return;
    try {
      final provider = context.read<AttendanceProvider>();
      await provider.fetchEquipment();
      if (mounted) {
        setState(() {
          _inventory = provider.availableEquipment;
        });
      }
    } catch (e) {
      debugPrint("Error loading inventory: $e");
    }
  }

  Future<void> _loadShiftData() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isActive = prefs.getBool('shiftActive') ?? false;
    
    if (isActive) {
      final String? startTimeStr = prefs.getString('shiftStartTime');
      final List<String> eqList = prefs.getStringList('activeEquipment') ?? [];
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
            _activeEquipment = eqList;
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
    await prefs.remove('activeEquipment');
    
    _initializeScanner(); // Reactivate the camera hardware

    setState(() {
      _shiftActive = false;
      _activeEquipment = [];
    });
    
    _loadInventory(); // Reload inventory since shift ended
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
          builder: (context) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: Text(settings.t('Mengesahkan...')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.lightBlueAccent),
                  const SizedBox(height: 16),
                  Text(
                    settings.t('Mendapatkan Kunci Satelit GPS...'),
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            );
          },
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
          if (!mounted) return;
          
          if (provider.errorMessage!.contains('Sila aktifkan') || provider.errorMessage!.contains('kebenaran lokasi')) {
            // MODAL A: Hardware/Location Rejection
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                icon: const Icon(Icons.location_on, color: Colors.orange, size: 48),
                title: Text(settings.t('Lokasi Diperlukan')),
                content: Text(
                  settings.t('Hai! Sistem perlukan akses lokasi (GPS) anda untuk mengesahkan kawasan rondaan. Sila aktifkan tetapan ini untuk memulakan shif.'),
                  textAlign: TextAlign.center,
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _isProcessing = false);
                      _scannerController?.start();
                    },
                    child: Text(settings.t('Batal')),
                  ),
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Geolocator.openLocationSettings();
                      setState(() => _isProcessing = false);
                      _scannerController?.start();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                    child: Text(settings.t('Tetapan')),
                  ),
                ],
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
              friendlyError = settings.t("Anda telah pun merekodkan checkpoint ini untuk shif yang sedang aktif. Anda tidak perlu mengimbasnya dua kali. Sila teruskan rondaan ke lokasi seterusnya.");
              modalTitle = settings.t('Peringatan Shif');
              modalIcon = Icons.info_outline;
              modalColor = Colors.orange;
            } else if (friendlyError.contains('Unknown Checkpoint')) {
              friendlyError = settings.t("Kod QR tidak sah. Sila pastikan anda mengimbas kod QR KRT yang didaftarkan.");
            } else if (friendlyError.contains('tamat tempoh')) {
              friendlyError = settings.t("Kod QR ini telah tamat tempoh pelindungan (60 saat). Sila minta Ketua memaparkan Kod QR yang baharu untuk mengelakkan penipuan tangkapan skrin.");
              modalTitle = settings.t('QR Tamat Tempoh');
              modalIcon = Icons.timer_off;
              modalColor = Colors.orange;
            } else if (friendlyError.contains('terlalu jauh')) {
              friendlyError = settings.t("Sistem Anti-Penipuan mengesan anda tidak berada berdekatan dengan Ketua (Pos Utama). Sila rapat dengan Ketua untuk clock-in.");
              modalTitle = settings.t('Lokasi Tidak Sah');
              modalIcon = Icons.location_off;
              modalColor = Colors.redAccent;
            }

            // MODAL B: System/Temporal Lockout Rejection
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                icon: Icon(modalIcon, color: modalColor, size: 48),
                title: Text(modalTitle),
                content: Text(
                  friendlyError,
                  textAlign: TextAlign.center,
                ),
                actions: [
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _isProcessing = false);
                      _scannerController?.start();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: modalColor,
                    ),
                    child: Text(settings.t('Faham & Tutup')),
                  ),
                ],
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
    final settings = Provider.of<SettingsProvider>(context);
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
                  Text(
                    settings.t('Rondaan Aktif'),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).primaryColor,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${settings.t('Anggaran Tamat Shif')}: $endTimeStr',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                    ),
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.05),
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          _buildInfoRow(Icons.flag, settings.t("Checkpoint"), settings.t(_formatCheckpoint(_activeCheckpoint))),
                          const Divider(height: 32),
                          _buildInfoRow(Icons.my_location, settings.t("GPS Koordinat"), _activeLocation),
                          if (_activeEquipment.isNotEmpty) ...[
                            const Divider(height: 32),
                            _buildInfoRow(Icons.inventory_2_outlined, settings.t("Peralatan"), _activeEquipment.join(", ")),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: widget.onNavigateToDashboard,
                      icon: const Icon(Icons.dashboard_outlined),
                      label: Text(
                        settings.t('KEMBALI KE PAPAN PEMUKA'),
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
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
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.flash_on, color: Colors.white),
                            onPressed: () => _scannerController?.toggleTorch(),
                            style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                                onPressed: () => _scannerController?.switchCamera(),
                                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                              ),
                              const SizedBox(height: 8),
                              IconButton(
                                icon: Icon(
                                  _showEquipmentRecord ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showEquipmentRecord = !_showEquipmentRecord;
                                  });
                                },
                                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!_isProcessing && _inventory.isNotEmpty && _showEquipmentRecord)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, color: Colors.lightBlueAccent, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  settings.t('Peralatan Tersedia'),
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _inventory.map((eq) {
                                final int available = int.parse(eq['available_quantity'].toString());
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Text(
                                    '${eq['item_name']}: $available',
                                    style: TextStyle(
                                      color: available > 0 ? Colors.greenAccent : Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                  ],
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

  String _formatCheckpoint(String rawCheckpoint) {
    if (rawCheckpoint.isEmpty) {
      return 'Pos Utama KRT';
    }
    if (rawCheckpoint.startsWith('SRS_ATTENDANCE') || 
        rawCheckpoint.contains('|') || 
        rawCheckpoint.startsWith('http') || 
        rawCheckpoint.contains('://')) {
      return 'Pos Utama KRT';
    }
    return rawCheckpoint;
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
            final theme = Theme.of(context);
            return AlertDialog(
              icon: const Icon(Icons.inventory_2_outlined, color: Colors.lightBlueAccent, size: 48),
              title: Text(settings.t('Pilih Peralatan')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    settings.t('Tandakan peralatan yang anda ambil dari Pos Utama.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (provider.availableEquipment.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        settings.t('Tiada peralatan direkodkan.'),
                        style: TextStyle(color: theme.disabledColor),
                      ),
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
                              title: Text(
                                eq['item_name'],
                                style: TextStyle(
                                  color: outOfStock ? theme.disabledColor : theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              subtitle: Text(
                                '${settings.t("Tinggal")}: $available',
                                style: TextStyle(
                                  color: outOfStock ? Colors.redAccent : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                ),
                              ),
                              value: isSelected,
                              activeColor: Colors.lightBlueAccent,
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
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _isProcessing = false);
                    _scannerController?.start();
                  },
                  child: Text(settings.t('Batal')),
                ),
                FilledButton(
                  onPressed: provider.isLoading ? null : () async {
                    final navigator = Navigator.of(context);
                    bool ok = await provider.submitEquipmentSelection(selectedEquipment);
                    if (ok && mounted) {
                      navigator.pop(); // Close dialog
                      _finalizeShiftStart(selectedEquipment);
                    }
                  },
                  child: provider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(settings.t('Sahkan & Mula Shif')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _finalizeShiftStart(List<String> selectedEquipmentIds) async {
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
    if (!mounted) return;
    final provider = context.read<AttendanceProvider>();
    final prefs = await SharedPreferences.getInstance();
    
    // Map selected equipment IDs to names
    final List<String> selectedNames = [];
    for (var id in selectedEquipmentIds) {
      final item = provider.availableEquipment.firstWhere((eq) => eq['id'] == id, orElse: () => null);
      if (item != null) {
        selectedNames.add(item['item_name']);
      }
    }
    
    await prefs.setBool('shiftActive', true);
    await prefs.setString('activeCheckpoint', 'Pos Utama KRT');
    await prefs.setString('activeLocation', locationString);
    await prefs.setString('shiftStartTime', now.toIso8601String());
    await prefs.setStringList('activeEquipment', selectedNames);

    if (mounted) {
      setState(() {
        _shiftActive = true;
        _activeCheckpoint = 'Pos Utama KRT';
        _activeLocation = locationString;
        _shiftStartTime = now;
        _activeEquipment = selectedNames;
        _isProcessing = false;
      });
    }
    
    _scannerController?.dispose();
    _scannerController = null;
  }
}