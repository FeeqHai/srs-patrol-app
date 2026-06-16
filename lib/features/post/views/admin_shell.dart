import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/responsive_shell.dart';
import 'analytics_screen.dart';
import 'admin_incident_screen.dart';
import 'qr_generator_screen.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/global_menu_button.dart';
import 'admin_squad_schedule_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AnalyticsScreen(),
    const QrGeneratorScreen(),
    const AdminIncidentScreen(),
    const AdminSquadScheduleScreen(),
  ];

  final List<String> _pageTitles = [
    'Pantau Analitik',
    'Jana Kod QR',
    'Laporan Insiden',
    'Jadual & Skuad',
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return ResponsiveShell(
      currentIndex: _currentIndex,
      onIndexChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      screens: _screens,
      items: [
        NavigationItem(icon: Icons.dashboard, label: settings.t('Pantau')),
        NavigationItem(icon: Icons.qr_code_scanner, label: settings.t('Jana QR')),
        NavigationItem(icon: Icons.folder_shared, label: settings.t('Laporan')),
        NavigationItem(icon: Icons.calendar_month, label: settings.t('Skuad')),
      ],
      title: settings.t(_pageTitles[_currentIndex]),
      actions: const [GlobalMenuButton()],
    );
  }
}
