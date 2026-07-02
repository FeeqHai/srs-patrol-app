import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/pdf_saver.dart';

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

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = true;
  bool _showPdfView = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  String get _monthLabel =>
      '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

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
        _records = _filterSelectedMonth(_dedupeRecords(enrichedData));
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

  List<Map<String, dynamic>> _filterSelectedMonth(
    List<Map<String, dynamic>> rows,
  ) {
    return rows.where((row) {
      final date = _clockInDate(row);
      return date != null &&
          date.year == _selectedMonth.year &&
          date.month == _selectedMonth.month;
    }).toList();
  }

  Future<void> _selectMonth() async {
    final now = DateTime.now();
    var selectedYear = _selectedMonth.year;
    var selectedMonth = _selectedMonth.month;

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pilih Bulan dan Tahun'),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedYear,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tahun'),
                  items: List.generate(now.year - 2020 + 1, (index) {
                    final year = now.year - index;
                    return DropdownMenuItem(
                      value: year,
                      child: Text('$year', overflow: TextOverflow.ellipsis),
                    );
                  }),
                  onChanged: (year) {
                    if (year == null) return;
                    setDialogState(() {
                      selectedYear = year;
                      if (selectedYear == now.year &&
                          selectedMonth > now.month) {
                        selectedMonth = now.month;
                      }
                    });
                  },
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.8,
                  children: List.generate(12, (index) {
                    final month = index + 1;
                    final isFuture =
                        selectedYear == now.year && month > now.month;
                    final isSelected = month == selectedMonth;
                    return FilledButton(
                      onPressed: isFuture
                          ? null
                          : () => Navigator.pop(
                              dialogContext,
                              DateTime(selectedYear, month),
                            ),
                      style: FilledButton.styleFrom(
                        backgroundColor: isSelected
                            ? Theme.of(context).primaryColor
                            : Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.08),
                        foregroundColor: isSelected
                            ? Colors.white
                            : Theme.of(context).textTheme.bodyLarge?.color,
                        disabledBackgroundColor: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.04),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: Text(
                        _monthNames[index].substring(0, 3),
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );

    if (picked == null) return;
    setState(() => _selectedMonth = DateTime(picked.year, picked.month));
    await _fetchRecords();
  }

  Future<pw.Document> _buildAttendanceBookPdf() async {
    final pdf = pw.Document();
    final displayRows = List<Map<String, dynamic>>.from(_records);
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
        _pdfDataCell(_formatDate(_clockInDate(row))),
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

  String? _firstValue(Map<String, dynamic> row, List<String> keys) {
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
    final rows = _records;
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'Tiada rekod kedatangan untuk $_monthLabel.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.disabledColor),
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
            columns: const [
              DataColumn(label: Text('Tarikh')),
              DataColumn(label: Text('Masa Bertugas')),
              DataColumn(label: Text('Nama')),
              DataColumn(label: Text('No. KP')),
              DataColumn(label: Text('Masa Tamat')),
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final fileName =
        'buku_rekod_kedatangan_srs_${DateFormat('yyyy_MM').format(_selectedMonth)}.pdf';

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
              onTap: _selectMonth,
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
                        '${settings.t("Bulan Laporan")}: $_monthLabel',
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
          if (_records.isEmpty && !_isLoading && _error == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                'PDF masih boleh dijana sebagai borang kosong untuk $_monthLabel.',
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
