import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../incident/services/incident_service.dart';
import '../../../core/constants/api_constants.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  List<dynamic> _incidents = [];
  List<int> _weeklyCounts = List.filled(7, 0);
  int _totalWeeklyIncidents = 0;
  int _totalPatrollers = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final service = IncidentService();
      final incidents = await service.fetchAllIncidents();
      
      // Calculate last 7 days including today
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      int totalWeekly = 0;
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
              totalWeekly++;
            }
          } catch (_) {}
        }
      }
      
      // Fetch patrollers count
      int patrollerCount = 0;
      try {
        final response = await http.get(Uri.parse('${ApiConstants.baseUrl}auth/get_patrollers.php'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'success') {
            patrollerCount = (data['data'] as List).length;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _incidents = incidents;
          _weeklyCounts = counts;
          _totalWeeklyIncidents = totalWeekly;
          _totalPatrollers = patrollerCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Isn';
      case 2: return 'Sel';
      case 3: return 'Rab';
      case 4: return 'Kha';
      case 5: return 'Jum';
      case 6: return 'Sab';
      case 7: return 'Aha';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
    }

    final spots = List.generate(7, (index) {
      return FlSpot(index.toDouble(), _weeklyCounts[index].toDouble());
    });

    // Generate last 7 days labels
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<String> daysLabels = List.generate(7, (index) {
      final d = today.subtract(Duration(days: 6 - index));
      return _getDayName(d.weekday);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Papan Pemuka Analitik',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ringkasan insiden dan statistik rondaan minggu ini.',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 32),
          
          // KPI Cards
          Row(
            children: [
              _buildKpiCard('Total Insiden (Minggu)', '$_totalWeeklyIncidents', Icons.warning, Colors.redAccent),
              const SizedBox(width: 16),
              _buildKpiCard('Rondaan Aktif', 'N/A', Icons.directions_walk, Colors.greenAccent),
              const SizedBox(width: 16),
              _buildKpiCard('Peronda Sedia Ada', '$_totalPatrollers', Icons.people, Colors.indigoAccent),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Chart Section
          Container(
            height: 400,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trend Insiden (7 Hari Terakhir)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < daysLabels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(daysLabels[value.toInt()], style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
                          spots: spots,
                          isCurved: true,
                          color: Colors.indigoAccent,
                          barWidth: 4,
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.indigoAccent.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
