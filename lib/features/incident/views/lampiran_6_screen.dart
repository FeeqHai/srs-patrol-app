import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/location_option.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/utils/pdf_saver.dart';

class Lampiran6Screen extends StatefulWidget {
  const Lampiran6Screen({super.key});

  @override
  State<Lampiran6Screen> createState() => _Lampiran6ScreenState();
}

class _Lampiran6ScreenState extends State<Lampiran6Screen> {
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

  int _monthOffset = 0; // 0 = Current Month, 1 = Previous Month
  DateTime _selectedDate = DateTime.now();
  String _selectedLevel = 'daerah'; // 'daerah' or 'negeri'
  bool _showPdfView =
      true; // default to inline PDF preview for better mobile UX
  bool _isLoading = true;
  bool _isLoadingFilters = false;
  Map<String, dynamic> _data = {};
  String _monthLabel = '';
  String _yearLabel = '';
  Map<String, dynamic> _metadata = {};
  final AuthService _authService = AuthService();
  LocationOption? _selectedState;
  LocationOption? _selectedDistrict;
  LocationOption? _selectedZone;
  List<LocationOption> _states = const [];
  List<LocationOption> _districts = const [];
  List<LocationOption> _zones = const [];
  String? _filterError;

  @override
  void initState() {
    super.initState();
    _initializeFilters();
  }

  Future<void> _initializeFilters() async {
    final auth = context.read<AuthProvider>();
    setState(() => _isLoadingFilters = true);
    try {
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
          setState(() {
            _zones = zones;
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
    await _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final endpoint = Uri.parse(
        ApiConstants.buildApiUrl('incidents/get_lampiran_6_summary.php'),
      );
      final query = <String, String>{
        'month_offset': '$_monthOffset',
        'level': _selectedLevel,
      };
      if (authProvider.role == 'super_admin') {
        if (_selectedState != null) query['state_id'] = _selectedState!.id;
        if (_selectedDistrict != null) {
          query['district_id'] = _selectedDistrict!.id;
        }
        if (_selectedZone != null) query['zone_id'] = _selectedZone!.id;
      } else {
        if (authProvider.stateId != null) {
          query['state_id'] = authProvider.stateId!;
        }
        if (authProvider.districtId != null) {
          query['district_id'] = authProvider.districtId!;
        }
        if (_selectedZone != null) query['zone_id'] = _selectedZone!.id;
      }
      final url = endpoint.replace(queryParameters: query);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final Map<String, String> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['status'] == 'success') {
          setState(() {
            _data = body['data'] ?? {};
            _monthLabel = body['month_label'] ?? '';
            _yearLabel = body['year_label'] ?? '';
            _metadata = body['metadata'] ?? {};
            _isLoading = false;
          });
        } else {
          throw Exception(body['message']);
        }
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _data = {};
        _metadata = {};
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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
    await _fetchSummary();
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
    await _fetchSummary();
  }

  Future<void> _selectZone(LocationOption? zone) async {
    setState(() => _selectedZone = zone);
    await _fetchSummary();
  }

  Future<void> _selectMonth(BuildContext context) async {
    final now = DateTime.now();
    var selectedYear = _selectedDate.year;
    var selectedMonth = _selectedDate.month;

    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Pilih Bulan dan Tahun'),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedYear,
                  decoration: const InputDecoration(labelText: 'Tahun'),
                  items: List.generate(now.year - 2020 + 1, (index) {
                    final year = now.year - index;
                    return DropdownMenuItem(value: year, child: Text('$year'));
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
                        disabledForegroundColor: Theme.of(
                          context,
                        ).disabledColor,
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
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month);
        final now = DateTime.now();
        _monthOffset =
            (now.year - picked.year) * 12 + (now.month - picked.month);
      });
      _fetchSummary();
    }
  }

  pw.Widget _pdfMiniCell(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 6.5,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  pw.Widget _pdfTextCell(
    String text, {
    bool alignCenter = false,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: alignCenter
          ? pw.Center(
              child: pw.Text(
                text,
                style: pw.TextStyle(
                  fontWeight: isBold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  fontSize: 6.5,
                ),
              ),
            )
          : pw.Text(
              text,
              style: pw.TextStyle(
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontSize: 6.5,
              ),
            ),
    );
  }

  pw.Widget _buildTableHeader(pw.BorderSide borderSide) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(top: borderSide, left: borderSide, right: borderSide),
      ),
      height: 60,
      child: pw.Row(
        children: [
          // 1. Kategori Column
          pw.Container(
            width: 75,
            decoration: pw.BoxDecoration(border: pw.Border(right: borderSide)),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'KATEGORI',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
            ),
          ),
          // 2. Jenis Kes / Negeri Column
          pw.Container(
            width: 162,
            decoration: pw.BoxDecoration(border: pw.Border(right: borderSide)),
            alignment: pw.Alignment.center,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'JENIS KES',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 7,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'NEGERI',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 7,
                  ),
                ),
              ],
            ),
          ),
          // 3. Jum Column
          pw.Container(
            width: 35,
            decoration: pw.BoxDecoration(border: pw.Border(right: borderSide)),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'JUM.',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
            ),
          ),
          // 4. Agensi Columns Spanning Container
          pw.Container(
            width: 275, // 45 + 65 + 45 + 45 + 75 = 275
            child: pw.Column(
              children: [
                // Top spanning header
                pw.Container(
                  height: 30,
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    border: pw.Border(bottom: borderSide),
                  ),
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                  child: pw.Text(
                    'BILANGAN KES DILAPORKAN KEPADA AGENSI-\nAGENSI/YANG DIRUJUK UNTUK PENYELESAIAN',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 6,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                // Bottom individual headers
                pw.Container(
                  height: 30,
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 45,
                        decoration: pw.BoxDecoration(
                          border: pw.Border(right: borderSide),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'POLIS',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 6,
                          ),
                        ),
                      ),
                      pw.Container(
                        width: 65,
                        decoration: pw.BoxDecoration(
                          border: pw.Border(right: borderSide),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'JABATAN\nAGAMA',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 5.5,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Container(
                        width: 45,
                        decoration: pw.BoxDecoration(
                          border: pw.Border(right: borderSide),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'PBT',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 6,
                          ),
                        ),
                      ),
                      pw.Container(
                        width: 45,
                        decoration: pw.BoxDecoration(
                          border: pw.Border(right: borderSide),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'OBB',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 6,
                          ),
                        ),
                      ),
                      pw.Container(
                        width: 75,
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'LAIN -\nLAIN',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 6,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<pw.Document> _buildLampiran6Pdf() async {
    final pdf = pw.Document();
    final borderSide = const pw.BorderSide(
      width: 0.5,
      color: PdfColors.grey600,
    );

    // Compute Totals
    int totalOverall = 0;
    int totalPolis = 0;
    int totalAgama = 0;
    int totalPbt = 0;
    int totalObb = 0;
    int totalLain = 0;

    _data.forEach((groupName, subcats) {
      if (subcats is Map) {
        subcats.forEach((name, counts) {
          totalOverall += (counts['total'] as num?)?.toInt() ?? 0;
          totalPolis += (counts['polis'] as num?)?.toInt() ?? 0;
          totalAgama += (counts['agama'] as num?)?.toInt() ?? 0;
          totalPbt += (counts['pbt'] as num?)?.toInt() ?? 0;
          totalObb += (counts['obb'] as num?)?.toInt() ?? 0;
          totalLain += (counts['lain'] as num?)?.toInt() ?? 0;
        });
      }
    });

    // Build Portrait PDF Document
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Top Section: Header details & ISO Metadata Table
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'JABATAN PERPADUAN NEGARA DAN INTEGRASI NASIONAL',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'MS ISO 9001:2008',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Pengurusan Rukun Tetangga dan Skim Rondaan Sukarela (JPNIN/RT 01)',
                      style: pw.TextStyle(fontSize: 6.5),
                    ),
                  ],
                ),
                pw.Table(
                  border: pw.TableBorder.all(
                    width: 0.5,
                    color: PdfColors.black,
                  ),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(50),
                    1: const pw.FixedColumnWidth(60),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        _pdfMiniCell('M/Surat :'),
                        _pdfMiniCell(
                          _selectedLevel == 'daerah' ? '45 / 48' : '46 / 48',
                          isBold: true,
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _pdfMiniCell('Terbitan :'),
                        _pdfMiniCell('06', isBold: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _pdfMiniCell('Pindaan :'),
                        _pdfMiniCell('06', isBold: true),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // Main Titles
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'LAMPIRAN D3(C)',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'LAPORAN PENGENDALIAN SRS',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Metadata row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Negeri : ${_metadata['negeri'] ?? "-"}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Daerah : ${_metadata['daerah'] ?? "-"}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Zon : ${_metadata['zone'] ?? "-"}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Text(
                      'Bulan : $_monthLabel',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(width: 30),
                    pw.Text(
                      'Tahun : $_yearLabel',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // Top table title header
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              child: pw.Text(
                'BILANGAN KES DITANGANI OLEH PASUKAN-PASUKAN RONDAAN SUKARELA DI SELURUH NEGARA',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),

            // Custom multi-level header
            _buildTableHeader(borderSide),

            // Render categorized rows with merged left cell
            pw.Table(
              border: pw.TableBorder(
                left: borderSide,
                right: borderSide,
                bottom: borderSide,
                verticalInside: borderSide,
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(75),
                1: const pw.FixedColumnWidth(472),
              },
              children: _data.entries.map((entry) {
                final groupName = entry.key;
                final subcats = entry.value;

                final subcategoryRows = <pw.TableRow>[];
                if (subcats is Map) {
                  subcats.forEach((name, counts) {
                    subcategoryRows.add(
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(
                              left: 6,
                              top: 4,
                              bottom: 4,
                            ),
                            child: pw.Text(
                              name,
                              style: const pw.TextStyle(fontSize: 6.5),
                            ),
                          ),
                          _pdfTextCell(
                            counts['total']?.toString() ?? '0',
                            alignCenter: true,
                            isBold: true,
                          ),
                          _pdfTextCell(
                            counts['polis']?.toString() ?? '0',
                            alignCenter: true,
                          ),
                          _pdfTextCell(
                            counts['agama']?.toString() ?? '0',
                            alignCenter: true,
                          ),
                          _pdfTextCell(
                            counts['pbt']?.toString() ?? '0',
                            alignCenter: true,
                          ),
                          _pdfTextCell(
                            counts['obb']?.toString() ?? '0',
                            alignCenter: true,
                          ),
                          _pdfTextCell(
                            counts['lain']?.toString() ?? '0',
                            alignCenter: true,
                          ),
                        ],
                      ),
                    );
                  });
                }

                String cleanGroupName = groupName
                    .replaceAll('A. ', '')
                    .replaceAll('B. ', '')
                    .replaceAll('C. ', '')
                    .replaceAll('D. ', '')
                    .replaceAll(' - ', '\n')
                    .replaceAll(' ', '\n');

                return pw.TableRow(
                  children: [
                    // Cell 1: Merged Category Cell
                    pw.Container(
                      alignment: pw.Alignment.center,
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        cleanGroupName,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 6.5,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    // Cell 2: Right Subcategories Table
                    pw.Table(
                      border: pw.TableBorder(
                        bottom: borderSide,
                        horizontalInside: borderSide,
                        verticalInside: borderSide,
                      ),
                      columnWidths: {
                        0: const pw.FixedColumnWidth(162),
                        1: const pw.FixedColumnWidth(35),
                        2: const pw.FixedColumnWidth(45),
                        3: const pw.FixedColumnWidth(65),
                        4: const pw.FixedColumnWidth(45),
                        5: const pw.FixedColumnWidth(45),
                        6: const pw.FixedColumnWidth(75),
                      },
                      children: subcategoryRows,
                    ),
                  ],
                );
              }).toList(),
            ),

            // Grand Total Row
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  left: borderSide,
                  right: borderSide,
                  bottom: borderSide,
                ),
              ),
              height: 25,
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 237,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(right: borderSide),
                    ),
                    alignment: pw.Alignment.centerLeft,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                    child: pw.Text(
                      'JUMLAH KES DILAPORKAN KEPADA AGENSI UNTUK RUJUKAN DAN TINDAKAN SUSULAN',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 6,
                      ),
                    ),
                  ),
                  pw.Container(
                    width: 35,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(right: borderSide),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      totalOverall.toString(),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 7,
                      ),
                    ),
                  ),
                  pw.Container(
                    width: 45,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(right: borderSide),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      totalPolis.toString(),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 7,
                      ),
                    ),
                  ),
                  pw.Container(
                    width: 65,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(right: borderSide),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      totalAgama.toString(),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 7,
                      ),
                    ),
                  ),
                  pw.Container(
                    width: 45,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(right: borderSide),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      totalPbt.toString(),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 7,
                      ),
                    ),
                  ),
                  pw.Container(
                    width: 45,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(right: borderSide),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      totalObb.toString(),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 7,
                      ),
                    ),
                  ),
                  pw.Container(
                    width: 75,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      totalLain.toString(),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Signatures block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Disediakan oleh :',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 25),
                    pw.Text(
                      '..............................................................',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      _selectedLevel == 'daerah'
                          ? '(Tandatangan PPM/PPK)'
                          : '(Tandatangan)',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                    pw.Text(
                      'Nama : ${_metadata['admin_name'] ?? "Admin KRT"}',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                    pw.Text(
                      'Tarikh : _____________________',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Disahkan oleh :',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 25),
                    pw.Text(
                      '..............................................................',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      _selectedLevel == 'daerah'
                          ? '(Tandatangan PPB/PPD)'
                          : '(Tandatangan PPN)',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                    pw.Text(
                      'Nama : ______________________',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                    pw.Text(
                      'Tarikh : _____________________',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Divider(thickness: 0.5, color: PdfColors.grey500),
            pw.Text(
              'Prosedur ini adalah dokumen terkawal dan boleh didapati di laman www.jpnin.gov.my.\nJika prosedur ini dicetak, maka prosedur ini bukan dokumen terkawal.',
              style: const pw.TextStyle(
                fontSize: 5.5,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  List<DataRow> _buildTableRows(ThemeData theme, SettingsProvider settings) {
    final rows = <DataRow>[];

    _data.forEach((groupName, subcats) {
      // 1. Group Header Row
      rows.add(
        DataRow(
          color: WidgetStateProperty.all(
            theme.primaryColor.withValues(alpha: 0.05),
          ),
          cells: [
            DataCell(
              Text(
                groupName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const DataCell(Text('')),
            const DataCell(Text('')),
            const DataCell(Text('')),
            const DataCell(Text('')),
            const DataCell(Text('')),
            const DataCell(Text('')),
          ],
        ),
      );

      // 2. Subcategories
      if (subcats is Map) {
        subcats.forEach((name, counts) {
          rows.add(
            DataRow(
              cells: [
                DataCell(
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Text(name, style: const TextStyle(fontSize: 12)),
                  ),
                ),
                DataCell(
                  Text(
                    counts['total']?.toString() ?? '0',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(Text(counts['polis']?.toString() ?? '0')),
                DataCell(Text(counts['agama']?.toString() ?? '0')),
                DataCell(Text(counts['pbt']?.toString() ?? '0')),
                DataCell(Text(counts['obb']?.toString() ?? '0')),
                DataCell(Text(counts['lain']?.toString() ?? '0')),
              ],
            ),
          );
        });
      }
    });

    // Compute Grand Totals
    int totalOverall = 0;
    int totalPolis = 0;
    int totalAgama = 0;
    int totalPbt = 0;
    int totalObb = 0;
    int totalLain = 0;

    _data.forEach((groupName, subcats) {
      if (subcats is Map) {
        subcats.forEach((name, counts) {
          totalOverall += (counts['total'] as num?)?.toInt() ?? 0;
          totalPolis += (counts['polis'] as num?)?.toInt() ?? 0;
          totalAgama += (counts['agama'] as num?)?.toInt() ?? 0;
          totalPbt += (counts['pbt'] as num?)?.toInt() ?? 0;
          totalObb += (counts['obb'] as num?)?.toInt() ?? 0;
          totalLain += (counts['lain'] as num?)?.toInt() ?? 0;
        });
      }
    });

    // Add Grand Total Row
    rows.add(
      DataRow(
        color: WidgetStateProperty.all(
          theme.primaryColor.withValues(alpha: 0.1),
        ),
        cells: [
          DataCell(
            Text(
              settings.t('JUMLAH KESELURUHAN'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataCell(
            Text(
              totalOverall.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataCell(
            Text(
              totalPolis.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataCell(
            Text(
              totalAgama.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataCell(
            Text(
              totalPbt.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataCell(
            Text(
              totalObb.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataCell(
            Text(
              totalLain.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return rows;
  }

  Widget _buildLocationFilters(SettingsProvider settings, ThemeData theme) {
    final auth = context.watch<AuthProvider>();
    final isSuperAdmin = auth.role == 'super_admin';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('Borang Lampiran D3(C)')),
        elevation: 0,
        actions: [
          if (!_isLoading && _data.isNotEmpty)
            IconButton(
              icon: Icon(
                _showPdfView ? Icons.table_chart : Icons.picture_as_pdf,
              ),
              tooltip: _showPdfView
                  ? settings.t('Tunjuk Jadual Data')
                  : settings.t('Tunjuk PDF Laporan'),
              onPressed: () {
                setState(() {
                  _showPdfView = !_showPdfView;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. Month / Year Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.cardColor,
            child: InkWell(
              onTap: () => _selectMonth(context),
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
                  color: theme.cardColor,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: theme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${settings.t("Bulan Laporan")}: $_monthLabel $_yearLabel',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: theme.textTheme.bodyLarge?.color?.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Segment Selector for Level (Daerah / Negeri)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: theme.cardColor,
            child: Container(
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedLevel = 'daerah');
                        _fetchSummary();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedLevel == 'daerah'
                              ? theme.primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            settings.t('Peringkat Daerah (PPD)'),
                            style: TextStyle(
                              color: _selectedLevel == 'daerah'
                                  ? Colors.white
                                  : theme.textTheme.bodyLarge?.color
                                        ?.withValues(alpha: 0.8),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedLevel = 'negeri');
                        _fetchSummary();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedLevel == 'negeri'
                              ? theme.primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            settings.t('Peringkat Negeri (PPN)'),
                            style: TextStyle(
                              color: _selectedLevel == 'negeri'
                                  ? Colors.white
                                  : theme.textTheme.bodyLarge?.color
                                        ?.withValues(alpha: 0.8),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          _buildLocationFilters(settings, theme),

          // 3. Metadata Display Card (Only visible in Table mode)
          if (!_isLoading && _metadata.isNotEmpty && !_showPdfView)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Card(
                elevation: 1,
                color: theme.cardColor,
                shadowColor: Colors.black.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${settings.t("Negeri")}: ${_metadata["negeri"] ?? ""}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '$_monthLabel $_yearLabel',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color
                                  ?.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${settings.t("Daerah")}: ${_metadata["daerah"] ?? ""}  |  ${settings.t("Zon")}: ${_metadata["zone"] ?? ""}',
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color?.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${settings.t("Nama SRS")}: ${_metadata["nama_srs"] ?? ""}',
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color?.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Embedded PDF Preview or Data Table Display
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: theme.primaryColor),
                  )
                : _data.isEmpty
                ? Center(
                    child: Text(settings.t('Tiada rekod untuk bulan ini.')),
                  )
                : _showPdfView
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
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
                          final doc = await _buildLampiran6Pdf();
                          return doc.save();
                        },
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                        pdfFileName: 'laporan_lampiran_d3c_$_monthLabel.pdf',
                        actions: [
                          PdfPreviewAction(
                            icon: Tooltip(
                              message: settings.t('Muat Turun PDF'),
                              child: const Icon(Icons.download),
                            ),
                            onPressed: (context, build, pageFormat) async {
                              final bytes = await build(pageFormat);
                              if (context.mounted) {
                                await savePdf(
                                  context,
                                  bytes,
                                  'laporan_lampiran_d3c_$_monthLabel.pdf',
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Card(
                          elevation: 2,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.1),
                            ),
                          ),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.resolveWith(
                              (states) =>
                                  theme.primaryColor.withValues(alpha: 0.08),
                            ),
                            columns: [
                              DataColumn(
                                label: Text(
                                  settings.t('KATEGORI / JENIS KES'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  settings.t('JUM.'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  settings.t('POLIS'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  settings.t('JABATAN AGAMA'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  settings.t('PBT'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  settings.t('OBB'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  settings.t('LAIN-LAIN'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            rows: _buildTableRows(theme, settings),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
