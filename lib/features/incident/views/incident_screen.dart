// File: lib/features/incident/views/incident_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'incident_report_screen.dart';
import 'incident_detail_screen.dart';
import '../../auth/models/location_option.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/malaysia_time.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../../core/utils/pdf_saver.dart';
import '../../../core/widgets/command_center_widgets.dart';

class IncidentScreen extends StatefulWidget {
  final String? patrollerIdFilter;
  final VoidCallback? onClose;

  const IncidentScreen({super.key, this.patrollerIdFilter, this.onClose});

  @override
  State<IncidentScreen> createState() => _IncidentScreenState();
}

class _IncidentScreenState extends State<IncidentScreen>
    with SingleTickerProviderStateMixin {
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
  final AuthService _authService = AuthService();
  List<LocationOption> _states = const [];
  List<LocationOption> _districts = const [];
  List<LocationOption> _zones = const [];
  LocationOption? _selectedState;
  LocationOption? _selectedDistrict;
  LocationOption? _selectedZone;
  DateTimeRange? _selectedDateRange;
  bool _isLoadingFilters = false;
  String? _filterError;

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

    _initializeFilters();
    _fetchIncidents();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _fetchIncidents();
      }
    });
  }

  Future<void> _initializeFilters() async {
    final auth = context.read<AuthProvider>();
    if (auth.role == 'peronda') return;

    setState(() => _isLoadingFilters = true);
    try {
      if (auth.role == 'super_admin') {
        final states = await _authService.fetchLocations(level: 'states');
        if (!mounted) return;
        setState(() {
          _states = states;
          _filterError = null;
        });
      } else if (auth.districtId != null) {
        final zones = await _authService.fetchLocations(
          level: 'zones',
          parentId: auth.districtId,
        );
        if (!mounted) return;
        setState(() {
          _zones = zones;
          _filterError = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _filterError = 'Tidak dapat memuatkan senarai lokasi.');
    } finally {
      if (mounted) setState(() => _isLoadingFilters = false);
    }
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
      String url = ApiConstants.buildApiUrl(
        'incidents/fetch_incidents.php?page=$_page&limit=10',
      );

      final authProvider = context.read<AuthProvider>();
      final String? effectiveFilter;
      if (widget.patrollerIdFilter != null) {
        effectiveFilter = widget.patrollerIdFilter;
      } else if (authProvider.role == 'peronda') {
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
      if (authProvider.role != 'peronda') {
        if (authProvider.role == 'super_admin') {
          if (_selectedState != null) {
            url += '&state_id=${Uri.encodeComponent(_selectedState!.id)}';
          }
          if (_selectedDistrict != null) {
            url += '&district_id=${Uri.encodeComponent(_selectedDistrict!.id)}';
          }
        } else {
          if (authProvider.stateId != null) {
            url += '&state_id=${Uri.encodeComponent(authProvider.stateId!)}';
          }
          if (authProvider.districtId != null) {
            url +=
                '&district_id=${Uri.encodeComponent(authProvider.districtId!)}';
          }
        }
        if (_selectedZone != null) {
          url += '&zone_id=${Uri.encodeComponent(_selectedZone!.id)}';
        }
      }

      // Handle tab-based dates
      if (_tabController.index == 0) {
        // Today
        final todayStr = MalaysiaTime.dateKey(MalaysiaTime.now());
        url += '&start_date=$todayStr&end_date=$todayStr';
      } else {
        // Archive
        if (_selectedDateRange != null) {
          final startStr = MalaysiaTime.dateKey(_selectedDateRange!.start);
          final endStr = MalaysiaTime.dateKey(_selectedDateRange!.end);
          url += '&start_date=$startStr&end_date=$endStr';
        } else {
          // Default Archive view: get incidents up to yesterday
          final yesterday = MalaysiaTime.now().subtract(
            const Duration(days: 1),
          );
          final yesterdayStr = MalaysiaTime.dateKey(yesterday);
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
            content: Text(
              'Ralat rangkaian: $e',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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
        content: Text(
          settings.t("Adakah anda pasti mahu menghapus laporan ini?"),
        ),
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
        Uri.parse(ApiConstants.buildApiUrl('incidents/delete_incident.php')),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
        body: {'id': id},
      );
      appLogger.d(
        '=== RAW INCIDENT STATUS NETWORK DATA ===\n'
        'Target URI Hit: ${response.request?.url}\n'
        'HTTP Status Code: ${response.statusCode}\n'
        'Raw Body Response: "${response.body}"\n'
        '=============================',
      );

      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        if (res['status'] == 'success') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(settings.t("Laporan berjaya dihapuskan.")),
              backgroundColor: Colors.green,
            ),
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
        SnackBar(
          content: Text('${settings.t("Ralat:")} $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitIncident(String id) async {
    final settings = context.read<SettingsProvider>();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse(ApiConstants.buildApiUrl('incidents/update_status.php')),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
        body: {'id': id, 'status': 'Submitted'},
      );
      appLogger.d(
        '=== RAW DAILY NOTE SUBMIT NETWORK DATA ===\n'
        'Target URI Hit: ${response.request?.url}\n'
        'HTTP Status Code: ${response.statusCode}\n'
        'Raw Body Response: "${response.body}"\n'
        '=============================',
      );

      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        if (res['status'] == 'success') {
          if (!mounted) return;
          await _showReportSuccessfulDialog();
          await _refresh();
        } else {
          throw Exception(res['message']);
        }
      } else {
        throw Exception("Server Error ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.t("Ralat:")} $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _bulkDelete() async {
    final settings = context.read<SettingsProvider>();
    if (_selectedIncidentIds.isEmpty) return;

    // Guard: Prevent deletion of submitted records
    final hasSubmitted = _selectedIncidentIds.any((id) {
      final incident = _incidents.firstWhere(
        (i) => i['id'].toString() == id,
        orElse: () => null,
      );
      if (incident != null) {
        final status = incident['status'] ?? 'Pending';
        return status.toLowerCase() == 'submitted';
      }
      return false;
    });

    if (hasSubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.t("Laporan yang telah dihantar tidak boleh dihapuskan."),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t("Hapus Batch")),
        content: Text(
          settings.t("Adakah anda pasti mahu menghapus semua laporan dipilih?"),
        ),
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
          Uri.parse(ApiConstants.buildApiUrl('incidents/delete_incident.php')),
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
          body: {'id': id},
        );
        appLogger.d(
          '=== RAW INCIDENT STATUS NETWORK DATA ===\n'
          'Target URI Hit: ${response.request?.url}\n'
          'HTTP Status Code: ${response.statusCode}\n'
          'Raw Body Response: "${response.body}"\n'
          '=============================',
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
      SnackBar(
        content: Text(
          "$successCount ${settings.t("laporan berjaya dihapuskan.")}",
        ),
        backgroundColor: Colors.green,
      ),
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

    final pendingIds = _selectedIncidentIds.where((id) {
      final incident = _incidents.firstWhere(
        (inc) => inc['id'].toString() == id,
        orElse: () => null,
      );
      if (incident == null) return false;
      return _isPendingStatus(incident['status'] ?? 'Pending');
    }).toList();

    if (pendingIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.t('note_pending_submission')),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    int successCount = 0;
    for (final id in pendingIds) {
      try {
        final response = await http.post(
          Uri.parse(ApiConstants.buildApiUrl('incidents/update_status.php')),
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
          body: {'id': id, 'status': 'Submitted'},
        );
        appLogger.d(
          '=== RAW DAILY NOTE SUBMIT NETWORK DATA ===\n'
          'Target URI Hit: ${response.request?.url}\n'
          'HTTP Status Code: ${response.statusCode}\n'
          'Raw Body Response: "${response.body}"\n'
          '=============================',
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
    final failedCount = pendingIds.length - successCount;
    if (successCount > 0) {
      await _showReportSuccessfulDialog(count: successCount);
    }
    if (!mounted) return;
    if (failedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount berjaya, $failedCount gagal'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    setState(() {
      _selectedIncidentIds.clear();
      _isBatchMode = false;
    });
    _refresh();
  }

  bool _isPendingStatus(dynamic status) {
    final normalized = (status ?? '').toString().toLowerCase();
    return normalized == 'pending' || normalized == 'draft';
  }

  Future<void> _showReportSuccessfulDialog({int? count}) async {
    final settings = context.read<SettingsProvider>();
    final message = count == null
        ? settings.t(
            'Data insiden telah direkodkan ke dalam sistem Nota Harian.',
          )
        : settings
              .t('daily_notes_submitted_count')
              .replaceFirst('X', count.toString());

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF2DA44E),
                size: 64,
              ),
              const SizedBox(height: 20),
              Text(
                settings.t('report_successful'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2DA44E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    settings.t('Selesai'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    final settings = context.read<SettingsProvider>();
    final authProvider = context.read<AuthProvider>();
    final theme = Theme.of(context);
    final bool showZoneFilter = authProvider.role != 'peronda';
    String tempCategory = _selectedFilter;
    final bool isSuperAdmin = authProvider.role == 'super_admin';
    var tempState = _selectedState;
    var tempDistrict = _selectedDistrict;
    var tempZone = _selectedZone;
    var sheetDistricts = List<LocationOption>.from(_districts);
    var sheetZones = List<LocationOption>.from(_zones);
    var sheetError = _filterError;
    var isLoadingLocations = false;
    var sheetOpen = true;

    Future<void> loadDistricts(
      LocationOption? state,
      StateSetter setSheetState,
    ) async {
      setSheetState(() {
        tempState = state;
        tempDistrict = null;
        tempZone = null;
        sheetDistricts = const [];
        sheetZones = const [];
        sheetError = null;
        isLoadingLocations = state != null;
      });
      if (state == null) return;
      try {
        final districts = await _authService.fetchLocations(
          level: 'districts',
          parentId: state.id,
        );
        if (!mounted || !sheetOpen || tempState?.id != state.id) return;
        setSheetState(() {
          sheetDistricts = districts;
          isLoadingLocations = false;
        });
      } catch (_) {
        if (!mounted || !sheetOpen) return;
        setSheetState(() {
          sheetError = settings.t('Tidak dapat memuatkan daerah.');
          isLoadingLocations = false;
        });
      }
    }

    Future<void> loadZones(
      LocationOption? district,
      StateSetter setSheetState,
    ) async {
      setSheetState(() {
        tempDistrict = district;
        tempZone = null;
        sheetZones = const [];
        sheetError = null;
        isLoadingLocations = district != null;
      });
      if (district == null) return;
      try {
        final zones = await _authService.fetchLocations(
          level: 'zones',
          parentId: district.id,
        );
        if (!mounted || !sheetOpen || tempDistrict?.id != district.id) return;
        setSheetState(() {
          sheetZones = zones;
          isLoadingLocations = false;
        });
      } catch (_) {
        if (!mounted || !sheetOpen) return;
        setSheetState(() {
          sheetError = settings.t('Tidak dapat memuatkan zon.');
          isLoadingLocations = false;
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Text(
                    settings.t("Kategori"),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: tempCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.dividerColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _filterOptions.map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: Text(
                          val,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => tempCategory = val);
                      }
                    },
                  ),
                  if (showZoneFilter) ...[
                    const SizedBox(height: 16),
                    if (isLoadingLocations || _isLoadingFilters) ...[
                      LinearProgressIndicator(color: theme.primaryColor),
                      const SizedBox(height: 12),
                    ],
                    if (sheetError != null) ...[
                      Text(
                        sheetError!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (isSuperAdmin) ...[
                      _IncidentLocationDropdown(
                        label: settings.t('Negeri'),
                        value: tempState,
                        items: _states,
                        allLabel: settings.t('Semua Negeri'),
                        onChanged: (value) =>
                            loadDistricts(value, setSheetState),
                      ),
                      const SizedBox(height: 12),
                      _IncidentLocationDropdown(
                        label: settings.t('Daerah'),
                        value: tempDistrict,
                        items: sheetDistricts,
                        allLabel: settings.t('Semua Daerah'),
                        enabled: tempState != null,
                        onChanged: (value) => loadZones(value, setSheetState),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      Text(
                        '${settings.t("Negeri")}: ${authProvider.stateName ?? "-"}  |  ${settings.t("Daerah")}: ${authProvider.districtName ?? "-"}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                    ],
                    _IncidentLocationDropdown(
                      label: settings.t('Zon Rondaan'),
                      value: tempZone,
                      items: sheetZones,
                      allLabel: settings.t('Semua Zon'),
                      enabled: isSuperAdmin ? tempDistrict != null : true,
                      onChanged: (value) =>
                          setSheetState(() => tempZone = value),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    settings.t("Pilih Tarikh"),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final List<DateTime?>? results =
                          await showCalendarDatePicker2Dialog(
                            context: context,
                            config: CalendarDatePicker2WithActionButtonsConfig(
                              calendarType: CalendarDatePicker2Type.range,
                              selectedDayHighlightColor: theme.primaryColor,
                              weekdayLabelTextStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              controlsTextStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
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
                            _selectedDateRange = DateTimeRange(
                              start: results[0]!,
                              end: results[0]!,
                            );
                          } else if (results.length >= 2 &&
                              results[0] != null &&
                              results[1] != null) {
                            _selectedDateRange = DateTimeRange(
                              start: results[0]!,
                              end: results[1]!,
                            );
                          }
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
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
                              _selectedState = null;
                              _selectedDistrict = null;
                              _selectedZone = null;
                              _districts = const [];
                              if (isSuperAdmin) _zones = const [];
                              _selectedDateRange = null;
                              _filterError = null;
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
                              _selectedState = showZoneFilter
                                  ? tempState
                                  : null;
                              _selectedDistrict = showZoneFilter
                                  ? tempDistrict
                                  : null;
                              _selectedZone = showZoneFilter ? tempZone : null;
                              _districts = sheetDistricts;
                              _zones = sheetZones;
                              _filterError = sheetError;
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
    ).whenComplete(() => sheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    final authProvider = context.watch<AuthProvider>();
    final isArchiveTab = _tabController.index == 1;
    final isAdminOrSquadLeader =
        authProvider.role == 'ketua_krt' ||
        authProvider.role == 'ketua_peronda';

    final displayIncidents = _incidents.where((incident) {
      if (isArchiveTab && isAdminOrSquadLeader) {
        final status = (incident['status'] ?? '').toString().toLowerCase();
        return status == 'submitted';
      }
      return true;
    }).toList();
    return Scaffold(
      appBar: widget.patrollerIdFilter != null
          ? AppBar(
              title: Row(
                children: [
                  const SizedBox(width: 8),
                  Text(
                    settings.t('Nota Harian Rondaan'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: settings.t('Kembali'),
              ),
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              children: [
                CommandHeader(
                  title: settings.t('Log Insiden & Nota Harian'),
                  subtitle: settings.t(
                    'Semak laporan rondaan, hantar nota kepada KRT, dan susun rekod operasi.',
                  ),
                  icon: Icons.warning_amber_rounded,
                  compact: true,
                ),
              ],
            ),
          ),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
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
                        Tab(
                          child: Text(
                            settings.t('Hari Ini'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Tab(
                          child: Text(
                            settings.t('Arkib'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (widget.patrollerIdFilter == null)
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
                  ? Center(
                      child: CircularProgressIndicator(
                        color: theme.primaryColor,
                      ),
                    )
                  : displayIncidents.isEmpty && !_isLoading
                  ? ListView(
                      children: [
                        const SizedBox(height: 200),
                        Center(
                          child: Text(
                            settings.t("Tiada insiden direkodkan."),
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                            ),
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
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.redAccent,
                              ),
                            ),
                          );
                        }
                        return _buildIncidentCard(displayIncidents[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: widget.patrollerIdFilter == null
          ? FloatingActionButton(
              heroTag: 'incident_add_daily_note_fab',
              tooltip: settings.t('add_daily_note'),
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              onPressed: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IncidentReportScreen(),
                  ),
                );
                if (saved == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(settings.t('daily_note_saved_message')),
                      backgroundColor: const Color(0xFF2DA44E),
                    ),
                  );
                }
                await _refresh();
              },
              child: const Icon(Icons.edit_note_rounded),
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
          if (parsed.isNotEmpty) {
            imageUrl = ApiConstants.resolveUploadUrl(parsed.first.toString());
          }
        } else {
          imageUrl = ApiConstants.resolveUploadUrl(
            data['image_url'].toString(),
          );
        }
      } catch (e) {
        imageUrl = ApiConstants.resolveUploadUrl(data['image_url'].toString());
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
      color: theme.cardColor,
      elevation: 3,
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
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IncidentDetailScreen(incident: data),
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          IncidentDetailScreen(incident: data),
                    ),
                  );
                }
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 130),
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
              if (imageUrl != null)
                Container(
                  width: 92,
                  height: 130,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),

              // 3. Centered Content area
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: imageUrl != null ? 15.0 : 19.0,
                    right: 13.0,
                    top: 13.0,
                    bottom: 13.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (data['category'] ?? "UMUM").toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              data['zone'] ??
                                  data['district_zone'] ??
                                  'Zon Umum',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['title'] ?? settings.t("Tiada Tajuk"),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 15,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            () {
                              try {
                                final dt = MalaysiaTime.fromUtcDatabase(
                                  data['created_at'],
                                );
                                return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                              } catch (_) {
                                return data['created_at'].toString();
                              }
                            }(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
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
                      if (_isPendingStatus(status))
                        IconButton(
                          icon: const Icon(
                            Icons.send_outlined,
                            color: Colors.green,
                            size: 21,
                          ),
                          tooltip: settings.t("send_to_krt"),
                          onPressed: () => _submitIncident(id),
                          constraints: const BoxConstraints(
                            minWidth: 50,
                            minHeight: 50,
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Icon(
                            Icons.check_circle_outline,
                            color: Colors.blue,
                            size: 19,
                          ),
                        ),
                      // Three dot menu button
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.grey,
                          size: 21,
                        ),
                        onSelected: (action) {
                          if (action == 'delete') {
                            _deleteIncident(id);
                          } else if (action == 'preview') {
                            if (context.mounted) {
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
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Scaffold(
                                        appBar: AppBar(
                                          title: Text(
                                            settings.t(
                                              'Pratonton Buku Nota Harian',
                                            ),
                                          ),
                                        ),
                                        body: PdfPreview(
                                          build: (format) async {
                                            final doc =
                                                await IncidentDetailScreen.buildPdf(
                                                  data,
                                                );
                                            return doc.save();
                                          },
                                          canChangeOrientation: false,
                                          canChangePageFormat: false,
                                          canDebug: false,
                                          pdfFileName:
                                              'buku_nota_harian_${data['id']}.pdf',
                                          actions: [
                                            PdfPreviewAction(
                                              icon: Tooltip(
                                                message: settings.t(
                                                  'Muat Turun PDF',
                                                ),
                                                child: const Icon(
                                                  Icons.download,
                                                ),
                                              ),
                                              onPressed:
                                                  (
                                                    context,
                                                    build,
                                                    pageFormat,
                                                  ) async {
                                                    final bytes = await build(
                                                      pageFormat,
                                                    );
                                                    if (context.mounted) {
                                                      await savePdf(
                                                        context,
                                                        bytes,
                                                        'buku_nota_harian_${data['id']}.pdf',
                                                      );
                                                    }
                                                  },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      appBar: AppBar(
                                        title: Text(
                                          settings.t(
                                            'Pratonton Buku Nota Harian',
                                          ),
                                        ),
                                      ),
                                      body: PdfPreview(
                                        build: (format) async {
                                          final doc =
                                              await IncidentDetailScreen.buildPdf(
                                                data,
                                              );
                                          return doc.save();
                                        },
                                        canChangeOrientation: false,
                                        canChangePageFormat: false,
                                        canDebug: false,
                                        pdfFileName:
                                            'buku_nota_harian_${data['id']}.pdf',
                                        actions: [
                                          PdfPreviewAction(
                                            icon: Tooltip(
                                              message: settings.t(
                                                'Muat Turun PDF',
                                              ),
                                              child: const Icon(Icons.download),
                                            ),
                                            onPressed:
                                                (
                                                  context,
                                                  build,
                                                  pageFormat,
                                                ) async {
                                                  final bytes = await build(
                                                    pageFormat,
                                                  );
                                                  if (context.mounted) {
                                                    await savePdf(
                                                      context,
                                                      bytes,
                                                      'buku_nota_harian_${data['id']}.pdf',
                                                    );
                                                  }
                                                },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'preview',
                            child: Row(
                              children: [
                                const Icon(Icons.picture_as_pdf, size: 18),
                                const SizedBox(width: 8),
                                Text(settings.t("Preview")),
                              ],
                            ),
                          ),
                          if (status.toLowerCase() != 'submitted')
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 18,
                                  ),
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
                )
              else if (status.toLowerCase() == 'submitted')
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: Colors.blue,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncidentLocationDropdown extends StatelessWidget {
  const _IncidentLocationDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.allLabel,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final LocationOption? value;
  final List<LocationOption> items;
  final String allLabel;
  final ValueChanged<LocationOption?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<LocationOption?>(
      key: ValueKey('$label-${value?.id ?? "all"}-${items.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.dividerColor.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      items: [
        DropdownMenuItem<LocationOption?>(
          value: null,
          child: Text(allLabel, overflow: TextOverflow.ellipsis),
        ),
        ...items.map(
          (item) => DropdownMenuItem<LocationOption?>(
            value: item,
            child: Text(item.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
