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
import '../../auth/providers/auth_provider.dart';
import '../../incident/views/incident_detail_screen.dart';
import '../../incident/views/lampiran_6_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToScan;

  const DashboardScreen({super.key, required this.onNavigateToScan});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _shiftActive = false;
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
      final response = await ApiClient.getData('schedules/get_user_schedule.php');
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
          if (mounted) {
            setState(() {
              _fullName = data['full_name'] ?? 'Peronda';
              _zoneName = data['zone'] ?? data['district_zone'] ?? '';
            });
          }
        }
      }
    } catch (_) {
      // Keep defaults
    }
  }

  String _getInitials(String name) {
    final names = name.trim().split(" ");
    String initials = "";
    int numWords = names.length > 2 ? 2 : names.length;
    for (var i = 0; i < numWords; i++) {
      if (names[i].isNotEmpty) {
        initials += names[i][0];
      }
    }
    return initials.isEmpty ? "P" : initials.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchSquadInfo();
    _loadShiftData();
    _fetchNoteStatistics();
    _pollSOS();
    _sosDashboardTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollSOS());
  }

  Future<void> _pollSOS() async {
    if (!mounted) return;

    // Only poll SOS if shift is active
    final prefs = await SharedPreferences.getInstance();
    final bool isShiftActive = prefs.getBool('shiftActive') ?? false;
    if (!isShiftActive) {
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
        Uri.parse(ApiConstants.buildApiUrl('incidents/check_sos.php?exclude_user=$currentUserId')),
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

  List<int> _toCountList(dynamic values, int length) {
    if (values is! List) return List.filled(length, 0);

    final counts = values
        .map((value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0)
        .toList();
    if (counts.length == length) return counts;

    return List<int>.generate(
      length,
      (index) => index < counts.length ? counts[index] : 0,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sosDashboardTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadShiftData() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isActive = prefs.getBool('shiftActive') ?? false;

    // Load local state first for instant UI response (premium feel)
    if (isActive) {
      final String? startTimeStr = prefs.getString('shiftStartTime');
      final List<String> eqList = prefs.getStringList('activeEquipment') ?? [];
      if (startTimeStr != null) {
        final DateTime startTime = DateTime.parse(startTimeStr);
        final Duration diff = DateTime.now().difference(startTime);

        if (diff.inHours < 4) {
          setState(() {
            _shiftActive = true;
            _shiftStartTime = startTime;
            _activeEquipment = eqList;
          });
          _startTimer();
        } else {
          setState(() {
            _shiftActive = false;
            _activeEquipment = [];
          });
        }
      }
    } else {
      setState(() {
        _shiftActive = false;
        _activeEquipment = [];
      });
    }

    // Now query server asynchronously to sync and correct the state
    try {
      final response = await ApiClient.getData('attendance/check_active_shift.php');
      if (response['status'] == 'success') {
        final bool hasActiveShift = response['has_active_shift'] ?? false;
        
        if (hasActiveShift) {
          final data = response['data'];
          final String clockInTimeStr = data['clock_in_time'];
          
          DateTime startTime = DateTime.parse(clockInTimeStr);
          final Duration diff = DateTime.now().difference(startTime);

          if (diff.inHours >= 4) {
            // Shift has expired (max 4 hours)
            await prefs.setBool('shiftActive', false);
            await prefs.remove('activeCheckpoint');
            await prefs.remove('shiftStartTime');
            await prefs.remove('activeEquipment');
            setState(() {
              _shiftActive = false;
              _activeEquipment = [];
            });
            _timer?.cancel();
          } else {
            // Keep shift active and update SharedPreferences
            await prefs.setBool('shiftActive', true);
            String rawCheckpoint = data['checkpoint_id'] ?? '';
            String cleanCheckpoint = rawCheckpoint;
            if (rawCheckpoint.startsWith('SRS_ATTENDANCE') || rawCheckpoint.contains('|')) {
              cleanCheckpoint = 'Pos Utama KRT';
            }
            await prefs.setString('activeCheckpoint', cleanCheckpoint);
            await prefs.setString('shiftStartTime', startTime.toIso8601String());
            
            final List<dynamic> eqList = data['equipment'] ?? [];
            final List<String> eqStrings = eqList.map((e) => e.toString()).toList();
            await prefs.setStringList('activeEquipment', eqStrings);
            
            setState(() {
              _shiftActive = true;
              _shiftStartTime = startTime;
              _activeEquipment = eqStrings;
            });
            _startTimer();
          }
        } else {
          // Server says no active shift, clear local state
          await prefs.setBool('shiftActive', false);
          await prefs.remove('activeCheckpoint');
          await prefs.remove('shiftStartTime');
          await prefs.remove('activeEquipment');
          setState(() {
            _shiftActive = false;
            _activeEquipment = [];
          });
          _timer?.cancel();
        }
      }
    } catch (e) {
      // Ignore network errors here to allow offline local fallback
    }
  }

  void _startTimer() {
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
      _elapsedTime = "${twoDigits(diff.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    });
  }

  void _showSquadMembersDialog(BuildContext context, SettingsProvider settings) {
    if (_squad == null || _squad!['members'] == null) return;
    
    final members = _squad!['members'] as List<dynamic>;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.people_outline, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _squad!['squad_name'] ?? settings.t('Kumpulan Rondaan Anda'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: members.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      settings.t('Tiada ahli dalam kumpulan ini.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final name = member['full_name'] ?? '';
                      final phone = member['phone_number'] ?? '';
                      final isLeader = (member['squad_role'] ?? '').toString().toUpperCase() == 'LEADER';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLeader 
                              ? colorScheme.secondary.withValues(alpha: 0.2) 
                              : colorScheme.primary.withValues(alpha: 0.1),
                          child: Icon(
                            isLeader ? Icons.shield : Icons.person,
                            color: isLeader ? colorScheme.secondary : colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(phone),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isLeader 
                                ? colorScheme.secondary.withValues(alpha: 0.15) 
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isLeader 
                                  ? colorScheme.secondary 
                                  : theme.dividerColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            isLeader ? settings.t('Ketua') : settings.t('Ahli (Peranan)'),
                            style: TextStyle(
                              color: isLeader ? colorScheme.secondary : theme.textTheme.bodyMedium?.color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(settings.t('Tutup')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final authProvider = context.read<AuthProvider>();
    final isAdminOrKetua = authProvider.role == 'admin' || 
                           authProvider.role == 'ketua' || 
                           authProvider.role == 'ketua_krt' || 
                           authProvider.role == 'ketua_peronda';
    final isPatrollerOrSquadLeader = authProvider.role == 'peronda' || 
                                     authProvider.role == 'ketua_peronda';

    final hour = DateTime.now().hour;
    String greetingKey = 'Selamat Pagi';
    if (hour >= 12 && hour < 14) {
      greetingKey = 'Selamat Tengah Hari';
    } else if (hour >= 14 && hour < 19) {
      greetingKey = 'Selamat Petang';
    } else if (hour >= 19 || hour < 5) {
      greetingKey = 'Selamat Malam';
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_activeSosList.isNotEmpty)
                _buildSosBanner(),
              
              // Personalized Greeting Header Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${settings.t(greetingKey)},',
                          style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fullName,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      _getInitials(_fullName),
                      style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (isPatrollerOrSquadLeader) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _squad != null ? () => _showSquadMembersDialog(context, settings) : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: theme.brightness == Brightness.dark
                              ? [const Color(0xFF1E3A8A), const Color(0xFF1D4ED8)]
                              : [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.85)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _squad != null ? Icons.shield : Icons.shield_outlined,
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
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _squadName.isNotEmpty ? _squadName : settings.t('Tiada Kumpulan'),
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                                ),
                                if (_squad != null && authProvider.role != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.5), width: 1),
                                    ),
                                    child: Text(
                                      authProvider.role == 'ketua_peronda'
                                          ? settings.t('Ketua Peronda')
                                          : settings.t('Peronda'),
                                      style: TextStyle(
                                        color: theme.colorScheme.secondary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    settings.t('Klik untuk melihat senarai ahli'),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_squad != null) ...[
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.white70,
                              size: 24,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // KPI / Stats Section (3 Columns on Mobile, no Glassmorphism)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.08), shape: BoxShape.circle),
                            child: Icon(Icons.map_outlined, color: theme.primaryColor, size: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            settings.t('Zon Rondaan'),
                            style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _zoneName.isNotEmpty ? _zoneName : settings.t('Tiada'),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), shape: BoxShape.circle),
                            child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            settings.t('Jumlah Nota'),
                            style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_noteCount',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (_shiftActive ? Colors.green : Colors.blueGrey).withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _shiftActive ? Icons.timer_outlined : Icons.directions_walk_outlined,
                              color: _shiftActive ? Colors.green : Colors.blueGrey,
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            settings.t('Status'),
                            style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _shiftActive ? settings.t('Aktif') : settings.t('Sedia'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _shiftActive ? Colors.green : theme.textTheme.bodyLarge?.color,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Shift Action Card (M3 styled glowing CTA container)
              Text(
                settings.t('Status Semasa'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _shiftActive ? Colors.green.withValues(alpha: 0.06) : theme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _shiftActive ? Colors.green.withValues(alpha: 0.3) : theme.primaryColor,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_shiftActive ? Colors.green : theme.primaryColor).withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      _shiftActive ? Icons.shield : Icons.local_police,
                      color: _shiftActive ? Colors.green : Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _shiftActive ? settings.t('Sedang Meronda') : settings.t('Sedia Untuk Rondaan'),
                      style: TextStyle(
                        fontSize: 20,
                        color: _shiftActive ? Colors.green : Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _shiftActive
                          ? _elapsedTime
                          : settings.t('Tekan untuk memulakan rondaan'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _shiftActive ? 32 : 14,
                        fontWeight: _shiftActive ? FontWeight.bold : FontWeight.normal,
                        color: _shiftActive ? theme.textTheme.bodyLarge?.color : Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    if (_shiftActive && _activeEquipment.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 16, color: Colors.green.shade600),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${settings.t("Peralatan")}: ${_activeEquipment.join(", ")}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
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
                        onPressed: widget.onNavigateToScan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _shiftActive ? Colors.redAccent : theme.colorScheme.secondary,
                          foregroundColor: _shiftActive ? Colors.white : Colors.black87,
                          elevation: 2,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _shiftActive
                              ? settings.t('IMBAS QR PULANG')
                              : settings.t('MULAKAN SHIF'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    settings.t('Ringkasan Aktiviti'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color),
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
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${settings.t('Jumlah Nota')}: $_noteCount',
                      style: TextStyle(color: theme.textTheme.titleMedium?.color, fontSize: 16, fontWeight: FontWeight.bold),
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
                            final currentTrendData = isWeekly ? _weeklyCounts : _monthlyCounts;
                            _noteCount = currentTrendData.fold(0, (sum, count) => sum + count);
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
                                      settings.t('Isn'), settings.t('Sel'), settings.t('Rab'), 
                                      settings.t('Kha'), settings.t('Jum'), settings.t('Sab'), settings.t('Aha')
                                    ];
                                    final todayIndex = DateTime.now().weekday - 1;
                                    final startDayIndex = (todayIndex - 6) % 7;
                                    
                                    int displayIndex = (startDayIndex + value.toInt()) % 7;
                                    if (displayIndex < 0) displayIndex += 7;
                                    
                                    if (value.toInt() >= 0 && value.toInt() < 7) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(daysLabels[displayIndex], style: TextStyle(color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7), fontSize: 10)),
                                      );
                                    }
                                  } else {
                                    final today = DateTime.now();
                                    final d = today.subtract(Duration(days: 29 - value.toInt()));
                                    if (value.toInt() >= 0 && value.toInt() < 30) {
                                      if (value.toInt() % 5 != 0 && value.toInt() != 29) {
                                        return const SizedBox();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(DateFormat('d/M').format(d), style: TextStyle(color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7), fontSize: 10)),
                                      );
                                    }
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                _chartPeriod == 'Weekly' ? 7 : 30,
                                (index) => FlSpot(
                                  index.toDouble(),
                                  (_chartPeriod == 'Weekly' ? _weeklyCounts : _monthlyCounts)[index].toDouble(),
                                ),
                              ),
                              isCurved: true,
                              preventCurveOverShooting: true,
                              color: theme.primaryColor,
                              barWidth: 4,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
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
                                color: theme.primaryColor.withValues(alpha: 0.12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isAdminOrKetua) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Lampiran6Screen()),
                      );
                    },
                    icon: const Icon(Icons.analytics),
                    label: Text(
                      settings.t('JANA LAPORAN LAMPIRAN 6'),
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ],
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
                    Text(settings.t('AMARAN KECEMASAN (SOS)'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('${sos['full_name']} ${settings.t('memerlukan bantuan!')}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('${settings.t('Masa')}: ${sos['created_at']}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => IncidentDetailScreen(incident: sos)));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: Text(settings.t('LIHAT LOKASI'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
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
          border: Border.all(color: isDark ? Colors.white30 : Colors.grey.shade400, width: 1),
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
                        ? (isDark ? theme.primaryColor.withValues(alpha: 0.2) : const Color(0xFFE8F0FE)) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.only(
                      topLeft: index == 0 ? const Radius.circular(7) : Radius.zero,
                      bottomLeft: index == 0 ? const Radius.circular(7) : Radius.zero,
                      topRight: isLast ? const Radius.circular(7) : Radius.zero,
                      bottomRight: isLast ? const Radius.circular(7) : Radius.zero,
                    ),
                    border: index > 0 
                        ? Border(left: BorderSide(color: isDark ? Colors.white30 : Colors.grey.shade400, width: 1)) 
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
                          color: isDark ? theme.primaryColor : const Color(0xFF0F3D87)
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected 
                              ? (isDark ? Colors.white : const Color(0xFF0F3D87)) 
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
