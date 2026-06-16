import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}auth/get_patrollers.php'));
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
                    hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.5)),
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedZone,
                      dropdownColor: Theme.of(context).cardColor,
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      icon: Icon(Icons.filter_list, color: Theme.of(context).primaryColor),
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
            ? Center(child: Text(settings.t('Tiada padanan carian.'), style: const TextStyle(color: Colors.white54)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredPatrollers.length,
                itemBuilder: (context, index) {
                  final patroller = filteredPatrollers[index];
                  final isActive = patroller['account_status'] == 'approved' || patroller['account_status'] == 'active';
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: isActive ? Colors.green.shade600 : Colors.orange.shade600,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(patroller['full_name'], style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('${settings.t('Zon')}: ${patroller['district_zone'] ?? settings.t('Tiada')} | IC: ${patroller['ic_number']}', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6))),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.phone, size: 14, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 4),
                              Text(patroller['phone_number'] ?? '-', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.8))),
                            ],
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6)),
                        onSelected: (value) {
                          if (value == 'edit') {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t('Ciri kemas kini akan datang'))));
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit, size: 18),
                                const SizedBox(width: 8),
                                Text(settings.t('Kemas Kini')),
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
    );
  }
}
