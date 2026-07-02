import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/responsive_shell.dart';
import 'analytics_screen.dart';
import 'admin_incident_screen.dart';
import 'qr_generator_screen.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/app_notification_button.dart';
import '../../../core/widgets/global_menu_button.dart';
import 'admin_squad_schedule_screen.dart';
import 'admin_member_screen.dart';
import 'admin_equipment_screen.dart';
import 'super_admin_screen.dart';
import 'admin_location_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;
  bool _hideAppBar = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isSuperAdmin = context.watch<AuthProvider>().role == 'super_admin';

    final List<String> pageTitles = [
      if (isSuperAdmin) 'Super Admin',
      'Pantau Analitik',
      if (isSuperAdmin) 'Pengurusan Lokasi',
      'Jana Kod QR',
      'Log & Inventori Peralatan',
      'Jadual & Skuad',
      'Laporan Insiden',
      'Pengurusan Ahli',
    ];

    final List<Widget> screens = [
      if (isSuperAdmin) const SuperAdminScreen(),
      const AnalyticsScreen(),
      if (isSuperAdmin) const AdminLocationScreen(),
      const QrGeneratorScreen(),
      const AdminEquipmentScreen(),
      const AdminSquadScheduleScreen(),
      AdminIncidentScreen(
        onSubViewChanged: (hide) {
          setState(() {
            _hideAppBar = hide;
          });
        },
      ),
      const AdminMemberScreen(),
    ];

    return ResponsiveShell(
      currentIndex: _currentIndex,
      onIndexChanged: (index) {
        setState(() {
          _currentIndex = index;
          _hideAppBar = false;
        });
      },
      screens: screens,
      showAppBar: !_hideAppBar,
      items: [
        if (isSuperAdmin)
          NavigationItem(
            icon: Icons.security_outlined,
            label: settings.t('Super Admin'),
          ),
        NavigationItem(icon: Icons.dashboard, label: settings.t('Pantau')),
        if (isSuperAdmin)
          NavigationItem(
            icon: Icons.location_city_outlined,
            label: settings.t('Lokasi'),
          ),
        NavigationItem(
          icon: Icons.qr_code_scanner,
          label: settings.t('Jana QR'),
        ),
        NavigationItem(
          icon: Icons.inventory_2_outlined,
          label: settings.t('Peralatan'),
        ),
        NavigationItem(icon: Icons.calendar_month, label: settings.t('Skuad')),
        NavigationItem(icon: Icons.folder_shared, label: settings.t('Laporan')),
        NavigationItem(icon: Icons.people, label: settings.t('Ahli')),
      ],
      title: settings.t(pageTitles[_currentIndex]),
      actions: const [AppNotificationButton(), GlobalMenuButton()],
    );
  }
}
