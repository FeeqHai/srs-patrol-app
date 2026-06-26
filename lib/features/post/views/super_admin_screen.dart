import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/settings_provider.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  static const double _pageMaxWidth = 1040;

  bool _isLoading = true;
  String? _error;
  DateTime? _lastUpdated;
  Map<String, dynamic> _stats = {};
  List<dynamic> _krtAdmins = [];
  List<dynamic> _districtCoverage = [];

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
          _lastUpdated = DateTime.now();
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

  int _asInt(String key) {
    final value = _stats[key];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
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
      return _buildErrorState(settings, theme);
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
                      _buildScopeSummary(settings, theme),
                      const SizedBox(height: 14),
                      _buildActionRequired(settings, theme),
                      const SizedBox(height: 18),
                      _buildSectionHeader(
                        settings.t('Ringkasan Pantas'),
                        theme,
                      ),
                      const SizedBox(height: 10),
                      _buildQuickOverview(settings, theme),
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

  Widget _buildErrorState(SettingsProvider settings, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 56,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _fetchOverview,
              icon: const Icon(Icons.refresh),
              label: Text(settings.t('Cuba Lagi')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeSummary(SettingsProvider settings, ThemeData theme) {
    final lastUpdated = _lastUpdated == null
        ? settings.t('Belum dikemas kini')
        : DateFormat('dd MMM yyyy, hh:mm a').format(_lastUpdated!);

    return _SurfacePanel(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showScopeSheet(settings),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconTile(
                    icon: Icons.public_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings.t('Skop Semasa'),
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.66),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          settings.t(
                            'Malaysia / Semua Negeri / Semua Daerah / Semua Zon',
                          ),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${settings.t('Dikemas kini')}: $lastUpdated',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.64),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showScopeSheet(settings),
                      icon: const Icon(Icons.tune_outlined),
                      label: Text(settings.t('Tukar Skop')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    height: 48,
                    child: IconButton.filled(
                      onPressed: _isLoading ? null : _fetchOverview,
                      tooltip: settings.t('Muat Semula'),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionRequired(SettingsProvider settings, ThemeData theme) {
    final actions = [
      _DashboardAction(
        label: settings.t('Akaun Menunggu'),
        value: _asInt('pending_accounts'),
        icon: Icons.person_add_alt_1_outlined,
        color: Colors.orange,
        description: settings.t('Akaun baharu memerlukan semakan.'),
      ),
      _DashboardAction(
        label: settings.t('Pemulangan Menunggu'),
        value: _asInt('pending_returns'),
        icon: Icons.assignment_return_outlined,
        color: Colors.deepOrange,
        description: settings.t('Pemulangan rondaan menunggu pengesahan.'),
      ),
      _DashboardAction(
        label: settings.t('Insiden Hari Ini'),
        value: _asInt('today_incidents'),
        icon: Icons.warning_amber_outlined,
        color: Colors.red,
        description: settings.t('Catatan hari ini untuk perhatian.'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(settings.t('Perlu Tindakan'), theme),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 760) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: actions
                      .map(
                        (action) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: SizedBox(
                            width: 204,
                            child: _ActionRequiredCard(
                              action: action,
                              onTap: () => _showActionSheet(action, settings),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            }

            const columns = 3;
            return _ResponsiveTileWrap(
              columns: columns,
              spacing: 10,
              children: actions
                  .map(
                    (action) => _ActionRequiredCard(
                      action: action,
                      onTap: () => _showActionSheet(action, settings),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickOverview(SettingsProvider settings, ThemeData theme) {
    final metrics = [
      _Metric(
        settings.t('Jumlah Pengguna'),
        _asInt('total_users'),
        Icons.people_alt_outlined,
        Colors.indigo,
      ),
      _Metric(
        settings.t('Shif Aktif'),
        _asInt('active_shifts'),
        Icons.directions_walk_outlined,
        Colors.green,
      ),
      _Metric(
        settings.t('Ketua KRT'),
        _asInt('total_krt_admins'),
        Icons.admin_panel_settings_outlined,
        Colors.blue,
      ),
      _Metric(
        settings.t('Negeri Diliputi'),
        _asInt('total_states'),
        Icons.map_outlined,
        Colors.teal,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        return _ResponsiveTileWrap(
          columns: columns,
          spacing: 10,
          children: metrics.map(_QuickMetricCard.new).toList(),
        );
      },
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
              onAction: _krtAdmins.isEmpty
                  ? null
                  : () => _showKrtAdminsSheet(settings),
            ),
            const SizedBox(height: 8),
            if (preview.isEmpty)
              _buildEmptyText(settings.t('Tiada Ketua KRT direkodkan.'), theme)
            else
              ...preview.map(
                (admin) =>
                    _KrtAdminPreviewRow(admin: admin, settings: settings),
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
              onAction: _cleanDistrictCoverage.isEmpty
                  ? null
                  : () => _showDistrictCoverageSheet(settings),
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

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        color: theme.textTheme.bodyLarge?.color,
        fontSize: 16,
        fontWeight: FontWeight.w800,
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

  void _showActionSheet(_DashboardAction action, SettingsProvider settings) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _IconTile(icon: action.icon, color: action.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        action.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      action.value.toString(),
                      style: TextStyle(
                        color: action.color.shade700,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(action.description),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(settings.t('Tutup')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showScopeSheet(SettingsProvider settings) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.t('Tukar Skop'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _ScopeOptionTile(
                  title: settings.t('Malaysia'),
                  subtitle: settings.t('Semua negeri, daerah dan zon'),
                  icon: Icons.check_circle,
                  selected: true,
                ),
                _ScopeOptionTile(
                  title: settings.t('Negeri / Daerah / Zon'),
                  subtitle: settings.t('Penapis skop belum disambungkan.'),
                  icon: Icons.lock_outline,
                  selected: false,
                  enabled: false,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showKrtAdminsSheet(SettingsProvider settings) {
    _showSearchableSheet(
      title: settings.t('Ketua KRT'),
      icon: Icons.admin_panel_settings_outlined,
      searchHint: settings.t('Cari Ketua KRT...'),
      source: _krtAdmins.whereType<Map<String, dynamic>>().toList(),
      filter: (item, query) {
        final haystack = [
          item['full_name'],
          item['email'],
          item['state_name'],
          item['district_name'],
          item['zone_name'],
        ].join(' ').toLowerCase();
        return haystack.contains(query.toLowerCase());
      },
      rowBuilder: (context, item) =>
          _KrtAdminPreviewRow(admin: item, settings: settings),
      emptyText: settings.t('Tiada Ketua KRT direkodkan.'),
    );
  }

  void _showDistrictCoverageSheet(SettingsProvider settings) {
    _showSearchableSheet(
      title: settings.t('Liputan Daerah'),
      icon: Icons.map_outlined,
      searchHint: settings.t('Cari daerah...'),
      source: _cleanDistrictCoverage,
      filter: (item, query) {
        final haystack = [
          item['state_name'],
          item['district_name'],
        ].join(' ').toLowerCase();
        return haystack.contains(query.toLowerCase());
      },
      grouped: true,
      rowBuilder: (context, item) =>
          _DistrictCoverageRow(coverage: item, settings: settings),
      emptyText: settings.t('Tiada liputan daerah direkodkan.'),
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

class _ResponsiveTileWrap extends StatelessWidget {
  const _ResponsiveTileWrap({
    required this.children,
    required this.columns,
    required this.spacing,
  });

  final List<Widget> children;
  final int columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }
}

class _DashboardAction {
  final String label;
  final int value;
  final IconData icon;
  final MaterialColor color;
  final String description;

  const _DashboardAction({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class _ActionRequiredCard extends StatelessWidget {
  const _ActionRequiredCard({required this.action, required this.onTap});

  final _DashboardAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: action.color.withValues(alpha: 0.22)),
            color: action.color.withValues(alpha: 0.06),
          ),
          child: Row(
            children: [
              _IconTile(icon: action.icon, color: action.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      action.value.toString(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.72,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.46,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric {
  final String label;
  final int value;
  final IconData icon;
  final MaterialColor color;

  const _Metric(this.label, this.value, this.icon, this.color);
}

class _QuickMetricCard extends StatelessWidget {
  const _QuickMetricCard(this.metric);

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SurfacePanel(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 86,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(metric.icon, size: 20, color: metric.color.shade700),
                  const Spacer(),
                  Text(
                    metric.value.toString(),
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Text(
                metric.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.7,
                  ),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
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
  const _KrtAdminPreviewRow({required this.admin, required this.settings});

  final Map<String, dynamic> admin;
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final location = [admin['district_name'], admin['zone_name']]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .join(' • ');

    return ListTile(
      minVerticalPadding: 8,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.12),
        child: Icon(
          Icons.person_outline,
          color: Theme.of(context).colorScheme.primary,
        ),
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
  });

  final String stateName;
  final List<Map<String, dynamic>> rows;
  final SettingsProvider settings;

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
            (row) => _DistrictCoverageRow(coverage: row, settings: settings),
          ),
        ],
      ),
    );
  }
}

class _DistrictCoverageRow extends StatelessWidget {
  const _DistrictCoverageRow({required this.coverage, required this.settings});

  final Map<String, dynamic> coverage;
  final SettingsProvider settings;

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

class _ScopeOptionTile extends StatelessWidget {
  const _ScopeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).disabledColor;
    return ListTile(
      enabled: enabled,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
