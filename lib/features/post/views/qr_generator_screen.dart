import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/command_center_widgets.dart';
import '../../auth/providers/auth_provider.dart';

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

  Future<void> _fetchLocationAndGenerateQR({String? mode}) async {
    if (mode != null) {
      _qrMode = mode;
    }
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          _currentLocation = '${place.locality}, ${place.administrativeArea}';
        }
      } catch (e) {
        _currentLocation =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
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

  Future<void> _handleQrAction(String mode) async {
    if (_isLoading) return;

    final settings = context.read<SettingsProvider>();
    final hasRunningQr = _qrData != null && _timeLeft > 0;
    if (hasRunningQr) {
      final isSameMode = mode == _qrMode;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            settings.t(isSameMode ? 'Jana semula QR?' : 'Tukar mod QR?'),
          ),
          content: Text(
            settings.t(
              isSameMode
                  ? 'QR semasa masih aktif. Jana semula akan membatalkan kod yang sedang berjalan.'
                  : 'QR semasa masih aktif. Menukar mod akan membatalkan kod yang sedang berjalan.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(settings.t('Batal')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(settings.t('Teruskan')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    _timer?.cancel();
    setState(() {
      _qrMode = mode;
      _qrData = null;
      _timeLeft = 60;
    });
    await _fetchLocationAndGenerateQR(mode: mode);
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
    final response = await ApiClient.getData(
      'attendance/get_pending_returns.php',
    );
    if (!mounted) return;

    if (response['status'] != 'success') {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            response['message'] ??
                context.read<SettingsProvider>().t(
                  'Gagal memuatkan pemulangan.',
                ),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final pendingReturns = List<Map<String, dynamic>>.from(
      (response['data'] ?? []).map((item) => Map<String, dynamic>.from(item)),
    );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final sheetSettings = sheetContext.watch<SettingsProvider>();
        String? acknowledgingId;

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
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
                      style: Theme.of(sheetContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    if (pendingReturns.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            sheetSettings.t(
                              'Tiada pemulangan menunggu pengesahan.',
                            ),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: pendingReturns.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final pendingReturn = pendingReturns[index];
                            final returnId = pendingReturn['id'].toString();
                            final isAcknowledging = acknowledgingId == returnId;
                            final equipment = List<String>.from(
                              pendingReturn['equipment'] ?? const [],
                            );

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(pendingReturn['full_name'] ?? ''),
                              subtitle: Text(
                                equipment.isEmpty
                                    ? sheetSettings.t(
                                        'Tiada peralatan dipinjam',
                                      )
                                    : equipment.join(', '),
                              ),
                              trailing: IconButton(
                                icon: isAcknowledging
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.task_alt_rounded),
                                color: Theme.of(context).colorScheme.primary,
                                tooltip: sheetSettings.t('Sahkan Pemulangan'),
                                onPressed: acknowledgingId != null
                                    ? null
                                    : () async {
                                        setSheetState(() {
                                          acknowledgingId = returnId;
                                        });
                                        final acknowledgeResponse =
                                            await ApiClient.postData(
                                              'attendance/acknowledge_return.php',
                                              {'attendance_id': returnId},
                                            );
                                        if (!sheetContext.mounted) return;

                                        if (acknowledgeResponse['status'] ==
                                            'success') {
                                          setSheetState(() {
                                            pendingReturns.removeAt(index);
                                            acknowledgingId = null;
                                          });
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                sheetSettings.t(
                                                  'Pemulangan telah disahkan.',
                                                ),
                                              ),
                                            ),
                                          );
                                        } else {
                                          setSheetState(() {
                                            acknowledgingId = null;
                                          });
                                          ScaffoldMessenger.of(
                                            sheetContext,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                acknowledgeResponse['message'] ??
                                                    sheetSettings.t(
                                                      'Gagal mengesahkan pemulangan.',
                                                    ),
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
      },
    );
  }

  Widget _buildQrInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.62,
                ),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrActionButton({
    required String mode,
    required String label,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final selected = _qrMode == mode;
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : () => _handleQrAction(mode),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 42),
          foregroundColor: selected ? Colors.black87 : theme.primaryColor,
          backgroundColor: selected
              ? CommandColors.accentYellow
              : theme.cardColor,
          side: BorderSide(
            color: selected ? Colors.black87 : theme.primaryColor,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildQrGenerationPanel({
    required SettingsProvider settings,
    required AuthProvider auth,
    required ThemeData theme,
    required bool isDark,
    required bool isClockOut,
    required double qrSize,
    required Color errorBg,
    required Color errorText,
    required Color errorSubtext,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: commandCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Location Card (Replaces QR Generation Title) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2838) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: theme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.zoneName ?? settings.t('Kawasan Rondaan'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _currentLocation,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQrInfoChip(
                  icon: isClockOut
                      ? Icons.assignment_return_outlined
                      : Icons.login_rounded,
                  label: settings.t('Mod QR'),
                  value: isClockOut ? 'OUT' : 'IN',
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQrInfoChip(
                  icon: Icons.timer_outlined,
                  label: settings.t('Tempoh'),
                  value: _qrData == null ? '60s' : '${_timeLeft}s',
                  color: _timeLeft > 15
                      ? CommandColors.success
                      : CommandColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildQrActionButton(
                mode: 'IN',
                label: settings.t('Clock In'),
                icon: Icons.login_rounded,
              ),
              const SizedBox(width: 8),
              _buildQrActionButton(
                mode: 'OUT',
                label: settings.t('Clock Out'),
                icon: Icons.assignment_return_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _isLoading
                ? Container(
                    key: const ValueKey('qr-loading'),
                    height: 240,
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: theme.primaryColor,
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : _qrData != null
                ? Container(
                    key: const ValueKey('qr-active'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: theme.primaryColor.withValues(alpha: 0.08),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.25 : 0.05,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: _qrData!,
                            version: QrVersions.auto,
                            size: qrSize.toDouble(),
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
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: LinearProgressIndicator(
                            value: _timeLeft / 60.0,
                            minHeight: 7,
                            backgroundColor: theme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _timeLeft > 15
                                  ? theme.primaryColor
                                  : Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    key: ValueKey(
                      _hasBeenGenerated ? 'qr-expired' : 'qr-ready',
                    ),
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _hasBeenGenerated
                          ? errorBg
                          : theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _hasBeenGenerated
                            ? errorText.withValues(alpha: 0.2)
                            : theme.dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        CommandIconBox(
                          icon: _hasBeenGenerated
                              ? Icons.timer_off_rounded
                              : Icons.qr_code_scanner_rounded,
                          color: _hasBeenGenerated
                              ? errorText
                              : theme.primaryColor,
                          size: 54,
                          iconSize: 28,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          settings.t(
                            _hasBeenGenerated
                                ? 'Kod QR Telah Tamat Tempoh'
                                : 'Sedia Menjana Kod QR',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _hasBeenGenerated
                                ? errorText
                                : theme.textTheme.titleMedium?.color,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          settings.t(
                            _hasBeenGenerated
                                ? (isClockOut
                                      ? 'Sila jana semula kod QR untuk pemulangan seterusnya.'
                                      : 'Sila jana semula kod QR untuk peronda seterusnya.')
                                : 'Tekan Clock In atau Clock Out untuk menjana QR 60 saat.',
                          ),
                          style: TextStyle(
                            color: _hasBeenGenerated
                                ? errorSubtext
                                : theme.textTheme.bodyMedium?.color?.withValues(
                                    alpha: 0.66,
                                  ),
                            fontWeight: FontWeight.w500,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnAcknowledgementPanel({
    required SettingsProvider settings,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: commandCardDecoration(context),
      child: Row(
        children: [
          CommandIconBox(
            icon: Icons.fact_check_outlined,
            color: theme.primaryColor,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.t('Pengesahan Pemulangan'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textTheme.titleMedium?.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  settings.t('Patrol returns are awaiting acknowledgement.'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.66,
                    ),
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _showPendingReturns,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.primaryColor,
              side: BorderSide(color: theme.primaryColor),
              minimumSize: const Size(88, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              settings.t('Lihat'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final errorBg = isDark ? const Color(0xFF3F1919) : const Color(0xFFFEEBEE);
    final errorText = isDark
        ? const Color(0xFFFFB4AB)
        : const Color(0xFFC00010);
    final errorSubtext = isDark
        ? const Color(0xFFF5C2C2)
        : const Color(0xFF7A1C1C);
    final isClockOut = _qrMode == 'OUT';
    final isSquadLeader = auth.role == 'ketua_peronda';

    return LayoutBuilder(
      builder: (context, constraints) {
        final qrSize = (constraints.maxWidth - 96).clamp(176.0, 240.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CommandHeader(
                    title: settings.t(
                      isSquadLeader
                          ? (isClockOut
                                ? 'Jana QR Clock Out Skuad'
                                : 'Jana QR Kehadiran Skuad')
                          : (isClockOut
                                ? 'Jana QR Clock Out'
                                : 'Jana QR Kehadiran'),
                    ),
                    subtitle: settings.t(
                      isSquadLeader
                          ? (isClockOut
                                ? 'Papar kod QR pemulangan di pos rondaan skuad dan sahkan peralatan selepas rondaan.'
                                : 'Papar kod QR ini kepada ahli skuad untuk merekod kehadiran rondaan.')
                          : (isClockOut
                                ? 'Papar kod QR pemulangan di pos rondaan dan sahkan peralatan selepas rondaan.'
                                : 'Papar kod QR ini kepada peronda untuk merekod kehadiran rondaan.'),
                    ),
                    icon: Icons.qr_code_2_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildQrGenerationPanel(
                    settings: settings,
                    auth: auth,
                    theme: theme,
                    isDark: isDark,
                    isClockOut: isClockOut,
                    qrSize: qrSize,
                    errorBg: errorBg,
                    errorText: errorText,
                    errorSubtext: errorSubtext,
                  ),
                  if (isClockOut) ...[
                    const SizedBox(height: 12),
                    _buildReturnAcknowledgementPanel(
                      settings: settings,
                      theme: theme,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
