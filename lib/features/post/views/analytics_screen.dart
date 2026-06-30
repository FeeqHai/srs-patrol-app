import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
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
  List<int> _monthlyCounts = List.filled(30, 0);
  Map<String, int> _categoryCounts = {
    'Jenayah Kekerasan': 0,
    'Jenayah Harta Benda': 0,
    'Narkotik & Sosial': 0,
    'Lain-lain': 0,
  };
  Map<String, int> _zoneCounts = {
    'Zon Pusat': 0,
    'Zon Utara': 0,
    'Zon Selatan': 0,
    'Zon Barat': 0,
    'Zon Timur': 0,
  };
  int _totalWeeklyIncidents = 0;
  int _totalPatrollers = 0;
  int _activeShiftsCount = 0;
  List<dynamic> _allIncidents = [];
  String _chartPeriod = 'Weekly'; // 'Weekly' or 'Monthly'
  int _touchedPieIndex = -1;
  bool _showPieChart = true;
  bool _showHotspotBarChart = true;
  String _fullName = 'Admin';

  @override
  void initState() {
    super.initState();
    _fetchData();
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
            _fullName = data['full_name'] ?? 'Admin';
          });
        }
      }
    } catch (_) {
      // Keep default
    }
  }

  String _getCategoryGroup(String category) {
    if (category.contains('Jenayah Kekerasan')) {
      return 'Jenayah Kekerasan';
    } else if (category.contains('Jenayah Harta Benda')) {
      return 'Jenayah Harta Benda';
    } else if (category.contains('Jenayah Narkotik') ||
        category.contains('Gejala Sosial')) {
      return 'Narkotik & Sosial';
    }
    return 'Lain-lain';
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch high-level statistics from get_stats.php
      final statsResponse = await ApiClient.getData('admin/get_stats.php');
      if (statsResponse['status'] == 'success' ||
          statsResponse['success'] == true) {
        final data = statsResponse['data'];
        _totalPatrollers = data['total_patrollers'] ?? 0;
        _activeShiftsCount = data['active_shifts'] ?? 0;
        _totalWeeklyIncidents = data['weekly_incidents'] ?? 0;
      }

      // Fetch Profile for greeting
      await _fetchUserProfile();

      // 3. Fetch all incidents to compute local chart trends, category breakdowns, and zone heatmaps
      final service = IncidentService();
      final incidents = await service.fetchAllIncidents();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Weekly trend
      List<int> weeklyCounts = List.filled(7, 0);
      for (var inc in incidents) {
        if (inc['created_at'] != null) {
          try {
            final date = DateTime.parse(inc['created_at']);
            final incDay = DateTime(date.year, date.month, date.day);
            final diff = today.difference(incDay).inDays;

            if (diff >= 0 && diff < 7) {
              weeklyCounts[6 - diff]++;
            }
          } catch (_) {}
        }
      }

      // Monthly trend
      List<int> monthlyCounts = List.filled(30, 0);
      for (var inc in incidents) {
        if (inc['created_at'] != null) {
          try {
            final date = DateTime.parse(inc['created_at']);
            final incDay = DateTime(date.year, date.month, date.day);
            final diff = today.difference(incDay).inDays;

            if (diff >= 0 && diff < 30) {
              monthlyCounts[29 - diff]++;
            }
          } catch (_) {}
        }
      }

      // Category Breakdown
      Map<String, int> categoryCounts = {
        'Jenayah Kekerasan': 0,
        'Jenayah Harta Benda': 0,
        'Narkotik & Sosial': 0,
        'Lain-lain': 0,
      };

      // Zone Heatmap
      Map<String, int> zoneCounts = {
        'Zon Pusat': 0,
        'Zon Utara': 0,
        'Zon Selatan': 0,
        'Zon Barat': 0,
        'Zon Timur': 0,
      };

      for (var inc in incidents) {
        final cat = inc['category'] ?? '';
        final group = _getCategoryGroup(cat);
        if (categoryCounts.containsKey(group)) {
          categoryCounts[group] = categoryCounts[group]! + 1;
        }

        final z = inc['zone'] ?? '';
        if (zoneCounts.containsKey(z)) {
          zoneCounts[z] = zoneCounts[z]! + 1;
        }
      }

      if (mounted) {
        setState(() {
          _weeklyCounts = weeklyCounts;
          _monthlyCounts = monthlyCounts;
          _categoryCounts = categoryCounts;
          _zoneCounts = zoneCounts;
          _allIncidents = incidents;
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
      case 1:
        return settings.t('Isn');
      case 2:
        return settings.t('Sel');
      case 3:
        return settings.t('Rab');
      case 4:
        return settings.t('Kha');
      case 5:
        return settings.t('Jum');
      case 6:
        return settings.t('Sab');
      case 7:
        return settings.t('Aha');
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
    }

    // Line Chart preparation
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isWeekly = _chartPeriod == 'Weekly';
    final spotCount = isWeekly ? 7 : 30;
    final trendData = isWeekly ? _weeklyCounts : _monthlyCounts;
    final periodTotal = trendData.isNotEmpty
        ? trendData.reduce((a, b) => a + b)
        : 0;

    final spots = List.generate(spotCount, (index) {
      return FlSpot(index.toDouble(), trendData[index].toDouble());
    });

    final List<String> chartLabels = List.generate(spotCount, (index) {
      final d = today.subtract(Duration(days: (spotCount - 1) - index));
      if (isWeekly) {
        return _getDayName(d.weekday);
      } else {
        return DateFormat('d/M').format(d);
      }
    });

    final totalIncidents = _allIncidents.length;

    // Pie Chart preparation
    List<PieChartSectionData> pieSections = [];
    if (totalIncidents == 0) {
      pieSections = [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 1,
          title: '0%',
          radius: 35,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
      ];
    } else {
      final categories = [
        'Jenayah Kekerasan',
        'Jenayah Harta Benda',
        'Narkotik & Sosial',
        'Lain-lain',
      ];
      final colors = [
        Colors.redAccent,
        Colors.orange,
        Colors.blue,
        Colors.grey,
      ];

      pieSections = List.generate(categories.length, (index) {
        final cat = categories[index];
        final count = _categoryCounts[cat] ?? 0;
        final pct = totalIncidents > 0 ? (count / totalIncidents * 100) : 0.0;
        final isTouched = index == _touchedPieIndex;
        final radius = isTouched ? 45.0 : 35.0;
        final fontSize = isTouched ? 14.0 : 11.0;
        final fontWeight = isTouched ? FontWeight.bold : FontWeight.normal;

        return PieChartSectionData(
          color: colors[index],
          value: count.toDouble(),
          title: count > 0 ? '${pct.toStringAsFixed(0)}%' : '',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: Colors.white,
          ),
        );
      });
    }

    // Bar Chart preparation
    final zones = [
      'Zon Pusat',
      'Zon Utara',
      'Zon Selatan',
      'Zon Barat',
      'Zon Timur',
    ];
    final zoneLabels = ['Pusat', 'Utara', 'Selatan', 'Barat', 'Timur'];
    int maxZoneCount = 0;
    _zoneCounts.forEach((_, val) {
      if (val > maxZoneCount) maxZoneCount = val;
    });

    List<BarChartGroupData> barGroups = List.generate(zones.length, (index) {
      final zone = zones[index];
      final count = _zoneCounts[zone] ?? 0;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: theme.primaryColor,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: (maxZoneCount > 0 ? maxZoneCount : 10).toDouble(),
              color: theme.primaryColor.withValues(alpha: 0.05),
            ),
          ),
        ],
      );
    });

    // Ranked list of hotspots
    final sortedZones =
        zones.map((z) => {'name': z, 'count': _zoneCounts[z] ?? 0}).toList()
          ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final hour = DateTime.now().hour;
    String greetingKey = 'Selamat Pagi';
    if (hour >= 12 && hour < 14) {
      greetingKey = 'Selamat Tengah Hari';
    } else if (hour >= 14 && hour < 19) {
      greetingKey = 'Selamat Petang';
    } else if (hour >= 19 || hour < 5) {
      greetingKey = 'Selamat Malam';
    }

    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black87;
    final subtitleColor =
        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
        Colors.grey.shade600;

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: theme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Personalized Greeting Header Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${settings.t(greetingKey)},',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fullName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.titleLarge?.color,
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
                      fallback: 'A',
                    ),
                    radius: 26,
                  ),
                ),
              ],
            ),
            if (auth.role == 'ketua_krt') ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.primaryColor.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_city_outlined,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${settings.t("Skop Daerah")}: ${auth.districtName ?? "-"}',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${auth.stateName ?? "-"} • ${auth.zoneName ?? settings.t("Semua Zon")}',
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // KPI Metrics Row (3-Cards)
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    settings.t('Insiden (Minggu)'),
                    '$_totalWeeklyIncidents',
                    Icons.warning_amber_rounded,
                    Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiCard(
                    settings.t('Shif Aktif'),
                    '$_activeShiftsCount',
                    Icons.radar,
                    Colors.green.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiCard(
                    settings.t('Peronda Terdaftar'),
                    '$_totalPatrollers',
                    Icons.people_alt_outlined,
                    theme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // JPNIN Lampiran 6 Report Generation Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Lampiran6Screen(),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics_outlined, color: Colors.white),
                label: Text(
                  settings.t('JANA LAPORAN LAMPIRAN 6'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Line Chart Card
            Card(
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.05),
              color: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${settings.t('Jumlah Insiden')}: $periodTotal',
                      style: TextStyle(
                        color: textColor,
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
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
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
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < chartLabels.length) {
                                    if (!isWeekly &&
                                        idx % 5 != 0 &&
                                        idx != chartLabels.length - 1) {
                                      return const SizedBox();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        chartLabels[idx],
                                        style: TextStyle(
                                          color: subtitleColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox();
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
                                color: theme.primaryColor.withValues(
                                  alpha: 0.15,
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
            ),
            const SizedBox(height: 24),

            // Pie Chart Card
            Card(
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.05),
              color: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                settings.t('Peratusan Kategori Jenayah'),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                settings.t('Pecahan Mengikut Kategori'),
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              _showPieChart
                                  ? Icons.list_alt_rounded
                                  : Icons.pie_chart_rounded,
                              size: 20,
                              color: theme.primaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _showPieChart = !_showPieChart;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _showPieChart
                        ? Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: SizedBox(
                                  height: 140,
                                  child: PieChart(
                                    PieChartData(
                                      pieTouchData: PieTouchData(
                                        touchCallback:
                                            (
                                              FlTouchEvent event,
                                              pieTouchResponse,
                                            ) {
                                              setState(() {
                                                if (!event
                                                        .isInterestedForInteractions ||
                                                    pieTouchResponse == null ||
                                                    pieTouchResponse
                                                            .touchedSection ==
                                                        null) {
                                                  _touchedPieIndex = -1;
                                                  return;
                                                }
                                                _touchedPieIndex =
                                                    pieTouchResponse
                                                        .touchedSection!
                                                        .touchedSectionIndex;
                                              });
                                            },
                                      ),
                                      borderData: FlBorderData(show: false),
                                      sectionsSpace: 4,
                                      centerSpaceRadius: 30,
                                      sections: pieSections,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildPieLegendItem(
                                      settings.t('Jenayah Kekerasan'),
                                      _categoryCounts['Jenayah Kekerasan'] ?? 0,
                                      Colors.redAccent,
                                      totalIncidents,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildPieLegendItem(
                                      settings.t('Jenayah Harta Benda'),
                                      _categoryCounts['Jenayah Harta Benda'] ??
                                          0,
                                      Colors.orange,
                                      totalIncidents,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildPieLegendItem(
                                      settings.t('Narkotik & Sosial'),
                                      _categoryCounts['Narkotik & Sosial'] ?? 0,
                                      Colors.blue,
                                      totalIncidents,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildPieLegendItem(
                                      settings.t('Lain-lain'),
                                      _categoryCounts['Lain-lain'] ?? 0,
                                      Colors.grey,
                                      totalIncidents,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSeverityProgressItem(
                                settings.t('Jenayah Kekerasan'),
                                _categoryCounts['Jenayah Kekerasan'] ?? 0,
                                Colors.redAccent,
                                totalIncidents,
                              ),
                              const SizedBox(height: 16),
                              _buildSeverityProgressItem(
                                settings.t('Jenayah Harta Benda'),
                                _categoryCounts['Jenayah Harta Benda'] ?? 0,
                                Colors.orange,
                                totalIncidents,
                              ),
                              const SizedBox(height: 16),
                              _buildSeverityProgressItem(
                                settings.t('Narkotik & Sosial'),
                                _categoryCounts['Narkotik & Sosial'] ?? 0,
                                Colors.blue,
                                totalIncidents,
                              ),
                              const SizedBox(height: 16),
                              _buildSeverityProgressItem(
                                settings.t('Lain-lain'),
                                _categoryCounts['Lain-lain'] ?? 0,
                                Colors.grey,
                                totalIncidents,
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Combined Hotspot Kawasan (Zon) Card
            Card(
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.05),
              color: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                settings.t('Hotspot Kawasan (Zon)'),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                settings.t('Kawasan dengan insiden tertinggi'),
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              _showHotspotBarChart
                                  ? Icons.list_alt_rounded
                                  : Icons.bar_chart_rounded,
                              size: 20,
                              color: theme.primaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _showHotspotBarChart = !_showHotspotBarChart;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _showHotspotBarChart
                        ? SizedBox(
                            height: 180,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY:
                                    (maxZoneCount > 0 ? maxZoneCount : 10)
                                        .toDouble() +
                                    2,
                                barTouchData: BarTouchData(enabled: true),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 32,
                                      getTitlesWidget: (value, meta) {
                                        final idx = value.toInt();
                                        if (idx >= 0 &&
                                            idx < zoneLabels.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8.0,
                                            ),
                                            child: Text(
                                              zoneLabels[idx],
                                              style: TextStyle(
                                                color: subtitleColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox();
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
                                barGroups: barGroups,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(sortedZones.length, (
                              index,
                            ) {
                              final zoneData = sortedZones[index];
                              final rank = index + 1;
                              final name = zoneData['name'] as String;
                              final count = zoneData['count'] as int;
                              final pct = totalIncidents > 0
                                  ? (count / totalIncidents)
                                  : 0.0;

                              Color badgeColor;
                              if (rank == 1) {
                                badgeColor = Colors.redAccent;
                              } else if (rank == 2) {
                                badgeColor = Colors.orange;
                              } else if (rank == 3) {
                                badgeColor = Colors.amber;
                              } else {
                                badgeColor = Colors.grey;
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '#$rank',
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: pct,
                                              backgroundColor: theme
                                                  .dividerColor
                                                  .withValues(alpha: 0.05),
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    badgeColor,
                                                  ),
                                              minHeight: 6,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      '$count ${settings.t("Insiden")}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: subtitleColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Severity & Stats Breakdown Card
          ],
        ),
      ),
    );
  }

  Widget _buildPieLegendItem(String label, int count, Color color, int total) {
    final theme = Theme.of(context);
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$count ($pct%)',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSeverityProgressItem(
    String label,
    int count,
    Color color,
    int total,
  ) {
    final theme = Theme.of(context);
    final pct = total > 0 ? (count / total) : 0.0;
    final pctText = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              '$count ($pctText%)',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: theme.dividerColor.withValues(alpha: 0.05),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
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
                                  : BorderSide.none.color,
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

class _ActivePulseDot extends StatefulWidget {
  const _ActivePulseDot();

  @override
  State<_ActivePulseDot> createState() => _ActivePulseDotState();
}

class _ActivePulseDotState extends State<_ActivePulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
              ),
            ],
          ),
        );
      },
    );
  }
}
