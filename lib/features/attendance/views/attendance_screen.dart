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

class _AttendanceScreenState extends State<AttendanceScreen>
    with WidgetsBindingObserver {
  SettingsProvider get settings =>
      Provider.of<SettingsProvider>(context, listen: false);
  MobileScannerController? _scannerController;

  bool _isProcessing = false;
  bool _isSubmittingReturn = false;
  bool _shiftActive = false;
  bool _returnScannerOpen = false;
  String _returnStatus = 'ready';
  String? _pendingMessage;
  String _activeCheckpoint = "";
  String _activeLocation = "";
  DateTime? _shiftStartTime;
  List<String> _activeEquipment = [];
  List<dynamic> _inventory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadShiftData();
    _initializeScanner();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    if (_returnStatus == 'active' ||
        _returnStatus == 'pending_acknowledgement') {
      return;
    }

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
    final provider = context.read<AttendanceProvider>();
    await provider.syncActiveShiftFromServer();
    if (!mounted) return;

    if (provider.hasServerShift) {
      setState(() {
        _returnStatus = provider.returnStatus;
        _pendingMessage = provider.pendingAcknowledgementMessage;
        _shiftActive = provider.returnStatus == 'active';
        _returnScannerOpen = false;
        _activeCheckpoint = _formatCheckpoint(provider.checkpointId ?? '');
        _activeLocation = 'Pos Utama KRT';
        _shiftStartTime = provider.clockInTime;
        _activeEquipment = provider.borrowedEquipmentNames;
      });
    } else {
      setState(() {
        _returnStatus = 'ready';
        _pendingMessage = null;
        _shiftActive = false;
        _returnScannerOpen = false;
        _activeEquipment = [];
        _shiftStartTime = null;
      });
      _loadInventory();
    }
  }

  void _initializeScanner() {
    if (_scannerController != null) return;
    _scannerController = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  bool get _scannerVisible =>
      mounted &&
      (_returnScannerOpen || (!_shiftActive && _returnStatus == 'ready'));

  Future<void> _stopScanner() async {
    try {
      await _scannerController?.stop();
    } catch (e) {
      debugPrint('Scanner stop ignored: $e');
    }
  }

  Future<void> _startScannerIfVisible() async {
    if (!_scannerVisible) return;
    _initializeScanner();
    try {
      await _scannerController?.start();
    } catch (e) {
      debugPrint('Scanner start ignored: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopScanner();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _loadShiftData();
      _startScannerIfVisible();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? qrData = barcodes.first.rawValue;
      if (qrData != null) {
        if (_shiftActive) {
          await _handleClockOutScan(qrData);
          return;
        }

        final String? currentUserId = context.read<AuthProvider>().userId;
        final provider = context.read<AttendanceProvider>();

        setState(() => _isProcessing = true);
        await _stopScanner();
        if (!mounted) return;

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
                  const CircularProgressIndicator(
                    color: Colors.lightBlueAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    settings.t('Mendapatkan Kunci Satelit GPS...'),
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );

        if (currentUserId == null) {
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CRITICAL ERROR: User session lost.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isProcessing = false);
          await _startScannerIfVisible();
          return;
        }

        final bool success = await provider.processQrScan(
          currentUserId,
          qrData,
        );

        if (!mounted) return;
        Navigator.pop(context);

        if (success) {
          // Fetch equipment before showing dialog
          await provider.fetchEquipment();
          if (!mounted) return;

          await _showEquipmentSelectionDialog(provider);
        } else {
          if (!mounted) return;

          if (provider.errorMessage!.contains('Sila aktifkan') ||
              provider.errorMessage!.contains('kebenaran lokasi')) {
            // MODAL A: Hardware/Location Rejection
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                icon: const Icon(
                  Icons.location_on,
                  color: Colors.orange,
                  size: 48,
                ),
                title: Text(settings.t('Lokasi Diperlukan')),
                content: Text(
                  settings.t(
                    'Hai! Sistem perlukan akses lokasi (GPS) anda untuk mengesahkan kawasan rondaan. Sila aktifkan tetapan ini untuk memulakan shif.',
                  ),
                  textAlign: TextAlign.center,
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (!mounted) return;
                      setState(() => _isProcessing = false);
                      _startScannerIfVisible();
                    },
                    child: Text(settings.t('Batal')),
                  ),
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Geolocator.openLocationSettings();
                      if (!mounted) return;
                      setState(() => _isProcessing = false);
                      _startScannerIfVisible();
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
            String friendlyError =
                provider.errorMessage ?? "Ralat pelayan tidak diketahui.";
            String modalTitle = 'Imbasan Ditolak';
            IconData modalIcon = Icons.error_outline;
            Color modalColor = Colors.redAccent;

            // Translate backend strings into human UI
            if (friendlyError.contains('Shift Lockout') ||
                friendlyError.contains('Temporal Lock')) {
              friendlyError = settings.t(
                "Anda telah pun merekodkan checkpoint ini untuk shif yang sedang aktif. Anda tidak perlu mengimbasnya dua kali. Sila teruskan rondaan ke lokasi seterusnya.",
              );
              modalTitle = settings.t('Peringatan Shif');
              modalIcon = Icons.info_outline;
              modalColor = Colors.orange;
            } else if (friendlyError.contains('Unknown Checkpoint')) {
              friendlyError = settings.t(
                "Kod QR tidak sah. Sila pastikan anda mengimbas kod QR KRT yang didaftarkan.",
              );
            } else if (friendlyError.contains('tamat tempoh')) {
              friendlyError = settings.t(
                "Kod QR ini telah tamat tempoh pelindungan (60 saat). Sila minta Ketua memaparkan Kod QR yang baharu untuk mengelakkan penipuan tangkapan skrin.",
              );
              modalTitle = settings.t('QR Tamat Tempoh');
              modalIcon = Icons.timer_off;
              modalColor = Colors.orange;
            } else if (friendlyError.contains('terlalu jauh')) {
              friendlyError = settings.t(
                "Sistem Anti-Penipuan mengesan anda tidak berada berdekatan dengan Ketua (Pos Utama). Sila rapat dengan Ketua untuk clock-in.",
              );
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
                content: Text(friendlyError, textAlign: TextAlign.center),
                actions: [
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (!mounted) return;
                      setState(() => _isProcessing = false);
                      _startScannerIfVisible();
                    },
                    style: FilledButton.styleFrom(backgroundColor: modalColor),
                    child: Text(settings.t('Faham & Tutup')),
                  ),
                ],
              ),
            );
          }

          if (!mounted) return;
          setState(() => _isProcessing = false);
          await _startScannerIfVisible();
        }
      }
    }
  }

  Future<void> _handleClockOutScan(String qrData) async {
    final provider = context.read<AttendanceProvider>();

    setState(() => _isProcessing = true);
    await _stopScanner();
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.lightBlueAccent),
      ),
    );

    final loaded = await provider.fetchBorrowedEquipment();

    if (!mounted) return;
    Navigator.pop(context);

    if (!loaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ??
                settings.t('Gagal memuatkan peralatan dipinjam.'),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _isProcessing = false);
      await _startScannerIfVisible();
      return;
    }

    await _showEquipmentReturnDialog(provider, qrData);
  }

  Future<void> _showEquipmentReturnDialog(
    AttendanceProvider provider,
    String qrData,
  ) async {
    final returnedEquipment = <String>[];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final borrowedEquipment = provider.borrowedEquipment;
            final allReturned =
                returnedEquipment.length == borrowedEquipment.length;

            return AlertDialog(
              icon: const Icon(
                Icons.assignment_return_outlined,
                color: Colors.lightBlueAccent,
                size: 48,
              ),
              title: Text(settings.t('Sahkan Pemulangan Peralatan')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    settings.t(
                      'Tandakan semua peralatan yang telah diserahkan kepada Ketua KRT.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.t(
                      'Semua peralatan perlu ditanda sebelum tamat syif.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (borrowedEquipment.isEmpty)
                    Text(
                      settings.t('Tiada peralatan dipinjam untuk shif ini.'),
                      textAlign: TextAlign.center,
                    )
                  else
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: borrowedEquipment.map((equipment) {
                            final equipmentId = equipment['id'].toString();
                            final isReturned = returnedEquipment.contains(
                              equipmentId,
                            );
                            return CheckboxListTile(
                              value: isReturned,
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    returnedEquipment.add(equipmentId);
                                  } else {
                                    returnedEquipment.remove(equipmentId);
                                  }
                                });
                              },
                              activeColor: Colors.lightBlueAccent,
                              title: Text(
                                equipment['item_name'] ??
                                    settings.t('Peralatan'),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: provider.isLoading || _isSubmittingReturn
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          if (!mounted) return;
                          setState(() {
                            _isProcessing = false;
                            _isSubmittingReturn = false;
                          });
                          _startScannerIfVisible();
                        },
                  child: Text(settings.t('Batal')),
                ),
                FilledButton(
                  onPressed:
                      !allReturned || provider.isLoading || _isSubmittingReturn
                      ? null
                      : () async {
                          if (_isSubmittingReturn) return;
                          setDialogState(() => _isSubmittingReturn = true);

                          final accepted = await provider.requestClockOut(
                            qrData,
                            returnedEquipment,
                          );
                          if (!dialogContext.mounted) return;

                          if (!accepted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  provider.errorMessage ??
                                      settings.t(
                                        'Pemulangan tidak dapat disahkan.',
                                      ),
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            setDialogState(() => _isSubmittingReturn = false);
                            return;
                          }

                          Navigator.of(dialogContext).pop();
                          WidgetsBinding.instance.addPostFrameCallback((
                            _,
                          ) async {
                            await _stopScanner();
                            await _loadShiftData();
                            if (!mounted) return;
                            setState(() {
                              _isProcessing = false;
                              _isSubmittingReturn = false;
                              _returnScannerOpen = false;
                            });
                          });
                        },
                  child: provider.isLoading || _isSubmittingReturn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(settings.t('Hantar Pemulangan')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    if (_returnStatus == 'pending_acknowledgement') {
      return _buildPendingAcknowledgementView(settings);
    }

    if (_shiftActive && !_returnScannerOpen) {
      final String endTimeStr = _shiftStartTime != null
          ? DateFormat(
              'hh:mm a',
            ).format(_shiftStartTime!.add(const Duration(hours: 4)))
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
                    child: const Icon(
                      Icons.verified_user,
                      color: Colors.greenAccent,
                      size: 90,
                    ),
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
                      side: BorderSide(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.05),
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            Icons.flag,
                            settings.t("Checkpoint"),
                            settings.t(_formatCheckpoint(_activeCheckpoint)),
                          ),
                          const Divider(height: 32),
                          _buildInfoRow(
                            Icons.my_location,
                            settings.t("GPS Koordinat"),
                            _activeLocation,
                          ),
                          if (_activeEquipment.isNotEmpty) ...[
                            const Divider(height: 32),
                            _buildInfoRow(
                              Icons.inventory_2_outlined,
                              settings.t("Peralatan"),
                              _activeEquipment.join(", "),
                            ),
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
                      onPressed: () {
                        _initializeScanner();
                        setState(() => _returnScannerOpen = true);
                        _startScannerIfVisible();
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(
                        settings.t('IMBAS QR PULANG'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    settings.t(
                      'Sila kembali ke pos rondaan untuk imbas QR pulang.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: widget.onNavigateToDashboard,
                      icon: const Icon(Icons.dashboard_outlined),
                      label: Text(
                        settings.t('KEMBALI KE PAPAN PEMUKA'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
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
            MobileScanner(controller: _scannerController!, onDetect: _onDetect),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: Colors.lightBlueAccent.withValues(alpha: 0.8),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    spreadRadius: 10000,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.flash_on, color: Colors.white),
                        onPressed: () => _scannerController?.toggleTorch(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.flip_camera_ios,
                          color: Colors.white,
                        ),
                        onPressed: () => _scannerController?.switchCamera(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_shiftActive &&
                        !_isProcessing &&
                        _inventory.isNotEmpty)
                      InkWell(
                        onTap: _showEquipmentListDialog,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.70,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1E1E1E,
                            ).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.inventory,
                                color: Colors.lightBlueAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  settings.t(
                                    'Click to see available equipment',
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      margin: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        bottom: 24,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isProcessing
                                ? Icons.gps_fixed
                                : Icons.qr_code_scanner,
                            color: _isProcessing
                                ? Colors.orange
                                : Colors.lightBlueAccent,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              _isProcessing
                                  ? settings.t('Sistem sedang mengesahkan...')
                                  : _shiftActive
                                  ? settings.t(
                                      'Imbas QR Clock Out di Pos Utama',
                                    )
                                  : settings.t(
                                      'Imbas QR Clock In KRT untuk mula',
                                    ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  Widget _buildPendingAcknowledgementView(SettingsProvider settings) {
    final theme = Theme.of(context);
    final message =
        _pendingMessage ??
        settings.t(
          'Pemulangan anda telah dihantar. Sila tunggu Ketua KRT mengesahkan penerimaan peralatan.',
        );

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.hourglass_top,
                  color: Colors.orange,
                  size: 86,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                settings.t('Menunggu Pengesahan Ketua KRT'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.72,
                  ),
                ),
              ),
              if (_activeEquipment.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildInfoRow(
                  Icons.inventory_2_outlined,
                  settings.t('Peralatan'),
                  _activeEquipment.join(', '),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          setState(() => _isProcessing = true);
                          await _loadShiftData();
                          if (mounted) {
                            setState(() => _isProcessing = false);
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(settings.t('Semak Status Pemulangan')),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: widget.onNavigateToDashboard,
                  icon: const Icon(Icons.dashboard_outlined),
                  label: Text(settings.t('KEMBALI KE PAPAN PEMUKA')),
                ),
              ),
            ],
          ),
        ),
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
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEquipmentListDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Equipment List',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white12),
            ),
            icon: const Icon(
              Icons.inventory,
              color: Colors.lightBlueAccent,
              size: 48,
            ),
            title: Text(
              settings.t('Peralatan Tersedia'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: _inventory.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      settings.t('Tiada peralatan direkodkan.'),
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  )
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: _inventory.map<Widget>((eq) {
                        final int available = int.parse(
                          eq['available_quantity'].toString(),
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            '${eq['item_name']}: $available',
                            style: TextStyle(
                              color: available > 0
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  settings.t('Tutup'),
                  style: const TextStyle(color: Colors.lightBlueAccent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEquipmentSelectionDialog(
    AttendanceProvider provider,
  ) async {
    List<String> selectedEquipment = [];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              icon: const Icon(
                Icons.inventory_2_outlined,
                color: Colors.lightBlueAccent,
                size: 48,
              ),
              title: Text(settings.t('Pilih Peralatan')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    settings.t(
                      'Tandakan peralatan yang anda ambil dari Pos Utama.',
                    ),
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
                            final bool isSelected = selectedEquipment.contains(
                              eq['id'],
                            );
                            final int available = int.parse(
                              eq['available_quantity'].toString(),
                            );
                            final bool outOfStock = available <= 0;
                            return CheckboxListTile(
                              title: Text(
                                eq['item_name'],
                                style: TextStyle(
                                  color: outOfStock
                                      ? theme.disabledColor
                                      : theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              subtitle: Text(
                                '${settings.t("Tinggal")}: $available',
                                style: TextStyle(
                                  color: outOfStock
                                      ? Colors.redAccent
                                      : theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.6),
                                ),
                              ),
                              value: isSelected,
                              activeColor: Colors.lightBlueAccent,
                              onChanged: outOfStock
                                  ? null
                                  : (bool? val) {
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
                    if (!mounted) return;
                    setState(() => _isProcessing = false);
                    _startScannerIfVisible();
                  },
                  child: Text(settings.t('Batal')),
                ),
                FilledButton(
                  onPressed: provider.isLoading
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          bool ok = await provider.submitEquipmentSelection(
                            selectedEquipment,
                          );
                          if (ok && mounted) {
                            navigator.pop(); // Close dialog
                            _finalizeShiftStart();
                          }
                        },
                  child: provider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
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

  Future<void> _finalizeShiftStart() async {
    Position? position = await Geolocator.getLastKnownPosition();
    String locationString = "GPS Data Secured";

    if (position != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          locationString = '${place.locality}, ${place.administrativeArea}';
        } else {
          locationString =
              "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
        }
      } catch (e) {
        locationString =
            "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
      }
    }

    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeLocation', locationString);
    await _loadShiftData();

    if (mounted) {
      setState(() {
        _activeLocation = locationString;
        _isProcessing = false;
      });
    }
    await _stopScanner();
  }
}
