import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../models/verified_identity.dart';
import '../services/identity_verification_api.dart';
import '../services/identity_verification_engine.dart';
import 'mykad_camera_screen.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  final IdentityVerificationEngine _engine = IdentityVerificationEngine();
  final IdentityVerificationApi _api = IdentityVerificationApi();

  bool _consented = false;
  bool _busy = false;
  String? _message;
  XFile? _myKadImage;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    unawaited(_engine.deleteTemporaryImages([_myKadImage]));
    unawaited(_engine.dispose());
    super.dispose();
  }

  Future<void> _captureAndExtractMyKad() async {
    if (!_isAndroid || !_consented || _busy) return;
    final shouldOpenCamera = await _showMyKadCaptureNotice();
    if (!mounted || !shouldOpenCamera) return;

    try {
      final analysis = await repeatMyKadCaptureUntilConfirmed<MyKadAnalysis>(
        capture: () async {
          final file = await Navigator.push<XFile>(
            context,
            MaterialPageRoute<XFile>(builder: (_) => const MyKadCameraScreen()),
          );
          if (!mounted) return null;
          if (file == null) {
            setState(() => _message = null);
            return null;
          }

          _myKadImage = file;
          setState(() {
            _busy = true;
            _message = _t(
              'Menyemak kualiti dan membaca nama serta nombor MyKad...',
            );
          });

          final result = await _engine.analyzeMyKad(file);
          if (!result.isAcceptable) {
            await _clearImage();
            _showFailure(result.issues.map(_t).join('\n'));
            return null;
          }

          await _clearImage();
          return result;
        },
        confirm: (result) async {
          if (!mounted) return true;
          final extractedData = result.data!;
          final confirmed = await _showExtractedDataReview(
            fullName: extractedData.fullName,
            icNumber: extractedData.icNumber,
          );
          if (mounted && !confirmed) setState(() => _message = null);
          return confirmed;
        },
      );
      if (!mounted || analysis == null) return;

      final extractedData = analysis.data!;
      setState(() {
        _message = _t('Menyediakan sesi pendaftaran...');
      });
      final session = await _api.start(icNumber: extractedData.icNumber);
      final completedSession = await _api.complete(
        session: session,
        fullName: extractedData.fullName,
        qualityPassed: analysis.quality.isAcceptable,
        ocrVersion: IdentityVerificationEngine.ocrVersion,
      );
      final result = VerifiedIdentity(
        fullName: extractedData.fullName,
        icNumber: extractedData.icNumber,
        verificationToken: completedSession.token,
        verifiedAt: DateTime.now(),
        expiresAt: completedSession.expiresAt,
      );

      await _clearImage();
      if (mounted) Navigator.pop(context, result);
    } on VerificationApiException catch (error) {
      await _clearImage();
      _showFailure(_t(error.message));
    } catch (error) {
      await _clearImage();
      _showFailure(_t(_cleanError(error)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearImage() async {
    await _engine.deleteTemporaryImages([_myKadImage]);
    _myKadImage = null;
  }

  String _t(String key) => context.read<SettingsProvider>().t(key);

  Future<bool> _showExtractedDataReview({
    required String fullName,
    required String icNumber,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => MyKadExtractionReviewDialog(
            fullName: fullName,
            icNumber: icNumber,
          ),
        ) ??
        false;
  }

  Future<bool> _showMyKadCaptureNotice() async {
    final settings = context.read<SettingsProvider>();
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.screen_rotation_rounded, size: 42),
            title: Text(settings.t('Sediakan MyKad')),
            content: Text(
              settings.t(
                'Anda boleh memegang telefon secara menegak atau melintang. '
                'Letakkan MyKad secara mendatar di dalam bingkai dan pastikan seluruh kad, '
                'termasuk keempat-empat penjuru, berada dalam bingkai. '
                'Elakkan silau dan pegang telefon dengan stabil.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(settings.t('BATAL')),
              ),
              FilledButton.icon(
                key: const Key('open-mykad-camera-button'),
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(settings.t('BUKA KAMERA')),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showFailure(String message) {
    if (!mounted) return;
    setState(() => _message = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(settings.t('Pengekstrakan Data MyKad'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.t(
                        'Pengekstrakan prototaip — bukan pengesahan pemilik MyKad',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      settings.t(
                        'Tujuan: membaca nama penuh dan nombor MyKad untuk mengisi borang pendaftaran.\n\n'
                        'Data diproses: imej MyKad, nama penuh dan nombor MyKad. Tiada swafoto, '
                        'pengesanan hidup atau perbandingan wajah dilakukan.\n\n'
                        'Privasi: imej MyKad diproses pada peranti dan tidak dihantar ke pelayan. '
                        'Fail imej sementara dipadam apabila proses tamat atau skrin ini ditutup. '
                        'Anda boleh membatalkan sebelum bersetuju.',
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_isAndroid)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    settings.t(
                      'Pengekstrakan data MyKad hanya tersedia melalui aplikasi Android iRonda.',
                    ),
                  ),
                ),
              )
            else ...[
              CheckboxListTile(
                key: const Key('identity-consent-checkbox'),
                value: _consented,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _consented = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  settings.t(
                    'Saya bersetuju dengan pemprosesan sementara MyKad untuk mengekstrak '
                    'nama penuh dan nombor MyKad bagi pendaftaran iRonda.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Text('1')),
                title: Text(
                  settings.t('Imbas dan baca MyKad'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  settings.t(
                    'Pegang telefon secara menegak atau melintang. Kualiti imej akan diperiksa sebelum '
                    'nama penuh dan nombor MyKad dibaca.',
                  ),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(_message!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  key: const Key('identity-start-button'),
                  onPressed: _consented && !_busy
                      ? _captureAndExtractMyKad
                      : null,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.document_scanner_outlined),
                  label: Text(
                    settings.t(_busy ? 'MEMPROSES...' : 'IMBAS MYKAD'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
Future<T?> repeatMyKadCaptureUntilConfirmed<T>({
  required Future<T?> Function() capture,
  required Future<bool> Function(T result) confirm,
}) async {
  while (true) {
    final result = await capture();
    if (result == null) return null;
    if (await confirm(result)) return result;
  }
}

class MyKadExtractionReviewDialog extends StatelessWidget {
  const MyKadExtractionReviewDialog({
    required this.fullName,
    required this.icNumber,
    super.key,
  });

  final String fullName;
  final String icNumber;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return AlertDialog(
      icon: const Icon(Icons.fact_check_outlined, size: 42),
      title: Text(settings.t('Semak Maklumat Diekstrak')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settings.t(
                'Pastikan nama penuh dan nombor MyKad berikut sepadan dengan kad anda.',
              ),
            ),
            const SizedBox(height: 20),
            _ExtractedDataField(
              label: settings.t('Nama Penuh (Mengikut MyKad)'),
              value: fullName,
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 12),
            _ExtractedDataField(
              label: settings.t('Nombor MyKad'),
              value: _formatIcNumber(icNumber),
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 16),
            Text(
              settings.t(
                'Tiada maklumat dihantar ke pelayan sehingga anda memilih BETUL.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        Row(
          key: const Key('mykad-review-actions-row'),
          children: [
            Expanded(
              flex: 3,
              child: Transform.scale(
                key: const Key('mykad-review-rescan-scale'),
                scale: 0.9,
                child: OutlinedButton.icon(
                  key: const Key('mykad-review-rescan-button'),
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.refresh_rounded),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(settings.t('IMBAS SEMULA')),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 2,
              child: Transform.scale(
                key: const Key('mykad-review-confirm-scale'),
                scale: 0.9,
                child: FilledButton.icon(
                  key: const Key('mykad-review-confirm-button'),
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.check_rounded),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(settings.t('BETUL')),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _formatIcNumber(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 12) return value;
    return '${digits.substring(0, 6)}-${digits.substring(6, 8)}-'
        '${digits.substring(8)}';
  }
}

class _ExtractedDataField extends StatelessWidget {
  const _ExtractedDataField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
