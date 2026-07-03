import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/command_center_widgets.dart';
import '../../auth/models/location_option.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';

class AdminSquadScheduleScreen extends StatefulWidget {
  const AdminSquadScheduleScreen({super.key});

  @override
  State<AdminSquadScheduleScreen> createState() =>
      _AdminSquadScheduleScreenState();
}

class _AdminSquadScheduleScreenState extends State<AdminSquadScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: CommandHeader(
            title: settings.t('Jadual & Skuad'),
            subtitle: settings.t(
              'Susun kumpulan rondaan dan jadual tugasan untuk operasi harian.',
            ),
            icon: Icons.groups_3_outlined,
            compact: true,
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(
            alpha: 0.6,
          ),
          indicatorColor: theme.colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: theme.dividerColor.withValues(alpha: 0.1),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
          tabs: [
            Tab(text: settings.t('Kumpulan')),
            Tab(text: settings.t('Penjadualan')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [_SquadManagementTab(), _ScheduleManagementTab()],
          ),
        ),
      ],
    );
  }
}

class _SquadManagementTab extends StatefulWidget {
  const _SquadManagementTab();

  @override
  State<_SquadManagementTab> createState() => _SquadManagementTabState();
}

class _SquadManagementTabState extends State<_SquadManagementTab> {
  List<dynamic> _squads = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  final AuthService _authService = AuthService();
  LocationOption? _selectedState;
  LocationOption? _selectedDistrict;
  LocationOption? _selectedZone;
  List<LocationOption> _states = const [];
  List<LocationOption> _districts = const [];
  List<LocationOption> _zones = const [];
  String? _filterError;

  SettingsProvider get settings =>
      Provider.of<SettingsProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _initializeFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeFilters() async {
    final auth = context.read<AuthProvider>();
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
      setState(
        () => _filterError = settings.t('Tidak dapat memuatkan lokasi.'),
      );
    }
    await _fetchSquads();
  }

  String _currentLocationQuery() {
    final auth = context.read<AuthProvider>();
    final query = <String, String>{};
    if (auth.role != 'super_admin') {
      if (auth.stateId != null) query['state_id'] = auth.stateId!;
      if (auth.districtId != null) query['district_id'] = auth.districtId!;
    }
    final encoded = Uri(queryParameters: query).query;
    return encoded.isEmpty ? '' : '?$encoded';
  }

  Future<void> _fetchSquads() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.getData(
        'admin/squads.php${_currentLocationQuery()}',
      );
      if (response['status'] == 'success' || response['success'] == true) {
        setState(() => _squads = response['data'] ?? []);
      }
    } catch (e) {
      debugPrint("Error fetching squads: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredSquads {
    final query = _searchController.text.trim().toLowerCase();
    return _squads.where((squad) {
      final members = squad['members'] as List<dynamic>? ?? [];
      final searchText = [
        squad['name']?.toString() ?? '',
        _locationTrail(squad, settings),
        ...members.map((member) => member['full_name']?.toString() ?? ''),
      ].join(' ').toLowerCase();
      final matchesSearch = query.isEmpty || searchText.contains(query);
      final matchesState =
          _selectedState == null ||
          squad['state_id']?.toString() == _selectedState!.id;
      final matchesDistrict =
          _selectedDistrict == null ||
          squad['district_id']?.toString() == _selectedDistrict!.id;
      final matchesZone =
          _selectedZone == null ||
          squad['zone_id']?.toString() == _selectedZone!.id;
      return matchesSearch && matchesState && matchesDistrict && matchesZone;
    }).toList();
  }

  List<String> _activeSquadFilterLabels(SettingsProvider settings) {
    return [
      if (_selectedState != null) _selectedState!.name,
      if (_selectedDistrict != null) _selectedDistrict!.name,
      if (_selectedZone != null) _selectedZone!.name,
    ];
  }

  void _showSquadFilterSheet(SettingsProvider settings) {
    final auth = context.read<AuthProvider>();
    final isSuperAdmin = auth.role == 'super_admin';
    var selectedState = _selectedState;
    var selectedDistrict = _selectedDistrict;
    var selectedZone = _selectedZone;
    var sheetDistricts = List<LocationOption>.from(_districts);
    var sheetZones = List<LocationOption>.from(_zones);
    var sheetError = _filterError;
    var isLoading = false;
    var sheetOpen = true;

    Future<void> loadDistricts(
      LocationOption? state,
      StateSetter setSheetState,
    ) async {
      setSheetState(() {
        selectedState = state;
        selectedDistrict = null;
        selectedZone = null;
        sheetDistricts = const [];
        sheetZones = const [];
        sheetError = null;
        isLoading = state != null;
      });
      if (state == null) return;
      try {
        final districts = await _authService.fetchLocations(
          level: 'districts',
          parentId: state.id,
        );
        if (!mounted || !sheetOpen || selectedState?.id != state.id) return;
        setSheetState(() {
          sheetDistricts = districts;
          isLoading = false;
        });
      } catch (_) {
        if (!mounted || !sheetOpen) return;
        setSheetState(() {
          sheetError = settings.t('Tidak dapat memuatkan daerah.');
          isLoading = false;
        });
      }
    }

    Future<void> loadZones(
      LocationOption? district,
      StateSetter setSheetState,
    ) async {
      setSheetState(() {
        selectedDistrict = district;
        selectedZone = null;
        sheetZones = const [];
        sheetError = null;
        isLoading = district != null;
      });
      if (district == null) return;
      try {
        final zones = await _authService.fetchLocations(
          level: 'zones',
          parentId: district.id,
        );
        if (!mounted || !sheetOpen || selectedDistrict?.id != district.id) {
          return;
        }
        setSheetState(() {
          sheetZones = zones;
          isLoading = false;
        });
      } catch (_) {
        if (!mounted || !sheetOpen) return;
        setSheetState(() {
          sheetError = settings.t('Tidak dapat memuatkan zon.');
          isLoading = false;
        });
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          settings.t('Tapis Kumpulan'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: settings.t('Tutup'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (isLoading) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                  if (sheetError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      sheetError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (isSuperAdmin) ...[
                    _LocationDropdown(
                      label: settings.t('Negeri'),
                      value: selectedState,
                      items: _states,
                      allLabel: settings.t('Semua Negeri'),
                      onChanged: (value) => loadDistricts(value, setSheetState),
                    ),
                    const SizedBox(height: 12),
                    _LocationDropdown(
                      label: settings.t('Daerah'),
                      value: selectedDistrict,
                      items: sheetDistricts,
                      allLabel: settings.t('Semua Daerah'),
                      enabled: selectedState != null,
                      onChanged: (value) => loadZones(value, setSheetState),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${settings.t("Negeri")} • ${settings.t("Daerah")}: '
                        '${auth.stateName ?? "-"} • ${auth.districtName ?? "-"}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _LocationDropdown(
                    label: settings.t('Zon'),
                    value: selectedZone,
                    items: sheetZones,
                    allLabel: settings.t('Semua Zon'),
                    enabled: isSuperAdmin ? selectedDistrict != null : true,
                    onChanged: (value) =>
                        setSheetState(() => selectedZone = value),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              selectedState = null;
                              selectedDistrict = null;
                              selectedZone = null;
                              sheetDistricts = const [];
                              sheetZones = isSuperAdmin
                                  ? const []
                                  : List<LocationOption>.from(_zones);
                              sheetError = null;
                            });
                          },
                          child: Text(settings.t('Reset')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _selectedState = selectedState;
                              _selectedDistrict = selectedDistrict;
                              _selectedZone = selectedZone;
                              _districts = sheetDistricts;
                              _zones = sheetZones;
                              _filterError = sheetError;
                            });
                            Navigator.pop(context);
                          },
                          child: Text(settings.t('Tapis')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() => sheetOpen = false);
  }

  Future<void> _createSquad({
    required String name,
    required String stateId,
    required String districtId,
    required String zoneId,
    required String headUserId,
    required List<String> memberIds,
  }) async {
    final auth = context.read<AuthProvider>();

    final body = <String, String>{'action': 'create_squad', 'name': name};
    body['state_id'] = auth.role == 'super_admin'
        ? stateId
        : auth.stateId ?? stateId;
    body['district_id'] = auth.role == 'super_admin'
        ? districtId
        : auth.districtId ?? districtId;
    body['zone_id'] = zoneId;
    body['head_user_id'] = headUserId;
    body['member_ids'] = memberIds.join(',');

    try {
      final response = await ApiClient.postData('admin/squads.php', body);
      if (response['success'] == true || response['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(settings.t('Kumpulan berjaya dicipta!'))),
          );
        }
        _fetchSquads();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                settings.t(response['message'] ?? 'Ralat mencipta kumpulan'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${settings.t("Ralat")}: $e')));
      }
    }
  }

  Future<void> _addMember(String squadId, String userId) async {
    try {
      final response = await ApiClient.postData('admin/squads.php', {
        'action': 'add_member',
        'squad_id': squadId,
        'user_id': userId,
      });
      if (response['success'] == true || response['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(settings.t('Ahli berjaya ditambah!'))),
          );
        }
        _fetchSquads();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                settings.t(response['message'] ?? 'Ralat menambah ahli'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${settings.t("Ralat")}: $e')));
      }
    }
  }

  Future<void> _removeMember(String squadId, String userId) async {
    try {
      final response = await ApiClient.postData('admin/squads.php', {
        'action': 'remove_member',
        'squad_id': squadId,
        'user_id': userId,
      });
      if (response['success'] == true || response['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(settings.t('Ahli berjaya dikeluarkan!'))),
          );
        }
        _fetchSquads();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                settings.t(response['message'] ?? 'Ralat mengeluarkan ahli'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${settings.t("Ralat")}: $e')));
      }
    }
  }

  Future<void> _deleteSquad(String squadId) async {
    try {
      final response = await ApiClient.postData('admin/squads.php', {
        'action': 'delete_squad',
        'squad_id': squadId,
      });
      if (response['success'] == true || response['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(settings.t('Kumpulan dipadam!'))),
          );
        }
        _fetchSquads();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                settings.t(response['message'] ?? 'Ralat memadam kumpulan'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(settings.t('Ralat memadam kumpulan'))),
        );
      }
    }
  }

  Future<void> _showCreateSquadDialog() async {
    final TextEditingController nameController = TextEditingController();
    final theme = Theme.of(context);
    final auth = context.read<AuthProvider>();
    final isSuperAdmin = auth.role == 'super_admin';
    LocationOption? selectedState = _selectedState;
    LocationOption? selectedDistrict = _selectedDistrict;
    LocationOption? selectedZone = _selectedZone;
    var modalStates = List<LocationOption>.from(_states);
    var modalDistricts = List<LocationOption>.from(_districts);
    var modalZones = List<LocationOption>.from(_zones);
    var allPatrollers = <dynamic>[];
    var isLoading = false;
    var sheetOpen = true;
    String? selectedHeadId;
    final selectedMemberIds = <String>{};
    String? modalError;

    bool isActive(dynamic patroller) {
      final status = (patroller['account_status'] ?? patroller['status'] ?? '')
          .toString()
          .toLowerCase();
      return status == 'active' || status == 'approved';
    }

    bool isUnassigned(dynamic patroller) {
      final squadName = patroller['squad_name']?.toString().trim();
      return squadName == null || squadName.isEmpty;
    }

    bool matchesDistrict(dynamic patroller) {
      final districtId = isSuperAdmin
          ? selectedDistrict?.id
          : auth.districtId ?? selectedDistrict?.id;
      if (districtId == null) return false;
      return patroller['district_id']?.toString() == districtId;
    }

    bool matchesZone(dynamic patroller) {
      final zoneId = selectedZone?.id;
      if (zoneId == null) return false;
      return patroller['zone_id']?.toString() == zoneId;
    }

    List<dynamic> eligiblePatrollers(String role) {
      return allPatrollers.where((patroller) {
        return patroller['role']?.toString() == role &&
            isActive(patroller) &&
            isUnassigned(patroller) &&
            matchesDistrict(patroller) &&
            matchesZone(patroller);
      }).toList()..sort(
        (a, b) => (a['full_name'] ?? '').toString().compareTo(
          (b['full_name'] ?? '').toString(),
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          Center(child: CircularProgressIndicator(color: theme.primaryColor)),
    );
    try {
      if (isSuperAdmin && modalStates.isEmpty) {
        modalStates = await _authService.fetchLocations(level: 'states');
      }
      final response = await ApiClient.getData('auth/get_patrollers.php');
      allPatrollers = response['status'] == 'success'
          ? (response['data'] as List<dynamic>? ?? [])
          : <dynamic>[];
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${settings.t("Ralat memuat senarai:")} $e')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);

    Future<void> selectState(
      LocationOption? state,
      StateSetter setModalState,
    ) async {
      setModalState(() {
        selectedState = state;
        selectedDistrict = null;
        selectedZone = null;
        modalDistricts = const [];
        modalZones = const [];
        selectedHeadId = null;
        selectedMemberIds.clear();
        modalError = null;
        isLoading = state != null;
      });
      if (state == null) return;
      try {
        final districts = await _authService.fetchLocations(
          level: 'districts',
          parentId: state.id,
        );
        if (!mounted || !sheetOpen || selectedState?.id != state.id) return;
        setModalState(() {
          modalDistricts = districts;
          isLoading = false;
        });
      } catch (e) {
        if (!mounted || !sheetOpen) return;
        setModalState(() {
          modalError = '${settings.t("Tidak dapat memuatkan daerah.")} $e';
          isLoading = false;
        });
      }
    }

    Future<void> selectDistrict(
      LocationOption? district,
      StateSetter setModalState,
    ) async {
      setModalState(() {
        selectedDistrict = district;
        selectedZone = null;
        modalZones = const [];
        selectedHeadId = null;
        selectedMemberIds.clear();
        modalError = null;
        isLoading = district != null;
      });
      if (district == null) return;
      try {
        final zones = await _authService.fetchLocations(
          level: 'zones',
          parentId: district.id,
        );
        if (!mounted || !sheetOpen || selectedDistrict?.id != district.id) return;
        setModalState(() {
          modalZones = zones;
          isLoading = false;
        });
      } catch (e) {
        if (!mounted || !sheetOpen) return;
        setModalState(() {
          modalError = '${settings.t("Tidak dapat memuatkan zon.")} $e';
          isLoading = false;
        });
      }
    }

    void showValidationMessage(String message) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final headOptions = eligiblePatrollers('ketua_peronda');
            final memberOptions = eligiblePatrollers('peronda');
            final canPickMembers =
                (isSuperAdmin
                    ? selectedDistrict != null
                    : auth.districtId != null) &&
                selectedZone != null &&
                selectedHeadId != null;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.86,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.t('Cipta Kumpulan Baru'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        decoration: _squadDialogInputDecoration(
                          theme,
                          settings.t('Nama Kumpulan'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isSuperAdmin) ...[
                        _LocationDropdown(
                          label: settings.t('Negeri'),
                          value: selectedState,
                          items: modalStates,
                          allLabel: settings.t('Semua Negeri'),
                          onChanged: (value) =>
                              selectState(value, setModalState),
                        ),
                        const SizedBox(height: 12),
                        _LocationDropdown(
                          label: settings.t('Daerah'),
                          value: selectedDistrict,
                          items: modalDistricts,
                          allLabel: settings.t('Semua Daerah'),
                          enabled: selectedState != null,
                          onChanged: (value) =>
                              selectDistrict(value, setModalState),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<LocationOption?>(
                          initialValue: selectedZone,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          decoration: _squadDialogInputDecoration(
                            theme,
                            settings.t('Pilih Zon'),
                          ),
                          items: [
                            DropdownMenuItem<LocationOption?>(
                              value: null,
                              child: Text(settings.t('Pilih Zon')),
                            ),
                            ...modalZones.map(
                              (zone) => DropdownMenuItem<LocationOption?>(
                                value: zone,
                                child: Text(zone.name),
                              ),
                            ),
                          ],
                          onChanged: selectedDistrict == null || modalZones.isEmpty
                              ? null
                              : (value) {
                                  setModalState(() {
                                    selectedZone = value;
                                    selectedHeadId = null;
                                    selectedMemberIds.clear();
                                  });
                                },
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.dividerColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Text(
                            '${settings.t("Negeri")} • ${settings.t("Daerah")}: '
                            '${auth.stateName ?? "-"} • ${auth.districtName ?? "-"}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<LocationOption?>(
                          initialValue: selectedZone,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          decoration: _squadDialogInputDecoration(
                            theme,
                            settings.t('Pilih Zon'),
                          ),
                          items: [
                            DropdownMenuItem<LocationOption?>(
                              value: null,
                              child: Text(settings.t('Pilih Zon')),
                            ),
                            ...modalZones.map(
                              (zone) => DropdownMenuItem<LocationOption?>(
                                value: zone,
                                child: Text(zone.name),
                              ),
                            ),
                          ],
                          onChanged: modalZones.isEmpty
                              ? null
                              : (value) {
                                  setModalState(() {
                                    selectedZone = value;
                                    selectedHeadId = null;
                                    selectedMemberIds.clear();
                                  });
                                },
                        ),
                      ],
                      if (isLoading) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(color: theme.primaryColor),
                      ],
                      if (modalError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          modalError!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        settings.t('Ketua Peronda'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'squad-head-${selectedDistrict?.id}-${selectedZone?.id}-${headOptions.length}',
                        ),
                        initialValue: selectedHeadId,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        decoration: _squadDialogInputDecoration(
                          theme,
                          settings.t('Pilih Ketua Peronda'),
                        ),
                        items: headOptions
                            .map(
                              (patroller) => DropdownMenuItem<String>(
                                value: patroller['id']?.toString(),
                                child: Text(
                                  patroller['full_name']?.toString() ?? '-',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged:
                            (isSuperAdmin && selectedDistrict == null) ||
                                    selectedZone == null ||
                                    headOptions.isEmpty
                            ? null
                            : (value) {
                                setModalState(() {
                                  selectedHeadId = value;
                                  selectedMemberIds.remove(value);
                                });
                              },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${settings.t('Peronda')} (${selectedMemberIds.length}/20)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settings.t('Pilih 2 hingga 20 peronda.'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.68,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!canPickMembers || memberOptions.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.dividerColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            canPickMembers
                                ? settings.t('Tiada peronda dijumpai')
                                : (selectedZone == null
                                    ? settings.t('Sila pilih zon dan ketua peronda dahulu.')
                                    : settings.t('Pilih ketua peronda dahulu.')),
                            style: TextStyle(color: theme.disabledColor),
                          ),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 280),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: memberOptions.length,
                            itemBuilder: (context, index) {
                              final patroller = memberOptions[index];
                              final id = patroller['id']?.toString() ?? '';
                              final selected = selectedMemberIds.contains(id);
                              return CheckboxListTile(
                                value: selected,
                                onChanged: (checked) {
                                  if (checked == true &&
                                      selectedMemberIds.length >= 20) {
                                    showValidationMessage(
                                      settings.t(
                                        'Maksimum 20 peronda dibenarkan.',
                                      ),
                                    );
                                    return;
                                  }
                                  setModalState(() {
                                    if (checked == true) {
                                      selectedMemberIds.add(id);
                                    } else {
                                      selectedMemberIds.remove(id);
                                    }
                                  });
                                },
                                title: Text(
                                  patroller['full_name']?.toString() ?? '-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  _locationTrail(patroller, settings),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: isLoading
                              ? null
                              : () {
                                  final name = nameController.text.trim();
                                  final stateId = isSuperAdmin
                                      ? selectedState?.id
                                      : auth.stateId;
                                  final districtId = isSuperAdmin
                                      ? selectedDistrict?.id
                                      : auth.districtId;
                                  if (name.isEmpty) {
                                    showValidationMessage(
                                      settings.t('Nama Kumpulan diperlukan.'),
                                    );
                                    return;
                                  }
                                  if (stateId == null || districtId == null) {
                                    showValidationMessage(
                                      settings.t(
                                        'Pilih negeri dan daerah untuk kumpulan ini.',
                                      ),
                                    );
                                    return;
                                  }
                                  if (selectedZone == null) {
                                    showValidationMessage(
                                      settings.t('Pilih zon untuk kumpulan ini.'),
                                    );
                                    return;
                                  }
                                  if (selectedHeadId == null) {
                                    showValidationMessage(
                                      settings.t('Pilih Ketua Peronda'),
                                    );
                                    return;
                                  }
                                  if (selectedMemberIds.length < 2 ||
                                      selectedMemberIds.length > 20) {
                                    showValidationMessage(
                                      settings.t('Pilih 2 hingga 20 peronda.'),
                                    );
                                    return;
                                  }
                                  Navigator.pop(context);
                                  _createSquad(
                                    name: name,
                                    stateId: stateId,
                                    districtId: districtId,
                                    zoneId: selectedZone!.id,
                                    headUserId: selectedHeadId!,
                                    memberIds: selectedMemberIds.toList(),
                                  );
                                },
                          child: Text(
                            settings.t('Simpan Kumpulan'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      sheetOpen = false;
    });
  }

  InputDecoration _squadDialogInputDecoration(ThemeData theme, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primaryColor, width: 2),
      ),
    );
  }

  void _showAddMemberDialog(String squadId) async {
    final theme = Theme.of(context);
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          Center(child: CircularProgressIndicator(color: theme.primaryColor)),
    );

    try {
      final response = await ApiClient.getData('auth/get_patrollers.php');
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (response['status'] == 'success') {
        final List<dynamic> patrollers = response['data'] ?? [];

        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: theme.colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.t('Pilih Peronda'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: patrollers.isEmpty
                        ? Center(
                            child: Text(
                              settings.t('Tiada peronda dijumpai'),
                              style: TextStyle(color: theme.disabledColor),
                            ),
                          )
                        : ListView.builder(
                            itemCount: patrollers.length,
                            itemBuilder: (context, index) {
                              final p = patrollers[index];
                              final squadName = p['squad_name'];
                              final isAssigned =
                                  squadName != null &&
                                  squadName.toString().isNotEmpty;

                              return Card(
                                elevation: 0,
                                color: isAssigned
                                    ? theme.disabledColor.withValues(alpha: 0.1)
                                    : theme.cardColor,
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: theme.dividerColor),
                                ),
                                child: ListTile(
                                  leading: UserAvatar(
                                    imageUrl: p['profile_image_url'] as String?,
                                    initials: UserAvatar.initialsFromName(
                                      p['full_name'] as String?,
                                      fallback: 'P',
                                    ),
                                    radius: 20,
                                  ),
                                  title: Text(
                                    p['full_name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isAssigned
                                          ? theme.disabledColor
                                          : theme.textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  subtitle: Text(
                                    isAssigned
                                        ? '${settings.t("Telah ditugaskan ke:")} $squadName'
                                        : _locationTrail(p, settings),
                                    style: TextStyle(
                                      color: isAssigned
                                          ? Colors.redAccent.shade700
                                          : theme.textTheme.bodyMedium?.color
                                                ?.withValues(alpha: 0.6),
                                      fontWeight: isAssigned
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: isAssigned
                                      ? SizedBox(
                                          width: 90,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Icon(
                                                Icons.lock_outline,
                                                color: theme.disabledColor,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                settings.t('Terkunci'),
                                                style: TextStyle(
                                                  color: theme.disabledColor,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                theme.colorScheme.secondary,
                                            foregroundColor: Colors.black,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _addMember(
                                              squadId,
                                              p['id'].toString(),
                                            );
                                          },
                                          child: Text(settings.t('Pilih')),
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${settings.t("Ralat memuat senarai:")} $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final activeFilters = _activeSquadFilterLabels(settings);
    final isFilterActive = activeFilters.isNotEmpty;
    final filteredSquads = _filteredSquads;
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
    }

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      hintText: settings.t('Cari kumpulan atau ahli...'),
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
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: settings.t('Tapis Kumpulan'),
                      icon: Icon(
                        Icons.filter_list,
                        color: isFilterActive
                            ? Colors.white
                            : theme.primaryColor,
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
                      onPressed: () => _showSquadFilterSheet(settings),
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
          if (activeFilters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: activeFilters
                      .map(
                        (label) => Chip(
                          label: Text(label, overflow: TextOverflow.ellipsis),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton.icon(
              onPressed: _showCreateSquadDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(settings.t('Cipta Kumpulan Baru')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredSquads.isEmpty
                ? ListView(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    children: [
                      Icon(
                        Icons.group_off,
                        size: 64,
                        color: theme.disabledColor,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          settings.t('Tiada Kumpulan Direkodkan'),
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredSquads.length,
                    itemBuilder: (context, index) {
                      final squad = filteredSquads[index];
                      final members = squad['members'] as List<dynamic>? ?? [];

                      return Card(
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.05),
                        color: theme.cardColor,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: theme.brightness == Brightness.dark
                                ? Colors.white12
                                : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            iconColor: theme.primaryColor,
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.group,
                                    color: theme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        squad['name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color:
                                              theme.textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${members.length} ${settings.t("Ahli")}',
                                        style: TextStyle(
                                          color: theme
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                              ?.withValues(alpha: 0.6),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _locationTrail(squad, settings),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: theme
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withValues(alpha: 0.68),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(
                                          settings.t('Padam Kumpulan'),
                                        ),
                                        content: Text(
                                          '${settings.t("Adakah anda pasti untuk memadam kumpulan")} "${squad['name']}"? ${settings.t("Semua data ahli dan jadual berkaitan kumpulan ini akan dipadam.")}',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text(settings.t('Batal')),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.redAccent,
                                            ),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _deleteSquad(squad['id']);
                                            },
                                            child: Text(
                                              settings.t('Padam'),
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.scaffoldBackgroundColor,
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(16),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    if (members.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Text(
                                          settings.t('Belum ada ahli.'),
                                          style: TextStyle(
                                            color: theme.disabledColor,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      )
                                    else
                                      ...members.map(
                                        (m) => ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 24,
                                              ),
                                          leading: UserAvatar(
                                            imageUrl:
                                                m['profile_image_url']
                                                    as String?,
                                            initials:
                                                UserAvatar.initialsFromName(
                                                  m['full_name'] as String?,
                                                  fallback: 'P',
                                                ),
                                            radius: 16,
                                          ),
                                          title: Text(
                                            m['full_name'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: theme
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.color,
                                            ),
                                          ),
                                          subtitle: Text(
                                            [
                                                  m['ic_number']?.toString() ??
                                                      '',
                                                  _locationTrail(m, settings),
                                                ]
                                                .where(
                                                  (part) => part.isNotEmpty,
                                                )
                                                .join(' | '),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color
                                                  ?.withValues(alpha: 0.6),
                                            ),
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                              color: Colors.redAccent,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: Text(
                                                    settings.t(
                                                      'Keluarkan Ahli',
                                                    ),
                                                  ),
                                                  content: Text(
                                                    '${settings.t("Adakah anda pasti untuk mengeluarkan")} "${m['full_name']}" ${settings.t("daripada kumpulan?")}',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                          ),
                                                      child: Text(
                                                        settings.t('Batal'),
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                Colors
                                                                    .redAccent,
                                                          ),
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                        _removeMember(
                                                          squad['id'],
                                                          m['user_id']
                                                              .toString(),
                                                        );
                                                      },
                                                      child: Text(
                                                        settings.t('Keluarkan'),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _showAddMemberDialog(squad['id']),
                                        icon: const Icon(Icons.person_add),
                                        label: Text(settings.t('Tambah Ahli')),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: theme.primaryColor,
                                          side: BorderSide(
                                            color: theme.primaryColor,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          minimumSize: const Size(
                                            double.infinity,
                                            44,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleManagementTab extends StatefulWidget {
  const _ScheduleManagementTab();

  @override
  State<_ScheduleManagementTab> createState() => _ScheduleManagementTabState();
}

class _ScheduleManagementTabState extends State<_ScheduleManagementTab> {
  List<dynamic> _schedules = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  bool _showHistory = false;
  final AuthService _authService = AuthService();
  LocationOption? _selectedState;
  LocationOption? _selectedDistrict;
  LocationOption? _selectedZone;
  List<LocationOption> _states = const [];
  List<LocationOption> _districts = const [];
  List<LocationOption> _zones = const [];

  SettingsProvider get settings =>
      Provider.of<SettingsProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _initializeFilters();
  }

  Future<void> _initializeFilters() async {
    final auth = context.read<AuthProvider>();
    try {
      if (auth.role == 'super_admin') {
        final states = await _authService.fetchLocations(level: 'states');
        if (!mounted) return;
        setState(() => _states = states);
      } else if (auth.districtId != null) {
        final zones = await _authService.fetchLocations(
          level: 'zones',
          parentId: auth.districtId,
        );
        if (!mounted) return;
        setState(() => _zones = zones);
      }
    } catch (e) {
      debugPrint('Unable to load schedule assignment locations: $e');
    }
    await _fetchSchedules();
  }

  String _currentLocationQuery() {
    final auth = context.read<AuthProvider>();
    final query = <String, String>{};
    if (auth.role == 'super_admin') {
      if (_selectedState != null) query['state_id'] = _selectedState!.id;
      if (_selectedDistrict != null) {
        query['district_id'] = _selectedDistrict!.id;
      }
    } else {
      if (auth.stateId != null) query['state_id'] = auth.stateId!;
      if (auth.districtId != null) query['district_id'] = auth.districtId!;
    }
    if (_selectedZone != null) query['zone_id'] = _selectedZone!.id;
    final encoded = Uri(queryParameters: query).query;
    return encoded.isEmpty ? '' : '?$encoded';
  }

  Future<void> _fetchSchedules() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.getData(
        'admin/schedules.php${_currentLocationQuery()}',
      );
      if (response['success'] == true || response['status'] == 'success') {
        setState(() => _schedules = response['data'] ?? []);
      }
    } catch (e) {
      debugPrint("Error fetching schedules: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createSchedule(
    String squadId,
    String stateId,
    String districtId,
    String zoneId,
    String date,
    String startTime,
    String endTime,
  ) async {
    try {
      final response = await ApiClient.postData('admin/schedules.php', {
        'action': 'create_schedule',
        'squad_id': squadId,
        'state_id': stateId,
        'district_id': districtId,
        'zone_id': zoneId,
        'shift_date': date,
        'start_time': startTime,
        'end_time': endTime,
      });
      if (response['success'] == true || response['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(settings.t('shift_assigned_success'))),
          );
        }
        _fetchSchedules();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                settings.t(response['message'] ?? 'Ralat menetapkan jadual'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${settings.t("Ralat")}: $e')));
      }
    }
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    try {
      final response = await ApiClient.postData('admin/schedules.php', {
        'action': 'delete_schedule',
        'schedule_id': scheduleId,
      });
      if (response['success'] == true || response['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(settings.t('schedule_deleted_success'))),
          );
        }
        _fetchSchedules();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                settings.t(response['message'] ?? 'Ralat memadam jadual'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${settings.t("Ralat")}: $e')));
      }
    }
  }

  void _showCreateScheduleDialog() {
    final theme = Theme.of(context);
    final auth = context.read<AuthProvider>();
    final isSuperAdmin = auth.role == 'super_admin';
    LocationOption? selectedPatrolState = _selectedState;
    LocationOption? selectedPatrolDistrict = _selectedDistrict;
    LocationOption? selectedPatrolZone = _selectedZone;
    var modalDistricts = List<LocationOption>.from(_districts);
    var modalZones = List<LocationOption>.from(_zones);
    var availableSquads = <dynamic>[];
    String? selectedSquadId;
    var isLoadingLocations = false;
    var isLoadingSquads = false;
    String? modalError;
    var didPrime = false;
    var sheetOpen = true;

    if (!isSuperAdmin && selectedPatrolZone == null && _zones.isNotEmpty) {
      selectedPatrolZone = _zones.firstWhere(
        (zone) => zone.id == auth.zoneId,
        orElse: () => _zones.first,
      );
    }

    Future<void> loadSquads(StateSetter setModalState) async {
      final stateId = isSuperAdmin ? selectedPatrolState?.id : auth.stateId;
      final districtId = isSuperAdmin
          ? selectedPatrolDistrict?.id
          : auth.districtId;
      if (stateId == null || districtId == null) {
        setModalState(() {
          availableSquads = [];
          selectedSquadId = null;
        });
        return;
      }

      setModalState(() {
        isLoadingSquads = true;
        modalError = null;
        availableSquads = [];
        selectedSquadId = null;
      });
      try {
        final query = isSuperAdmin
            ? '?${Uri(queryParameters: {'state_id': stateId, 'district_id': districtId}).query}'
            : '';
        final response = await ApiClient.getData('admin/squads.php$query');
        if (!mounted || !sheetOpen) return;
        final squads =
            (response['success'] == true || response['status'] == 'success')
            ? (response['data'] as List<dynamic>? ?? [])
            : <dynamic>[];
        setModalState(() {
          availableSquads = squads;
          selectedSquadId = squads.isEmpty
              ? null
              : squads.first['id']?.toString();
        });
      } catch (e) {
        if (!mounted || !sheetOpen) return;
        setModalState(
          () => modalError = '${settings.t("Ralat memuatkan kumpulan:")} $e',
        );
      } finally {
        if (mounted && sheetOpen) {
          setModalState(() => isLoadingSquads = false);
        }
      }
    }

    Future<void> loadDistricts(
      LocationOption? state,
      StateSetter setModalState,
    ) async {
      setModalState(() {
        selectedPatrolState = state;
        selectedPatrolDistrict = null;
        selectedPatrolZone = null;
        modalDistricts = const [];
        modalZones = const [];
        availableSquads = [];
        selectedSquadId = null;
        modalError = null;
        isLoadingLocations = state != null;
      });
      _selectedState = state;
      _selectedDistrict = null;
      _selectedZone = null;
      _districts = const [];
      _zones = const [];
      if (state == null) return;
      try {
        final districts = await _authService.fetchLocations(
          level: 'districts',
          parentId: state.id,
        );
        if (!mounted || !sheetOpen || selectedPatrolState?.id != state.id) {
          return;
        }
        setModalState(() {
          modalDistricts = districts;
          isLoadingLocations = false;
        });
        _districts = districts;
      } catch (_) {
        if (!mounted || !sheetOpen) return;
        setModalState(() {
          modalError = settings.t('Tidak dapat memuatkan daerah.');
          isLoadingLocations = false;
        });
      }
    }

    Future<void> loadZones(
      LocationOption? district,
      StateSetter setModalState,
    ) async {
      setModalState(() {
        selectedPatrolDistrict = district;
        selectedPatrolZone = null;
        modalZones = const [];
        availableSquads = [];
        selectedSquadId = null;
        modalError = null;
        isLoadingLocations = district != null;
      });
      _selectedDistrict = district;
      _selectedZone = null;
      _zones = const [];
      if (district == null) return;
      try {
        final zones = await _authService.fetchLocations(
          level: 'zones',
          parentId: district.id,
        );
        if (!mounted ||
            !sheetOpen ||
            selectedPatrolDistrict?.id != district.id) {
          return;
        }
        setModalState(() {
          modalZones = zones;
          isLoadingLocations = false;
        });
        _zones = zones;
        await loadSquads(setModalState);
      } catch (_) {
        if (!mounted || !sheetOpen) return;
        setModalState(() {
          modalError = settings.t('Tidak dapat memuatkan zon.');
          isLoadingLocations = false;
        });
      }
    }

    void selectZone(LocationOption? zone, StateSetter setModalState) {
      setModalState(() => selectedPatrolZone = zone);
      _selectedZone = zone;
    }

    void primeSheet(StateSetter setModalState) {
      if (didPrime) return;
      didPrime = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !sheetOpen) return;
        loadSquads(setModalState);
      });
    }

    void showValidationMessage(String message) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    DateTime selectedDate =
        _dateOnly(_selectedDate).isBefore(_dateOnly(DateTime.now()))
        ? DateTime.now()
        : _selectedDate;
    TimeOfDay startTime = const TimeOfDay(hour: 22, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 2, minute: 0);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            primeSheet(setModalState);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.t('assign_shift'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _LocationFilterPanel(
                      isSuperAdmin: isSuperAdmin,
                      isLoading: isLoadingLocations,
                      error: modalError,
                      selectedState: selectedPatrolState,
                      selectedDistrict: selectedPatrolDistrict,
                      selectedZone: selectedPatrolZone,
                      states: _states,
                      districts: modalDistricts,
                      zones: modalZones,
                      fixedStateName: auth.stateName,
                      fixedDistrictName: auth.districtName,
                      onStateChanged: (value) =>
                          loadDistricts(value, setModalState),
                      onDistrictChanged: (value) =>
                          loadZones(value, setModalState),
                      onZoneChanged: (value) =>
                          selectZone(value, setModalState),
                    ),
                    const SizedBox(height: 16),

                    if (isLoadingSquads) ...[
                      LinearProgressIndicator(color: theme.primaryColor),
                      const SizedBox(height: 12),
                    ],

                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'assign-shift-squad-${selectedPatrolState?.id}-${selectedPatrolDistrict?.id}-${availableSquads.length}',
                      ),
                      initialValue: selectedSquadId,
                      isExpanded: true,
                      dropdownColor: theme.cardColor,
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                      decoration: _dialogInputDecoration(
                        theme,
                        settings.t('choose_squad'),
                      ),
                      selectedItemBuilder: (context) => availableSquads
                          .map(
                            (s) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                s['name']?.toString() ??
                                    settings.t('Kumpulan Tanpa Nama'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      items: availableSquads.map<DropdownMenuItem<String>>((s) {
                        final name =
                            s['name']?.toString() ??
                            settings.t('Kumpulan Tanpa Nama');
                        final location = _locationTrail(s, settings);
                        return DropdownMenuItem<String>(
                          value: s['id'].toString(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.62,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: availableSquads.isEmpty || isLoadingSquads
                          ? null
                          : (val) {
                              setModalState(() => selectedSquadId = val);
                            },
                    ),
                    const SizedBox(height: 16),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.calendar_today,
                        color: theme.primaryColor,
                      ),
                      title: Text(
                        settings.t('choose_date'),
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      subtitle: Text(
                        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      trailing: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.primaryColor,
                          side: BorderSide(color: theme.primaryColor),
                        ),
                        onPressed: () async {
                          final today = _dateOnly(DateTime.now());
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dateOnly(selectedDate).isBefore(today)
                                ? today
                                : selectedDate,
                            firstDate: today,
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        child: Text(settings.t('Pilih')),
                      ),
                    ),
                    const Divider(),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.access_time,
                        color: theme.primaryColor,
                      ),
                      title: Text(
                        settings.t('choose_start_time'),
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      subtitle: Text(
                        startTime.format(context),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      trailing: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.primaryColor,
                          side: BorderSide(color: theme.primaryColor),
                        ),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: startTime,
                          );
                          if (picked != null) {
                            setModalState(() => startTime = picked);
                          }
                        },
                        child: Text(settings.t('Pilih')),
                      ),
                    ),
                    const Divider(),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.access_time,
                        color: Colors.redAccent,
                      ),
                      title: Text(
                        settings.t('choose_end_time'),
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      subtitle: Text(
                        endTime.format(context),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      trailing: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.primaryColor,
                          side: BorderSide(color: theme.primaryColor),
                        ),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: endTime,
                          );
                          if (picked != null) {
                            setModalState(() => endTime = picked);
                          }
                        },
                        child: Text(settings.t('Pilih')),
                      ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isLoadingSquads
                            ? null
                            : () {
                                final selectedPatrolStateId = isSuperAdmin
                                    ? selectedPatrolState?.id
                                    : auth.stateId;
                                final selectedPatrolDistrictId = isSuperAdmin
                                    ? selectedPatrolDistrict?.id
                                    : auth.districtId;
                                if (selectedPatrolStateId == null ||
                                    selectedPatrolDistrictId == null ||
                                    selectedPatrolZone == null) {
                                  showValidationMessage(
                                    isSuperAdmin
                                        ? settings.t(
                                            'Pilih negeri, daerah dan zon rondaan dahulu.',
                                          )
                                        : settings.t(
                                            'Pilih zon rondaan dahulu.',
                                          ),
                                  );
                                  return;
                                }
                                if (selectedSquadId == null) {
                                  showValidationMessage(
                                    settings.t(
                                      'Sila cipta kumpulan terlebih dahulu!',
                                    ),
                                  );
                                  return;
                                }

                                final dateStr =
                                    "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
                                final startStr =
                                    "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00";
                                final endStr =
                                    "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00";

                                if (_hasLocalScheduleOverlap(
                                  selectedSquadId!,
                                  dateStr,
                                  startStr,
                                  endStr,
                                )) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        settings.t('schedule_overlap_error'),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                Navigator.pop(context);
                                _createSchedule(
                                  selectedSquadId!,
                                  selectedPatrolStateId,
                                  selectedPatrolDistrictId,
                                  selectedPatrolZone!.id,
                                  dateStr,
                                  startStr,
                                  endStr,
                                );
                              },
                        child: Text(
                          settings.t('assign_shift'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => sheetOpen = false);
  }

  InputDecoration _dialogInputDecoration(ThemeData theme, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
      ),
      filled: true,
      fillColor: theme.dividerColor.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primaryColor, width: 2),
      ),
    );
  }

  bool _hasLocalScheduleOverlap(
    String squadId,
    String shiftDate,
    String startTime,
    String endTime,
  ) {
    final candidate = _scheduleWindow(shiftDate, startTime, endTime);
    if (candidate == null) return false;

    for (final schedule in _schedules) {
      if (schedule['squad_id']?.toString() != squadId) continue;
      final existing = _scheduleWindow(
        schedule['shift_date']?.toString() ?? '',
        schedule['start_time']?.toString() ?? '',
        schedule['end_time']?.toString() ?? '',
      );
      if (existing == null) continue;
      final overlaps =
          candidate.start.isBefore(existing.end) &&
          candidate.end.isAfter(existing.start);
      if (overlaps) return true;
    }
    return false;
  }

  _ScheduleWindow? _scheduleWindow(
    String shiftDate,
    String startTime,
    String endTime,
  ) {
    final date = DateTime.tryParse(shiftDate);
    if (date == null) return null;
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    if (startParts.length < 2 || endParts.length < 2) return null;

    final start = DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(startParts[0]) ?? 0,
      int.tryParse(startParts[1]) ?? 0,
    );
    var end = DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(endParts[0]) ?? 0,
      int.tryParse(endParts[1]) ?? 0,
    );
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }
    return _ScheduleWindow(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
    }

    final selectedDateSchedules = _schedules.where((schedule) {
      return schedule['shift_date']?.toString() == _dateKey(_selectedDate);
    }).toList();
    final visibleSchedules = _showHistory
        ? _historySchedules()
        : _upcomingSchedules();

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: RefreshIndicator(
        onRefresh: _fetchSchedules,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            FilledButton.icon(
              onPressed: _showCreateScheduleDialog,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(settings.t('assign_shift')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ScheduleCalendar(
              selectedDate: _selectedDate,
              scheduleDates: _scheduleDateKeys(),
              onDateChanged: (date) => setState(() => _selectedDate = date),
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title:
                  '${settings.t('selected_date')} - ${_dateKey(_selectedDate)}',
            ),
            const SizedBox(height: 8),
            if (selectedDateSchedules.isEmpty)
              _ScheduleEmptyState(
                message: settings.t('Tiada Jadual Rondaan Direkodkan'),
              )
            else
              ...selectedDateSchedules.map(
                (schedule) => _ScheduleCard(
                  schedule: schedule,
                  onDelete: () => _confirmDeleteSchedule(schedule),
                ),
              ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.upcoming_outlined),
                  label: Text(settings.t('upcoming_schedules')),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.history_outlined),
                  label: Text(settings.t('schedule_history')),
                ),
              ],
              selected: {_showHistory},
              onSelectionChanged: (selection) {
                setState(() => _showHistory = selection.first);
              },
            ),
            const SizedBox(height: 12),
            if (visibleSchedules.isEmpty)
              _ScheduleEmptyState(
                message: settings.t('Tiada Jadual Rondaan Direkodkan'),
              )
            else
              ...visibleSchedules.map(
                (schedule) => _ScheduleCard(
                  schedule: schedule,
                  onDelete: () => _confirmDeleteSchedule(schedule),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSchedule(Map<String, dynamic> schedule) async {
    final squadName =
        schedule['squad_name'] ?? settings.t('Kumpulan Tanpa Nama');
    final shiftDate = schedule['shift_date'] ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t('Padam Jadual')),
        content: Text(
          '${settings.t("Adakah anda pasti untuk memadam jadual rondaan bagi kumpulan")} "$squadName" ${settings.t("pada tarikh")} $shiftDate?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(settings.t('Batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(settings.t('Padam')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteSchedule(schedule['id'].toString());
    }
  }

  List<dynamic> _upcomingSchedules() {
    final today = _dateOnly(DateTime.now());
    final items = _schedules.where((schedule) {
      final date = DateTime.tryParse(schedule['shift_date']?.toString() ?? '');
      return date != null && !_dateOnly(date).isBefore(today);
    }).toList();
    items.sort((a, b) => _scheduleDateTime(a).compareTo(_scheduleDateTime(b)));
    return items;
  }

  List<dynamic> _historySchedules() {
    final today = _dateOnly(DateTime.now());
    final items = _schedules.where((schedule) {
      final date = DateTime.tryParse(schedule['shift_date']?.toString() ?? '');
      return date != null && _dateOnly(date).isBefore(today);
    }).toList();
    items.sort((a, b) => _scheduleDateTime(b).compareTo(_scheduleDateTime(a)));
    return items;
  }

  Set<String> _scheduleDateKeys() {
    return _schedules
        .map((schedule) => schedule['shift_date']?.toString() ?? '')
        .where((date) => date.isNotEmpty)
        .toSet();
  }

  DateTime _scheduleDateTime(dynamic schedule) {
    final date = DateTime.tryParse(schedule['shift_date']?.toString() ?? '');
    final time = schedule['start_time']?.toString() ?? '00:00:00';
    if (date == null) return DateTime.fromMillisecondsSinceEpoch(0);
    final parts = time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _LocationFilterPanel extends StatelessWidget {
  const _LocationFilterPanel({
    required this.isSuperAdmin,
    required this.isLoading,
    required this.error,
    required this.selectedState,
    required this.selectedDistrict,
    required this.selectedZone,
    required this.states,
    required this.districts,
    required this.zones,
    required this.fixedStateName,
    required this.fixedDistrictName,
    required this.onStateChanged,
    required this.onDistrictChanged,
    required this.onZoneChanged,
  });

  final bool isSuperAdmin;
  final bool isLoading;
  final String? error;
  final LocationOption? selectedState;
  final LocationOption? selectedDistrict;
  final LocationOption? selectedZone;
  final List<LocationOption> states;
  final List<LocationOption> districts;
  final List<LocationOption> zones;
  final String? fixedStateName;
  final String? fixedDistrictName;
  final ValueChanged<LocationOption?> onStateChanged;
  final ValueChanged<LocationOption?> onDistrictChanged;
  final ValueChanged<LocationOption?> onZoneChanged;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading) ...[
            LinearProgressIndicator(color: theme.primaryColor),
            const SizedBox(height: 10),
          ],
          if (error != null) ...[
            Text(
              error!,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (!isSuperAdmin) ...[
            Text(
              '${settings.t("Negeri")}: ${fixedStateName ?? "-"}  |  ${settings.t("Daerah")}: ${fixedDistrictName ?? "-"}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _LocationDropdown(
              label: settings.t('Zon'),
              value: selectedZone,
              items: zones,
              allLabel: settings.t('Semua Zon'),
              onChanged: onZoneChanged,
            ),
          ] else
            LayoutBuilder(
              builder: (context, constraints) {
                final children = [
                  _LocationDropdown(
                    label: settings.t('Negeri'),
                    value: selectedState,
                    items: states,
                    allLabel: settings.t('Semua Negeri'),
                    onChanged: onStateChanged,
                  ),
                  _LocationDropdown(
                    label: settings.t('Daerah'),
                    value: selectedDistrict,
                    items: districts,
                    allLabel: settings.t('Semua Daerah'),
                    enabled: selectedState != null,
                    onChanged: onDistrictChanged,
                  ),
                  _LocationDropdown(
                    label: settings.t('Zon'),
                    value: selectedZone,
                    items: zones,
                    allLabel: settings.t('Semua Zon'),
                    enabled: selectedDistrict != null,
                    onChanged: onZoneChanged,
                  ),
                ];

                if (constraints.maxWidth < 680) {
                  return Column(
                    children: [
                      for (final child in children) ...[
                        child,
                        if (child != children.last) const SizedBox(height: 10),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      Expanded(child: children[i]),
                      if (i != children.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
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
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

String _locationTrail(dynamic item, SettingsProvider settings) {
  if (item is! Map) return '-';
  final state = _firstText(item, const [
    'member_state_name',
    'state_name',
    'state',
  ]);
  final district = _firstText(item, const [
    'member_district_name',
    'district_name',
    'district',
  ]);
  final zone = _firstText(item, const [
    'member_zone_name',
    'zone_name',
    'zone',
    'district_zone',
  ]);
  final parts = [
    state,
    district,
    zone,
  ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();
  if (parts.isEmpty) return settings.t('Lokasi tidak direkodkan');
  return parts.join(' • ');
}

String? _firstText(Map item, List<String> keys) {
  for (final key in keys) {
    final value = item[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

class _ScheduleWindow {
  const _ScheduleWindow(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

class _ScheduleCalendar extends StatefulWidget {
  const _ScheduleCalendar({
    required this.selectedDate,
    required this.scheduleDates,
    required this.onDateChanged,
  });

  final DateTime selectedDate;
  final Set<String> scheduleDates;
  final ValueChanged<DateTime> onDateChanged;

  @override
  State<_ScheduleCalendar> createState() => _ScheduleCalendarState();
}

class _ScheduleCalendarState extends State<_ScheduleCalendar> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
    );
  }

  @override
  void didUpdateWidget(covariant _ScheduleCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.selectedDate.month != widget.selectedDate.month) {
      _visibleMonth = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final monthLabel =
        '${_monthName(_visibleMonth.month, settings)} ${_visibleMonth.year}';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: settings.t('previous_months'),
                onPressed: () => setState(() {
                  _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month - 1,
                  );
                }),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: settings.t('this_month'),
                onPressed: () => setState(() {
                  _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month + 1,
                  );
                }),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          ..._calendarRows().map(
            (week) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: week
                    .map(
                      (date) => Expanded(
                        child: _CalendarDayCell(
                          date: date,
                          selectedDate: widget.selectedDate,
                          hasSchedule:
                              date != null &&
                              widget.scheduleDates.contains(_dateKey(date)),
                          onTap: date == null
                              ? null
                              : () => widget.onDateChanged(date),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              final today = DateTime.now();
              widget.onDateChanged(today);
              setState(() => _visibleMonth = DateTime(today.year, today.month));
            },
            icon: const Icon(Icons.today_outlined),
            label: Text(settings.t('today')),
          ),
        ],
      ),
    );
  }

  List<List<DateTime?>> _calendarRows() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingBlanks = firstDay.weekday - 1;
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(leadingBlanks, null),
      ...List.generate(
        daysInMonth,
        (index) => DateTime(_visibleMonth.year, _visibleMonth.month, index + 1),
      ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _monthName(int month, SettingsProvider settings) {
    const english = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const malay = [
      'Januari',
      'Februari',
      'Mac',
      'April',
      'Mei',
      'Jun',
      'Julai',
      'Ogos',
      'September',
      'Oktober',
      'November',
      'Disember',
    ];
    return settings.isEnglish ? english[month - 1] : malay[month - 1];
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.selectedDate,
    required this.hasSchedule,
    required this.onTap,
  });

  final DateTime? date;
  final DateTime selectedDate;
  final bool hasSchedule;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = DateTime.now();
    final isSelected =
        date != null &&
        date!.year == selectedDate.year &&
        date!.month == selectedDate.month &&
        date!.day == selectedDate.day;
    final isToday =
        date != null &&
        date!.year == today.year &&
        date!.month == today.month &&
        date!.day == today.day;

    if (date == null) {
      return const SizedBox(height: 44);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isToday && !isSelected
                    ? Border.all(color: colorScheme.primary, width: 1.2)
                    : null,
              ),
              child: Text(
                date!.day.toString(),
                style: textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: hasSchedule ? 6 : 0,
              height: hasSchedule ? 6 : 0,
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.secondary : colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule, required this.onDelete});

  final dynamic schedule;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final shiftDate = schedule['shift_date']?.toString() ?? '';
    final startTime = _shortTime(schedule['start_time']?.toString() ?? '');
    final endTime = _shortTime(schedule['end_time']?.toString() ?? '');
    final date = DateTime.tryParse(shiftDate);
    final today = DateTime.now();
    final isPast =
        date != null &&
        DateTime(
          date.year,
          date.month,
          date.day,
        ).isBefore(DateTime(today.year, today.month, today.day));
    final isToday =
        date != null &&
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final status = isPast
        ? settings.t('completed')
        : isToday
        ? settings.t('current_schedules')
        : settings.t('upcoming');

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.event_note,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    schedule['squad_name']?.toString() ??
                        settings.t('Kumpulan Tanpa Nama'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _Meta(
                  icon: Icons.place_outlined,
                  text: _locationTrail(schedule, settings),
                ),
                _Meta(icon: Icons.calendar_today_outlined, text: shiftDate),
                _Meta(
                  icon: Icons.schedule_outlined,
                  text: '$startTime - $endTime',
                ),
                _Meta(
                  icon: Icons.groups_outlined,
                  text:
                      '${schedule['member_count'] ?? 0} ${settings.t('ahli')}',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Chip(
                label: Text(status),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortTime(String value) =>
      value.length > 5 ? value.substring(0, 5) : value;
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 96,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleEmptyState extends StatelessWidget {
  const _ScheduleEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 42,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
