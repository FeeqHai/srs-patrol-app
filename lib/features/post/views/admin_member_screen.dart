import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/command_center_widgets.dart';
import '../../auth/models/location_option.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';

const String _all = 'all';
const String _locationSeparator = ' • ';

class AdminMemberScreen extends StatefulWidget {
  const AdminMemberScreen({super.key});

  @override
  State<AdminMemberScreen> createState() => _AdminMemberScreenState();
}

class _AdminMemberScreenState extends State<AdminMemberScreen> {
  final AuthService _authService = AuthService();
  final _searchController = TextEditingController();

  List<UserModel> _members = [];
  List<LocationOption> _states = const [];
  List<LocationOption> _districts = const [];
  List<LocationOption> _zones = const [];
  LocationOption? _state;
  LocationOption? _district;
  LocationOption? _zone;
  String _status = _all;
  String _role = _all;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    await Future.wait([_fetchMembers(), _loadLocationFilters()]);
  }

  Future<void> _loadLocationFilters() async {
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Tidak dapat memuatkan lokasi.');
    }
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoading = true);
    try {
      final data =
          await ApiClient.getData('auth/get_patrollers.php')
              as Map<String, dynamic>;
      if (data['status'] != 'success') {
        throw Exception(data['message'] ?? 'Gagal memuatkan ahli.');
      }
      final members = (data['data'] as List<dynamic>? ?? [])
          .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _members = members;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Ralat Rangkaian: $e';
      });
    }
  }

  List<UserModel> get _filteredMembers {
    final search = _searchController.text.trim().toLowerCase();
    final filtered = _members.where((member) {
      final text = [
        member.fullName,
        member.email ?? '',
        member.icNumber ?? '',
        member.phoneNumber ?? '',
      ].join(' ').toLowerCase();
      final matchesSearch = search.isEmpty || text.contains(search);
      final matchesState = _state == null || member.stateId == _state!.id;
      final matchesDistrict =
          _district == null || member.districtId == _district!.id;
      final matchesZone = _zone == null || member.zoneId == _zone!.id;
      final matchesStatus =
          _status == _all || member.accountStatusEnum.wireValue == _status;
      final matchesRole = _role == _all || member.role == _role;
      return matchesSearch &&
          matchesState &&
          matchesDistrict &&
          matchesZone &&
          matchesStatus &&
          matchesRole;
    }).toList();
    filtered.sort((a, b) {
      final priorityCompare = _memberPriority(a).compareTo(_memberPriority(b));
      if (priorityCompare != 0) return priorityCompare;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });
    return filtered;
  }

  int _memberPriority(UserModel member) {
    if (member.accountStatusEnum == AccountStatus.pending) return 0;
    if (member.mustChangePassword) return 1;
    return 2;
  }

  Future<void> _postAction(Map<String, String> body) async {
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await ApiClient.postData('admin/update_user.php', body);
      final ok = data['status'] == 'success';
      messenger.showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? settings.t('Kemas kini selesai')),
          backgroundColor: ok ? Colors.green : Colors.redAccent,
        ),
      );
      if (ok) {
        if (data['temporary_password'] != null && mounted) {
          await _showTempPassword(data['temporary_password'].toString());
        }
        await _fetchMembers();
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${settings.t('Ralat Rangkaian')}: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _showTempPassword(String password) async {
    final settings = context.read<SettingsProvider>();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t('Kata Laluan Sementara')),
        content: SelectableText(
          password,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(settings.t('Tutup')),
          ),
        ],
      ),
    );
  }

  void _showStatusSheet(UserModel member) {
    final settings = context.read<SettingsProvider>();
    AccountStatus selected = member.accountStatusEnum;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${settings.t('Tukar Status')}: ${member.fullName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SegmentedButton<AccountStatus>(
                selected: {selected},
                segments: [
                  ButtonSegment(
                    value: AccountStatus.pending,
                    label: Text(settings.t('Menunggu')),
                  ),
                  ButtonSegment(
                    value: AccountStatus.active,
                    label: Text(settings.t('Aktif')),
                  ),
                  ButtonSegment(
                    value: AccountStatus.inactive,
                    label: Text(settings.t('Nyahaktif')),
                  ),
                ],
                onSelectionChanged: (value) =>
                    setSheetState(() => selected = value.first),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _postAction({
                    'action': 'update_status',
                    'user_id': member.id,
                    'account_status': selected.wireValue,
                  });
                },
                child: Text(settings.t('Simpan')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoleSheet(UserModel member) {
    final settings = context.read<SettingsProvider>();
    final isSuperAdmin = context.read<AuthProvider>().role == 'super_admin';
    final roles = [
      'peronda',
      'ketua_peronda',
      if (isSuperAdmin) ...['ketua_krt', 'super_admin'],
    ];
    String selected = roles.contains(member.role) ? member.role : 'peronda';
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${settings.t('Tukar Peranan')}: ${member.fullName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                items: roles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(
                          _roleLabel(role, settings),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setSheetState(() => selected = value);
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _postAction({
                    'action': 'promote_role',
                    'user_id': member.id,
                    'role': selected,
                  });
                },
                child: Text(settings.t('Simpan')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(UserModel member) async {
    final settings = context.read<SettingsProvider>();
    final name = TextEditingController(text: member.fullName);
    final ic = TextEditingController(text: member.icNumber ?? '');
    final phone = TextEditingController(text: member.phoneNumber ?? '');
    final email = TextEditingController(text: member.email ?? '');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t('Edit Profil Ahli')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: settings.t('Nama Penuh'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ic,
                decoration: InputDecoration(
                  labelText: settings.t('No. Kad Pengenalan'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                decoration: InputDecoration(
                  labelText: settings.t('No. Telefon'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(settings.t('Batal')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _postAction({
                'action': 'update_profile',
                'user_id': member.id,
                'full_name': name.text.trim(),
                'ic_number': ic.text.trim(),
                'phone_number': phone.text.trim(),
                'email': email.text.trim(),
              });
            },
            child: Text(settings.t('Simpan')),
          ),
        ],
      ),
    );
    name.dispose();
    ic.dispose();
    phone.dispose();
    email.dispose();
  }

  Future<void> _showTransferDialog(UserModel member) async {
    final settings = context.read<SettingsProvider>();
    LocationOption? state;
    LocationOption? district;
    LocationOption? zone;
    List<LocationOption> districts = const [];
    List<LocationOption> zones = const [];

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(settings.t('Pindah Lokasi Ahli')),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _locationDropdown(
                  label: settings.t('Negeri'),
                  value: state,
                  items: _states,
                  onChanged: (value) async {
                    setDialogState(() {
                      state = value;
                      district = null;
                      zone = null;
                      districts = const [];
                      zones = const [];
                    });
                    if (value == null) return;
                    final loaded = await _authService.fetchLocations(
                      level: 'districts',
                      parentId: value.id,
                    );
                    if (context.mounted) {
                      setDialogState(() => districts = loaded);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _locationDropdown(
                  label: settings.t('Daerah'),
                  value: district,
                  items: districts,
                  onChanged: state == null
                      ? null
                      : (value) async {
                          setDialogState(() {
                            district = value;
                            zone = null;
                            zones = const [];
                          });
                          if (value == null) return;
                          final loaded = await _authService.fetchLocations(
                            level: 'zones',
                            parentId: value.id,
                          );
                          if (context.mounted) {
                            setDialogState(() => zones = loaded);
                          }
                        },
                ),
                const SizedBox(height: 12),
                _locationDropdown(
                  label: settings.t('Zon'),
                  value: zone,
                  items: zones,
                  onChanged: district == null
                      ? null
                      : (value) => setDialogState(() => zone = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(settings.t('Batal')),
            ),
            FilledButton(
              onPressed: state == null || district == null || zone == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      _postAction({
                        'action': 'transfer_location',
                        'user_id': member.id,
                        'state_id': state!.id,
                        'district_id': district!.id,
                        'zone_id': zone!.id,
                      });
                    },
              child: Text(settings.t('Pindah')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetPassword(UserModel member) async {
    final settings = context.read<SettingsProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t('Reset Kata Laluan')),
        content: Text(
          '${settings.t('Jana kata laluan sementara untuk')} ${member.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(settings.t('Batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(settings.t('Reset')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _postAction({'action': 'reset_password', 'user_id': member.id});
    }
  }

  Widget _locationDropdown({
    required String label,
    required LocationOption? value,
    required List<LocationOption> items,
    required ValueChanged<LocationOption?>? onChanged,
  }) {
    return DropdownButtonFormField<LocationOption>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  String _roleLabel(String role, SettingsProvider settings) {
    switch (role) {
      case 'super_admin':
        return settings.t('Super Admin');
      case 'ketua_krt':
        return settings.t('Ketua KRT');
      case 'ketua_peronda':
        return settings.t('Ketua Peronda');
      default:
        return settings.t('Peronda');
    }
  }

  String _statusLabel(String status, SettingsProvider settings) {
    switch (status) {
      case 'pending':
        return settings.t('Menunggu');
      case 'active':
        return settings.t('Aktif');
      case 'inactive':
        return settings.t('Nyahaktif');
      default:
        return settings.t('Semua');
    }
  }

  String _memberLocation(UserModel member) {
    final parts = [
      member.stateName,
      member.districtName,
      member.zoneName ?? member.districtZone,
    ].where((part) => part != null && part.trim().isNotEmpty).cast<String>();
    final location = parts.join(_locationSeparator);
    return location.isEmpty ? '-' : location;
  }

  List<String> _activeFilterLabels(SettingsProvider settings) {
    return [
      if (_status != _all) _statusLabel(_status, settings),
      if (_role != _all) _roleLabel(_role, settings),
      if (_state != null) _state!.name,
      if (_district != null) _district!.name,
      if (_zone != null) _zone!.name,
    ];
  }

  String get _quickFilterKey {
    if (_status == _all && _role == _all) return _all;
    if (_status == 'pending' && _role == _all) return 'pending';
    if (_status == 'active' && _role == _all) return 'active';
    if (_status == _all && _role == 'peronda') return 'peronda';
    if (_status == _all && _role == 'ketua_peronda') return 'ketua_peronda';
    return 'custom';
  }

  void _applyQuickFilter(String key) {
    setState(() {
      switch (key) {
        case 'pending':
          _status = 'pending';
          _role = _all;
          break;
        case 'active':
          _status = 'active';
          _role = _all;
          break;
        case 'peronda':
          _status = _all;
          _role = 'peronda';
          break;
        case 'ketua_peronda':
          _status = _all;
          _role = 'ketua_peronda';
          break;
        default:
          _status = _all;
          _role = _all;
      }
    });
  }

  void _showMemberFilterSheet(SettingsProvider settings) {
    final isSuperAdmin = context.read<AuthProvider>().role == 'super_admin';
    var selectedStatus = _status;
    var selectedRole = _role;
    var selectedState = _state;
    var selectedDistrict = _district;
    var selectedZone = _zone;
    var sheetDistricts = List<LocationOption>.from(_districts);
    var sheetZones = List<LocationOption>.from(_zones);
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
      });
      if (state == null) return;
      final districts = await _authService.fetchLocations(
        level: 'districts',
        parentId: state.id,
      );
      if (!mounted || !sheetOpen || selectedState?.id != state.id) return;
      setSheetState(() => sheetDistricts = districts);
    }

    Future<void> loadZones(
      LocationOption? district,
      StateSetter setSheetState,
    ) async {
      setSheetState(() {
        selectedDistrict = district;
        selectedZone = null;
        sheetZones = const [];
      });
      if (district == null) return;
      final zones = await _authService.fetchLocations(
        level: 'zones',
        parentId: district.id,
      );
      if (!mounted || !sheetOpen || selectedDistrict?.id != district.id) {
        return;
      }
      setSheetState(() => sheetZones = zones);
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
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
                          settings.t('Tapis Pengurusan Ahli'),
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
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: settings.t('Status'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: _all,
                        child: Text(settings.t('Semua')),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text(settings.t('Menunggu')),
                      ),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text(settings.t('Aktif')),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text(settings.t('Nyahaktif')),
                      ),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => selectedStatus = value ?? _all),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: settings.t('Peranan'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: _all,
                        child: Text(settings.t('Semua')),
                      ),
                      DropdownMenuItem(
                        value: 'peronda',
                        child: Text(settings.t('Peronda')),
                      ),
                      DropdownMenuItem(
                        value: 'ketua_peronda',
                        child: Text(settings.t('Ketua Peronda')),
                      ),
                      if (isSuperAdmin)
                        DropdownMenuItem(
                          value: 'ketua_krt',
                          child: Text(settings.t('Ketua KRT')),
                        ),
                      if (isSuperAdmin)
                        DropdownMenuItem(
                          value: 'super_admin',
                          child: Text(settings.t('Super Admin')),
                        ),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => selectedRole = value ?? _all),
                  ),
                  if (isSuperAdmin) ...[
                    const SizedBox(height: 12),
                    _nullableLocationDropdown(
                      label: settings.t('Negeri'),
                      value: selectedState,
                      items: _states,
                      allLabel: settings.t('Semua Negeri'),
                      onChanged: (value) => loadDistricts(value, setSheetState),
                    ),
                    const SizedBox(height: 12),
                    _nullableLocationDropdown(
                      label: settings.t('Daerah'),
                      value: selectedDistrict,
                      items: sheetDistricts,
                      allLabel: settings.t('Semua Daerah'),
                      enabled: selectedState != null,
                      onChanged: (value) => loadZones(value, setSheetState),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _nullableLocationDropdown(
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
                              selectedStatus = _all;
                              selectedRole = _all;
                              selectedState = null;
                              selectedDistrict = null;
                              selectedZone = null;
                              sheetDistricts = const [];
                              sheetZones = isSuperAdmin
                                  ? const []
                                  : List<LocationOption>.from(_zones);
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
                              _status = selectedStatus;
                              _role = selectedRole;
                              _state = selectedState;
                              _district = selectedDistrict;
                              _zone = selectedZone;
                              _districts = sheetDistricts;
                              _zones = sheetZones;
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

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildQuickFilterChips(SettingsProvider settings, ThemeData theme) {
    final selected = _quickFilterKey;
    final chips = [
      (_all, settings.t('Semua'), Icons.people_alt_outlined),
      ('pending', settings.t('Menunggu'), Icons.pending_actions_outlined),
      ('active', settings.t('Aktif'), Icons.verified_outlined),
      ('peronda', settings.t('Peronda'), Icons.directions_walk_outlined),
      (
        'ketua_peronda',
        settings.t('Ketua Peronda'),
        Icons.supervisor_account_outlined,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((chip) {
            final isSelected = selected == chip.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: isSelected,
                showCheckmark: false,
                avatar: Icon(
                  chip.$3,
                  size: 17,
                  color: isSelected ? Colors.white : theme.primaryColor,
                ),
                label: Text(
                  chip.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : theme.primaryColor,
                  fontWeight: FontWeight.w800,
                ),
                selectedColor: theme.primaryColor,
                backgroundColor: theme.cardColor,
                side: BorderSide(
                  color: isSelected
                      ? theme.primaryColor
                      : theme.dividerColor.withValues(alpha: 0.22),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                onSelected: (_) => _applyQuickFilter(chip.$1),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterBar(SettingsProvider settings, ThemeData theme) {
    final activeFilters = _activeFilterLabels(settings);
    final isFilterActive = activeFilters.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: settings.t(
                      'Cari nama, IC, telefon atau e-mel...',
                    ),
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
                    tooltip: settings.t('Tapis Pengurusan Ahli'),
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
                    onPressed: () => _showMemberFilterSheet(settings),
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
        ],
      ),
    );
  }

  Widget _nullableLocationDropdown({
    required String label,
    required LocationOption? value,
    required List<LocationOption> items,
    required String allLabel,
    required ValueChanged<LocationOption?> onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<LocationOption?>(
      key: ValueKey('$label-${value?.id ?? 'all'}-${items.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
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

  Widget _buildMemberCard(
    UserModel member,
    SettingsProvider settings, {
    bool isPendingSection = false,
  }) {
    final theme = Theme.of(context);
    final isSuperAdmin = context.read<AuthProvider>().role == 'super_admin';
    final status = member.accountStatusEnum;
    final statusColor = status == AccountStatus.active
        ? Colors.green.shade700
        : status == AccountStatus.pending
        ? Colors.orange.shade800
        : Colors.redAccent;

    return Card(
      elevation: isPendingSection ? 3 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPendingSection
              ? Colors.orange.withValues(alpha: 0.35)
              : theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isPendingSection ? 16 : 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPendingSection) ...[
              Row(
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    size: 18,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      settings.t('Pendaftaran baharu memerlukan semakan'),
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                UserAvatar(
                  imageUrl: member.effectiveProfileImageUrl,
                  initials: UserAvatar.initialsFromName(
                    member.fullName,
                    fallback: '?',
                  ),
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _chip(
                            _roleLabel(member.role, settings),
                            theme.primaryColor,
                          ),
                          _chip(settings.t(status.wireValue), statusColor),
                          if (member.mustChangePassword)
                            _chip(
                              settings.t('Perlu Tukar Kata Laluan'),
                              Colors.deepPurple,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (status == AccountStatus.pending)
                  IconButton(
                    tooltip: settings.t('Menunggu Kelulusan'),
                    onPressed: null,
                    icon: const Icon(Icons.more_vert),
                  )
                else
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'status') _showStatusSheet(member);
                      if (value == 'role') _showRoleSheet(member);
                      if (value == 'profile') _showEditProfileDialog(member);
                      if (value == 'location') _showTransferDialog(member);
                      if (value == 'password') _resetPassword(member);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'status',
                        child: Text(settings.t('Tukar Status')),
                      ),
                      PopupMenuItem(
                        value: 'role',
                        child: Text(settings.t('Tukar Peranan')),
                      ),
                      if (isSuperAdmin) ...[
                        PopupMenuItem(
                          value: 'profile',
                          child: Text(settings.t('Edit Profil')),
                        ),
                        PopupMenuItem(
                          value: 'location',
                          child: Text(settings.t('Pindah Lokasi')),
                        ),
                        PopupMenuItem(
                          value: 'password',
                          child: Text(settings.t('Reset Kata Laluan')),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _memberInfoRow(
              Icons.location_on_outlined,
              _memberLocation(member),
              theme,
            ),
            const SizedBox(height: 6),
            _memberInfoRow(
              Icons.badge_outlined,
              'IC: ${member.icNumber ?? '-'}  |  ${member.phoneNumber ?? '-'}',
              theme,
            ),
            if (member.email != null) ...[
              const SizedBox(height: 6),
              _memberInfoRow(Icons.mail_outline, member.email!, theme),
            ],
            if (status == AccountStatus.pending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _postAction({
                        'action': 'update_status',
                        'user_id': member.id,
                        'account_status': 'active',
                      }),
                      icon: const Icon(Icons.check),
                      label: Text(settings.t('Lulus')),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _postAction({
                        'action': 'update_status',
                        'user_id': member.id,
                        'account_status': 'inactive',
                      }),
                      icon: const Icon(Icons.close),
                      label: Text(settings.t('Tolak')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _memberInfoRow(IconData icon, String text, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.48),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textTheme.titleMedium?.color,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              count,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMembersState(SettingsProvider settings) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 96, 8, 120),
      children: [
        CommandEmptyStateCard(
          icon: Icons.manage_search_outlined,
          title: settings.t('Tiada ahli dijumpai.'),
          message: settings.t('Cuba ubah carian atau penapis ahli.'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final filtered = _filteredMembers;
    final pendingMembers = filtered
        .where((member) => member.accountStatusEnum == AccountStatus.pending)
        .toList();
    final activeMembers = filtered
        .where((member) => member.accountStatusEnum != AccountStatus.pending)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: CommandHeader(
            title: settings.t('Pusat Pengurusan Ahli'),
            subtitle: settings.t(
              'Semak pendaftaran, status akaun, peranan dan lokasi ahli KRT/SRS.',
            ),
            icon: Icons.groups_2_outlined,
            compact: true,
          ),
        ),
        _buildFilterBar(settings, theme),
        _buildQuickFilterChips(settings, theme),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchMembers,
            child: _isLoading
                ? ListView(
                    children: [
                      const SizedBox(height: 180),
                      Center(
                        child: CircularProgressIndicator(
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  )
                : filtered.isEmpty
                ? _buildEmptyMembersState(settings)
                : ListView(
                    padding: const EdgeInsets.only(top: 4, bottom: 110),
                    children: [
                      if (pendingMembers.isNotEmpty) ...[
                        _buildSectionHeader(
                          settings.t('Menunggu Kelulusan'),
                          '${pendingMembers.length}',
                          Icons.pending_actions_rounded,
                          Colors.orange.shade800,
                        ),
                        ...pendingMembers.map(
                          (member) => _buildMemberCard(
                            member,
                            settings,
                            isPendingSection: true,
                          ),
                        ),
                      ],
                      if (activeMembers.isNotEmpty) ...[
                        _buildSectionHeader(
                          settings.t('Ahli Aktif & Berdaftar'),
                          '${activeMembers.length}',
                          Icons.groups_2_outlined,
                          theme.primaryColor,
                        ),
                        ...activeMembers.map(
                          (member) => _buildMemberCard(member, settings),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
