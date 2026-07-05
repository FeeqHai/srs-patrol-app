import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/command_center_widgets.dart';
import 'admin_equipment_screen.dart';
import 'squad_attendance_assessment_screen.dart';

class SquadShiftScreen extends StatefulWidget {
  const SquadShiftScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<SquadShiftScreen> createState() => _SquadShiftScreenState();
}

class _SquadShiftScreenState extends State<SquadShiftScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasActiveLeaderShift = false;
  String? _errorMessage;
  String? _qrPayload;
  String _qrMode = 'IN';
  int _timeLeft = 0;
  Timer? _timer;
  Map<String, dynamic>? _squad;
  Map<String, dynamic>? _todaySchedule;
  List<Map<String, dynamic>> _pendingReturns = [];
  String? _returnsError;
  final Set<String> _acknowledgingReturnIds = {};

  @override
  void initState() {
    super.initState();
    _loadShiftContext();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadShiftContext() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final responses = await Future.wait([
        ApiClient.getData('schedules/get_user_schedule.php'),
        ApiClient.getData('attendance/check_active_shift.php'),
        ApiClient.getData('attendance/get_pending_returns.php'),
      ]);
      final scheduleResponse = responses[0] as Map<String, dynamic>;
      final activeResponse = responses[1] as Map<String, dynamic>;
      final returnsResponse = responses[2] as Map<String, dynamic>;

      if (scheduleResponse['status'] != 'success') {
        throw Exception(
          scheduleResponse['message'] ?? 'Unable to load squad schedule.',
        );
      }

      final schedules = List<Map<String, dynamic>>.from(
        (scheduleResponse['schedules'] ?? const []).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
      final today = DateTime.now();
      final todayKey =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final todaySchedules = schedules
          .where((schedule) => schedule['shift_date']?.toString() == todayKey)
          .toList();

      final activeScheduleId =
          (activeResponse['data'] as Map<String, dynamic>?)?['schedule_id']
              ?.toString() ??
          activeResponse['schedule_id']?.toString();
      Map<String, dynamic>? activeSchedule;
      if (activeScheduleId != null) {
        for (final schedule in schedules) {
          if (schedule['id']?.toString() == activeScheduleId) {
            activeSchedule = schedule;
            break;
          }
        }
      }
      final hasActiveShift =
          activeResponse['status'] == 'success' &&
          activeResponse['has_active_shift'] == true;
      final displaySchedule =
          activeSchedule ??
          (todaySchedules.isNotEmpty ? todaySchedules.first : null);
      final returns = returnsResponse['status'] == 'success'
          ? List<Map<String, dynamic>>.from(
              (returnsResponse['data'] ?? const []).map(
                (item) => Map<String, dynamic>.from(item),
              ),
            )
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _squad = scheduleResponse['squad'] is Map
            ? Map<String, dynamic>.from(scheduleResponse['squad'])
            : null;
        _todaySchedule = displaySchedule;
        _hasActiveLeaderShift = hasActiveShift && activeSchedule != null;
        _pendingReturns = returns;
        _returnsError = returnsResponse['status'] == 'success'
            ? null
            : returnsResponse['message']?.toString();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _startShift() async {
    await _submitShiftAction(
      endpoint: 'attendance/start_shift.php',
      mode: 'IN',
    );
  }

  Future<void> _endShift() async {
    await _submitShiftAction(endpoint: 'attendance/end_shift.php', mode: 'OUT');
  }

  Future<void> _acknowledgeReturn(Map<String, dynamic> pendingReturn) async {
    final returnId = pendingReturn['id']?.toString() ?? '';
    if (returnId.isEmpty || _acknowledgingReturnIds.contains(returnId)) return;

    setState(() => _acknowledgingReturnIds.add(returnId));
    try {
      final response = await ApiClient.postData(
        'attendance/acknowledge_return.php',
        {'attendance_id': returnId},
      );

      if (!mounted) return;
      final settings = context.read<SettingsProvider>();
      if (response['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ??
                  settings.t('Pemulangan peronda telah disahkan.'),
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _pendingReturns.removeWhere(
            (item) => item['id']?.toString() == returnId,
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ??
                  settings.t('Gagal mengesahkan pemulangan.'),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.read<SettingsProvider>().t('Ralat Rangkaian')}: $error',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _acknowledgingReturnIds.remove(returnId));
      }
    }
  }

  Future<void> _submitShiftAction({
    required String endpoint,
    required String mode,
  }) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final position = await _determinePosition();
      final response = await ApiClient.postData(endpoint, {
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
      });

      if (response['status'] != 'success') {
        throw Exception(response['message'] ?? 'Shift action failed.');
      }

      _startQrTimer((response['expires_in'] as num?)?.toInt() ?? 60);
      if (!mounted) return;
      setState(() {
        _qrPayload = response['qr_payload']?.toString();
        _qrMode = mode;
        _hasActiveLeaderShift = mode == 'IN';
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Berjaya.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _startQrTimer(int seconds) {
    _timer?.cancel();
    _timeLeft = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _qrPayload = null;
          timer.cancel();
        }
      });
    });
  }

  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Sila aktifkan perkhidmatan lokasi (GPS).');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Kebenaran lokasi diperlukan untuk shif rondaan.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Lokasi disekat. Sila benarkan melalui tetapan telefon.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: Text(settings.t('Rondaan Skuad')))
          : null,
      body: RefreshIndicator(
        onRefresh: _loadShiftContext,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            CommandHeader(
              title: settings.t('Rondaan Skuad'),
              subtitle: settings.t(
                'Mulakan shif, rekod kehadiran ketua, dan paparkan QR untuk ahli skuad.',
              ),
              icon: Icons.groups_2_outlined,
              compact: true,
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _buildShiftSummary(settings, theme),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _buildErrorPanel(theme),
              ],
              const SizedBox(height: 12),
              _buildActionPanel(settings, theme),
              if (_returnsError != null) ...[
                const SizedBox(height: 12),
                _buildReturnsErrorPanel(settings, theme),
              ],
              if (_pendingReturns.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildPendingReturnsPanel(settings, theme),
              ],
              if (_qrPayload != null) ...[
                const SizedBox(height: 12),
                _buildQrPanel(settings, theme),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShiftSummary(SettingsProvider settings, ThemeData theme) {
    final squadName =
        _squad?['squad_name']?.toString() ??
        _squad?['name']?.toString() ??
        settings.t('Skuad belum ditetapkan');
    final schedule = _todaySchedule;
    final scheduleText = schedule == null
        ? settings.t('Tiada jadual rondaan hari ini.')
        : '${schedule['start_time']} - ${schedule['end_time']}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: commandCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow(
            icon: Icons.shield_outlined,
            label: settings.t('Skuad/Kampung'),
            value: squadName,
            theme: theme,
          ),
          const SizedBox(height: 10),
          _summaryRow(
            icon: Icons.schedule_outlined,
            label: settings.t('Jadual Hari Ini'),
            value: scheduleText,
            theme: theme,
          ),
          const SizedBox(height: 10),
          _summaryRow(
            icon: _hasActiveLeaderShift
                ? Icons.play_circle_outline
                : Icons.info_outline,
            label: settings.t('Status'),
            value: _hasActiveLeaderShift
                ? settings.t('Shif sedang berjalan')
                : settings.t('Shif belum dimulakan'),
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.65,
                  ),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorPanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.24)),
      ),
      child: Text(
        _errorMessage!,
        style: TextStyle(
          color: theme.brightness == Brightness.dark
              ? Colors.red.shade100
              : Colors.red.shade800,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildActionPanel(SettingsProvider settings, ThemeData theme) {
    final canStart = _todaySchedule != null && !_hasActiveLeaderShift;
    final canEnd = _todaySchedule != null && _hasActiveLeaderShift;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: commandCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: canStart && !_isSubmitting ? _startShift : null,
            icon: _isSubmitting && !_hasActiveLeaderShift
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(settings.t('Mula Shif')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _todaySchedule != null
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SquadAttendanceAssessmentScreen(
                        scheduleId: _todaySchedule?['id']?.toString(),
                      ),
                    ),
                  )
                : null,
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(settings.t('Penilaian Kehadiran')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    title: Text(settings.t('Pengesahan Pemulangan')),
                  ),
                  body: const AdminEquipmentScreen(
                    readOnlyInventory: true,
                    squadLeaderMode: true,
                    initialTabIndex: 2,
                  ),
                ),
              ),
            ).then((_) => _loadShiftContext()),
            icon: const Icon(Icons.assignment_return_outlined),
            label: Text(
              _pendingReturns.isEmpty
                  ? settings.t('Pengesahan Pemulangan')
                  : '${settings.t('Pengesahan Pemulangan')} (${_pendingReturns.length})',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: canEnd && !_isSubmitting ? _startShift : null,
            icon: const Icon(Icons.qr_code_2_rounded),
            label: Text(settings.t('Jana Semula QR Masuk')),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: canEnd && !_isSubmitting ? _endShift : null,
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            icon: _isSubmitting && _hasActiveLeaderShift
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.stop_rounded),
            label: Text(settings.t('Tamat Shif')),
          ),
          if (_qrMode == 'OUT') ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: !_isSubmitting ? _endShift : null,
              icon: const Icon(Icons.assignment_return_outlined),
              label: Text(settings.t('Jana Semula QR Keluar')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQrPanel(SettingsProvider settings, ThemeData theme) {
    final isClockOut = _qrMode == 'OUT';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: commandCardDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isClockOut
                    ? Icons.assignment_return_outlined
                    : Icons.login_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  settings.t(
                    isClockOut ? 'QR Keluar Ahli Skuad' : 'QR Masuk Ahli Skuad',
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${_timeLeft}s',
                style: TextStyle(
                  color: _timeLeft > 15 ? Colors.green : Colors.redAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: _qrPayload!,
              version: QrVersions.auto,
              size: 230,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            settings.t(
              isClockOut
                  ? 'Minta ahli skuad imbas QR ini untuk tamatkan kehadiran.'
                  : 'Minta ahli skuad imbas QR ini untuk mula kehadiran.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnsErrorPanel(SettingsProvider settings, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${settings.t('Pengesahan Pemulangan')}: $_returnsError',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingReturnsPanel(SettingsProvider settings, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: commandCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_return_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  settings.t('Pemulangan Menunggu'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${_pendingReturns.length}',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            settings.t(
              'Sahkan pemulangan peralatan ahli skuad yang telah selesai rondaan.',
            ),
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.68),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ..._pendingReturns.map((pendingReturn) {
            final returnId = pendingReturn['id']?.toString() ?? '';
            final isAcknowledging = _acknowledgingReturnIds.contains(returnId);
            final equipment = List<String>.from(
              pendingReturn['equipment'] ?? const [],
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      pendingReturn['full_name']?.toString() ??
                          settings.t('Peronda'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      equipment.isEmpty
                          ? settings.t('Tiada peralatan dipinjam')
                          : equipment.join(', '),
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.72,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: isAcknowledging
                          ? null
                          : () => _acknowledgeReturn(pendingReturn),
                      icon: isAcknowledging
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.task_alt_rounded),
                      label: Text(settings.t('Sahkan Pemulangan')),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
