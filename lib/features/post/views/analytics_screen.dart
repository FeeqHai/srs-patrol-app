import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/settings_provider.dart';
import '../../incident/services/incident_service.dart';
import '../../../core/network/api_client.dart';
import '../../incident/views/lampiran_6_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  List<int> _weeklyCounts = List.filled(7, 0);
  int _totalWeeklyIncidents = 0;
  int _totalPatrollers = 0;
  int _activeShiftsCount = 0;
  List<dynamic> _activeShifts = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch high-level statistics from get_stats.php
      final statsResponse = await ApiClient.getData('admin/get_stats.php');
      if (statsResponse['success'] == true) {
        final data = statsResponse['data'];
        _totalPatrollers = data['total_patrollers'] ?? 0;
        _activeShiftsCount = data['active_shifts'] ?? 0;
        _totalWeeklyIncidents = data['weekly_incidents'] ?? 0;
      }

      // 2. Fetch list of active shifts from get_active_shifts.php
      final activeResponse = await ApiClient.getData('admin/get_active_shifts.php');
      if (activeResponse['success'] == true) {
        _activeShifts = activeResponse['data'] ?? [];
      }

      // 3. Fetch all incidents to compute local chart trends
      final service = IncidentService();
      final incidents = await service.fetchAllIncidents();
      
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
          _weeklyCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching analytics: $e");
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

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<String> daysLabels = List.generate(7, (index) {
      final d = today.subtract(Duration(days: 6 - index));
      return _getDayName(d.weekday);
    });

    final textColor = Colors.black87;
    final subtitleColor = Colors.grey.shade600;

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: theme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Description
            Text(
              settings.t('Monitor & Analitik'),
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: theme.primaryColor),
            ),
            const SizedBox(height: 4),
            Text(
              settings.t('Paparan pemantauan rondaan dan trend insiden semasa.'),
              style: TextStyle(color: subtitleColor, fontSize: 14),
            ),
            const SizedBox(height: 24),
            
            // KPI Metrics Row (3-Cards)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildKpiCard(
                    settings.t('Insiden (Minggu)'),
                    '$_totalWeeklyIncidents',
                    Icons.warning_amber_rounded,
                    Colors.redAccent,
                  ),
                  const SizedBox(width: 12),
                  _buildKpiCard(
                    settings.t('Shif Aktif'),
                    '$_activeShiftsCount',
                    Icons.radar,
                    Colors.green.shade600,
                  ),
                  const SizedBox(width: 12),
                  _buildKpiCard(
                    settings.t('Peronda Terdaftar'),
                    '$_totalPatrollers',
                    Icons.people_alt_outlined,
                    theme.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // JPNIN Lampiran 6 Report Generation Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Lampiran6Screen()),
                  );
                },
                icon: const Icon(Icons.analytics_outlined, color: Colors.white),
                label: Text(
                  settings.t('JANA LAPORAN LAMPIRAN 6'),
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Line Chart Card
            Card(
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.05),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.t('Trend Insiden (7 Hari Terakhir)'),
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          minY: 0,
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 && value.toInt() < daysLabels.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        daysLabels[value.toInt()],
                                        style: TextStyle(color: subtitleColor, fontSize: 11, fontWeight: FontWeight.w500),
                                      ),
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
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 4,
                                    color: Colors.white,
                                    strokeWidth: 3,
                                    strokeColor: theme.primaryColor,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: theme.primaryColor.withValues(alpha: 0.15),
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
            const SizedBox(height: 24),

            // Live Patrol Feed Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  settings.t('Rondaan Aktif Semasa'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.primaryColor),
                ),
                const _ActivePulseDot(),
              ],
            ),
            const SizedBox(height: 12),
            
            _activeShifts.isEmpty
                ? Card(
                    elevation: 1,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.shield_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              settings.t('Tiada rondaan aktif dijalankan ketika ini.'),
                              style: TextStyle(color: subtitleColor, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _activeShifts.length,
                    itemBuilder: (context, index) {
                      final shift = _activeShifts[index];
                      final clockIn = shift['clock_in_time'] != null
                          ? DateFormat('hh:mm a').format(DateTime.parse(shift['clock_in_time']))
                          : 'TBA';
                      final name = shift['full_name'] ?? 'Peronda';
                      final squad = shift['squad_name'] ?? settings.t('Tiada Kumpulan');
                      final phone = shift['phone_number'] ?? '';

                      return Card(
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.05),
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                                radius: 22,
                                child: Icon(Icons.person, color: theme.primaryColor, size: 24),
                              ),
                              const Positioned(
                                bottom: 2,
                                right: 2,
                                child: _ActivePulseDot(),
                              ),
                            ],
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${settings.t('Kumpulan')}: $squad',
                                style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              if (phone.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  phone,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              'Mula: $clockIn',
                              style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivePulseDot extends StatefulWidget {
  const _ActivePulseDot();

  @override
  State<_ActivePulseDot> createState() => _ActivePulseDotState();
}

class _ActivePulseDotState extends State<_ActivePulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1500),
    );
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withValues(alpha: _animation.value),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 4,
                spreadRadius: 2 * (1.0 - _animation.value),
              )
            ],
          ),
        );
      },
    );
  }
}
