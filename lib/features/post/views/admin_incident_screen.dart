import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/command_center_widgets.dart';
import '../../auth/models/location_option.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';
import '../../incident/views/incident_screen.dart';

class AdminIncidentScreen extends StatefulWidget {
  final ValueChanged<bool>? onSubViewChanged;
  const AdminIncidentScreen({super.key, this.onSubViewChanged});

  @override
  State<AdminIncidentScreen> createState() => _AdminIncidentScreenState();
}

class _AdminIncidentScreenState extends State<AdminIncidentScreen> {
  List<dynamic> _patrollers = [];
  String _searchQuery = '';
  final AuthService _authService = AuthService();
  List<LocationOption> _states = const [];
  List<LocationOption> _districts = const [];
  List<LocationOption> _zones = const [];
  LocationOption? _selectedState;
  LocationOption? _selectedDistrict;
  LocationOption? _selectedZone;
  String _selectedNoteFilter = 'all';
  String _selectedSortPriority = 'Default';
  bool _isLoading = true;
  bool _isLoadingFilters = false;
  String? _error;
  String? _filterError;

  @override
  void initState() {
    super.initState();
    _initializeFilters();
    _fetchPatrollers();
  }

  Future<void> _initializeFilters() async {
    final auth = context.read<AuthProvider>();
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

  Future<void> _fetchPatrollers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final Map<String, String> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse(ApiConstants.buildApiUrl('auth/get_patrollers.php')),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final List<dynamic> patrollerList = List.from(data['data'] ?? []);

          // Fetch incidents to calculate note counts
          try {
            final incidentsResponse = await http.get(
              Uri.parse(
                ApiConstants.buildApiUrl(
                  'incidents/fetch_incidents.php?page=1&limit=9999',
                ),
              ),
              headers: headers,
            );
            if (incidentsResponse.statusCode == 200) {
              final incidentsData = json.decode(incidentsResponse.body);
              final List<dynamic> incidentsList = incidentsData['data'] ?? [];
              final Map<String, int> noteCounts = {};
              for (var incident in incidentsList) {
                final status = incident['status']?.toString() ?? '';
                if (status.toLowerCase() == 'submitted') {
                  final userId = incident['user_id']?.toString();
                  if (userId != null) {
                    noteCounts[userId] = (noteCounts[userId] ?? 0) + 1;
                  }
                }
              }
              for (var patroller in patrollerList) {
                final String patrollerId = patroller['id']?.toString() ?? '';
                patroller['note_count'] = noteCounts[patrollerId] ?? 0;
              }
            }
          } catch (e) {
            debugPrint("Error fetching incidents for count: $e");
          }

          setState(() {
            _patrollers = patrollerList;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data['message'];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Pelayan Gagal: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ralat Rangkaian: $e';
        _isLoading = false;
      });
    }
  }

  void _showFilterBottomSheet() {
    final settings = context.read<SettingsProvider>();
    final auth = context.read<AuthProvider>();
    final theme = Theme.of(context);
    final isSuperAdmin = auth.role == 'super_admin';
    var tempState = _selectedState;
    var tempDistrict = _selectedDistrict;
    var tempZone = _selectedZone;
    var sheetDistricts = List<LocationOption>.from(_districts);
    var sheetZones = List<LocationOption>.from(_zones);
    String tempSortPriority = _selectedSortPriority;
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24.0,
                16.0,
                24.0,
                24.0 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        settings.t("Tapis Laporan Insiden"),
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
                  const SizedBox(height: 12),
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
                    _LocationDropdown(
                      label: settings.t('Negeri'),
                      value: tempState,
                      items: _states,
                      allLabel: settings.t('Semua Negeri'),
                      onChanged: (value) => loadDistricts(value, setSheetState),
                    ),
                    const SizedBox(height: 12),
                    _LocationDropdown(
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
                      '${settings.t("Negeri")}: ${auth.stateName ?? "-"}  |  ${settings.t("Daerah")}: ${auth.districtName ?? "-"}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _LocationDropdown(
                    label: settings.t('Zon Rondaan'),
                    value: tempZone,
                    items: sheetZones,
                    allLabel: settings.t('Semua Zon'),
                    enabled: isSuperAdmin ? tempDistrict != null : true,
                    onChanged: (value) => setSheetState(() => tempZone = value),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    settings.t("Susunan Prioriti"),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: tempSortPriority,
                    isExpanded: true,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.dividerColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'Default',
                        child: Text(
                          settings.t('Abjad (Default)'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Paling Banyak Nota',
                        child: Text(
                          settings.t('Paling Banyak Nota'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Tiada Nota',
                        child: Text(
                          settings.t('Tiada Nota'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => tempSortPriority = val);
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedState = null;
                              _selectedDistrict = null;
                              _selectedZone = null;
                              _districts = const [];
                              _zones = isSuperAdmin
                                  ? const []
                                  : List<LocationOption>.from(_zones);
                              _selectedNoteFilter = 'all';
                              _selectedSortPriority = 'Default';
                              _filterError = null;
                            });
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(settings.t('Reset')),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _selectedState = tempState;
                              _selectedDistrict = tempDistrict;
                              _selectedZone = tempZone;
                              _districts = sheetDistricts;
                              _zones = sheetZones;
                              _filterError = sheetError;
                              _selectedSortPriority = tempSortPriority;
                            });
                            Navigator.pop(context);
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: theme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(settings.t('Tapis')),
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

  void _openPatrollerReports(dynamic patroller) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            IncidentScreen(patrollerIdFilter: patroller['id']),
      ),
    );
  }

  Widget _buildStatusChips(
    SettingsProvider settings,
    ThemeData theme,
    List<LocationOption> zones,
  ) {
    final zoneChips = zones
        .take(4)
        .map(
          (zone) =>
              _ReportChipData(zone.id, zone.name, Icons.location_on_outlined),
        );
    final chips = [
      _ReportChipData('all', settings.t('Semua'), Icons.dashboard_outlined),
      _ReportChipData(
        'with_notes',
        settings.t('Ada Nota'),
        Icons.sticky_note_2_outlined,
      ),
      _ReportChipData(
        'no_notes',
        settings.t('No Notes'),
        Icons.note_alt_outlined,
      ),
      ...zoneChips,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((chip) {
            final isZoneChip =
                zones.any((zone) => zone.id == chip.key) && chip.key != 'all';
            final selected = isZoneChip
                ? _selectedZone?.id == chip.key
                : _selectedNoteFilter == chip.key ||
                      (chip.key == 'all' &&
                          _selectedNoteFilter == 'all' &&
                          _selectedZone == null);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected,
                showCheckmark: false,
                avatar: Icon(
                  chip.icon,
                  size: 17,
                  color: selected ? Colors.white : theme.primaryColor,
                ),
                label: Text(
                  chip.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : theme.primaryColor,
                  fontWeight: FontWeight.w800,
                ),
                selectedColor: theme.primaryColor,
                backgroundColor: theme.cardColor,
                side: BorderSide(
                  color: selected
                      ? theme.primaryColor
                      : theme.dividerColor.withValues(alpha: 0.22),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                onSelected: (_) {
                  setState(() {
                    if (chip.key == 'all') {
                      _selectedNoteFilter = 'all';
                      _selectedZone = null;
                    } else if (isZoneChip) {
                      _selectedZone = zones.firstWhere(
                        (zone) => zone.id == chip.key,
                      );
                    } else {
                      _selectedNoteFilter = chip.key;
                    }
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReportCard(
    dynamic patroller,
    SettingsProvider settings,
    ThemeData theme,
  ) {
    final noteCount = patroller['note_count'] as int? ?? 0;
    final hasNotes = noteCount > 0;
    final zone = patroller['district_zone'] ?? settings.t('Tiada');
    final ic = patroller['ic_number'] ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openPatrollerReports(patroller),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatar(
                imageUrl: patroller['profile_image_url'] as String?,
                initials: UserAvatar.initialsFromName(
                  patroller['full_name'] as String?,
                  fallback: 'P',
                ),
                radius: 23,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patroller['full_name']?.toString() ??
                          settings.t('Tidak Diketahui'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _reportPill(
                          Icons.location_on_outlined,
                          '${settings.t('Zon')}: $zone',
                          theme.primaryColor,
                        ),
                        _reportPill(
                          Icons.badge_outlined,
                          'IC: $ic',
                          theme.textTheme.bodyMedium?.color?.withValues(
                                alpha: 0.62,
                              ) ??
                              Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: hasNotes
                          ? theme.primaryColor.withValues(alpha: 0.1)
                          : Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$noteCount ${settings.t('Nota')}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: hasNotes ? theme.primaryColor : Colors.redAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        settings.t('Lihat'),
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(SettingsProvider settings) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 92, 8, 120),
      children: [
        CommandEmptyStateCard(
          icon: Icons.assignment_outlined,
          title: settings.t('Tiada padanan carian.'),
          message: settings.t(
            'Ubah carian, nota, atau penapis zon untuk melihat laporan.',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      );
    }

    if (_patrollers.isEmpty) {
      return Center(
        child: Text(
          settings.t('Tiada peronda dijumpai.'),
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    final zones = _zones;

    // Apply filtering
    final filteredPatrollers = _patrollers.where((p) {
      final matchesSearch = p['full_name'].toString().toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesState =
          _selectedState == null ||
          p['state_id']?.toString() == _selectedState!.id;
      final matchesDistrict =
          _selectedDistrict == null ||
          p['district_id']?.toString() == _selectedDistrict!.id;
      final matchesZone =
          _selectedZone == null ||
          p['zone_id']?.toString() == _selectedZone!.id;
      final noteCount = p['note_count'] as int? ?? 0;
      final matchesNotes =
          _selectedNoteFilter == 'all' ||
          (_selectedNoteFilter == 'with_notes' && noteCount > 0) ||
          (_selectedNoteFilter == 'no_notes' && noteCount == 0);
      return matchesSearch &&
          matchesState &&
          matchesDistrict &&
          matchesZone &&
          matchesNotes;
    }).toList();

    if (_selectedSortPriority == 'Paling Banyak Nota') {
      filteredPatrollers.sort((a, b) {
        final int countA = a['note_count'] ?? 0;
        final int countB = b['note_count'] ?? 0;
        return countB.compareTo(countA);
      });
    } else if (_selectedSortPriority == 'Tiada Nota') {
      filteredPatrollers.sort((a, b) {
        final int countA = a['note_count'] ?? 0;
        final int countB = b['note_count'] ?? 0;
        if (countA == 0 && countB != 0) return -1;
        if (countB == 0 && countA != 0) return 1;
        return countB.compareTo(countA);
      });
    } else {
      filteredPatrollers.sort(
        (a, b) =>
            a['full_name'].toString().compareTo(b['full_name'].toString()),
      );
    }

    final bool isFilterActive =
        _selectedState != null ||
        _selectedDistrict != null ||
        _selectedZone != null ||
        _selectedNoteFilter != 'all' ||
        _selectedSortPriority != 'Default';
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            children: [
              CommandHeader(
                title: settings.t('Suapan Laporan Peronda'),
                subtitle: settings.t(
                  'Pantau nota harian, zon rondaan, dan rekod peronda dari satu paparan operasi.',
                ),
                icon: Icons.assignment_outlined,
                compact: true,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: settings.t('Cari nama peronda...'),
                    hintStyle: TextStyle(
                      color: theme.textTheme.bodyLarge?.color?.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                    filled: true,
                    fillColor: theme.cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      color: isFilterActive ? Colors.white : theme.primaryColor,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: isFilterActive
                          ? theme.primaryColor
                          : theme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isFilterActive
                              ? Colors.transparent
                              : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed: _showFilterBottomSheet,
                  ),
                  if (isFilterActive)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        _buildStatusChips(settings, theme, zones),

        // List of filtered patrollers
        Expanded(
          child: filteredPatrollers.isEmpty
              ? _buildEmptyState(settings)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  itemCount: filteredPatrollers.length,
                  itemBuilder: (context, index) {
                    final patroller = filteredPatrollers[index];
                    return _buildReportCard(patroller, settings, theme);
                  },
                ),
        ),
      ],
    );
  }
}

class _ReportChipData {
  final String key;
  final String label;
  final IconData icon;

  const _ReportChipData(this.key, this.label, this.icon);
}

class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown({
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
      dropdownColor: theme.cardColor,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.dividerColor.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
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
