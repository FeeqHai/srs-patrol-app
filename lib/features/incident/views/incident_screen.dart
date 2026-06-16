// File: lib/features/incident/views/incident_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'incident_report_screen.dart';
import 'incident_detail_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/logger.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';

class IncidentScreen extends StatefulWidget {
  final String? patrollerIdFilter;

  const IncidentScreen({super.key, this.patrollerIdFilter});

  @override
  State<IncidentScreen> createState() => _IncidentScreenState();
}

class _IncidentScreenState extends State<IncidentScreen> {
  final List<dynamic> _incidents = [];
  int _page = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  
  String _selectedFilter = 'Semua';
  DateTimeRange? _selectedDateRange;
  final List<String> _filterOptions = [
    'Semua',
    'Jenayah Kekerasan',
    'Jenayah Harta Benda',
    'Jenayah Narkotik',
    'Gejala Sosial',
    'Lain-lain',
  ];

  @override
  void initState() {
    super.initState();
    _fetchIncidents();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _fetchIncidents();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchIncidents() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      String url =
          '${ApiConstants.baseUrl}incidents/fetch_incidents.php?page=$_page&limit=10';

      // --- ROW-LEVEL SECURITY ---
      // Determine which user_id to filter by:
      //   1. If an explicit patrollerIdFilter was passed (admin viewing a specific patroller), use it.
      //   2. Otherwise, if the logged-in user is a regular patroller, auto-filter to their own data.
      //   3. Admin / Ketua roles see everything (no filter).
      final authProvider = context.read<AuthProvider>();
      final String? effectiveFilter;
      if (widget.patrollerIdFilter != null) {
        effectiveFilter = widget.patrollerIdFilter;
      } else if (authProvider.role == 'peronda' || authProvider.role == 'ketua_peronda') {
        effectiveFilter = authProvider.userId;
      } else {
        effectiveFilter = null; // ketua_krt sees all
      }

      if (effectiveFilter != null) {
        url += '&user_id=$effectiveFilter';
      }
      if (_selectedFilter != 'Semua') {
        url += '&category=${Uri.encodeComponent(_selectedFilter)}';
      }
      if (_selectedDateRange != null) {
        final startStr = '${_selectedDateRange!.start.year}-${_selectedDateRange!.start.month.toString().padLeft(2, '0')}-${_selectedDateRange!.start.day.toString().padLeft(2, '0')}';
        final endStr = '${_selectedDateRange!.end.year}-${_selectedDateRange!.end.month.toString().padLeft(2, '0')}-${_selectedDateRange!.end.day.toString().padLeft(2, '0')}';
        url += '&start_date=$startStr&end_date=$endStr';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> newIncidents = body['data'];

        setState(() {
          _page++;
          _isLoading = false;
          if (newIncidents.length < 10) {
            _hasMore = false;
          }
          _incidents.addAll(newIncidents);
        });
      } else {
        throw Exception('Failed to load incidents: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      // DIRECTIVE E: EXCEPTION UNMASKING
      appLogger.e("=== CRITICAL NETWORK EXCEPTION ===\nException: $e\nTarget URI: ${ApiConstants.baseUrl}incidents/fetch_incidents.php\n==================================", error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ralat rangkaian: $e',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _page = 1;
      _incidents.clear();
      _hasMore = true;
    });
    await _fetchIncidents();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.patrollerIdFilter != null
          ? AppBar(
              title: Text(settings.t('Rekod Insiden')),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Tutup',
              ),
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedFilter,
                    decoration: InputDecoration(
                      labelText: settings.t('Tapis Kategori'),
                      prefixIcon: const Icon(Icons.filter_list),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: _filterOptions.map((String option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null && newValue != _selectedFilter) {
                        setState(() {
                          _selectedFilter = newValue;
                        });
                        _refresh();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: InkWell(
                    onTap: () async {
                      final List<DateTime?>? results = await showCalendarDatePicker2Dialog(
                        context: context,
                        config: CalendarDatePicker2WithActionButtonsConfig(
                          calendarType: CalendarDatePicker2Type.range,
                          selectedDayHighlightColor: theme.primaryColor,
                          weekdayLabelTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                          controlsTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          centerAlignModePicker: true,
                          customModePickerIcon: const SizedBox(),
                        ),
                        dialogSize: const Size(340, 420),
                        value: [
                          _selectedDateRange?.start,
                          _selectedDateRange?.end,
                        ],
                        borderRadius: BorderRadius.circular(20),
                      );

                      if (results != null && results.isNotEmpty) {
                        setState(() {
                          if (results.length == 1 && results[0] != null) {
                            _selectedDateRange = DateTimeRange(start: results[0]!, end: results[0]!);
                          } else if (results.length >= 2 && results[0] != null && results[1] != null) {
                            _selectedDateRange = DateTimeRange(start: results[0]!, end: results[1]!);
                          }
                        });
                        _refresh();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: _selectedDateRange != null ? theme.primaryColor : Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                        color: _selectedDateRange != null ? theme.primaryColor.withValues(alpha: 0.1) : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month,
                            size: 20,
                            color: _selectedDateRange != null ? theme.primaryColor : Colors.grey,
                          ),
                          if (_selectedDateRange != null) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDateRange = null;
                                });
                                _refresh();
                              },
                              child: const Icon(Icons.close, size: 16, color: Colors.red),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: theme.primaryColor,
              child: _incidents.isEmpty && _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: theme.primaryColor),
                    )
                  : _incidents.isEmpty && !_isLoading
                  ? ListView(
                      children: [
                        const SizedBox(height: 250),
                        Center(
                          child: Text(
                            settings.t("Tiada insiden direkodkan."),
                            style: TextStyle(color: theme.textTheme.bodySmall?.color),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 10, bottom: 80),
                      itemCount: _incidents.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _incidents.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.redAccent,
                              ),
                            ),
                          );
                        }
                        return _buildIncidentCard(_incidents[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: widget.patrollerIdFilter == null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 70.0), // Underneath SOS button, but above nav bar
              child: FloatingActionButton.extended(
                backgroundColor: theme.primaryColor,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const IncidentReportScreen(),
                    ),
                  );
                  await _refresh(); // Fix: Refresh list upon return
                },
                icon: const Icon(Icons.edit_document, color: Colors.white),
                label: Text(
                  settings.t("LAPOR INSIDEN"),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> data) {
    String? imageUrl;
    if (data['image_url'] != null && data['image_url'].toString().isNotEmpty) {
      try {
        if (data['image_url'].toString().trim().startsWith('[')) {
          List<dynamic> parsed = json.decode(data['image_url']);
          if (parsed.isNotEmpty) imageUrl = parsed.first.toString();
        } else {
          imageUrl = data['image_url'];
        }
      } catch (e) {
        imageUrl = data['image_url'];
      }
    }

    return InkWell(
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
                child: IncidentDetailScreen(incident: data),
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IncidentDetailScreen(incident: data),
            ),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null)
                  Container(
                    width: 110,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        bottomLeft: Radius.circular(15),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        bottomLeft: Radius.circular(15),
                      ),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.broken_image,
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  (data['category'] ?? "UMUM").toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (data['created_at'] != null)
                              Text(
                                () {
                                  try {
                                    final dt = DateTime.parse(data['created_at'].toString());
                                    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                  } catch (_) {
                                    return data['created_at'].toString();
                                  }
                                }(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['title'] ?? context.read<SettingsProvider>().t("Tiada Tajuk"),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Theme.of(context).textTheme.titleMedium?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['description'] ?? "",
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
