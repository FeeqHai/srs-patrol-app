import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/tracking_provider.dart';
import '../../../core/providers/settings_provider.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  void _triggerSos(BuildContext context) async {
    final trackingProvider = context.read<TrackingProvider>();
    final authProvider = context.read<AuthProvider>();
    final settings = context.read<SettingsProvider>();

    final userId = authProvider.userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.t('Sila log masuk untuk menggunakan fungsi kecemasan.')),
        ),
      );
      return;
    }

    // Show a confirmation dialog before sending
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          settings.t('Amaran Kecemasan (SOS)'),
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          settings.t('Adakah anda pasti mahu menghantar isyarat kecemasan? Kordinat GPS anda akan dihantar ke bilik gerakan serta-merta.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(settings.t('Batal')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(settings.t('HANTAR SOS')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await trackingProvider.triggerSos(userId);

    if (!context.mounted) return;

    if (success) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(settings.t('SOS Dihantar')),
            ],
          ),
          content: Text(
            settings.t('Bantuan sedang dalam perjalanan. Sila pastikan keselamatan diri anda dan hubungi talian 999 jika keadaan kritikal.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(settings.t('Tutup')),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.t(trackingProvider.errorMessage ?? 'Gagal menghantar SOS'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Consumer<TrackingProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            title: Text(
              settings.t('Pusat Kawalan & Kecemasan'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield, size: 80, color: Colors.white38),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    settings.t('Tekan butang SOS di bawah HANYA pada waktu kecemasan atau ancaman keselamatan.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 60),
                GestureDetector(
                  onTap: provider.isLoading ? null : () => _triggerSos(context),
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: provider.isLoading
                          ? Colors.redAccent.withValues(alpha: 0.5)
                          : Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                      border: Border.all(color: Colors.white24, width: 8),
                    ),
                    child: Center(
                      child: provider.isLoading
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(color: Colors.white),
                                const SizedBox(height: 10),
                                Text(
                                  settings.t('MENGESAN LOKASI...'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              settings.t('SOS'),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 4,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
