import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
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
    final settings = context.read<SettingsProvider>();
    switch (weekday) {
      case 1: return settings.t('Isn');
      case 2: return settings.t('Sel');
      case 3: return settings.t('Rab');
      case 4: return settings.t('Kha');
      case 5: return settings.t('Jum');
      case 6: return settings.t('Sab');
      case 7: return settings.t('Aha');
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: theme.primaryColor));
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

    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = textColor.withValues(alpha: 0.6);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            settings.t('Papan Pemuka Analitik'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            settings.t('Ringkasan insiden dan statistik rondaan minggu ini.'),
            style: TextStyle(color: subtitleColor, fontSize: 16),
          ),
          const SizedBox(height: 32),
          
          // KPI Cards
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildKpiCard(settings.t('Total Insiden (Minggu)'), '$_totalWeeklyIncidents', Icons.warning, Colors.redAccent),
                const SizedBox(width: 16),
                _buildKpiCard(settings.t('Peronda Sedia Ada'), '$_totalPatrollers', Icons.people, theme.primaryColor),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Chart Section
          Container(
            height: 400,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
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
                Text(settings.t('Trend Insiden (7 Hari Terakhir)'), style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
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
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < daysLabels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(daysLabels[value.toInt()], style: TextStyle(color: subtitleColor, fontSize: 12)),
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
                          preventCurveOverShooting: true,
                          color: theme.primaryColor,
                          barWidth: 4,
                          belowBarData: BarAreaData(
                            show: true,
                            color: theme.primaryColor.withValues(alpha: 0.3),
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
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              value,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
