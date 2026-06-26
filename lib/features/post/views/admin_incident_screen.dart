import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../incident/views/incident_screen.dart';

class AdminIncidentScreen extends StatefulWidget {
  final ValueChanged<bool>? onSubViewChanged;
  const AdminIncidentScreen({super.key, this.onSubViewChanged});

  @override
  State<AdminIncidentScreen> createState() => _AdminIncidentScreenState();
}

class _AdminIncidentScreenState extends State<AdminIncidentScreen> {
  List<dynamic> _patrollers = [];
  String _searchQuery = '';
  String _selectedZone = 'Semua Zon';
  String _selectedSortPriority = 'Default';
  bool _isLoading = true;
  String? _error;
  String? _selectedPatrollerId;

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
        Uri.parse(ApiConstants.buildApiUrl('auth/get_patrollers.php')),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final List<dynamic> patrollerList = List.from(data['data'] ?? []);

          // Fetch incidents to calculate note counts
          try {
            final incidentsResponse = await http.get(
              Uri.parse(ApiConstants.buildApiUrl('incidents/fetch_incidents.php?page=1&limit=9999')),
              headers: headers,
            );
            if (incidentsResponse.statusCode == 200) {
              final incidentsData = json.decode(incidentsResponse.body);
              final List<dynamic> incidentsList = incidentsData['data'] ?? [];
              final Map<String, int> noteCounts = {};
              for (var incident in incidentsList) {
                final status = incident['status']?.toString() ?? '';
                if (status.toLowerCase() == 'submitted') {
                  final userId = incident['user_id']?.toString();
                  if (userId != null) {
                    noteCounts[userId] = (noteCounts[userId] ?? 0) + 1;
                  }
                }
              }
              for (var patroller in patrollerList) {
                final String patrollerId = patroller['id']?.toString() ?? '';
                patroller['note_count'] = noteCounts[patrollerId] ?? 0;
              }
            }
          } catch (e) {
            debugPrint("Error fetching incidents for count: $e");
          }

          setState(() {
            _patrollers = patrollerList;
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

  void _showFilterBottomSheet(Set<String> zones) {
    final settings = context.read<SettingsProvider>();
    final theme = Theme.of(context);
    String tempZone = _selectedZone;
    String tempSortPriority = _selectedSortPriority;

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
                        settings.t("Tapis Laporan Insiden"),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    settings.t("Zon Rondaan"),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: zones.map((String zone) {
                      return DropdownMenuItem(
                        value: zone,
                        child: Text(zone == 'Semua Zon' ? settings.t(zone) : zone),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => tempZone = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    settings.t("Susunan Prioriti"),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: tempSortPriority,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.dividerColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'Default',
                        child: Text(settings.t('Abjad (Default)')),
                      ),
                      DropdownMenuItem(
                        value: 'Paling Banyak Nota',
                        child: Text(settings.t('Paling Banyak Nota')),
                      ),
                      DropdownMenuItem(
                        value: 'Tiada Nota',
                        child: Text(settings.t('Tiada Nota')),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => tempSortPriority = val);
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
                              _selectedZone = 'Semua Zon';
                              _selectedSortPriority = 'Default';
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
                              _selectedZone = tempZone;
                              _selectedSortPriority = tempSortPriority;
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    if (_selectedPatrollerId != null) {
      return IncidentScreen(
        patrollerIdFilter: _selectedPatrollerId,
        onClose: () {
          widget.onSubViewChanged?.call(false);
          setState(() => _selectedPatrollerId = null);
        },
      );
    }

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

    if (_selectedSortPriority == 'Paling Banyak Nota') {
      filteredPatrollers.sort((a, b) {
        final int countA = a['note_count'] ?? 0;
        final int countB = b['note_count'] ?? 0;
        return countB.compareTo(countA);
      });
    } else if (_selectedSortPriority == 'Tiada Nota') {
      filteredPatrollers.sort((a, b) {
        final int countA = a['note_count'] ?? 0;
        final int countB = b['note_count'] ?? 0;
        if (countA == 0 && countB != 0) return -1;
        if (countB == 0 && countA != 0) return 1;
        return countB.compareTo(countA);
      });
    } else {
      filteredPatrollers.sort((a, b) => a['full_name'].toString().compareTo(b['full_name'].toString()));
    }

    final bool isFilterActive = _selectedZone != 'Semua Zon' || _selectedSortPriority != 'Default';
    final theme = Theme.of(context);

    return Column(
      children: [
        // Search and Filter Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: settings.t('Cari nama peronda...'),
                    hintStyle: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5)),
                    prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                    filled: true,
                    fillColor: theme.cardColor,
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
                      borderSide: BorderSide(color: theme.primaryColor, width: 2),
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
                      backgroundColor: isFilterActive ? theme.primaryColor : theme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isFilterActive ? Colors.transparent : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed: () => _showFilterBottomSheet(zones),
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (patroller['note_count'] ?? 0) == 0
                                  ? Colors.redAccent.withValues(alpha: 0.15)
                                  : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${patroller['note_count'] ?? 0} ${settings.t('Nota')}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: (patroller['note_count'] ?? 0) == 0
                                    ? Colors.redAccent
                                    : Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_ios, color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6), size: 16),
                        ],
                      ),
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
                          widget.onSubViewChanged?.call(true);
                          setState(() {
                            _selectedPatrollerId = patroller['id'];
                          });
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
