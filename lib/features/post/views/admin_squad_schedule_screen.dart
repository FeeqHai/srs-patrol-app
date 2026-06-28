import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/user_avatar.dart';

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

  SettingsProvider get settings =>
      Provider.of<SettingsProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _fetchSquads();
  }

  Future<void> _fetchSquads() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.getData('admin/squads.php');
      if (response['status'] == 'success' || response['success'] == true) {
        setState(() => _squads = response['data'] ?? []);
      }
    } catch (e) {
      debugPrint("Error fetching squads: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createSquad(String name) async {
    try {
      final response = await ApiClient.postData('admin/squads.php', {
        'action': 'create_squad',
        'name': name,
      });
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

  void _showCreateSquadDialog() {
    final TextEditingController nameController = TextEditingController();
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
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
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  labelText: settings.t('Nama Kumpulan'),
                  labelStyle: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.6,
                    ),
                  ),
                  filled: true,
                  fillColor: theme.dividerColor.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
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
                    borderSide: BorderSide(color: theme.primaryColor, width: 2),
                  ),
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
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      Navigator.pop(context);
                      _createSquad(nameController.text);
                    }
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
        );
      },
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
                                        : '${settings.t("Zon")}: ${p['zone'] ?? p['district_zone'] ?? '-'}',
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
            padding: const EdgeInsets.all(20.0),
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
            child: _squads.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_off,
                          size: 64,
                          color: theme.disabledColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          settings.t('Tiada Kumpulan Direkodkan'),
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _squads.length,
                    itemBuilder: (context, index) {
                      final squad = _squads[index];
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
                                            m['ic_number'] ?? '',
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
  String? _selectedZoneId;

  SettingsProvider get settings =>
      Provider.of<SettingsProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  Future<void> _fetchSchedules() async {
    setState(() => _isLoading = true);
    try {
      final query = _selectedZoneId == null ? '' : '?zone_id=$_selectedZoneId';
      final response = await ApiClient.getData('admin/schedules.php$query');
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
    String date,
    String startTime,
    String endTime,
  ) async {
    try {
      final response = await ApiClient.postData('admin/schedules.php', {
        'action': 'create_schedule',
        'squad_id': squadId,
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

  void _showCreateScheduleDialog() async {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          Center(child: CircularProgressIndicator(color: theme.primaryColor)),
    );

    List<dynamic> squads = [];
    try {
      final response = await ApiClient.getData('admin/squads.php');
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (response['success'] == true || response['status'] == 'success') {
        squads = response['data'] ?? [];
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.t("Ralat memuatkan kumpulan:")} $e'),
        ),
      );
      return;
    }

    if (squads.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.t('Sila cipta kumpulan terlebih dahulu!')),
        ),
      );
      return;
    }

    final assignZones = _zoneOptionsFromSquads(squads);
    String? selectedAssignZoneId =
        _selectedZoneId ??
        (assignZones.isNotEmpty ? assignZones.first.id : null);
    List<dynamic> filteredSquads() => selectedAssignZoneId == null
        ? squads
        : squads
              .where(
                (squad) => squad['zone_id']?.toString() == selectedAssignZoneId,
              )
              .toList();
    var availableSquads = filteredSquads();
    String? selectedSquadId = availableSquads.isNotEmpty
        ? availableSquads[0]['id']?.toString()
        : squads[0]['id']?.toString();
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
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
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

                  if (assignZones.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedAssignZoneId,
                      dropdownColor: theme.cardColor,
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                      decoration: _dialogInputDecoration(
                        theme,
                        settings.t('filter_by_zone'),
                      ),
                      items: assignZones.map<DropdownMenuItem<String>>((zone) {
                        return DropdownMenuItem<String>(
                          value: zone.id,
                          child: Text(zone.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() {
                          selectedAssignZoneId = val;
                          availableSquads = filteredSquads();
                          selectedSquadId = availableSquads.isNotEmpty
                              ? availableSquads[0]['id']?.toString()
                              : null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  DropdownButtonFormField<String>(
                    key: ValueKey('squad-$selectedAssignZoneId'),
                    initialValue: selectedSquadId,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: _dialogInputDecoration(
                      theme,
                      settings.t('choose_squad'),
                    ),
                    items: availableSquads.map<DropdownMenuItem<String>>((s) {
                      return DropdownMenuItem<String>(
                        value: s['id'].toString(),
                        child: Text(s['name']),
                      );
                    }).toList(),
                    onChanged: (val) {
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
                    leading: Icon(Icons.access_time, color: theme.primaryColor),
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
                      onPressed: () {
                        if (selectedSquadId != null) {
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
                            dateStr,
                            startStr,
                            endStr,
                          );
                        }
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
            );
          },
        );
      },
    );
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
    final zones = _zoneOptions();

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
            if (zones.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(settings.t('all_zones')),
                        selected: _selectedZoneId == null,
                        onSelected: (_) {
                          setState(() => _selectedZoneId = null);
                          _fetchSchedules();
                        },
                      ),
                    ),
                    ...zones.map(
                      (zone) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(zone.name),
                          selected: zone.id == _selectedZoneId,
                          onSelected: (_) {
                            setState(() => _selectedZoneId = zone.id);
                            _fetchSchedules();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
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

  List<_ZoneOption> _zoneOptions() {
    final zones = <String, _ZoneOption>{};
    for (final schedule in _schedules) {
      final id = schedule['zone_id']?.toString();
      final name = schedule['zone_name']?.toString();
      if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
        zones[id] = _ZoneOption(id, name);
      }
    }
    return zones.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<_ZoneOption> _zoneOptionsFromSquads(List<dynamic> squads) {
    final zones = <String, _ZoneOption>{};
    for (final squad in squads) {
      final id = squad['zone_id']?.toString();
      final name = squad['zone_name']?.toString();
      if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
        zones[id] = _ZoneOption(id, name);
      }
    }
    return zones.values.toList()..sort((a, b) => a.name.compareTo(b.name));
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

class _ZoneOption {
  const _ZoneOption(this.id, this.name);

  final String id;
  final String name;
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
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.event_note, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule['squad_name']?.toString() ??
                        settings.t('Kumpulan Tanpa Nama'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _Meta(
                        icon: Icons.place_outlined,
                        text: schedule['zone_name']?.toString() ?? '-',
                      ),
                      _Meta(
                        icon: Icons.calendar_today_outlined,
                        text: shiftDate,
                      ),
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
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Chip(
                  label: Text(status),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
      ],
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
