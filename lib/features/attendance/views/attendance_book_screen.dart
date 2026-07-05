import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/pdf_saver.dart';
import '../../auth/models/location_option.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';

class AttendanceBookScreen extends StatefulWidget {
  const AttendanceBookScreen({super.key});

  @override
  State<AttendanceBookScreen> createState() => _AttendanceBookScreenState();
}

class _AttendanceBookScreenState extends State<AttendanceBookScreen> {
  static const List<String> _monthNames = [
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

  DateTime _selectedDate = _todayOnly();
  bool _isLoading = true;
  bool _showPdfView = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];

  final AuthService _authService = AuthService();
  List<LocationOption> _states = const [];
  List<LocationOption> _districts = const [];
  List<LocationOption> _zones = const [];

  LocationOption? _selectedState;
  LocationOption? _selectedDistrict;
  LocationOption? _selectedZone;

  bool _isLoadingFilters = false;
  String? _filterError;
  String? _currentSquadId;
  String? _currentSquadName;

  @override
  void initState() {
    super.initState();
    _initializeFilters();
  }

  Future<void> _initializeFilters() async {
    final auth = context.read<AuthProvider>();
    setState(() => _isLoadingFilters = true);
    try {
      if (auth.role == 'ketua_peronda') {
        await _loadCurrentSquadScope();
      }
      if (auth.role == 'super_admin') {
        final states = await _authService.fetchLocations(level: 'states');
        if (!mounted) return;
        setState(() {
          _states = states;
          _isLoadingFilters = false;
          _filterError = null;
        });
      } else {
        if (auth.districtId != null) {
          final zones = await _authService.fetchLocations(
            level: 'zones',
            parentId: auth.districtId,
          );
          if (!mounted) return;
          final defaultZone = auth.role == 'ketua_peronda'
              ? _locationById(zones, auth.zoneId)
              : null;
          setState(() {
            _zones = zones;
            _selectedZone = defaultZone;
            _isLoadingFilters = false;
            _filterError = null;
          });
        } else {
          setState(() => _isLoadingFilters = false);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingFilters = false;
        _filterError = 'Tidak dapat memuatkan senarai lokasi.';
      });
    }
    await _fetchRecords();
  }

  Future<void> _loadCurrentSquadScope() async {
    try {
      final response = await ApiClient.getData(
        'schedules/get_user_schedule.php',
      );
      if (response['status'] != 'success') return;
      final squad = response['squad'];
      if (squad is! Map) return;
      if (!mounted) return;
      setState(() {
        _currentSquadId = _firstValue(squad, ['id', 'squad_id']);
        _currentSquadName = _firstValue(squad, ['squad_name', 'name']);
      });
    } catch (_) {
      // If the backend already scopes by token, the report can still load.
    }
  }

  LocationOption? _locationById(List<LocationOption> options, String? id) {
    if (id == null || id.trim().isEmpty) return null;
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  Future<void> _selectState(LocationOption? state) async {
    setState(() {
      _selectedState = state;
      _selectedDistrict = null;
      _selectedZone = null;
      _districts = const [];
      _zones = const [];
      _filterError = null;
    });
    if (state != null) {
      try {
        final districts = await _authService.fetchLocations(
          level: 'districts',
          parentId: state.id,
        );
        if (!mounted || _selectedState?.id != state.id) return;
        setState(() => _districts = districts);
      } catch (_) {
        if (!mounted) return;
        setState(() => _filterError = 'Tidak dapat memuatkan daerah.');
      }
    }
  }

  Future<void> _selectDistrict(LocationOption? district) async {
    setState(() {
      _selectedDistrict = district;
      _selectedZone = null;
      _zones = const [];
      _filterError = null;
    });
    if (district != null) {
      try {
        final zones = await _authService.fetchLocations(
          level: 'zones',
          parentId: district.id,
        );
        if (!mounted || _selectedDistrict?.id != district.id) return;
        setState(() => _zones = zones);
      } catch (_) {
        if (!mounted) return;
        setState(() => _filterError = 'Tidak dapat memuatkan zon.');
      }
    }
  }

  Future<void> _selectZone(LocationOption? zone) async {
    setState(() => _selectedZone = zone);
  }

  List<Map<String, dynamic>> _filteredRecords() {
    final auth = context.read<AuthProvider>();
    final isSuperAdmin = auth.role == 'super_admin';
    final isSquadLeader = auth.role == 'ketua_peronda';

    return _records.where((row) {
      if (!isSuperAdmin) {
        if (auth.stateId != null &&
            _firstValue(row, ['state_id']) != auth.stateId) {
          return false;
        }
        if (auth.districtId != null &&
            _firstValue(row, ['district_id']) != auth.districtId) {
          return false;
        }
      } else {
        if (_selectedState != null &&
            _firstValue(row, ['state_id']) != _selectedState!.id) {
          return false;
        }
        if (_selectedDistrict != null &&
            _firstValue(row, ['district_id']) != _selectedDistrict!.id) {
          return false;
        }
      }

      if (_selectedZone != null &&
          _firstValue(row, ['zone_id']) != _selectedZone!.id) {
        return false;
      }
      if (isSquadLeader && !_matchesCurrentSquad(row)) {
        return false;
      }
      return true;
    }).toList();
  }

  bool _matchesCurrentSquad(Map<String, dynamic> row) {
    final rowSquadId = _firstValue(row, [
      'squad_id',
      'assigned_squad_id',
      'patrol_squad_id',
    ]);
    final rowSquadName = _firstValue(row, [
      'squad_name',
      'squad',
      'village_name',
      'kampung_name',
    ]);

    if (rowSquadId == null && rowSquadName == null) {
      return true;
    }
    if (_currentSquadId != null && rowSquadId == _currentSquadId) {
      return true;
    }
    if (_currentSquadName != null && rowSquadName != null) {
      return _normalizeLookup(rowSquadName) ==
          _normalizeLookup(_currentSquadName!);
    }
    return false;
  }

  String get _locationFilterLabel {
    final auth = context.read<AuthProvider>();
    final isSuperAdmin = auth.role == 'super_admin';
    final parts = <String>[];

    if (isSuperAdmin) {
      if (_selectedState != null) parts.add(_selectedState!.name);
      if (_selectedDistrict != null) parts.add(_selectedDistrict!.name);
    } else {
      if (auth.stateName != null) parts.add(auth.stateName!);
      if (auth.districtName != null) parts.add(auth.districtName!);
    }

    if (_selectedZone != null) parts.add(_selectedZone!.name);
    if (auth.role == 'ketua_peronda' &&
        _currentSquadName != null &&
        _currentSquadName!.trim().isNotEmpty) {
      parts.add(_currentSquadName!);
    }

    return parts.isEmpty ? 'Malaysia' : parts.join(' | ');
  }

  static DateTime _todayOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String get _dateLabel {
    final settings = context.read<SettingsProvider>();
    if (settings.isEnglish) {
      return DateFormat('d MMMM yyyy').format(_selectedDate);
    }
    return '${_selectedDate.day} ${_monthNames[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _fetchAttendanceData();
      final enrichedData = await _enrichWithMemberData(data);
      if (!mounted) return;
      setState(() {
        _records = _filterSelectedDate(_dedupeRecords(enrichedData));
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _records = [];
        _isLoading = false;
        _error = error.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceData() async {
    final endpoints = ['attendance/get_logs.php', 'equipment/get_logs.php'];
    Object? lastError;

    for (final endpoint in endpoints) {
      try {
        final response = await ApiClient.getData(endpoint);
        if (response is Map<String, dynamic> &&
            response['status'] == 'success') {
          final rawRows =
              response['data'] ??
              response['logs'] ??
              response['attendance'] ??
              const [];
          if (rawRows is List) {
            return rawRows
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList();
          }
        }
        lastError = response is Map
            ? response['message'] ?? 'Invalid attendance response.'
            : 'Invalid attendance response.';
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception(lastError ?? 'Tidak dapat memuatkan rekod kedatangan.');
  }

  Future<List<Map<String, dynamic>>> _enrichWithMemberData(
    List<Map<String, dynamic>> records,
  ) async {
    try {
      final response = await ApiClient.getData('auth/get_patrollers.php');
      if (response is! Map<String, dynamic> ||
          response['status'] != 'success' ||
          response['data'] is! List) {
        return records;
      }

      final byId = <String, Map<String, dynamic>>{};
      final byName = <String, Map<String, dynamic>>{};
      final byPhone = <String, Map<String, dynamic>>{};

      for (final item in response['data'] as List) {
        if (item is! Map) continue;
        final member = Map<String, dynamic>.from(item);
        final id = _firstValue(member, ['id', 'user_id']);
        final name = _firstValue(member, [
          'full_name',
          'patroller_name',
          'name',
        ]);
        final phone = _firstValue(member, ['phone_number', 'phone']);
        if (id != null) byId[id] = member;
        if (name != null) byName[_normalizeLookup(name)] = member;
        if (phone != null) byPhone[_normalizeLookup(phone)] = member;
      }

      return records.map((record) {
        final enriched = Map<String, dynamic>.from(record);
        final userId = _firstValue(enriched, ['user_id', 'patroller_id']);
        final name = _firstValue(enriched, [
          'patroller_name',
          'full_name',
          'name',
        ]);
        final phone = _firstValue(enriched, ['phone_number', 'phone']);
        final member =
            (userId != null ? byId[userId] : null) ??
            (phone != null ? byPhone[_normalizeLookup(phone)] : null) ??
            (name != null ? byName[_normalizeLookup(name)] : null);

        if (member != null) {
          enriched['ic_number'] ??= _firstValue(member, [
            'ic_number',
            'no_kp',
            'nric',
            'mykad',
          ]);
          enriched['patroller_name'] ??= _firstValue(member, [
            'full_name',
            'patroller_name',
            'name',
          ]);
          enriched['phone_number'] ??= _firstValue(member, [
            'phone_number',
            'phone',
          ]);
          enriched['state_id'] ??= member['state_id'];
          enriched['district_id'] ??= member['district_id'];
          enriched['zone_id'] ??= member['zone_id'];
          enriched['state_name'] ??= member['state_name'];
          enriched['district_name'] ??= member['district_name'];
          enriched['zone_name'] ??= member['zone_name'];
          enriched['squad_id'] ??= member['squad_id'];
          enriched['squad_name'] ??= member['squad_name'];
        }
        return enriched;
      }).toList();
    } catch (_) {
      return records;
    }
  }

  List<Map<String, dynamic>> _dedupeRecords(List<Map<String, dynamic>> rows) {
    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];

    for (final row in rows) {
      final key =
          _firstValue(row, ['attendance_id', 'id']) ??
          '${_firstValue(row, ['patroller_name', 'full_name', 'name'])}-${_firstValue(row, ['clock_in_time', 'created_at', 'borrowed_at'])}';
      if (seen.add(key)) deduped.add(row);
    }

    deduped.sort((a, b) {
      final aDate = _clockInDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = _clockInDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });
    return deduped;
  }

  List<Map<String, dynamic>> _filterSelectedDate(
    List<Map<String, dynamic>> rows,
  ) {
    return rows.where((row) {
      final date = _clockInDate(row);
      return date != null &&
          date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;
    }).toList();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? _todayOnly() : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: _todayOnly(),
    );

    if (picked == null) return;
    setState(
      () => _selectedDate = DateTime(picked.year, picked.month, picked.day),
    );
    await _fetchRecords();
  }

  Future<pw.Document> _buildAttendanceBookPdf() async {
    final pdf = pw.Document();
    final displayRows = List<Map<String, dynamic>>.from(_filteredRecords());
    while (displayRows.length < 6) {
      displayRows.add(const {});
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(24, 18, 24, 24),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'BUKU REKOD KEDATANGAN SRS',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              _locationFilterLabel,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 14),
          _buildPdfTable(displayRows),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildPdfTable(List<Map<String, dynamic>> rows) {
    const border = pw.TableBorder(
      top: pw.BorderSide(width: 0.6),
      bottom: pw.BorderSide(width: 0.6),
      left: pw.BorderSide(width: 0.6),
      right: pw.BorderSide(width: 0.6),
      horizontalInside: pw.BorderSide(width: 0.45),
      verticalInside: pw.BorderSide(width: 0.45),
    );

    return pw.Table(
      border: border,
      columnWidths: const {
        0: pw.FlexColumnWidth(1.05),
        1: pw.FlexColumnWidth(0.95),
        2: pw.FlexColumnWidth(1.9),
        3: pw.FlexColumnWidth(1.35),
        4: pw.FlexColumnWidth(1.05),
        5: pw.FlexColumnWidth(1.0),
        6: pw.FlexColumnWidth(1.05),
        7: pw.FlexColumnWidth(1.0),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey400),
          children: [
            _pdfHeaderCell('TARIKH'),
            _pdfHeaderCell('MASA\nBERTUGAS\nSYIF'),
            _pdfHeaderCell('NAMA'),
            _pdfHeaderCell('NO. KP'),
            _pdfHeaderCell('NO. SIRI\nKAD KENAL\nDIRI'),
            _pdfHeaderCell('T/TGN'),
            _pdfHeaderCell('MASA\nTAMAT SYIF'),
            _pdfHeaderCell('T/TGN'),
          ],
        ),
        ...rows.map((row) => _pdfDataRow(row)),
      ],
    );
  }

  pw.TableRow _pdfDataRow(Map<String, dynamic> row) {
    return pw.TableRow(
      children: [
        _pdfDataCell(_formatDate(_clockInDate(row) ?? _selectedDate)),
        _pdfDataCell(_formatTime(_clockInDate(row))),
        _pdfDataCell(
          _firstValue(row, ['patroller_name', 'full_name', 'name']) ?? '',
        ),
        _pdfDataCell(
          _firstValue(row, ['ic_number', 'no_kp', 'nric', 'mykad']) ?? '',
        ),
        _pdfDataCell(
          _firstValue(row, [
                'id_card_serial',
                'serial_no',
                'no_siri_kad_kenal_diri',
              ]) ??
              '',
        ),
        _pdfDataCell(''),
        _pdfDataCell(_formatTime(_clockOutDate(row))),
        _pdfDataCell(''),
      ],
    );
  }

  pw.Widget _pdfHeaderCell(String text) {
    return pw.Container(
      height: 42,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _pdfDataCell(String text) {
    return pw.Container(
      height: 36,
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
        style: const pw.TextStyle(fontSize: 7.5),
      ),
    );
  }

  DateTime? _clockInDate(Map<String, dynamic> row) {
    return _parseDate(
      _firstValue(row, [
        'clock_in_time',
        'created_at',
        'borrowed_at',
        'start_time',
        'started_at',
      ]),
    );
  }

  DateTime? _clockOutDate(Map<String, dynamic> row) {
    return _parseDate(
      _firstValue(row, [
        'clock_out_time',
        'returned_at',
        'return_acknowledged_at',
        'return_requested_at',
        'end_time',
        'ended_at',
      ]),
    );
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw == 'null') return null;
    return DateTime.tryParse(raw);
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    return DateFormat('dd/MM/yyyy').format(value);
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '';
    return DateFormat('hh:mm a').format(value);
  }

  String? _firstValue(Map<dynamic, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return null;
  }

  String _normalizeLookup(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Widget _buildRecordTable(ThemeData theme) {
    final settings = context.read<SettingsProvider>();
    final rows = _filteredRecords();
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _records.isEmpty
                ? '${settings.t("Tiada rekod kedatangan untuk")} $_dateLabel.'
                : settings.t(
                    'Tiada rekod kedatangan padan dengan penapis lokasi dipilih.',
                  ),
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.disabledColor),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              theme.primaryColor.withValues(alpha: 0.08),
            ),
            columns: [
              DataColumn(label: Text(settings.t('Tarikh'))),
              DataColumn(label: Text(settings.t('Masa Bertugas'))),
              DataColumn(label: Text(settings.t('Nama'))),
              DataColumn(label: Text(settings.t('No. KP'))),
              DataColumn(label: Text(settings.t('Masa Tamat'))),
            ],
            rows: rows.map((row) {
              return DataRow(
                cells: [
                  DataCell(Text(_formatDate(_clockInDate(row)))),
                  DataCell(Text(_formatTime(_clockInDate(row)))),
                  DataCell(
                    Text(
                      _firstValue(row, [
                            'patroller_name',
                            'full_name',
                            'name',
                          ]) ??
                          '-',
                    ),
                  ),
                  DataCell(
                    Text(
                      _firstValue(row, [
                            'ic_number',
                            'no_kp',
                            'nric',
                            'mykad',
                          ]) ??
                          '-',
                    ),
                  ),
                  DataCell(Text(_formatTime(_clockOutDate(row)))),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationFilters(SettingsProvider settings, ThemeData theme) {
    final auth = context.watch<AuthProvider>();
    final isSuperAdmin = auth.role == 'super_admin';
    final isSquadLeader = auth.role == 'ketua_peronda';

    Widget dropdown({
      required String label,
      required LocationOption? value,
      required List<LocationOption> items,
      required String allLabel,
      required ValueChanged<LocationOption?> onChanged,
      bool enabled = true,
    }) {
      return DropdownButtonFormField<LocationOption?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        items: [
          DropdownMenuItem<LocationOption?>(
            value: null,
            child: Text(allLabel, overflow: TextOverflow.ellipsis),
          ),
          ...items.map(
            (item) => DropdownMenuItem<LocationOption?>(
              value: item,
              child: Text(item.name, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: enabled ? onChanged : null,
      );
    }

    if (!isSuperAdmin) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        color: theme.cardColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${settings.t("Negeri")}: ${auth.stateName ?? "-"}  |  ${settings.t("Daerah")}: ${auth.districtName ?? "-"}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            dropdown(
              label: settings.t('Zon'),
              value: _selectedZone,
              items: _zones,
              allLabel: settings.t('Semua Zon'),
              onChanged: _selectZone,
            ),
          ],
        ),
      );
    }

    if (isSquadLeader) {
      final squadLabel =
          (_currentSquadName != null && _currentSquadName!.trim().isNotEmpty)
          ? _currentSquadName!
          : settings.t('Skuad belum ditetapkan');
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        color: theme.cardColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${settings.t("Negeri")}: ${auth.stateName ?? "-"}  |  ${settings.t("Daerah")}: ${auth.districtName ?? "-"}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${settings.t("Zon")}: ${_selectedZone?.name ?? auth.zoneName ?? "-"}',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.75,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${settings.t("Skuad/Kampung")}: $squadLabel',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              settings.t('Paparan dihadkan kepada skuad rondaan anda.'),
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withValues(
                  alpha: 0.68,
                ),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: theme.cardColor,
      child: Column(
        children: [
          if (_isLoadingFilters)
            LinearProgressIndicator(color: theme.primaryColor),
          if (_filterError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _filterError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 680;
              final children = [
                dropdown(
                  label: settings.t('Negeri'),
                  value: _selectedState,
                  items: _states,
                  allLabel: settings.t('Semua Negeri'),
                  onChanged: _selectState,
                ),
                dropdown(
                  label: settings.t('Daerah'),
                  value: _selectedDistrict,
                  items: _districts,
                  allLabel: settings.t('Semua Daerah'),
                  enabled: _selectedState != null,
                  onChanged: _selectDistrict,
                ),
                dropdown(
                  label: settings.t('Zon'),
                  value: _selectedZone,
                  items: _zones,
                  allLabel: settings.t('Semua Zon'),
                  enabled: _selectedDistrict != null,
                  onChanged: _selectZone,
                ),
              ];

              if (!isWide) {
                return Column(
                  children: [
                    for (final child in children) ...[
                      child,
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    Expanded(child: children[i]),
                    if (i != children.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final fileName =
        'buku_rekod_kedatangan_srs_${DateFormat('yyyy_MM_dd').format(_selectedDate)}.pdf';

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('Buku Rekod Kedatangan SRS')),
        elevation: 0,
        actions: [
          if (!_isLoading && _error == null)
            IconButton(
              icon: Icon(
                _showPdfView ? Icons.table_chart : Icons.picture_as_pdf,
              ),
              tooltip: _showPdfView
                  ? settings.t('Tunjuk Jadual Data')
                  : settings.t('Tunjuk PDF Laporan'),
              onPressed: () => setState(() => _showPdfView = !_showPdfView),
            ),
          IconButton(
            tooltip: settings.t('Cuba Lagi'),
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRecords,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.cardColor,
            child: InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.15),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: theme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${settings.t("Tarikh Laporan")}: $_dateLabel',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
          _buildLocationFilters(settings, theme),
          if (_records.isEmpty && !_isLoading && _error == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                '${settings.t("PDF masih boleh dijana sebagai borang kosong untuk")} $_dateLabel.',
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.7,
                  ),
                  fontSize: 12,
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: theme.primaryColor),
                  )
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 42,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _fetchRecords,
                            icon: const Icon(Icons.refresh),
                            label: Text(settings.t('Cuba Lagi')),
                          ),
                        ],
                      ),
                    ),
                  )
                : _showPdfView
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      elevation: 4,
                      clipBehavior: Clip.antiAlias,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: PdfPreview(
                        key: ValueKey(
                          '${_selectedDate.toIso8601String()}_${_selectedState?.id}_${_selectedDistrict?.id}_${_selectedZone?.id}',
                        ),
                        build: (format) async {
                          final doc = await _buildAttendanceBookPdf();
                          return doc.save();
                        },
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                        pdfFileName: fileName,
                        actions: [
                          PdfPreviewAction(
                            icon: Tooltip(
                              message: settings.t('Muat Turun PDF'),
                              child: const Icon(Icons.download),
                            ),
                            onPressed: (context, build, pageFormat) async {
                              final bytes = await build(pageFormat);
                              if (context.mounted) {
                                await savePdf(context, bytes, fileName);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildRecordTable(theme),
          ),
        ],
      ),
    );
  }
}
