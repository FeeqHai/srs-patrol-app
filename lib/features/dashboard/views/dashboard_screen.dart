import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../incident/services/incident_service.dart';
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
  int _incidentCount = 0;
  List<dynamic> _allIncidents = [];
  String _incidentFilter = 'Semua';
  List<int> _weeklyCounts = List.filled(7, 0);
  List<dynamic> _activeSosList = [];
  Timer? _sosDashboardTimer;
  String _fullName = 'Peronda';
  String _zoneName = '';
  List<String> _activeEquipment = [];

  Future<void> _fetchUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final Map<String, String> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}auth/get_profile.php'),
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

  int _calculateFilteredIncidents(List<dynamic> incidents, String filter) {
    if (filter == 'Semua') return incidents.length;
    
    final now = DateTime.now();
    int count = 0;
    for (var inc in incidents) {
      if (inc['created_at'] != null) {
        try {
          final date = DateTime.parse(inc['created_at']);
          if (filter == 'Harian') {
            if (date.year == now.year && date.month == now.month && date.day == now.day) count++;
          } else if (filter == 'Mingguan') {
            final diff = now.difference(date).inDays;
            if (diff >= 0 && diff <= 7) count++;
          } else if (filter == 'Bulanan') {
            if (date.year == now.year && date.month == now.month) count++;
          }
        } catch (_) {}
      }
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _loadShiftData();
    _fetchIncidentCount();
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
        Uri.parse('${ApiConstants.baseUrl}incidents/check_sos.php?exclude_user=$currentUserId'),
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

  Future<void> _fetchIncidentCount() async {
    try {
      final currentUserId = context.read<AuthProvider>().userId;
      final IncidentService service = IncidentService();
      final incidents = await service.fetchAllIncidents(patrollerId: currentUserId);
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      List<int> counts = List.filled(7, 0);
      
      for (var inc in incidents) {
        if (inc['created_at'] != null) {
          try {
            final date = DateTime.parse(inc['created_at']);
            final incDay = DateTime(date.year, date.month, date.day);
            final diff = today.difference(incDay).inDays;
            if (diff >= 0 && diff < 7) {
              int index = 6 - diff;
              counts[index]++;
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _allIncidents = incidents;
          _weeklyCounts = counts;
          _incidentCount = _calculateFilteredIncidents(_allIncidents, _incidentFilter);
        });
      }
    } catch (e) {
      // Keep it as 0 if network fails
    }
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final authProvider = context.read<AuthProvider>();
    final isAdminOrKetua = authProvider.role == 'admin' || 
                           authProvider.role == 'ketua' || 
                           authProvider.role == 'ketua_krt' || 
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
                            settings.t('Laporan Saya'),
                            style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_allIncidents.length}',
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
                        fontFamily: _shiftActive ? 'Courier' : null,
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
                    // Clickable Button inside container
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _shiftActive
                            ? () async {
                                final auth = context.read<AuthProvider>();
                                final currentUserId = auth.userId;
                                final messenger = ScaffoldMessenger.of(context);
                                final sProvider = context.read<SettingsProvider>();
                                final attProvider = context.read<AttendanceProvider>();
                                final navigator = Navigator.of(context);
                                
                                if (currentUserId != null) {
                                  // Show progress indicator dialog
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(
                                      child: CircularProgressIndicator(color: Colors.redAccent),
                                    ),
                                  );
                                  
                                  final bool success = await attProvider.clockOut(currentUserId);
                                  
                                  if (mounted) {
                                    navigator.pop(); // Close loading dialog
                                  }
                                  
                                  if (success) {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setBool('shiftActive', false);
                                    await prefs.remove('activeCheckpoint');
                                    await prefs.remove('shiftStartTime');
                                    await prefs.remove('activeLocation');
                                    await prefs.remove('activeEquipment');
                                    if (mounted) {
                                      setState(() {
                                        _shiftActive = false;
                                        _activeEquipment = [];
                                      });
                                      _timer?.cancel();
                                      messenger.showSnackBar(
                                        SnackBar(content: Text(sProvider.t('Shif rondaan ditamatkan.'))),
                                      );
                                    }
                                  } else {
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('${sProvider.t("Ralat")}: ${attProvider.errorMessage ?? "Gagal menamatkan shif."}')),
                                      );
                                    }
                                  }
                                }
                              }
                            : widget.onNavigateToScan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _shiftActive ? Colors.redAccent : theme.colorScheme.secondary,
                          foregroundColor: _shiftActive ? Colors.white : Colors.black87,
                          elevation: 2,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _shiftActive ? settings.t('Tamatkan Rondaan') : settings.t('MULAKAN SHIF'),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'Harian', label: Text(settings.t('Harian'), style: const TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'Mingguan', label: Text(settings.t('Mingguan'), style: const TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'Bulanan', label: Text(settings.t('Bulanan'), style: const TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'Semua', label: Text(settings.t('Semua'), style: const TextStyle(fontSize: 12))),
                  ],
                  selected: {_incidentFilter},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _incidentFilter = newSelection.first;
                      _incidentCount = _calculateFilteredIncidents(_allIncidents, newSelection.first);
                    });
                  },
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: theme.primaryColor,
                    selectedForegroundColor: Colors.white,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Trend Insiden Graph
              Container(
                height: 250,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(settings.t('Jumlah Insiden'), style: TextStyle(color: theme.textTheme.titleMedium?.color, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(_incidentCount.toString(), style: TextStyle(color: theme.primaryColor, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                                getTitlesWidget: (value, meta) {
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
                              spots: List.generate(7, (index) => FlSpot(index.toDouble(), _weeklyCounts[index].toDouble())),
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
}
