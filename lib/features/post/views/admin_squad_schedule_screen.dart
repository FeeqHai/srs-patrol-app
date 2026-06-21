import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/network/api_client.dart';

class AdminSquadScheduleScreen extends StatefulWidget {
  const AdminSquadScheduleScreen({super.key});

  @override
  State<AdminSquadScheduleScreen> createState() => _AdminSquadScheduleScreenState();
}

class _AdminSquadScheduleScreenState extends State<AdminSquadScheduleScreen> with SingleTickerProviderStateMixin {
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
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          indicatorColor: theme.colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: theme.dividerColor.withValues(alpha: 0.1),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: [
            Tab(text: settings.t('Kumpulan')),
            Tab(text: settings.t('Penjadualan')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _SquadManagementTab(),
              _ScheduleManagementTab(),
            ],
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

  SettingsProvider get settings => Provider.of<SettingsProvider>(context, listen: false);

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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t('Kumpulan berjaya dicipta!'))));
        _fetchSquads();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t(response['message'] ?? 'Ralat mencipta kumpulan'))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${settings.t("Ralat")}: $e')));
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t('Ahli berjaya ditambah!'))));
        _fetchSquads();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t(response['message'] ?? 'Ralat menambah ahli'))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${settings.t("Ralat")}: $e')));
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t('Ahli berjaya dikeluarkan!'))));
        _fetchSquads();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t(response['message'] ?? 'Ralat mengeluarkan ahli'))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${settings.t("Ralat")}: $e')));
    }
  }

  Future<void> _deleteSquad(String squadId) async {
    try {
      final response = await ApiClient.postData('admin/squads.php', {
        'action': 'delete_squad',
        'squad_id': squadId,
      });
      if (response['success'] == true || response['status'] == 'success') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t('Kumpulan dipadam!'))));
        _fetchSquads();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t(response['message'] ?? 'Ralat memadam kumpulan'))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t('Ralat memadam kumpulan'))));
    }
  }

  void _showCreateSquadDialog() {
    final TextEditingController nameController = TextEditingController();
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings.t('Cipta Kumpulan Baru'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.primaryColor),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  labelText: settings.t('Nama Kumpulan'),
                  labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: theme.dividerColor.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      builder: (_) => Center(child: CircularProgressIndicator(color: theme.primaryColor)),
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
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (context) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.t('Pilih Peronda'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.primaryColor),
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
                            final isAssigned = squadName != null && squadName.toString().isNotEmpty;

                            return Card(
                              elevation: 0,
                              color: isAssigned ? theme.disabledColor.withValues(alpha: 0.1) : theme.cardColor,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: theme.dividerColor),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isAssigned ? theme.disabledColor : theme.primaryColor,
                                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                                ),
                                title: Text(
                                  p['full_name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isAssigned ? theme.disabledColor : theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                subtitle: Text(
                                  isAssigned 
                                      ? '${settings.t("Telah ditugaskan ke:")} $squadName' 
                                      : '${settings.t("Zon")}: ${p['zone'] ?? p['district_zone'] ?? '-'}',
                                  style: TextStyle(
                                    color: isAssigned ? Colors.redAccent.shade700 : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                    fontWeight: isAssigned ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                                trailing: isAssigned
                                  ? SizedBox(
                                      width: 90,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Icon(Icons.lock_outline, color: theme.disabledColor, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            settings.t('Terkunci'),
                                            style: TextStyle(color: theme.disabledColor, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme.secondary,
                                        foregroundColor: Colors.black,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _addMember(squadId, p['id'].toString());
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${settings.t("Ralat memuat senarai:")} $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    if (_isLoading) return Center(child: CircularProgressIndicator(color: theme.primaryColor));

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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: _squads.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off, size: 64, color: theme.disabledColor),
                        const SizedBox(height: 16),
                        Text(
                          settings.t('Tiada Kumpulan Direkodkan'),
                          style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 16, fontWeight: FontWeight.w500),
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
                            color: theme.brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            iconColor: theme.primaryColor,
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.group, color: theme.primaryColor),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        squad['name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: theme.textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${members.length} ${settings.t("Ahli")}',
                                        style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(settings.t('Padam Kumpulan')),
                                        content: Text(
                                          '${settings.t("Adakah anda pasti untuk memadam kumpulan")} "${squad['name']}"? ${settings.t("Semua data ahli dan jadual berkaitan kumpulan ini akan dipadam.")}',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text(settings.t('Batal')),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _deleteSquad(squad['id']);
                                            },
                                            child: Text(
                                              settings.t('Padam'),
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              ],
                            ),
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.scaffoldBackgroundColor,
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                ),
                                child: Column(
                                  children: [
                                    if (members.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Text(
                                          settings.t('Belum ada ahli.'),
                                          style: TextStyle(color: theme.disabledColor, fontStyle: FontStyle.italic),
                                        ),
                                      )
                                    else
                                      ...members.map((m) => ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                                        leading: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: theme.cardColor,
                                          child: Icon(Icons.person, size: 16, color: theme.disabledColor),
                                        ),
                                        title: Text(
                                          m['full_name'],
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color),
                                        ),
                                        subtitle: Text(
                                          m['ic_number'] ?? '',
                                          style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Text(settings.t('Keluarkan Ahli')),
                                                content: Text(
                                                  '${settings.t("Adakah anda pasti untuk mengeluarkan")} "${m['full_name']}" ${settings.t("daripada kumpulan?")}',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    child: Text(settings.t('Batal')),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _removeMember(squad['id'], m['user_id'].toString());
                                                    },
                                                    child: Text(
                                                      settings.t('Keluarkan'),
                                                      style: const TextStyle(color: Colors.white),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      )),
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: OutlinedButton.icon(
                                        onPressed: () => _showAddMemberDialog(squad['id']),
                                        icon: const Icon(Icons.person_add),
                                        label: Text(settings.t('Tambah Ahli')),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: theme.primaryColor,
                                          side: BorderSide(color: theme.primaryColor),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          minimumSize: const Size(double.infinity, 44),
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
}class _ScheduleManagementTab extends StatefulWidget {
  const _ScheduleManagementTab();

  @override
  State<_ScheduleManagementTab> createState() => _ScheduleManagementTabState();
}

class _ScheduleManagementTabState extends State<_ScheduleManagementTab> {
  List<dynamic> _schedules = [];
  bool _isLoading = true;

  SettingsProvider get settings => Provider.of<SettingsProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  Future<void> _fetchSchedules() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.getData('admin/schedules.php');
      if (response['success'] == true || response['status'] == 'success') {
        setState(() => _schedules = response['data'] ?? []);
      }
    } catch (e) {
      debugPrint("Error fetching schedules: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createSchedule(String squadId, String date, String startTime, String endTime) async {
    try {
      final response = await ApiClient.postData('admin/schedules.php', {
        'action': 'create_schedule',
        'squad_id': squadId,
        'shift_date': date,
        'start_time': startTime,
        'end_time': endTime,
      });
      if (response['success'] == true || response['status'] == 'success') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t('Jadual berjaya ditetap!'))));
        _fetchSchedules();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t(response['message'] ?? 'Ralat menetapkan jadual'))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${settings.t("Ralat")}: $e')));
    }
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    try {
      final response = await ApiClient.postData('admin/schedules.php', {
        'action': 'delete_schedule',
        'schedule_id': scheduleId,
      });
      if (response['success'] == true || response['status'] == 'success') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t('Jadual berjaya dipadam!'))));
        _fetchSchedules();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t(response['message'] ?? 'Ralat memadam jadual'))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${settings.t("Ralat")}: $e')));
    }
  }

  void _showCreateScheduleDialog() async {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: theme.primaryColor)),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${settings.t("Ralat memuatkan kumpulan:")} $e')));
      return;
    }

    if (squads.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t('Sila cipta kumpulan terlebih dahulu!'))));
      return;
    }

    String? selectedSquadId = squads[0]['id'];
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay startTime = const TimeOfDay(hour: 22, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 2, minute: 0);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.t('Tetapkan Jadual Rondaan'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.primaryColor),
                  ),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    initialValue: selectedSquadId,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      labelText: settings.t('Pilih Kumpulan'),
                      labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
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
                    ),
                    items: squads.map<DropdownMenuItem<String>>((s) {
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
                    leading: Icon(Icons.calendar_today, color: theme.primaryColor),
                    title: Text(settings.t('Tarikh Rondaan'), style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6))),
                    subtitle: Text(
                      "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                    ),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.primaryColor,
                        side: BorderSide(color: theme.primaryColor),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
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
                    title: Text(settings.t('Masa Mula Rondaan'), style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6))),
                    subtitle: Text(
                      startTime.format(context),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
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
                    leading: const Icon(Icons.access_time, color: Colors.redAccent),
                    title: Text(settings.t('Masa Tamat Rondaan'), style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6))),
                    subtitle: Text(
                      endTime.format(context),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (selectedSquadId != null) {
                          final dateStr = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
                          final startStr = "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00";
                          final endStr = "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00";
                          
                          Navigator.pop(context);
                          _createSchedule(selectedSquadId!, dateStr, startStr, endStr);
                        }
                      },
                      child: Text(settings.t('Simpan Jadual'), style: const TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    if (_isLoading) return Center(child: CircularProgressIndicator(color: theme.primaryColor));

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: FilledButton.icon(
              onPressed: _showCreateScheduleDialog,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(settings.t('Tetapkan Jadual Rondaan')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: _schedules.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 64, color: theme.disabledColor),
                        const SizedBox(height: 16),
                        Text(
                          settings.t('Tiada Jadual Rondaan Direkodkan'),
                          style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _schedules.length,
                    itemBuilder: (context, index) {
                      final schedule = _schedules[index];
                      final shiftDate = schedule['shift_date'] ?? '';
                      final squadName = schedule['squad_name'] ?? settings.t('Kumpulan Tanpa Nama');
                      final startTime = schedule['start_time'] ?? '';
                      final endTime = schedule['end_time'] ?? '';
                      
                      final displayStart = startTime.length > 5 ? startTime.substring(0, 5) : startTime;
                      final displayEnd = endTime.length > 5 ? endTime.substring(0, 5) : endTime;

                      return Card(
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.05),
                        color: theme.cardColor,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: theme.brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD100).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.event_note, color: theme.primaryColor),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      squadName,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.bodyLarge?.color),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                                        const SizedBox(width: 4),
                                        Text(shiftDate, style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 13)),
                                        const SizedBox(width: 12),
                                        Icon(Icons.access_time, size: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$displayStart - $displayEnd',
                                          style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(settings.t('Padam Jadual')),
                                      content: Text(
                                        '${settings.t("Adakah anda pasti untuk memadam jadual rondaan bagi kumpulan")} "$squadName" ${settings.t("pada tarikh")} $shiftDate?',
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: Text(settings.t('Batal'))),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _deleteSchedule(schedule['id']);
                                          },
                                          child: Text(settings.t('Padam'), style: const TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )
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
