import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/settings_provider.dart';
import '../../auth/models/user_model.dart';

/// Status-filter values used by the segmented control. `'all'` shows every
/// member; the others constrain to a single [AccountStatus].
const String _kFilterAll = 'all';
const String _kFilterPending = 'pending';
const String _kFilterActive = 'active';
const String _kFilterInactive = 'inactive';

class AdminMemberScreen extends StatefulWidget {
  const AdminMemberScreen({super.key});

  @override
  State<AdminMemberScreen> createState() => _AdminMemberScreenState();
}

class _AdminMemberScreenState extends State<AdminMemberScreen> {
  List<UserModel> _members = [];
  String _searchQuery = '';
  String _selectedZone = 'Semua Zon';
  String _statusFilter = _kFilterAll;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    try {
      final data =
          await ApiClient.getData('auth/get_patrollers.php')
              as Map<String, dynamic>;
      if (data['status'] == 'success') {
        final list = (data['data'] as List<dynamic>)
            .map((j) => UserModel.fromJson(j as Map<String, dynamic>))
            .toList();
        if (!mounted) return;
        setState(() {
          _members = list;
          _isLoading = false;
          _error = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = (data['message'] ?? 'Gagal memuatkan ahli.').toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ralat Rangkaian: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildStatusChip(AccountStatus status, SettingsProvider settings) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status) {
      case AccountStatus.active:
        bgColor = Colors.green.withValues(alpha: 0.15);
        textColor = Colors.green.shade800;
        text = settings.t('Aktif');
      case AccountStatus.pending:
        bgColor = Colors.orange.withValues(alpha: 0.15);
        textColor = Colors.orange.shade800;
        text = settings.t('Menunggu');
      case AccountStatus.inactive:
        bgColor = Colors.red.withValues(alpha: 0.15);
        textColor = Colors.red.shade800;
        text = settings.t('Nyahaktif');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role, SettingsProvider settings) {
    Color bgColor;
    Color textColor;
    String text;

    if (role == 'ketua_peronda') {
      bgColor = Colors.amber.withValues(alpha: 0.15);
      textColor = Colors.amber.shade900;
      text = settings.t('Ketua Peronda');
    } else {
      bgColor = Colors.blue.withValues(alpha: 0.15);
      textColor = Colors.blue.shade800;
      text = settings.t('Peronda');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  void _showStatusBottomSheet(
    BuildContext context,
    UserModel member,
    SettingsProvider settings,
  ) {
    AccountStatus selected = member.accountStatusEnum;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 32.0),
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
                  Text(
                    '${settings.t('Tukar Status')}: ${member.fullName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<AccountStatus>(
                    segments: [
                      ButtonSegment<AccountStatus>(
                        value: AccountStatus.active,
                        label: Text(settings.t('Aktif')),
                        icon: const Icon(Icons.check_circle_outline),
                      ),
                      ButtonSegment<AccountStatus>(
                        value: AccountStatus.pending,
                        label: Text(settings.t('Menunggu')),
                        icon: const Icon(Icons.hourglass_empty),
                      ),
                      ButtonSegment<AccountStatus>(
                        value: AccountStatus.inactive,
                        label: Text(settings.t('Nyahaktif')),
                        icon: const Icon(Icons.block),
                      ),
                    ],
                    selected: {selected},
                    onSelectionChanged: (Set<AccountStatus> newSelection) {
                      setModalState(() {
                        selected = newSelection.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      selectedForegroundColor: Colors.white,
                      selectedBackgroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(settings.t('Batal')),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateUserStatus(member.id, selected);
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(settings.t('Tukar')),
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

  void _showRoleBottomSheet(
    BuildContext context,
    UserModel member,
    SettingsProvider settings,
  ) {
    String selectedRole = member.role;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 32.0),
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
                  Text(
                    '${settings.t('Tukar Peranan')}: ${member.fullName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment<String>(
                        value: 'peronda',
                        label: Text(settings.t('Peronda')),
                        icon: const Icon(Icons.person_outline),
                      ),
                      ButtonSegment<String>(
                        value: 'ketua_peronda',
                        label: Text(settings.t('Ketua Peronda')),
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                      ),
                    ],
                    selected: {selectedRole},
                    onSelectionChanged: (Set<String> newSelection) {
                      setModalState(() {
                        selectedRole = newSelection.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      selectedForegroundColor: Colors.white,
                      selectedBackgroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(settings.t('Batal')),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateUserRole(member.id, selectedRole);
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(settings.t('Tukar')),
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

  Future<void> _updateUserStatus(String userId, AccountStatus status) async {
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final data = await ApiClient.postData('admin/update_user.php', {
        'action': 'update_status',
        'user_id': userId,
        'account_status': status.wireValue,
      });

      if (data['status'] == 'success') {
        messenger.showSnackBar(
          SnackBar(
            content: Text(settings.t('Kemas kini berjaya')),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchMembers();
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? settings.t('Kemas kini gagal')),
            backgroundColor: Colors.redAccent,
          ),
        );
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

  Future<void> _updateUserRole(String userId, String role) async {
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final data = await ApiClient.postData('admin/update_user.php', {
        'action': 'promote_role',
        'user_id': userId,
        'role': role,
      });

      if (data['status'] == 'success') {
        messenger.showSnackBar(
          SnackBar(
            content: Text(settings.t('Kemas kini berjaya')),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchMembers();
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? settings.t('Kemas kini gagal')),
            backgroundColor: Colors.redAccent,
          ),
        );
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

  /// Confirms rejection before setting the member to `inactive`. Approve is
  /// reversible so it skips confirmation; reject feels destructive.
  void _confirmReject(UserModel member) {
    final settings = context.read<SettingsProvider>();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.person_remove_outlined, size: 40),
        title: Text(settings.t('Tolak Pendaftaran')),
        content: Text(
          settings.t('Adakah anda pasti ingin menolak pendaftaran ahli ini?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(settings.t('Batal')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _updateUserStatus(member.id, AccountStatus.inactive);
            },
            child: Text(settings.t('Ya, Tolak')),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    final settings = context.read<SettingsProvider>();
    final theme = Theme.of(context);
    String tempStatus = _statusFilter;
    String tempZone = _selectedZone;

    final Set<String> zonesSet = {'Semua Zon'};
    for (final m in _members) {
      final z = m.districtZone;
      if (z != null && z.isNotEmpty) zonesSet.add(z);
    }
    final List<String> zonesList = zonesSet.toList();

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
                        settings.t("Tapis Pengurusan Ahli"),
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
                  Text(
                    settings.t("Status Akaun"),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: tempStatus,
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
                        value: _kFilterAll,
                        child: Text(settings.t('Semua')),
                      ),
                      DropdownMenuItem(
                        value: _kFilterActive,
                        child: Text(settings.t('Aktif')),
                      ),
                      DropdownMenuItem(
                        value: _kFilterPending,
                        child: Text(settings.t('Menunggu')),
                      ),
                      DropdownMenuItem(
                        value: _kFilterInactive,
                        child: Text(settings.t('Nyahaktif')),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => tempStatus = val);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    settings.t("Zon Rondaan"),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: tempZone,
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
                    items: zonesList.map((String zone) {
                      return DropdownMenuItem(
                        value: zone,
                        child: Text(
                          zone == 'Semua Zon' ? settings.t(zone) : zone,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => tempZone = val);
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
                              _statusFilter = _kFilterAll;
                              _selectedZone = 'Semua Zon';
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
                              _statusFilter = tempStatus;
                              _selectedZone = tempZone;
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
    );
  }

  Widget _buildMemberCard(UserModel member, SettingsProvider settings) {
    final theme = Theme.of(context);
    final status = member.accountStatusEnum;
    final isPending = status == AccountStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Circle with status indicator dot
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      child: Text(
                        member.fullName.isNotEmpty
                            ? member.fullName[0].toUpperCase()
                            : 'P',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: status == AccountStatus.active
                              ? Colors.green
                              : status == AccountStatus.pending
                              ? Colors.orange
                              : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildRoleChip(member.role, settings),
                          _buildStatusChip(status, settings),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${settings.t('Zon')}: ${member.districtZone ?? settings.t('Tiada')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'IC: ${member.icNumber ?? '-'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            member.phoneNumber ?? '-',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Trailing Action Menu (status + role). Kept on every card so
                // admins can still promote role / re-open a pending member.
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                  onSelected: (value) {
                    if (value == 'status') {
                      _showStatusBottomSheet(context, member, settings);
                    } else if (value == 'role') {
                      _showRoleBottomSheet(context, member, settings);
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'status',
                          child: Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 18,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(settings.t('Tukar Status')),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'role',
                          child: Row(
                            children: [
                              Icon(
                                Icons.admin_panel_settings_outlined,
                                size: 18,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(settings.t('Tukar Peranan')),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),
            // Inline Approve/Reject actions for pending members.
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _updateUserStatus(member.id, AccountStatus.active),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(settings.t('Lulus')),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmReject(member),
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(settings.t('Tolak')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    // Full-screen initial load only; afterwards the filter bar stays visible
    // so admins can retry / filter even on an empty (filtered) result set.
    if (_isLoading && _members.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
    }

    if (_error != null && _members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchMembers();
              },
              icon: const Icon(Icons.refresh),
              label: Text(settings.t('Cuba Lagi')),
            ),
          ],
        ),
      );
    }

    if (_members.isEmpty) {
      return Center(
        child: Text(
          settings.t('Tiada peronda dijumpai.'),
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
        ),
      );
    }

    // Build the zone dropdown values.
    final Set<String> zones = {'Semua Zon'};
    for (final m in _members) {
      final z = m.districtZone;
      if (z != null && z.isNotEmpty) zones.add(z);
    }

    // Filter pipeline: search ∩ zone ∩ statusFilter.
    final filtered = _members.where((m) {
      final matchesSearch = m.fullName.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesZone =
          _selectedZone == 'Semua Zon' || m.districtZone == _selectedZone;
      final matchesStatus =
          _statusFilter == _kFilterAll ||
          m.accountStatusEnum.wireValue == _statusFilter;
      return matchesSearch && matchesZone && matchesStatus;
    }).toList();

    final bool isFilterActive =
        _statusFilter != _kFilterAll || _selectedZone != 'Semua Zon';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: settings.t('Cari nama peronda...'),
                    hintStyle: TextStyle(color: Colors.grey.shade500),
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
        // List (pull-to-refresh + empty states).
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchMembers,
            color: theme.primaryColor,
            child: filtered.isEmpty
                ? ListView(
                    // Keep RefreshIndicator working even when empty.
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              _statusFilter == _kFilterPending
                                  ? Icons.check_circle_outline
                                  : _statusFilter == _kFilterInactive
                                  ? Icons.block
                                  : Icons.search_off,
                              size: 64,
                              color: theme.disabledColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _statusFilter == _kFilterPending
                                  ? settings.t(
                                      'Tiada ahli menunggu pengesahan.',
                                    )
                                  : _statusFilter == _kFilterInactive
                                  ? settings.t('Tiada ahli nyahaktif.')
                                  : settings.t('Tiada padanan carian.'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color
                                    ?.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _statusFilter == _kFilterPending
                                  ? settings.t(
                                      'Semua pendaftaran baharu telah diluluskan.',
                                    )
                                  : _statusFilter == _kFilterInactive
                                  ? settings.t(
                                      'Semua ahli berdaftar adalah aktif atau menunggu pengesahan.',
                                    )
                                  : settings.t(
                                      'Cuba cari dengan e-mel atau no. kad pengenalan lain.',
                                    ),
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.textTheme.bodyLarge?.color
                                    ?.withValues(alpha: 0.4),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
