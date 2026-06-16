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
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.lightBlueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.lightBlueAccent,
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
      if (response['success'] == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kumpulan berjaya dicipta!')));
        _fetchSquads();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'Ralat mencipta kumpulan')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ralat: $e')));
    }
  }

  Future<void> _addMember(String squadId, String userId) async {
    try {
      final response = await ApiClient.postData('admin/squads.php', {
        'action': 'add_member',
        'squad_id': squadId,
        'user_id': userId,
      });
      if (response['success'] == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ahli berjaya ditambah!')));
        _fetchSquads();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'Ralat menambah ahli')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ralat: $e')));
    }
  }

  Future<void> _removeMember(String squadId, String userId) async {
    try {
      final response = await ApiClient.postData('admin/squads.php', {
        'action': 'remove_member',
        'squad_id': squadId,
        'user_id': userId,
      });
      if (response['success'] == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ahli berjaya dikeluarkan!')));
        _fetchSquads();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'Ralat mengeluarkan ahli')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ralat: $e')));
    }
  }

  Future<void> _deleteSquad(String squadId) async {
    try {
      final response = await ApiClient.postData('admin/squads.php', {
        'action': 'delete_squad',
        'squad_id': squadId,
      });
      if (response['success'] == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kumpulan dipadam!')));
        _fetchSquads();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'Ralat memadam kumpulan')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ralat memadam kumpulan')));
    }
  }

  void _showCreateSquadDialog() {
    final TextEditingController nameController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cipta Kumpulan Baru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F3D87))),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Kumpulan',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F3D87))),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3D87),
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
                  child: const Text('Simpan Kumpulan', style: TextStyle(fontWeight: FontWeight.bold)),
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
    // Show loading dialog
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    try {
      final response = await ApiClient.getData('auth/get_patrollers.php');
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      
      if (response['status'] == 'success') {
        final List<dynamic> patrollers = response['data'] ?? [];
        
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (context) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pilih Peronda', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F3D87))),
                  const SizedBox(height: 16),
                  Expanded(
                    child: patrollers.isEmpty
                      ? const Center(child: Text('Tiada peronda dijumpai'))
                      : ListView.builder(
                          itemCount: patrollers.length,
                          itemBuilder: (context, index) {
                            final p = patrollers[index];
                            final squadName = p['squad_name'];
                            final isAssigned = squadName != null && squadName.toString().isNotEmpty;

                            return Card(
                              elevation: 0,
                              color: isAssigned ? Colors.grey.shade100 : Colors.grey.shade50,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: isAssigned ? Colors.grey.shade300 : Colors.grey.shade200)
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isAssigned ? Colors.grey : const Color(0xFF0F3D87),
                                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                                ),
                                title: Text(
                                  p['full_name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isAssigned ? Colors.grey : Colors.black87
                                  )
                                ),
                                subtitle: Text(
                                  isAssigned ? 'Telah ditugaskan ke: $squadName' : 'Zon: ${p['district_zone'] ?? '-'}',
                                  style: TextStyle(
                                    color: isAssigned ? Colors.redAccent.shade700 : Colors.grey.shade600,
                                    fontWeight: isAssigned ? FontWeight.w500 : FontWeight.normal
                                  )
                                ),
                                trailing: isAssigned
                                  ? const SizedBox(
                                      width: 90,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Icon(Icons.lock_outline, color: Colors.grey, size: 16),
                                          SizedBox(width: 4),
                                          Text('Terkunci', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFFD100),
                                        foregroundColor: Colors.black,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _addMember(squadId, p['id'].toString());
                                      },
                                      child: const Text('Pilih'),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ralat memuat senarai: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton.icon(
              onPressed: _showCreateSquadDialog,
              icon: const Icon(Icons.add_circle),
              label: const Text('Cipta Kumpulan Baru'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: const Color(0xFF0F3D87),
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: const Color(0xFF0F3D87).withValues(alpha: 0.4),
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
                        Icon(Icons.group_off, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Tiada Kumpulan Direkodkan', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500)),
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
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            iconColor: const Color(0xFF0F3D87),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F3D87).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.group, color: Color(0xFF0F3D87)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(squad['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                                      const SizedBox(height: 4),
                                      Text('${members.length} Ahli', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Padam Kumpulan'),
                                        content: Text('Adakah anda pasti untuk memadam kumpulan "${squad['name']}"? Semua data ahli dan jadual berkaitan kumpulan ini akan dipadam.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _deleteSquad(squad['id']);
                                            },
                                            child: const Text('Padam', style: TextStyle(color: Colors.white)),
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
                                  color: Colors.grey.shade50,
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                ),
                                child: Column(
                                  children: [
                                    if (members.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(24.0),
                                        child: Text('Belum ada ahli.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                                      )
                                    else
                                      ...members.map((m) => ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                                        leading: const CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.white,
                                          child: Icon(Icons.person, size: 16, color: Colors.grey),
                                        ),
                                        title: Text(m['full_name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                        subtitle: Text(m['ic_number'] ?? '', style: const TextStyle(fontSize: 12)),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Keluarkan Ahli'),
                                                content: Text('Adakah anda pasti untuk mengeluarkan "${m['full_name']}" daripada kumpulan?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _removeMember(squad['id'], m['user_id'].toString());
                                                    },
                                                    child: const Text('Keluarkan', style: TextStyle(color: Colors.white)),
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
                                        label: const Text('Tambah Ahli'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF0F3D87),
                                          side: const BorderSide(color: Color(0xFF0F3D87)),
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
      if (response['success'] == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jadual berjaya ditetap!')));
        _fetchSchedules();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'Ralat menetapkan jadual')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ralat: $e')));
    }
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    try {
      final response = await ApiClient.postData('admin/schedules.php', {
        'action': 'delete_schedule',
        'schedule_id': scheduleId,
      });
      if (response['success'] == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jadual berjaya dipadam!')));
        _fetchSchedules();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'Ralat memadam jadual')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ralat: $e')));
    }
  }

  void _showCreateScheduleDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ralat memuatkan kumpulan: $e')));
      return;
    }

    if (squads.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sila cipta kumpulan terlebih dahulu!')));
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
      backgroundColor: Colors.white,
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
                  const Text('Tetapkan Jadual Rondaan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F3D87))),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    initialValue: selectedSquadId,
                    decoration: InputDecoration(
                      labelText: 'Pilih Kumpulan',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    leading: const Icon(Icons.calendar_today, color: Color(0xFF0F3D87)),
                    title: const Text('Tarikh Rondaan', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    subtitle: Text(
                      "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    trailing: OutlinedButton(
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
                      child: const Text('Pilih'),
                    ),
                  ),
                  const Divider(),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time, color: Color(0xFF0F3D87)),
                    title: const Text('Masa Mula Rondaan', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    subtitle: Text(
                      startTime.format(context),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                        );
                        if (picked != null) {
                          setModalState(() => startTime = picked);
                        }
                      },
                      child: const Text('Pilih'),
                    ),
                  ),
                  const Divider(),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time, color: Colors.redAccent),
                    title: const Text('Masa Tamat Rondaan', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    subtitle: Text(
                      endTime.format(context),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                        );
                        if (picked != null) {
                          setModalState(() => endTime = picked);
                        }
                      },
                      child: const Text('Pilih'),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3D87),
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
                      child: const Text('Simpan Jadual', style: TextStyle(fontWeight: FontWeight.bold)),
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton.icon(
              onPressed: _showCreateScheduleDialog,
              icon: const Icon(Icons.calendar_month),
              label: const Text('Tetapkan Jadual Rondaan'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: const Color(0xFF0F3D87),
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: const Color(0xFF0F3D87).withValues(alpha: 0.4),
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
                        Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Tiada Jadual Rondaan Direkodkan',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500),
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
                      final squadName = schedule['squad_name'] ?? 'Kumpulan Tanpa Nama';
                      final startTime = schedule['start_time'] ?? '';
                      final endTime = schedule['end_time'] ?? '';
                      
                      final displayStart = startTime.length > 5 ? startTime.substring(0, 5) : startTime;
                      final displayEnd = endTime.length > 5 ? endTime.substring(0, 5) : endTime;

                      return Card(
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.05),
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
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
                                child: const Icon(Icons.event_note, color: Color(0xFF0F3D87)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      squadName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(shiftDate, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$displayStart - $displayEnd',
                                          style: const TextStyle(color: Colors.grey, fontSize: 13),
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
                                      title: const Text('Padam Jadual'),
                                      content: Text('Adakah anda pasti untuk memadam jadual rondaan bagi kumpulan "$squadName" pada tarikh $shiftDate?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _deleteSchedule(schedule['id']);
                                          },
                                          child: const Text('Padam', style: TextStyle(color: Colors.white)),
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
