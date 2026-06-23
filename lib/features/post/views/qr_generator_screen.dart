import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/network/api_client.dart';

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  static String? _savedQrData;
  static String _savedLocation = 'Sila jana kod QR.';
  static DateTime? _savedTime;
  static String _savedQrMode = 'IN';
  static bool _hasBeenGenerated = false;

  String? _qrData;
  String _currentLocation = 'Sila jana kod QR.';
  String _qrMode = 'IN';
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
        _qrMode = _savedQrMode;
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
      _qrData =
          'SRS_ATTENDANCE|$_qrMode|${position.latitude}|${position.longitude}|$timestamp';

      // Save state to static variables
      _savedQrData = _qrData;
      _savedLocation = _currentLocation;
      _savedTime = DateTime.now();
      _savedQrMode = _qrMode;
      _hasBeenGenerated = true;

      _startTimer(60);

    } catch (e) {
      if (!mounted) return;
      final locationMessage = _friendlyLocationError(e);
      debugPrint('Unable to detect QR location: $e');
      _currentLocation = locationMessage;
      _qrData = null;
      _savedQrData = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(locationMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyLocationError(Object error) {
    if (error is TimeoutException) {
      return context.read<SettingsProvider>().t(
        'Lokasi mengambil masa terlalu lama untuk dikesan. Sila cuba semula.',
      );
    }

    final message = error.toString().toLowerCase();
    if (message.contains('services are disabled') ||
        message.contains('service disabled')) {
      return context.read<SettingsProvider>().t(
        'Servis lokasi telefon tidak aktif. Sila hidupkan fungsi lokasi dan cuba semula.',
      );
    }
    if (message.contains('permanently denied') ||
        message.contains('denied forever')) {
      return context.read<SettingsProvider>().t(
        'Kebenaran lokasi telah disekat. Sila benarkan akses lokasi melalui tetapan telefon.',
      );
    }
    if (message.contains('permission') && message.contains('denied')) {
      return context.read<SettingsProvider>().t(
        'Kebenaran lokasi diperlukan untuk menjana QR. Sila benarkan akses lokasi.',
      );
    }
    return context.read<SettingsProvider>().t(
      'Lokasi tidak dapat dikesan. Sila cuba semula.',
    );
  }

  Future<void> _showPendingReturns() async {
    final messenger = ScaffoldMessenger.of(context);
    final response = await ApiClient.getData('attendance/get_pending_returns.php');
    if (!mounted) return;

    if (response['status'] != 'success') {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            response['message'] ??
                context.read<SettingsProvider>().t('Gagal memuatkan pemulangan.'),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final pendingReturns = List<dynamic>.from(response['data'] ?? []);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final sheetSettings = sheetContext.watch<SettingsProvider>();
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sheetSettings.t('Pengesahan Pemulangan'),
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (pendingReturns.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(sheetSettings.t('Tiada pemulangan menunggu pengesahan.')),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pendingReturns.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final pendingReturn = pendingReturns[index] as Map<String, dynamic>;
                        final equipment = List<String>.from(
                          pendingReturn['equipment'] ?? const [],
                        );
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(pendingReturn['full_name'] ?? ''),
                          subtitle: Text(
                            equipment.isEmpty
                                ? sheetSettings.t('Tiada peralatan dipinjam')
                                : equipment.join(', '),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.task_alt_rounded),
                            color: Theme.of(context).colorScheme.primary,
                            tooltip: sheetSettings.t('Sahkan Pemulangan'),
                            onPressed: () async {
                              final acknowledgeResponse = await ApiClient.postData(
                                'attendance/acknowledge_return.php',
                                {'attendance_id': pendingReturn['id'].toString()},
                              );
                              if (!sheetContext.mounted) return;

                              if (acknowledgeResponse['status'] == 'success') {
                                Navigator.pop(sheetContext);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      sheetSettings.t('Pemulangan peronda telah disahkan.'),
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      acknowledgeResponse['message'] ??
                                          sheetSettings.t('Gagal mengesahkan pemulangan.'),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
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
    final isClockOut = _qrMode == 'OUT';

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
            settings.t(isClockOut ? 'Jana QR Clock Out' : 'Jana QR Kehadiran'),
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
              settings.t(
                isClockOut
                    ? 'Papar kod QR ini di pos untuk pengesahan pulang peronda.'
                    : 'Papar kod QR ini kepada peronda untuk merekod kehadiran.',
              ),
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          SegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: 'IN',
                icon: const Icon(Icons.login_rounded),
                label: Text(settings.t('Clock In')),
              ),
              ButtonSegment<String>(
                value: 'OUT',
                icon: const Icon(Icons.assignment_return_outlined),
                label: Text(settings.t('Clock Out')),
              ),
            ],
            selected: {_qrMode},
            onSelectionChanged: _isLoading
                ? null
                : (selected) {
                    final mode = selected.first;
                    if (mode == _qrMode) return;
                    _timer?.cancel();
                    setState(() {
                      _qrMode = mode;
                      _qrData = null;
                      _timeLeft = 60;
                    });
                  },
          ),
          const SizedBox(height: 28),

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
                    settings.t(
                      isClockOut
                          ? 'Sila jana semula kod QR untuk pemulangan seterusnya.'
                          : 'Sila jana semula kod QR untuk peronda seterusnya.',
                    ),
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
                settings.t(isClockOut ? 'Jana QR Clock Out' : 'Jana Semula QR'),
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
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _showPendingReturns,
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(settings.t('Pengesahan Pemulangan')),
          ),
        ],
      ),
    );
  }
}
