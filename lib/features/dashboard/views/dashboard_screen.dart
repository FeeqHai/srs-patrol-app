import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/command_center_widgets.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../attendance/views/attendance_book_screen.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../incident/views/incident_detail_screen.dart';
import '../../incident/views/lampiran_6_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToScan;
  final VoidCallback? onNavigateToSchedule;
  final VoidCallback? onNavigateToIncident;
  final VoidCallback? onNavigateToReports;
  final VoidCallback? onSosPressed;

  const DashboardScreen({
    super.key,
    required this.onNavigateToScan,
    this.onNavigateToSchedule,
    this.onNavigateToIncident,
    this.onNavigateToReports,
    this.onSosPressed,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  bool _shiftActive = false;
  bool _pendingAcknowledgement = false;
  String? _pendingAcknowledgementMessage;
  DateTime? _shiftStartTime;
  Timer? _timer;
  String _elapsedTime = "00:00:00";
  int _noteCount = 0;
  List<int> _weeklyCounts = List.filled(7, 0);
  List<int> _monthlyCounts = List.filled(30, 0);
  String _chartPeriod = 'Weekly';
  List<dynamic> _activeSosList = [];
  Timer? _sosDashboardTimer;
  String _fullName = 'Peronda';
  String _zoneName = '';
  String _squadName = '';
  Map<String, dynamic>? _squad;
  List<String> _activeEquipment = [];

  Future<void> _fetchSquadInfo() async {
    try {
      final response = await ApiClient.getData(
        'schedules/get_user_schedule.php',
      );
      if (response['status'] == 'success') {
        final squadData = response['squad'];
        if (mounted) {
          setState(() {
            _squad = squadData;
            _squadName = squadData != null ? squadData['squad_name'] : '';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final Map<String, String> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await http.get(
        Uri.parse(ApiConstants.buildApiUrl('auth/get_profile.php')),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        if (body['status'] == 'success') {
          final data = body['data'];
          if (!mounted) return;
          await context.read<AuthProvider>().updateCurrentUserProfile(
            UserModel.fromJson(data as Map<String, dynamic>),
          );
          if (!mounted) return;
          setState(() {
            _fullName = data['full_name'] ?? 'Peronda';
            _zoneName = data['zone'] ?? data['district_zone'] ?? '';
          });
        }
      }
    } catch (_) {
      // Keep defaults
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserProfile();
    _fetchSquadInfo();
    _loadShiftData();
    _fetchNoteStatistics();
    _pollSOS();
    _sosDashboardTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pollSOS(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadShiftData();
    }
  }

  Future<void> _pollSOS() async {
    if (!mounted) return;

    // Only poll SOS if shift is active
    final prefs = await SharedPreferences.getInstance();
    final bool isShiftActive = prefs.getBool('shiftActive') ?? false;
    final String returnStatus =
        prefs.getString('attendanceReturnStatus') ?? 'ready';
    if (!isShiftActive || returnStatus != 'active') {
      if (_activeSosList.isNotEmpty) {
        setState(() => _activeSosList.clear());
      }
      return;
    }

    if (!mounted) return;
    final currentUserId = context.read<AuthProvider>().userId;
    if (currentUserId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final Map<String, String> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await http.get(
        Uri.parse(
          ApiConstants.buildApiUrl(
            'incidents/check_sos.php?exclude_user=$currentUserId',
          ),
        ),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          if (mounted) {
            setState(() {
              _activeSosList = data['data'] as List<dynamic>;
            });
          }
        }
      }
    } catch (e) {
      // Keep silent on errors
    }
  }

  Future<void> _fetchNoteStatistics() async {
    try {
      final response = await ApiClient.getData('admin/get_stats.php');
      if (response['status'] != 'success') return;

      final data = response['data'] as Map<String, dynamic>;
      final weeklyCounts = _toCountList(data['weekly_note_counts'], 7);
      final monthlyCounts = _toCountList(data['monthly_note_counts'], 30);

      if (mounted) {
        setState(() {
          _weeklyCounts = weeklyCounts;
          _monthlyCounts = monthlyCounts;
          final isWeekly = _chartPeriod == 'Weekly';
          final currentTrendData = isWeekly ? weeklyCounts : monthlyCounts;
          _noteCount = currentTrendData.fold(0, (sum, count) => sum + count);
        });
      }
    } catch (_) {
      // Keep it as 0 if network fails
    }
  }

  Future<void> _refreshDashboard() async {
    await Future.wait([
      _loadShiftData(),
      _fetchNoteStatistics(),
      _fetchSquadInfo(),
      _fetchUserProfile(),
    ]);
    await _pollSOS();
  }

  List<int> _toCountList(dynamic values, int length) {
    if (values is! List) return List.filled(length, 0);

    final counts = values
        .map(
          (value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0,
        )
        .toList();
    if (counts.length == length) return counts;

    return List<int>.generate(
      length,
      (index) => index < counts.length ? counts[index] : 0,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _sosDashboardTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadShiftData() async {
    final attendanceProvider = context.read<AttendanceProvider>();
    final prefs = await SharedPreferences.getInstance();
    final bool isActive = prefs.getBool('shiftActive') ?? false;
    final String cachedReturnStatus =
        prefs.getString('attendanceReturnStatus') ?? 'ready';

    // Cache is only a temporary placeholder until the server responds.
    if (isActive) {
      final String? startTimeStr = prefs.getString('shiftStartTime');
      final List<String> eqList = prefs.getStringList('activeEquipment') ?? [];
      if (startTimeStr != null) {
        final DateTime startTime = DateTime.parse(startTimeStr);

        setState(() {
          _pendingAcknowledgement =
              cachedReturnStatus == 'pending_acknowledgement';
          _shiftActive = cachedReturnStatus == 'active';
          _pendingAcknowledgementMessage = prefs.getString(
            'pendingAcknowledgementMessage',
          );
          _shiftStartTime = startTime;
          _activeEquipment = eqList;
        });
        if (_shiftActive) {
          _startTimer();
        }
      }
    } else {
      setState(() {
        _shiftActive = false;
        _pendingAcknowledgement = false;
        _pendingAcknowledgementMessage = null;
        _activeEquipment = [];
      });
    }

    // Now query server asynchronously to sync and correct the state
    try {
      await attendanceProvider.syncActiveShiftFromServer();
      if (!mounted) return;

      if (attendanceProvider.hasServerShift) {
        setState(() {
          _pendingAcknowledgement = attendanceProvider.isPendingAcknowledgement;
          _shiftActive = attendanceProvider.returnStatus == 'active';
          _pendingAcknowledgementMessage =
              attendanceProvider.pendingAcknowledgementMessage;
          _shiftStartTime = attendanceProvider.clockInTime;
          _activeEquipment = attendanceProvider.borrowedEquipmentNames;
        });
        if (_shiftActive) {
          _startTimer();
        } else {
          _timer?.cancel();
        }
      } else {
        setState(() {
          _shiftActive = false;
          _pendingAcknowledgement = false;
          _pendingAcknowledgementMessage = null;
          _activeEquipment = [];
          _shiftStartTime = null;
        });
        _timer?.cancel();
      }
    } catch (e) {
      // Keep the temporary cache view if the network fails.
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _updateElapsedTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateElapsedTime();
    });
  }

  void _updateElapsedTime() {
    if (_shiftStartTime == null) return;
    final Duration diff = DateTime.now().difference(_shiftStartTime!);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(diff.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(diff.inSeconds.remainder(60));
    setState(() {
      _elapsedTime =
          "${twoDigits(diff.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    });
  }

  void _showSquadMembersDialog(
    BuildContext context,
    SettingsProvider settings,
  ) {
    if (_squad == null || _squad!['members'] == null) return;

    final members = _squad!['members'] as List<dynamic>;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 28,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: size.height * 0.76,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CommandIconBox(
                        icon: Icons.groups_2_outlined,
                        color: colorScheme.primary,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _squad!['squad_name'] ??
                                  settings.t('Kumpulan Rondaan Anda'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${members.length} ${settings.t('Ahli (Peranan)')}',
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.62),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: settings.t('Tutup'),
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: members.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Text(
                              settings.t('Tiada ahli dalam kumpulan ini.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.6),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: members.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final member = members[index];
                              final name = member['full_name'] ?? '';
                              final phone = member['phone_number'] ?? '';
                              final isLeader =
                                  (member['squad_role'] ?? '')
                                      .toString()
                                      .toUpperCase() ==
                                  'LEADER';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.dividerColor.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    UserAvatar(
                                      imageUrl:
                                          member['profile_image_url']
                                              as String?,
                                      initials: UserAvatar.initialsFromName(
                                        name,
                                        fallback: isLeader ? 'KP' : 'P',
                                      ),
                                      radius: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (phone.toString().isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              phone,
                                              style: TextStyle(
                                                color: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color
                                                    ?.withValues(alpha: 0.68),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLeader
                                            ? colorScheme.secondary.withValues(
                                                alpha: 0.14,
                                              )
                                            : theme.dividerColor.withValues(
                                                alpha: 0.08,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isLeader
                                              ? colorScheme.secondary
                                              : theme.dividerColor.withValues(
                                                  alpha: 0.18,
                                                ),
                                        ),
                                      ),
                                      child: Text(
                                        isLeader
                                            ? settings.t('Ketua')
                                            : settings.t('Ahli (Peranan)'),
                                        style: TextStyle(
                                          color: isLeader
                                              ? colorScheme.secondary
                                              : theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color
                                                    ?.withValues(alpha: 0.76),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(settings.t('Tutup')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSquadSummaryCard(
    SettingsProvider settings,
    bool isPatrolLeader,
  ) {
    final theme = Theme.of(context);
    final roleText = isPatrolLeader
        ? settings.t('Ketua Peronda')
        : settings.t('Peronda');
    final locationText = _zoneName.isNotEmpty ? ' • $_zoneName' : '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _squad != null
            ? () => _showSquadMembersDialog(context, settings)
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.brightness == Brightness.dark
                  ? [const Color(0xFF1E3A8A), const Color(0xFF1D4ED8)]
                  : [
                      theme.primaryColor,
                      theme.primaryColor.withValues(alpha: 0.86),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.primaryColor.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.groups_2_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.t('Kumpulan Rondaan Anda'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _squadName.isNotEmpty
                          ? _squadName
                          : settings.t('Tiada Kumpulan'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$roleText$locationText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (_squad != null) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white70,
                  size: 26,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final authProvider = context.read<AuthProvider>();
    final isAdminOrKetua =
        authProvider.role == 'admin' ||
        authProvider.role == 'ketua' ||
        authProvider.role == 'ketua_krt' ||
        authProvider.role == 'ketua_peronda';
    final isPatrollerOrSquadLeader =
        authProvider.role == 'peronda' || authProvider.role == 'ketua_peronda';
    final isPatrolLeader = authProvider.role == 'ketua_peronda';

    final hour = DateTime.now().hour;
    String greetingKey = 'Selamat Pagi';
    if (hour >= 12 && hour < 14) {
      greetingKey = 'Selamat Tengah Hari';
    } else if (hour >= 14 && hour < 19) {
      greetingKey = 'Selamat Petang';
    } else if (hour >= 19 || hour < 5) {
      greetingKey = 'Selamat Malam';
    }

    final statusColor = _pendingAcknowledgement
        ? Colors.orange
        : (_shiftActive ? Colors.green : Colors.blueGrey);
    final statusLabel = _pendingAcknowledgement
        ? settings.t('Menunggu KRT')
        : (_shiftActive ? settings.t('Aktif') : settings.t('Sedia'));
    final cardColor = _pendingAcknowledgement
        ? Colors.orange.withValues(alpha: 0.08)
        : (_shiftActive
              ? Colors.green.withValues(alpha: 0.06)
              : theme.primaryColor);
    final cardForeground = _pendingAcknowledgement
        ? Colors.orange.shade800
        : (_shiftActive ? Colors.green : Colors.white);
    final cardTitle = _pendingAcknowledgement
        ? settings.t('Menunggu Pengesahan Ketua KRT')
        : (_shiftActive
              ? settings.t('Sedang Meronda')
              : settings.t('Sedia Untuk Rondaan'));
    final cardSubtitle = _pendingAcknowledgement
        ? (_pendingAcknowledgementMessage ??
              settings.t(
                'Pemulangan anda telah dihantar. Sila tunggu Ketua KRT mengesahkan penerimaan peralatan.',
              ))
        : (_shiftActive
              ? _elapsedTime
              : settings.t('Tekan untuk memulakan rondaan'));
    final cardActionLabel = _pendingAcknowledgement
        ? settings.t('Semak Status Pemulangan')
        : (_shiftActive
              ? settings.t('IMBAS QR PULANG')
              : settings.t('MULAKAN SHIF'));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_activeSosList.isNotEmpty) _buildSosBanner(),

                _buildCommandHeader(
                  settings: settings,
                  greetingKey: greetingKey,
                  isPatrolLeader: isPatrolLeader,
                ),
                if (isPatrollerOrSquadLeader) ...[
                  const SizedBox(height: 14),
                  _buildSquadSummaryCard(settings, isPatrolLeader),
                ],
                const SizedBox(height: 18),
                _buildCurrentStatusCard(
                  settings: settings,
                  theme: theme,
                  cardColor: cardColor,
                  cardForeground: cardForeground,
                  cardTitle: cardTitle,
                  cardSubtitle: cardSubtitle,
                  cardActionLabel: cardActionLabel,
                ),
                const SizedBox(height: 18),
                _buildRoleQuickActions(settings, isPatrolLeader),
                const SizedBox(height: 18),
                _buildPatrolInsightGrid(
                  settings: settings,
                  statusLabel: statusLabel,
                  statusColor: statusColor,
                  isPatrolLeader: isPatrolLeader,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      settings.t('Ringkasan Aktiviti'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Trend Insiden Graph
                Container(
                  height: 340,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${settings.t('Jumlah Nota')}: $_noteCount',
                        style: TextStyle(
                          color: theme.textTheme.titleMedium?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: _buildRectangularSegmentedToggle(
                          selectedValue: _chartPeriod,
                          options: {
                            'Weekly': settings.t('Mingguan'),
                            'Monthly': settings.t('Bulanan'),
                          },
                          width: double.infinity,
                          onChanged: (value) {
                            setState(() {
                              _chartPeriod = value;
                              final isWeekly = _chartPeriod == 'Weekly';
                              final currentTrendData = isWeekly
                                  ? _weeklyCounts
                                  : _monthlyCounts;
                              _noteCount = currentTrendData.fold(
                                0,
                                (sum, count) => sum + count,
                              );
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            minY: 0,
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    final isWeekly = _chartPeriod == 'Weekly';
                                    if (isWeekly) {
                                      final daysLabels = [
                                        settings.t('Isn'),
                                        settings.t('Sel'),
                                        settings.t('Rab'),
                                        settings.t('Kha'),
                                        settings.t('Jum'),
                                        settings.t('Sab'),
                                        settings.t('Aha'),
                                      ];
                                      final todayIndex =
                                          DateTime.now().weekday - 1;
                                      final startDayIndex =
                                          (todayIndex - 6) % 7;

                                      int displayIndex =
                                          (startDayIndex + value.toInt()) % 7;
                                      if (displayIndex < 0) displayIndex += 7;

                                      if (value.toInt() >= 0 &&
                                          value.toInt() < 7) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8.0,
                                          ),
                                          child: Text(
                                            daysLabels[displayIndex],
                                            style: TextStyle(
                                              color: theme
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withValues(alpha: 0.7),
                                              fontSize: 10,
                                            ),
                                          ),
                                        );
                                      }
                                    } else {
                                      final today = DateTime.now();
                                      final d = today.subtract(
                                        Duration(days: 29 - value.toInt()),
                                      );
                                      if (value.toInt() >= 0 &&
                                          value.toInt() < 30) {
                                        if (value.toInt() % 5 != 0 &&
                                            value.toInt() != 29) {
                                          return const SizedBox();
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8.0,
                                          ),
                                          child: Text(
                                            DateFormat('d/M').format(d),
                                            style: TextStyle(
                                              color: theme
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withValues(alpha: 0.7),
                                              fontSize: 10,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(
                                  _chartPeriod == 'Weekly' ? 7 : 30,
                                  (index) => FlSpot(
                                    index.toDouble(),
                                    (_chartPeriod == 'Weekly'
                                            ? _weeklyCounts
                                            : _monthlyCounts)[index]
                                        .toDouble(),
                                  ),
                                ),
                                isCurved: true,
                                preventCurveOverShooting: true,
                                color: theme.primaryColor,
                                barWidth: 4,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter:
                                      (spot, percent, barData, index) {
                                        return FlDotCirclePainter(
                                          radius: 3,
                                          color: Colors.white,
                                          strokeWidth: 2,
                                          strokeColor: theme.primaryColor,
                                        );
                                      },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: theme.primaryColor.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAdminOrKetua && !isPatrolLeader) ...[
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Lampiran6Screen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.analytics),
                        label: Text(
                          settings.t('JANA LAPORAN LAMPIRAN 6'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AttendanceBookScreen(),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.fact_check_outlined,
                          color: theme.primaryColor,
                        ),
                        label: Text(
                          settings.t('JANA BUKU KEDATANGAN SRS'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.primaryColor,
                          side: BorderSide(color: theme.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSosBanner() {
    final settings = context.watch<SettingsProvider>();
    final sos = _activeSosList.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.15),
        border: Border.all(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emergency, color: Colors.redAccent, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.t('AMARAN KECEMASAN (SOS)'),
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sos['full_name']} ${settings.t('memerlukan bantuan!')}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${settings.t('Masa')}: ${sos['created_at']}',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IncidentDetailScreen(incident: sos),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: Text(
                settings.t('LIHAT LOKASI'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandHeader({
    required SettingsProvider settings,
    required String greetingKey,
    required bool isPatrolLeader,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, const Color(0xFF1E5AB6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.t(greetingKey),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Consumer<AuthProvider>(
                builder: (context, auth, _) => UserAvatar(
                  imageUrl: auth.profileImageUrl,
                  initials: UserAvatar.initialsFromName(
                    auth.fullName ?? _fullName,
                    fallback: isPatrolLeader ? 'KP' : 'P',
                  ),
                  radius: 27,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStatusCard({
    required SettingsProvider settings,
    required ThemeData theme,
    required Color cardColor,
    required Color cardForeground,
    required String cardTitle,
    required String cardSubtitle,
    required String cardActionLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          settings.t('Status Semasa'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleMedium?.color,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _pendingAcknowledgement
                  ? Colors.orange.withValues(alpha: 0.4)
                  : (_shiftActive
                        ? Colors.green.withValues(alpha: 0.3)
                        : theme.primaryColor),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (_pendingAcknowledgement
                            ? Colors.orange
                            : (_shiftActive
                                  ? Colors.green
                                  : theme.primaryColor))
                        .withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                _pendingAcknowledgement
                    ? Icons.hourglass_top
                    : (_shiftActive ? Icons.shield : Icons.local_police),
                color: cardForeground,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                cardTitle,
                style: TextStyle(
                  fontSize: 20,
                  color: cardForeground,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cardSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: _shiftActive ? 32 : 14,
                  fontWeight: _shiftActive
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _shiftActive
                      ? theme.textTheme.bodyLarge?.color
                      : (_pendingAcknowledgement
                            ? theme.textTheme.bodyMedium?.color?.withValues(
                                alpha: 0.75,
                              )
                            : Colors.white.withValues(alpha: 0.8)),
                ),
              ),
              if ((_shiftActive || _pendingAcknowledgement) &&
                  _activeEquipment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${settings.t("Peralatan")}: ${_activeEquipment.join(", ")}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.8,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _pendingAcknowledgement
                      ? _refreshDashboard
                      : widget.onNavigateToScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _shiftActive
                        ? Colors.redAccent
                        : theme.colorScheme.secondary,
                    foregroundColor: _shiftActive
                        ? Colors.white
                        : Colors.black87,
                    elevation: 2,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    cardActionLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleQuickActions(
    SettingsProvider settings,
    bool isPatrolLeader,
  ) {
    final actions = isPatrolLeader
        ? [
            _DashboardActionData(
              label: settings.t('Pengesahan Rondaan'),
              icon: Icons.fact_check_outlined,
              onTap: widget.onNavigateToScan,
            ),
            _DashboardActionData(
              label: settings.t('Laporan Peronda'),
              icon: Icons.folder_shared_outlined,
              onTap: widget.onNavigateToReports ?? widget.onNavigateToIncident,
            ),
            _DashboardActionData(
              label: settings.t('Jadual Rondaan'),
              icon: Icons.calendar_month_outlined,
              onTap: widget.onNavigateToSchedule,
            ),
            _DashboardActionData(
              label: settings.t('JANA LAPORAN LAMPIRAN 6'),
              icon: Icons.analytics_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Lampiran6Screen(),
                  ),
                );
              },
            ),
            _DashboardActionData(
              label: settings.t('AMARAN SOS'),
              icon: Icons.emergency_outlined,
              color: Colors.redAccent,
              onTap: widget.onSosPressed,
            ),
          ]
        : [
            _DashboardActionData(
              label: settings.t('Imbas QR Kehadiran'),
              icon: Icons.qr_code_scanner_rounded,
              onTap: widget.onNavigateToScan,
            ),
            _DashboardActionData(
              label: settings.t('Lapor Insiden'),
              icon: Icons.report_gmailerrorred_outlined,
              onTap: widget.onNavigateToIncident,
            ),
            _DashboardActionData(
              label: settings.t('Jadual Rondaan'),
              icon: Icons.calendar_month_outlined,
              onTap: widget.onNavigateToSchedule,
            ),
            _DashboardActionData(
              label: 'SOS',
              icon: Icons.emergency_rounded,
              color: Colors.redAccent,
              onTap: widget.onSosPressed,
            ),
          ];

    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.flash_on_rounded,
                  color: theme.primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  settings.t('Quick Access'),
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760
                  ? (isPatrolLeader ? 5 : 4)
                  : 2;
              const spacing = 8.0;
              final tileWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: actions
                    .map(
                      (action) => SizedBox(
                        width: tileWidth,
                        child: CommandQuickActionTile(
                          label: action.label,
                          icon: action.icon,
                          onTap: action.onTap,
                          color: action.color,
                          destructive: action.color == Colors.redAccent,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPatrolInsightGrid({
    required SettingsProvider settings,
    required String statusLabel,
    required Color statusColor,
    required bool isPatrolLeader,
  }) {
    final memberCount = (_squad?['members'] as List<dynamic>?)?.length ?? 0;
    final metrics = isPatrolLeader
        ? [
            _PatrolMetricData(
              title: settings.t('Ahli Rondaan'),
              value: '$memberCount',
              caption: settings.t('Dalam skuad anda'),
              icon: Icons.groups_2_outlined,
              color: Theme.of(context).primaryColor,
            ),
            _PatrolMetricData(
              title: settings.t('Hari Ini'),
              value: _squadName.isNotEmpty ? _squadName : '-',
              caption: statusLabel,
              icon: Icons.event_available_outlined,
              color: statusColor,
            ),
            _PatrolMetricData(
              title: settings.t('Laporan'),
              value: '$_noteCount',
              caption: settings.t('Nota perlu perhatian'),
              icon: Icons.assignment_late_outlined,
              color: Colors.orange.shade800,
            ),
            _PatrolMetricData(
              title: settings.t('Pemulangan'),
              value: _activeEquipment.isEmpty
                  ? settings.t('Sedia')
                  : '${_activeEquipment.length}',
              caption: settings.t('Peralatan aktif'),
              icon: Icons.inventory_2_outlined,
              color: Colors.green.shade700,
            ),
          ]
        : [
            _PatrolMetricData(
              title: settings.t('Status Semasa'),
              value: _shiftActive ? _elapsedTime : settings.t('Tiada'),
              caption: statusLabel,
              icon: Icons.timer_outlined,
              color: statusColor,
            ),
            _PatrolMetricData(
              title: settings.t('Status'),
              value: statusLabel,
              caption: settings.t('QR rondaan'),
              icon: Icons.qr_code_scanner_outlined,
              color: statusColor,
            ),
            _PatrolMetricData(
              title: settings.t('Pemulangan'),
              value: _activeEquipment.isEmpty
                  ? settings.t('Sedia')
                  : '${_activeEquipment.length}',
              caption: settings.t('Item dipinjam'),
              icon: Icons.inventory_2_outlined,
              color: Colors.green.shade700,
            ),
            _PatrolMetricData(
              title: settings.t('Laporan Saya'),
              value: '$_noteCount',
              caption: settings.t('Nota terkini'),
              icon: Icons.article_outlined,
              color: Colors.orange.shade800,
            ),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) =>
                    SizedBox(width: width, child: _buildPatrolMetric(metric)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildPatrolMetric(_PatrolMetricData metric) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.032),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(metric.icon, color: metric.color, size: 19),
          ),
          const SizedBox(height: 12),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textTheme.titleMedium?.color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            metric.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.58),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRectangularSegmentedToggle({
    required String selectedValue,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
    double? width,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: width ?? 153,
      height: 36,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white30 : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: Row(
          children: options.entries.map((entry) {
            final isSelected = selectedValue == entry.key;
            final index = options.keys.toList().indexOf(entry.key);
            final isLast = index == options.length - 1;

            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                              ? theme.primaryColor.withValues(alpha: 0.2)
                              : const Color(0xFFE8F0FE))
                        : Colors.transparent,
                    borderRadius: BorderRadius.only(
                      topLeft: index == 0
                          ? const Radius.circular(7)
                          : Radius.zero,
                      bottomLeft: index == 0
                          ? const Radius.circular(7)
                          : Radius.zero,
                      topRight: isLast ? const Radius.circular(7) : Radius.zero,
                      bottomRight: isLast
                          ? const Radius.circular(7)
                          : Radius.zero,
                    ),
                    border: index > 0
                        ? Border(
                            left: BorderSide(
                              color: isDark
                                  ? Colors.white30
                                  : Colors.grey.shade400,
                              width: 1,
                            ),
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isSelected) ...[
                        Icon(
                          Icons.check,
                          size: 14,
                          color: isDark
                              ? theme.primaryColor
                              : const Color(0xFF0F3D87),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? (isDark
                                    ? Colors.white
                                    : const Color(0xFF0F3D87))
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _DashboardActionData {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _DashboardActionData({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });
}

class _PatrolMetricData {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  const _PatrolMetricData({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });
}
