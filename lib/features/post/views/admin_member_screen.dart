import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/constants/api_constants.dart';

class AdminMemberScreen extends StatefulWidget {
  const AdminMemberScreen({super.key});

  @override
  State<AdminMemberScreen> createState() => _AdminMemberScreenState();
}

class _AdminMemberScreenState extends State<AdminMemberScreen> {
  List<dynamic> _patrollers = [];
  String _searchQuery = '';
  String _selectedZone = 'Semua Zon';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPatrollers();
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
        Uri.parse('${ApiConstants.baseUrl}auth/get_patrollers.php'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _patrollers = data['data'];
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

  Widget _buildStatusChip(String status, SettingsProvider settings) {
    Color bgColor;
    Color textColor;
    String text;

    if (status == 'active' || status == 'approved') {
      bgColor = Colors.green.withValues(alpha: 0.15);
      textColor = Colors.green.shade800;
      text = settings.t('Aktif');
    } else if (status == 'pending') {
      bgColor = Colors.orange.withValues(alpha: 0.15);
      textColor = Colors.orange.shade800;
      text = settings.t('Menunggu');
    } else {
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

  void _showStatusBottomSheet(BuildContext context, Map<String, dynamic> patroller, SettingsProvider settings) {
    String selectedStatus = patroller['account_status'] ?? 'pending';

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
                    '${settings.t('Tukar Status')}: ${patroller['full_name']}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment<String>(
                        value: 'active',
                        label: Text(settings.t('Aktif')),
                        icon: const Icon(Icons.check_circle_outline),
                      ),
                      ButtonSegment<String>(
                        value: 'pending',
                        label: Text(settings.t('Menunggu')),
                        icon: const Icon(Icons.hourglass_empty),
                      ),
                      ButtonSegment<String>(
                        value: 'inactive',
                        label: Text(settings.t('Nyahaktif')),
                        icon: const Icon(Icons.block),
                      ),
                    ],
                    selected: {selectedStatus},
                    onSelectionChanged: (Set<String> newSelection) {
                      setModalState(() {
                        selectedStatus = newSelection.first;
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
                            _updateUserStatus(patroller['id'], selectedStatus);
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

  void _showRoleBottomSheet(BuildContext context, Map<String, dynamic> patroller, SettingsProvider settings) {
    String selectedRole = patroller['role'] ?? 'peronda';

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
                    '${settings.t('Tukar Peranan')}: ${patroller['full_name']}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            _updateUserRole(patroller['id'], selectedRole);
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

  Future<void> _updateUserStatus(String userId, String status) async {
    setState(() => _isLoading = true);
    final settings = context.read<SettingsProvider>();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final Map<String, String> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}admin/update_user.php'),
        headers: headers,
        body: {
          'action': 'update_status',
          'user_id': userId,
          'account_status': status,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(settings.t('Kemas kini berjaya')),
              backgroundColor: Colors.green,
            ),
          );
          _fetchPatrollers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? settings.t('Kemas kini gagal')),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() => _isLoading = false);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${settings.t('Ralat Pelayan')}: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.t('Ralat Rangkaian')}: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserRole(String userId, String role) async {
    setState(() => _isLoading = true);
    final settings = context.read<SettingsProvider>();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final Map<String, String> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}admin/update_user.php'),
        headers: headers,
        body: {
          'action': 'promote_role',
          'user_id': userId,
          'role': role,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(settings.t('Kemas kini berjaya')),
              backgroundColor: Colors.green,
            ),
          );
          _fetchPatrollers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? settings.t('Kemas kini gagal')),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() => _isLoading = false);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${settings.t('Ralat Pelayan')}: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.t('Ralat Rangkaian')}: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)));
    }

    if (_patrollers.isEmpty) {
      return Center(child: Text(settings.t('Tiada peronda dijumpai.'), style: const TextStyle(color: Colors.white70)));
    }

    // Extract unique zones for the dropdown
    final Set<String> zones = {'Semua Zon'};
    for (var p in _patrollers) {
      if (p['district_zone'] != null && p['district_zone'].toString().isNotEmpty) {
        zones.add(p['district_zone']);
      }
    }

    // Apply filtering
    final filteredPatrollers = _patrollers.where((p) {
      final matchesSearch = p['full_name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesZone = _selectedZone == 'Semua Zon' || p['district_zone'] == _selectedZone;
      return matchesSearch && matchesZone;
    }).toList();

    return Column(
      children: [
        // Search and Filter Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: settings.t('Cari nama peronda...'),
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedZone,
                      dropdownColor: Theme.of(context).cardColor,
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.w500),
                      icon: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).primaryColor),
                      isExpanded: true,
                      items: zones.map((zone) => DropdownMenuItem(
                        value: zone,
                        child: Text(zone == 'Semua Zon' ? settings.t(zone) : zone, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (value) {
                        setState(() => _selectedZone = value!);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // List of filtered patrollers
        Expanded(
          child: filteredPatrollers.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Theme.of(context).disabledColor.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      settings.t('Tiada padanan carian.'),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      settings.t('Cuba cari dengan e-mel atau no. kad pengenalan lain.'),
                      style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.4)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredPatrollers.length,
                itemBuilder: (context, index) {
                  final patroller = filteredPatrollers[index];
                  final status = patroller['account_status'] ?? 'pending';
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Circle with status indicator dot
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                child: Text(
                                  patroller['full_name'].toString().isNotEmpty
                                      ? patroller['full_name'].toString()[0].toUpperCase()
                                      : 'P',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
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
                                    color: status == 'active' || status == 'approved'
                                        ? Colors.green
                                        : status == 'pending'
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
                                  patroller['full_name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Chips
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _buildRoleChip(patroller['role'] ?? 'peronda', settings),
                                    _buildStatusChip(status, settings),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Information Row Details
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${settings.t('Zon')}: ${patroller['district_zone'] ?? settings.t('Tiada')}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.badge_outlined, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      'IC: ${patroller['ic_number']}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.phone_outlined, size: 14, color: Theme.of(context).primaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      patroller['phone_number'] ?? '-',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Trailing Action Menu
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                            onSelected: (value) {
                              if (value == 'status') {
                                _showStatusBottomSheet(context, patroller, settings);
                              } else if (value == 'role') {
                                _showRoleBottomSheet(context, patroller, settings);
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'status',
                                child: Row(
                                  children: [
                                    Icon(Icons.shield_outlined, size: 18, color: Theme.of(context).primaryColor),
                                    const SizedBox(width: 8),
                                    Text(settings.t('Tukar Status')),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'role',
                                child: Row(
                                  children: [
                                    Icon(Icons.admin_panel_settings_outlined, size: 18, color: Theme.of(context).primaryColor),
                                    const SizedBox(width: 8),
                                    Text(settings.t('Tukar Peranan')),
                                  ],
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
        ),
      ],
    );
  }
}
