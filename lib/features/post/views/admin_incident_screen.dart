import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)));
    }

    if (_patrollers.isEmpty) {
      return const Center(child: Text('Tiada peronda dijumpai.', style: TextStyle(color: Colors.white70)));
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
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Cari nama peronda...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.indigoAccent),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedZone,
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white),
                      icon: const Icon(Icons.filter_list, color: Colors.indigoAccent),
                      isExpanded: true,
                      items: zones.map((zone) => DropdownMenuItem(
                        value: zone,
                        child: Text(zone, overflow: TextOverflow.ellipsis),
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
            ? const Center(child: Text('Tiada padanan carian.', style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredPatrollers.length,
                itemBuilder: (context, index) {
                  final patroller = filteredPatrollers[index];
                  return Card(
                    color: const Color(0xFF1E1E1E),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.indigoAccent,
                        child: Icon(Icons.folder_shared, color: Colors.white),
                      ),
                      title: Text(patroller['full_name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      subtitle: Text('Zon: ${patroller['district_zone'] ?? 'Tiada'} | IC: ${patroller['ic_number']}', style: const TextStyle(color: Colors.white54)),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => IncidentScreen(
                          patrollerIdFilter: patroller['id'],
                          patrollerNameFilter: patroller['full_name'],
                        )));
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
