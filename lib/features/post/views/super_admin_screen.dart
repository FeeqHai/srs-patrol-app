import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/command_center_widgets.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../attendance/views/attendance_book_screen.dart';
import '../../incident/views/lampiran_6_screen.dart';

class SuperAdminScreen extends StatefulWidget {
  final VoidCallback? onOpenMembers;
  final VoidCallback? onOpenLocations;

  const SuperAdminScreen({super.key, this.onOpenMembers, this.onOpenLocations});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  static const double _pageMaxWidth = 1040;

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  List<dynamic> _krtAdmins = [];
  List<dynamic> _districtCoverage = [];
  bool _isQuickAccessExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchOverview();
  }

  Future<void> _fetchOverview() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await ApiClient.getData(
        'admin/super_admin_overview.php',
      );
      if (response['status'] == 'success') {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        if (!mounted) return;
        setState(() {
          _stats = data['stats'] as Map<String, dynamic>? ?? {};
          _krtAdmins = data['krt_admins'] as List<dynamic>? ?? [];
          _districtCoverage = data['district_coverage'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = response['message']?.toString() ?? 'Gagal memuatkan data.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ralat Rangkaian: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _cleanDistrictCoverage => _districtCoverage
      .whereType<Map<String, dynamic>>()
      .where((item) => !_isLegacyLocation(item))
      .toList();

  List<Map<String, dynamic>> get _legacyDistrictCoverage => _districtCoverage
      .whereType<Map<String, dynamic>>()
      .where(_isLegacyLocation)
      .toList();

  bool _isLegacyLocation(Map<String, dynamic> item) {
    final values = [
      item['state_name'],
      item['district_name'],
    ].map((value) => value?.toString().trim() ?? '').toList();

    if (values.any((value) => value.isEmpty)) return true;

    return values.any((value) {
      final lower = value.toLowerCase();
      return lower.contains('unknown') ||
          lower.contains('legacy') ||
          lower.contains('tidak diketahui');
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    if (_isLoading && _stats.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.lightBlueAccent),
      );
    }

    if (_error != null && _stats.isEmpty) {
      return _buildErrorState(settings);
    }

    return RefreshIndicator(
      onRefresh: _fetchOverview,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _pageMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CommandHeader(
                        title: settings.t('Super Admin Command Center'),
                        subtitle: settings.t(
                          'Pantau skop nasional, tindakan tertunda, liputan lokasi dan akaun KRT.',
                        ),
                        icon: Icons.admin_panel_settings_outlined,
                        compact: true,
                      ),

                      const SizedBox(height: 14),
                      _buildQuickAccessPanel(settings, theme),
                      const SizedBox(height: 18),
                      _buildKrtAdminPreview(settings, theme),
                      const SizedBox(height: 14),
                      _buildDistrictCoveragePreview(settings, theme),
                      if (_legacyDistrictCoverage.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildCleanupWarning(settings, theme),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(SettingsProvider settings) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CommandEmptyStateCard(
          icon: Icons.admin_panel_settings_outlined,
          title: settings.t('Data Super Admin tidak dapat dimuatkan'),
          message: _error!,
          actionLabel: settings.t('Cuba Lagi'),
          onAction: _fetchOverview,
        ),
      ),
    );
  }

  Widget _buildQuickAccessPanel(SettingsProvider settings, ThemeData theme) {
    final actions = [
      _SuperAdminQuickActionData(
        label: settings.t('Laporan Bulanan'),
        icon: Icons.picture_as_pdf_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Lampiran6Screen()),
          );
        },
      ),
      _SuperAdminQuickActionData(
        label: settings.t('Kedatangan'),
        icon: Icons.fact_check_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AttendanceBookScreen(),
            ),
          );
        },
      ),
      _SuperAdminQuickActionData(
        label: settings.t('Pengurusan Lokasi'),
        icon: Icons.location_city_outlined,
        onTap: widget.onOpenLocations,
      ),
      _SuperAdminQuickActionData(
        label: settings.t('Pengurusan Ahli'),
        icon: Icons.groups_2_outlined,
        onTap: widget.onOpenMembers,
      ),
    ];

    final displayActions = _isQuickAccessExpanded
        ? actions
        : actions.take(2).toList();

    void toggleQuickAccess() {
      setState(() {
        _isQuickAccessExpanded = !_isQuickAccessExpanded;
      });
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: toggleQuickAccess,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.flash_on_rounded,
                    size: 18,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    settings.t('Quick Access'),
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isQuickAccessExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.primaryColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760 ? 4 : 2;
                const spacing = 8.0;
                final tileWidth =
                    (constraints.maxWidth - (spacing * (columns - 1))) /
                    columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: displayActions
                      .map(
                        (action) => SizedBox(
                          width: tileWidth,
                          child: CommandQuickActionTile(
                            label: action.label,
                            icon: action.icon,
                            onTap: action.onTap,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Tooltip(
              message: settings.t(
                _isQuickAccessExpanded
                    ? 'Tutup Akses Pantas'
                    : 'Buka Akses Pantas',
              ),
              child: Semantics(
                button: true,
                label: settings.t(
                  _isQuickAccessExpanded
                      ? 'Tutup Akses Pantas'
                      : 'Buka Akses Pantas',
                ),
                child: InkWell(
                  onTap: toggleQuickAccess,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 76,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                        bottom: Radius.circular(16),
                      ),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.22),
                      ),
                    ),
                    child: AnimatedRotation(
                      turns: _isQuickAccessExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: theme.primaryColor,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKrtAdminPreview(SettingsProvider settings, ThemeData theme) {
    final preview = _krtAdmins
        .whereType<Map<String, dynamic>>()
        .take(2)
        .toList();

    return _SurfacePanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTopRow(
              title: settings.t('Ketua KRT'),
              icon: Icons.admin_panel_settings_outlined,
              actionLabel: settings.t('Lihat Semua'),
              onAction: widget.onOpenMembers,
            ),
            const SizedBox(height: 8),
            if (preview.isEmpty)
              _buildEmptyText(settings.t('Tiada Ketua KRT direkodkan.'), theme)
            else
              ...preview.map(
                (admin) => _KrtAdminPreviewRow(
                  admin: admin,
                  settings: settings,
                  onTap: widget.onOpenMembers,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictCoveragePreview(
    SettingsProvider settings,
    ThemeData theme,
  ) {
    final grouped = _groupCoverageByState(_cleanDistrictCoverage);
    final previewStates = grouped.entries.take(2).toList();

    return _SurfacePanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTopRow(
              title: settings.t('Liputan Daerah'),
              icon: Icons.map_outlined,
              actionLabel: settings.t('Lihat Semua'),
              onAction: widget.onOpenLocations,
            ),
            const SizedBox(height: 8),
            if (previewStates.isEmpty)
              _buildEmptyText(
                settings.t('Tiada liputan daerah direkodkan.'),
                theme,
              )
            else
              ...previewStates.map(
                (entry) => _StateCoveragePreview(
                  stateName: entry.key,
                  rows: entry.value.take(2).toList(),
                  settings: settings,
                  onTap: widget.onOpenLocations,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanupWarning(SettingsProvider settings, ThemeData theme) {
    final count = _legacyDistrictCoverage.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.38)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showLegacyCleanupSheet(settings),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _IconTile(
                icon: Icons.cleaning_services_outlined,
                color: Colors.amber,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.t('Pembersihan data diperlukan'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      settings
                          .t(
                            count == 1
                                ? '1 lokasi legasi perlu disemak.'
                                : 'lokasi legasi perlu disemak.',
                          )
                          .replaceFirst('{count}', count.toString()),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showLegacyCleanupSheet(settings),
                child: Text(settings.t('Semak')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyText(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.58),
          ),
        ),
      ),
    );
  }

  void _showLegacyCleanupSheet(SettingsProvider settings) {
    _showSearchableSheet(
      title: settings.t('Pembersihan data diperlukan'),
      icon: Icons.cleaning_services_outlined,
      searchHint: settings.t('Cari rekod...'),
      source: _legacyDistrictCoverage,
      filter: (item, query) {
        final haystack = [
          item['state_name'],
          item['district_name'],
        ].join(' ').toLowerCase();
        return haystack.contains(query.toLowerCase());
      },
      rowBuilder: (context, item) =>
          _DistrictCoverageRow(coverage: item, settings: settings),
      emptyText: settings.t('Tiada data legasi.'),
    );
  }

  void _showSearchableSheet({
    required String title,
    required IconData icon,
    required String searchHint,
    required List<Map<String, dynamic>> source,
    required bool Function(Map<String, dynamic>, String) filter,
    required Widget Function(BuildContext, Map<String, dynamic>) rowBuilder,
    required String emptyText,
    bool grouped = false,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String query = '';
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.42,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                final visible = source
                    .where(
                      (item) => query.trim().isEmpty || filter(item, query),
                    )
                    .toList();

                return SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).dividerColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              icon,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (value) =>
                              setSheetState(() => query = value),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: searchHint,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: visible.isEmpty
                              ? Center(child: Text(emptyText))
                              : grouped
                              ? _GroupedCoverageList(
                                  rows: visible,
                                  controller: scrollController,
                                  rowBuilder: rowBuilder,
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  itemCount: visible.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) =>
                                      rowBuilder(context, visible[index]),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupCoverageByState(
    List<Map<String, dynamic>> rows,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final state = row['state_name']?.toString().trim();
      final key = (state == null || state.isEmpty) ? 'Unknown' : state;
      grouped.putIfAbsent(key, () => []).add(row);
    }
    return grouped;
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.18)),
        ),
        child: child,
      ),
    );
  }
}

class _SuperAdminQuickActionData {
  const _SuperAdminQuickActionData({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _SectionTopRow extends StatelessWidget {
  const _SectionTopRow({
    required this.title,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _KrtAdminPreviewRow extends StatelessWidget {
  const _KrtAdminPreviewRow({
    required this.admin,
    required this.settings,
    this.onTap,
  });

  final Map<String, dynamic> admin;
  final SettingsProvider settings;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final location = [admin['district_name'], admin['zone_name']]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .join(' • ');

    return ListTile(
      onTap: onTap,
      minVerticalPadding: 8,
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(
        imageUrl: admin['profile_image_url'] as String?,
        initials: UserAvatar.initialsFromName(
          admin['full_name'] as String?,
          fallback: 'KK',
        ),
        radius: 20,
      ),
      title: Text(
        admin['full_name']?.toString() ?? settings.t('Ketua KRT'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        [
          admin['email']?.toString() ?? '',
          if (location.isNotEmpty) location,
        ].where((value) => value.isNotEmpty).join('\n'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _StatusPill(
        status: admin['account_status']?.toString() ?? 'pending',
        settings: settings,
      ),
    );
  }
}

class _StateCoveragePreview extends StatelessWidget {
  const _StateCoveragePreview({
    required this.stateName,
    required this.rows,
    required this.settings,
    this.onTap,
  });

  final String stateName;
  final List<Map<String, dynamic>> rows;
  final SettingsProvider settings;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stateName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          ...rows.map(
            (row) => _DistrictCoverageRow(
              coverage: row,
              settings: settings,
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistrictCoverageRow extends StatelessWidget {
  const _DistrictCoverageRow({
    required this.coverage,
    required this.settings,
    this.onTap,
  });

  final Map<String, dynamic> coverage;
  final SettingsProvider settings;
  final VoidCallback? onTap;

  int _asInt(String key) {
    final value = coverage[key];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final zones = _asInt('zones');
    final krt = _asInt('krt_admins');
    final members = _asInt('patrol_members');

    return ListTile(
      onTap: onTap,
      dense: true,
      minVerticalPadding: 6,
      contentPadding: EdgeInsets.zero,
      title: Text(
        coverage['district_name']?.toString() ?? settings.t('Daerah'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${_countLabel(zones, settings.t('zon'), settings.t('zon'))} • '
        '$krt ${settings.t('KRT')} • '
        '${_countLabel(members, settings.t('ahli'), settings.t('ahli'))}',
      ),
    );
  }

  String _countLabel(int count, String singular, String plural) {
    return '$count ${count == 1 ? singular : plural}';
  }
}

class _GroupedCoverageList extends StatelessWidget {
  const _GroupedCoverageList({
    required this.rows,
    required this.controller,
    required this.rowBuilder,
  });

  final List<Map<String, dynamic>> rows;
  final ScrollController controller;
  final Widget Function(BuildContext, Map<String, dynamic>) rowBuilder;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final state = row['state_name']?.toString().trim();
      final key = (state == null || state.isEmpty) ? 'Unknown' : state;
      grouped.putIfAbsent(key, () => []).add(row);
    }

    final children = <Widget>[];
    for (final entry in grouped.entries) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            entry.key,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
      );
      for (final row in entry.value) {
        children.add(rowBuilder(context, row));
        children.add(const Divider(height: 1));
      }
    }

    return ListView(controller: controller, children: children);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.settings});

  final String status;
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = normalized == 'active'
        ? Colors.green
        : normalized == 'inactive'
        ? Colors.red
        : Colors.orange;
    final label = normalized == 'active'
        ? settings.t('Aktif')
        : normalized == 'inactive'
        ? settings.t('Nyahaktif')
        : settings.t('Menunggu');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
