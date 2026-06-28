import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/models/location_option.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';

const String _all = 'all';

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

  Future<void> _selectState(LocationOption? state) async {
    setState(() {
      _state = state;
      _district = null;
      _zone = null;
      _districts = const [];
      _zones = const [];
    });
    if (state == null) return;
    final districts = await _authService.fetchLocations(
      level: 'districts',
      parentId: state.id,
    );
    if (!mounted || _state?.id != state.id) return;
    setState(() => _districts = districts);
  }

  Future<void> _selectDistrict(LocationOption? district) async {
    setState(() {
      _district = district;
      _zone = null;
      _zones = const [];
    });
    if (district == null) return;
    final zones = await _authService.fetchLocations(
      level: 'zones',
      parentId: district.id,
    );
    if (!mounted || _district?.id != district.id) return;
    setState(() => _zones = zones);
  }

  List<UserModel> get _filteredMembers {
    final search = _searchController.text.trim().toLowerCase();
    return _members.where((member) {
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
    final roles = ['peronda', 'ketua_peronda', if (isSuperAdmin) 'ketua_krt'];
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
                items: roles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(_roleLabel(role, settings)),
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

  Widget _buildFilterBar(SettingsProvider settings, ThemeData theme) {
    final isSuperAdmin = context.watch<AuthProvider>().role == 'super_admin';
    return Material(
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: settings.t('Cari nama, IC, telefon atau e-mel...'),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
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
                        setState(() => _status = value ?? _all),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    initialValue: _role,
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
                    ],
                    onChanged: (value) => setState(() => _role = value ?? _all),
                  ),
                ),
                if (isSuperAdmin) ...[
                  SizedBox(
                    width: 190,
                    child: _nullableLocationDropdown(
                      label: settings.t('Negeri'),
                      value: _state,
                      items: _states,
                      allLabel: settings.t('Semua Negeri'),
                      onChanged: _selectState,
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: _nullableLocationDropdown(
                      label: settings.t('Daerah'),
                      value: _district,
                      items: _districts,
                      allLabel: settings.t('Semua Daerah'),
                      enabled: _state != null,
                      onChanged: _selectDistrict,
                    ),
                  ),
                ],
                SizedBox(
                  width: 190,
                  child: _nullableLocationDropdown(
                    label: settings.t('Zon'),
                    value: _zone,
                    items: _zones,
                    allLabel: settings.t('Semua Zon'),
                    enabled: isSuperAdmin ? _district != null : true,
                    onChanged: (value) => setState(() => _zone = value),
                  ),
                ),
              ],
            ),
          ],
        ),
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

  Widget _buildMemberCard(UserModel member, SettingsProvider settings) {
    final isSuperAdmin = context.read<AuthProvider>().role == 'super_admin';
    final status = member.accountStatusEnum;
    final statusColor = status == AccountStatus.active
        ? Colors.green.shade700
        : status == AccountStatus.pending
        ? Colors.orange.shade800
        : Colors.redAccent;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          _chip(_roleLabel(member.role, settings), Colors.blue),
                          _chip(settings.t(status.wireValue), statusColor),
                        ],
                      ),
                    ],
                  ),
                ),
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
            Text(
              '${settings.t('Negeri')} / ${settings.t('Daerah')} / ${settings.t('Zon')}: '
              '${member.stateName ?? '-'} / ${member.districtName ?? '-'} / ${member.zoneName ?? member.districtZone ?? '-'}',
            ),
            const SizedBox(height: 4),
            Text(
              'IC: ${member.icNumber ?? '-'}  |  ${member.phoneNumber ?? '-'}',
            ),
            if (member.email != null) ...[
              const SizedBox(height: 4),
              Text(member.email!),
            ],
            if (status == AccountStatus.pending) ...[
              const SizedBox(height: 12),
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final filtered = _filteredMembers;

    return Column(
      children: [
        _buildFilterBar(settings, theme),
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
                ? ListView(
                    children: [
                      const SizedBox(height: 160),
                      Center(child: Text(settings.t('Tiada ahli dijumpai.'))),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildMemberCard(filtered[index], settings),
                  ),
          ),
        ),
      ],
    );
  }
}
