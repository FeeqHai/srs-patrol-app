import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../incident/views/incident_screen.dart';

class AdminIncidentScreen extends StatefulWidget {
  const AdminIncidentScreen({super.key});

  @override
  State<AdminIncidentScreen> createState() => _AdminIncidentScreenState();
}

class _AdminIncidentScreenState extends State<AdminIncidentScreen> {
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
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0F3D87),
                        child: Icon(Icons.folder_shared, color: Colors.white),
                      ),
                      title: Text(patroller['full_name'], style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                      subtitle: Text('${settings.t('Zon')}: ${patroller['district_zone'] ?? settings.t('Tiada')} | IC: ${patroller['ic_number']}', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6))),
                      trailing: Icon(Icons.arrow_forward_ios, color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6), size: 16),
                      onTap: () {
                        if (MediaQuery.of(context).size.width > 600) {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.all(40),
                              child: Container(
                                width: 800,
                                height: 700,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: IncidentScreen(
                                  patrollerIdFilter: patroller['id'],
                                ),
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => IncidentScreen(
                            patrollerIdFilter: patroller['id'],
                          )));
                        }
                      },
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
}
