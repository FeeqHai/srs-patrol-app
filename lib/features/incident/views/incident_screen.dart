// File: lib/features/incident/views/incident_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'incident_report_screen.dart';
import 'incident_detail_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/logger.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';

class IncidentScreen extends StatefulWidget {
  final String? patrollerIdFilter;

  const IncidentScreen({super.key, this.patrollerIdFilter});

  @override
  State<IncidentScreen> createState() => _IncidentScreenState();
}

class _IncidentScreenState extends State<IncidentScreen> with SingleTickerProviderStateMixin {
  final List<dynamic> _incidents = [];
  int _page = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  
  late TabController _tabController;
  
  // Batch selection states
  bool _isBatchMode = false;
  final Set<String> _selectedIncidentIds = {};
  

  
  // Filter states
  String _selectedFilter = 'Semua';
  String _selectedZone = 'Semua';
  DateTimeRange? _selectedDateRange;
  
  final List<String> _filterOptions = [
    'Semua',
    'Jenayah Kekerasan',
    'Jenayah Harta Benda',
    'Jenayah Narkotik',
    'Gejala Sosial',
    'Lain-lain',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _isBatchMode = false;
          _selectedIncidentIds.clear();
        });
        _refresh();
      }
    });
    
    _fetchIncidents();
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _fetchIncidents();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }



  Future<void> _fetchIncidents() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      String url =
          '${ApiConstants.baseUrl}incidents/fetch_incidents.php?page=$_page&limit=10';

      final authProvider = context.read<AuthProvider>();
      final String? effectiveFilter;
      if (widget.patrollerIdFilter != null) {
        effectiveFilter = widget.patrollerIdFilter;
      } else if (authProvider.role == 'peronda' || authProvider.role == 'ketua_peronda') {
        effectiveFilter = authProvider.userId;
      } else {
        effectiveFilter = null;
      }

      if (effectiveFilter != null) {
        url += '&user_id=$effectiveFilter';
      }
      if (_selectedFilter != 'Semua') {
        url += '&category=${Uri.encodeComponent(_selectedFilter)}';
      }
      if (_selectedZone != 'Semua') {
        url += '&zone=${Uri.encodeComponent(_selectedZone)}';
      }
      
      // Handle tab-based dates
      if (_tabController.index == 0) {
        // Today
        final today = DateTime.now();
        final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        url += '&start_date=$todayStr&end_date=$todayStr';
      } else {
        // Archive
        if (_selectedDateRange != null) {
          final startStr = '${_selectedDateRange!.start.year}-${_selectedDateRange!.start.month.toString().padLeft(2, '0')}-${_selectedDateRange!.start.day.toString().padLeft(2, '0')}';
          final endStr = '${_selectedDateRange!.end.year}-${_selectedDateRange!.end.month.toString().padLeft(2, '0')}-${_selectedDateRange!.end.day.toString().padLeft(2, '0')}';
          url += '&start_date=$startStr&end_date=$endStr';
        } else {
          // Default Archive view: get incidents up to yesterday
          final yesterday = DateTime.now().subtract(const Duration(days: 1));
          final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
          url += '&start_date=1970-01-01&end_date=$yesterdayStr';
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final Map<String, String> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> newIncidents = body['data'];

        setState(() {
          _page++;
          _isLoading = false;
          if (newIncidents.length < 10) {
            _hasMore = false;
          }
          _incidents.addAll(newIncidents);
        });
      } else {
        throw Exception('Gagal memuat turun laporan: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      appLogger.e("Exception: $e", error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat rangkaian: $e', style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _page = 1;
      _incidents.clear();
      _hasMore = true;
    });
    await _fetchIncidents();
  }

  Future<void> _deleteIncident(String id) async {
    final settings = context.read<SettingsProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t("Hapus Rekod")),
        content: Text(settings.t("Adakah anda pasti mahu menghapus laporan ini?")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(settings.t("Batal")),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(settings.t("Hapus")),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}incidents/delete_incident.php'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: {'id': id},
      );

      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        if (res['status'] == 'success') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(settings.t("Laporan berjaya dihapuskan.")), backgroundColor: Colors.green),
          );
          _refresh();
        } else {
          throw Exception(res['message']);
        }
      } else {
        throw Exception("Server Error ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${settings.t("Ralat:")} $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _submitIncident(String id) async {
    final settings = context.read<SettingsProvider>();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}incidents/update_status.php'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: {'id': id, 'status': 'Submitted'},
      );

      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        if (res['status'] == 'success') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(settings.t("Laporan berjaya dihantar.")), backgroundColor: Colors.green),
          );
          _refresh();
        } else {
          throw Exception(res['message']);
        }
      } else {
        throw Exception("Server Error ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${settings.t("Ralat:")} $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _bulkDelete() async {
    final settings = context.read<SettingsProvider>();
    if (_selectedIncidentIds.isEmpty) return;

    // Guard: Prevent deletion of submitted records
    final hasSubmitted = _selectedIncidentIds.any((id) {
      final incident = _incidents.firstWhere((i) => i['id'].toString() == id, orElse: () => null);
      if (incident != null) {
        final status = incident['status'] ?? 'Pending';
        return status.toLowerCase() == 'submitted';
      }
      return false;
    });

    if (hasSubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.t("Laporan yang telah dihantar tidak boleh dihapuskan.")),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t("Hapus Batch")),
        content: Text(settings.t("Adakah anda pasti mahu menghapus semua laporan dipilih?")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(settings.t("Batal")),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(settings.t("Hapus")),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    int successCount = 0;
    for (final id in _selectedIncidentIds) {
      try {
        final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}incidents/delete_incident.php'),
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: {'id': id},
        );
        if (response.statusCode == 200) {
          final res = json.decode(response.body);
          if (res['status'] == 'success') {
            successCount++;
          }
        }
      } catch (e) {
        appLogger.e("Bulk delete error for $id: $e");
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$successCount ${settings.t("laporan berjaya dihapuskan.")}"), backgroundColor: Colors.green),
    );

    setState(() {
      _selectedIncidentIds.clear();
      _isBatchMode = false;
    });
    _refresh();
  }

  Future<void> _bulkSubmit() async {
    final settings = context.read<SettingsProvider>();
    if (_selectedIncidentIds.isEmpty) return;

    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    int successCount = 0;
    for (final id in _selectedIncidentIds) {
      try {
        final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}incidents/update_status.php'),
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: {'id': id, 'status': 'Submitted'},
        );
        if (response.statusCode == 200) {
          final res = json.decode(response.body);
          if (res['status'] == 'success') {
            successCount++;
          }
        }
      } catch (e) {
        appLogger.e("Bulk submit error for $id: $e");
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$successCount ${settings.t("laporan berjaya dihantar.")}"), backgroundColor: Colors.green),
    );

    setState(() {
      _selectedIncidentIds.clear();
      _isBatchMode = false;
    });
    _refresh();
  }



  void _showFilterBottomSheet() {
    final settings = context.read<SettingsProvider>();
    final theme = Theme.of(context);
    String tempCategory = _selectedFilter;
    String tempZone = _selectedZone;
    final List<String> zonesList = ['Semua', 'Zon Pusat', 'Zon Utara', 'Zon Selatan', 'Zon Barat', 'Zon Timur'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        settings.t("Tapis Rekod Insiden"),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const Divider(),
                  Text(settings.t("Kategori"), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: tempCategory,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.dividerColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    items: _filterOptions.map((String val) {
                      return DropdownMenuItem<String>(value: val, child: Text(val));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => tempCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(settings.t("Zon Rondaan"), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: tempZone,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.dividerColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    items: zonesList.map((String val) {
                      return DropdownMenuItem<String>(value: val, child: Text(val));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => tempZone = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(settings.t("Pilih Tarikh"), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final List<DateTime?>? results = await showCalendarDatePicker2Dialog(
                        context: context,
                        config: CalendarDatePicker2WithActionButtonsConfig(
                          calendarType: CalendarDatePicker2Type.range,
                          selectedDayHighlightColor: theme.primaryColor,
                          weekdayLabelTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                          controlsTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          centerAlignModePicker: true,
                          customModePickerIcon: const SizedBox(),
                        ),
                        dialogSize: const Size(340, 420),
                        value: [
                          _selectedDateRange?.start,
                          _selectedDateRange?.end,
                        ],
                        borderRadius: BorderRadius.circular(20),
                      );

                      if (results != null && results.isNotEmpty) {
                        setSheetState(() {
                          if (results.length == 1 && results[0] != null) {
                            _selectedDateRange = DateTimeRange(start: results[0]!, end: results[0]!);
                          } else if (results.length >= 2 && results[0] != null && results[1] != null) {
                            _selectedDateRange = DateTimeRange(start: results[0]!, end: results[1]!);
                          }
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDateRange == null
                                ? settings.t("Pilih Julat Tarikh")
                                : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}',
                          ),
                          const Icon(Icons.calendar_month),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedFilter = 'Semua';
                              _selectedZone = 'Semua';
                              _selectedDateRange = null;
                            });
                            Navigator.pop(context);
                            _refresh();
                          },
                          child: Text(settings.t("Reset")),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _selectedFilter = tempCategory;
                              _selectedZone = tempZone;
                            });
                            Navigator.pop(context);
                            _refresh();
                          },
                          child: Text(settings.t("Tapis")),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    final displayIncidents = _incidents;

    return Scaffold(
      appBar: widget.patrollerIdFilter != null
          ? AppBar(
              title: Text(settings.t('Rekod Insiden')),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Tutup',
              ),
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
      body: Column(
        children: [
          // Dynamic Header toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_isBatchMode) ...[
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _isBatchMode = false;
                            _selectedIncidentIds.clear();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${_selectedIncidentIds.length} ${settings.t("terpilih")}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: settings.t("Hapus"),
                        onPressed: _bulkDelete,
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.green),
                        tooltip: settings.t("Hantar"),
                        onPressed: _bulkSubmit,
                      ),
                    ],
                  ),
                ] else ...[
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      labelColor: theme.primaryColor,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: theme.primaryColor,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(text: settings.t('Hari Ini')),
                        Tab(text: settings.t('Arkib')),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.checklist),
                        tooltip: settings.t("Mod Batch"),
                        onPressed: () {
                          setState(() {
                            _isBatchMode = true;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.filter_alt_outlined),
                        tooltip: settings.t("Tapis"),
                        onPressed: _showFilterBottomSheet,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          


          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: theme.primaryColor,
              child: displayIncidents.isEmpty && _isLoading
                  ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                  : displayIncidents.isEmpty && !_isLoading
                      ? ListView(
                          children: [
                            const SizedBox(height: 200),
                            Center(
                              child: Text(
                                settings.t("Tiada insiden direkodkan."),
                                style: TextStyle(color: theme.textTheme.bodySmall?.color),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: displayIncidents.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == displayIncidents.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
                              );
                            }
                            return _buildIncidentCard(displayIncidents[index]);
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: widget.patrollerIdFilter == null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 70.0),
              child: FloatingActionButton(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const IncidentReportScreen()),
                  );
                  await _refresh();
                },
                child: const Icon(Icons.add),
              ),
            )
          : null,
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> data) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final String id = data['id'].toString();
    final bool isSelected = _selectedIncidentIds.contains(id);
    final String status = data['status'] ?? 'Pending';

    String? imageUrl;
    if (data['image_url'] != null && data['image_url'].toString().isNotEmpty) {
      try {
        if (data['image_url'].toString().trim().startsWith('[')) {
          List<dynamic> parsed = json.decode(data['image_url']);
          if (parsed.isNotEmpty) imageUrl = parsed.first.toString();
        } else {
          imageUrl = data['image_url'];
        }
      } catch (e) {
        imageUrl = data['image_url'];
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isBatchMode
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedIncidentIds.remove(id);
                  } else {
                    _selectedIncidentIds.add(id);
                  }
                });
              }
            : () {
                if (MediaQuery.of(context).size.width > 600) {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(40),
                      child: Container(
                        width: 800,
                        height: 700,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                        child: IncidentDetailScreen(incident: data),
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => IncidentDetailScreen(incident: data)),
                  );
                }
              },
        child: SizedBox(
          height: 96, // Fixed logical layout height representing premium spacing
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Batch Selection Checkbox overlay
              if (_isBatchMode)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (bool? checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedIncidentIds.add(id);
                        } else {
                          _selectedIncidentIds.remove(id);
                        }
                      });
                    },
                  ),
                ),

              // 2. Left side Image Thumbnail
              Container(
                width: 75,
                height: 96,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: imageUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                    : const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
              ),

              // 3. Centered Content area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (data['category'] ?? "UMUM").toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              data['zone'] ?? data['district_zone'] ?? 'Zon Umum',
                              style: TextStyle(
                                fontSize: 9,
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['title'] ?? settings.t("Tiada Tajuk"),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 10, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            () {
                              try {
                                final dt = DateTime.parse(data['created_at'].toString());
                                return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                              } catch (_) {
                                return data['created_at'].toString();
                              }
                            }(),
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Right side Action Items
              if (!_isBatchMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status submit icon (separate submit icon)
                      if (status.toLowerCase() == 'pending' || status.toLowerCase() == 'draft')
                        IconButton(
                          icon: const Icon(Icons.send_outlined, color: Colors.green, size: 20),
                          tooltip: settings.t("Hantar Laporan"),
                          onPressed: () => _submitIncident(id),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Icon(Icons.check_circle_outline, color: Colors.blue, size: 18),
                        ),
                      // Three dot menu button
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                        onSelected: (action) {
                          if (action == 'delete') {
                            _deleteIncident(id);
                          } else if (action == 'edit') {
                            // Show edit popup info
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(settings.t("Ciri kemas kini sedang dibangunkan."))),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit, size: 18),
                                const SizedBox(width: 8),
                                Text(settings.t("Kemas Kini")),
                              ],
                            ),
                          ),
                          if (status.toLowerCase() != 'submitted')
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                  children: [
                                    const Icon(Icons.delete, color: Colors.red, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      settings.t("Hapus"),
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
