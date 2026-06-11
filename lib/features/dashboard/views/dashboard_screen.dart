import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/api_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../../incident/services/incident_service.dart';
import '../../incident/views/incident_detail_screen.dart';

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

    final currentUserId = context.read<AuthProvider>().userId;
    if (currentUserId == null) return;
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}incidents/check_sos.php?exclude_user=$currentUserId'));
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

    if (isActive) {
      final String? startTimeStr = prefs.getString('shiftStartTime');
      if (startTimeStr != null) {
        final DateTime startTime = DateTime.parse(startTimeStr);
        final Duration diff = DateTime.now().difference(startTime);

        // Check if 4 hours have passed
        if (diff.inHours >= 4) {
          // It expired, we just mark as inactive
          setState(() {
            _shiftActive = false;
          });
        } else {
          setState(() {
            _shiftActive = true;
            _shiftStartTime = startTime;
          });
          _startTimer();
        }
      }
    } else {
      setState(() {
        _shiftActive = false;
      });
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_activeSosList.isNotEmpty)
                _buildSosBanner(),
              const Text(
                'Selamat Datang, Peronda SRS!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ringkasan Aktiviti Anda',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _incidentFilter,
                        dropdownColor: const Color(0xFF1E1E1E),
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
                        items: ['Harian', 'Mingguan', 'Bulanan', 'Semua'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              _incidentFilter = newValue;
                              _incidentCount = _calculateFilteredIncidents(_allIncidents, newValue);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Rondaan Anda Card
              SizedBox(
                width: double.infinity,
                child: _buildMetricCard('Rondaan Anda', _shiftActive ? 'Aktif' : 'Tidak Aktif', _shiftActive ? Icons.verified_user : Icons.remove_circle_outline, _shiftActive ? Colors.greenAccent : Colors.grey)
              ),
              const SizedBox(height: 16),
              // Trend Insiden Graph
              Container(
                height: 250,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Jumlah Insiden', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(_incidentCount.toString(), style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final daysLabels = ['Isn', 'Sel', 'Rab', 'Kha', 'Jum', 'Sab', 'Aha'];
                                  final todayIndex = DateTime.now().weekday - 1;
                                  final startDayIndex = (todayIndex - 6) % 7;
                                  
                                  int displayIndex = (startDayIndex + value.toInt()) % 7;
                                  if (displayIndex < 0) displayIndex += 7;

                                  if (value.toInt() >= 0 && value.toInt() < 7) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(daysLabels[displayIndex], style: const TextStyle(color: Colors.white54, fontSize: 10)),
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
                              color: Colors.redAccent,
                              barWidth: 3,
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.redAccent.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Status Semasa',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _shiftActive ? null : widget.onNavigateToScan,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _shiftActive ? Colors.greenAccent.withValues(alpha: 0.1) : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _shiftActive ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.white12,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _shiftActive ? Icons.timer : Icons.directions_walk,
                        color: _shiftActive ? Colors.greenAccent : Colors.lightBlueAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _shiftActive ? 'Shif Aktif' : 'Bersedia Untuk Rondaan',
                        style: TextStyle(
                          fontSize: 18,
                          color: _shiftActive ? Colors.greenAccent : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _shiftActive
                            ? _elapsedTime
                            : 'Tekan untuk mula',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _shiftActive ? 24 : 14,
                          fontWeight: _shiftActive ? FontWeight.bold : FontWeight.normal,
                          color: _shiftActive ? Colors.white : Colors.white54,
                        ),
                      ),
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

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildSosBanner() {
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
                    const Text('AMARAN KECEMASAN (SOS)', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('${sos['full_name']} memerlukan bantuan!', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Masa: ${sos['created_at']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => IncidentDetailScreen(incident: sos)));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text('LIHAT LOKASI', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
