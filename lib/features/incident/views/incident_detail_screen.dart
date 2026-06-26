import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/image_viewer_screen.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/malaysia_time.dart';
import '../../../core/utils/pdf_saver.dart';

class IncidentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> incident;

  const IncidentDetailScreen({super.key, required this.incident});

  List<String> _parseImages(dynamic imageUrlData) {
    if (imageUrlData == null || imageUrlData.toString().isEmpty) return [];
    try {
      if (imageUrlData.toString().trim().startsWith('[')) {
        List<dynamic> parsed = json.decode(imageUrlData);
        return parsed
            .map((e) => ApiConstants.resolveUploadUrl(e.toString()))
            .whereType<String>()
            .toList();
      }
    } catch (e) {
      appLogger.w('Failed to parse image URL array, falling back to string: $e');
    }
    final imageUrl = ApiConstants.resolveUploadUrl(imageUrlData.toString());
    return imageUrl == null ? [] : [imageUrl];
  }

  static Future<pw.Document> buildPdf(Map<String, dynamic> incident) async {
    try {
      final pdf = pw.Document();

      final String namaPeronda = incident['full_name'] ?? '-';

      String tarikh = '-';
      String masa = '-';
      try {
        if (incident['created_at'] != null) {
          final dt = MalaysiaTime.fromUtcDatabase(incident['created_at']);
          tarikh = DateFormat('dd MMMM yyyy').format(dt);
          masa = DateFormat('hh:mm a').format(dt);
        }
      } catch (_) {}

      final String lokasi = incident['location_name'] ?? '-';
      final String peristiwa = incident['description'] ?? '-';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Title
                pw.Center(
                  child: pw.Text(
                    'BUKU NOTA HARIAN',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ),
                pw.SizedBox(height: 24),

                // Main bordered box matching exact Lampiran 4
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1.0),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pdfField('NAMA PERONDA', namaPeronda),
                      pw.SizedBox(height: 20),
                      pdfField('TARIKH RONDAAN', tarikh),
                      pw.SizedBox(height: 20),
                      pdfField('MASA RONDAAN', masa),
                      pw.SizedBox(height: 20),
                      pdfField('LOKASI RONDAAN', lokasi),
                      pw.SizedBox(height: 24),

                      // Peristiwa section
                      pw.Text(
                        'PERISTIWA BERLAKU\nSEMASA RONDAAN:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      pw.SizedBox(height: 16),
                      // Text representation of the lines
                      pw.Container(
                        width: double.infinity,
                        constraints: const pw.BoxConstraints(minHeight: 200),
                        child: pw.Text(
                          peristiwa,
                          style: const pw.TextStyle(fontSize: 12, lineSpacing: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Fetch and append evidence images if available
      List<String> imageUrls = [];
      final imageUrlData = incident['image_url'];
      if (imageUrlData != null && imageUrlData.toString().isNotEmpty) {
        try {
          if (imageUrlData.toString().trim().startsWith('[')) {
            List<dynamic> parsed = json.decode(imageUrlData.toString());
            imageUrls = parsed
                .map((e) => ApiConstants.resolveUploadUrl(e.toString()))
                .whereType<String>()
                .toList();
          } else {
            final imageUrl = ApiConstants.resolveUploadUrl(imageUrlData.toString());
            imageUrls = imageUrl == null ? [] : [imageUrl];
          }
        } catch (_) {
          final imageUrl = ApiConstants.resolveUploadUrl(imageUrlData.toString());
          imageUrls = imageUrl == null ? [] : [imageUrl];
        }
      }

      for (final url in imageUrls) {
        if (url.isNotEmpty) {
          try {
            final imageProvider = await networkImage(url);
            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(40),
                build: (pw.Context context) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Center(
                        child: pw.Text(
                          'GAMBAR BUKTI / EVIDEN',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            decoration: pw.TextDecoration.underline,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 24),
                      pw.Expanded(
                        child: pw.Center(
                          child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          } catch (e) {
            appLogger.e("Failed to load image for PDF: $url, error: $e");
          }
        }
      }

      return pdf;
    } catch (e, stackTrace) {
      final errorPdf = pw.Document();
      errorPdf.addPage(pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('ERROR GENERATING PDF:', style: pw.TextStyle(color: PdfColors.red, fontSize: 18)),
            pw.SizedBox(height: 16),
            pw.Text(e.toString()),
            pw.SizedBox(height: 16),
            pw.Text(stackTrace.toString(), style: const pw.TextStyle(fontSize: 8)),
          ]
        )
      ));
      return errorPdf;
    }
  }

  static pw.Widget pdfField(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 160,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
        ),
        pw.Text(' : '),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Future<pw.Document> _buildPdf() => IncidentDetailScreen.buildPdf(incident);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final images = _parseImages(incident['image_url']);

    final String namaPeronda = incident['full_name'] ?? '-';
    final String tarikh = incident['created_at'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(
            MalaysiaTime.fromUtcDatabase(incident['created_at']),
          )
        : '-';
    final String lokasi = incident['location_name'] ?? '-';
    final String kategori = incident['category'] ?? '-';
    final String peristiwa = incident['description'] ?? '-';
    final String agensiDirujuk = incident['reported_to'] ?? 'Tiada';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(settings.t('Buku Nota Harian')),
        actions: [
          // PDF Preview & Print button
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: settings.t('Pratonton PDF Lampiran 4'),
            onPressed: () {
              if (context.mounted) {
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
                         child: Scaffold(
                          appBar: AppBar(title: Text(settings.t('Pratonton Buku Nota Harian'))),
                          body: PdfPreview(
                            build: (format) async {
                              final doc = await _buildPdf();
                              return doc.save();
                            },
                            canChangeOrientation: false,
                            canChangePageFormat: false,
                            canDebug: false,
                            pdfFileName: 'buku_nota_harian_${incident['id']}.pdf',
                            actions: [
                              PdfPreviewAction(
                                icon: Tooltip(
                                  message: settings.t('Muat Turun PDF'),
                                  child: const Icon(Icons.download),
                                ),
                                onPressed: (context, build, pageFormat) async {
                                  final bytes = await build(pageFormat);
                                  if (context.mounted) {
                                    await savePdf(context, bytes, 'buku_nota_harian_${incident['id']}.pdf');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(settings.t('Pratonton Buku Nota Harian'))),
                        body: PdfPreview(
                          build: (format) async {
                            final doc = await _buildPdf();
                            return doc.save();
                          },
                          canChangeOrientation: false,
                          canChangePageFormat: false,
                          canDebug: false,
                          pdfFileName: 'buku_nota_harian_${incident['id']}.pdf',
                          actions: [
                            PdfPreviewAction(
                              icon: Tooltip(
                                message: settings.t('Muat Turun PDF'),
                                child: const Icon(Icons.download),
                              ),
                              onPressed: (context, build, pageFormat) async {
                                final bytes = await build(pageFormat);
                                if (context.mounted) {
                                  await savePdf(context, bytes, 'buku_nota_harian_${incident['id']}.pdf');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Evidence Images ───
          if (images.isNotEmpty) ...[
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ImageViewerScreen(imageUrls: images, initialIndex: index),
                      )),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(images[index], fit: BoxFit.cover, width: 250),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ─── Title ───
          Text(
            incident['title'] ?? settings.t('Tiada Tajuk'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 16),

          // ─── Formal Record Card ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                _buildInfoRow(context, Icons.person, settings.t('Nama Peronda'), namaPeronda),
                const Divider(height: 20),
                _buildInfoRow(context, Icons.calendar_today, settings.t('Tarikh & Masa'), tarikh),
                const Divider(height: 20),
                _buildInfoRow(context, Icons.location_on, settings.t('Lokasi Rondaan'), lokasi),
                const Divider(height: 20),
                _buildInfoRow(context, Icons.category, settings.t('Kategori'), kategori),
                const Divider(height: 20),
                _buildInfoRow(context, Icons.account_balance, settings.t('Agensi Dirujuk'), agensiDirujuk),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── Peristiwa Berlaku ───
          Text(
            settings.t('Peristiwa Berlaku Semasa Rondaan'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Text(
              peristiwa,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}
