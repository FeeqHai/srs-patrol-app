import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/command_center_widgets.dart';
import '../../auth/providers/auth_provider.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _squad;
  List<dynamic> _schedules = [];
  String? _error;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fetchUserSchedule();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserSchedule() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.getData(
        'schedules/get_user_schedule.php',
      );
      if (response['status'] == 'success') {
        if (mounted) {
          setState(() {
            _squad = response['squad'];
            _schedules = response['schedules'] ?? [];
            _isLoading = false;
          });
          _animationController.forward(from: 0.0);
        }
      } else {
        if (mounted) {
          setState(() {
            _error = response['message'] ?? 'Gagal memuatkan jadual.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Ralat rangkaian: Sila pastikan sambungan internet anda aktif.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchUserSchedule,
        color: colorScheme.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorView(settings, theme)
            : _buildContentView(settings, theme, colorScheme),
      ),
    );
  }

  Widget _buildErrorView(SettingsProvider settings, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.redAccent.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              settings.t(_error ?? 'Ralat berlaku'),
              style: TextStyle(
                fontSize: 16,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.8,
                ),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchUserSchedule,
              icon: const Icon(Icons.refresh),
              label: Text(settings.t('Cuba Lagi')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView(
    SettingsProvider settings,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final bool hasSquad = _squad != null;
    final String squadName = hasSquad
        ? _squad!['squad_name']
        : settings.t('Tiada Kumpulan');
    final authProvider = context.read<AuthProvider>();
    final String userRole = authProvider.role ?? '';
    final upcomingSchedules = _upcomingSchedules();
    final historySchedules = _historySchedules();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CommandHeader(
              title: settings.t('Jadual Rondaan'),
              subtitle: settings.t(
                'Lihat giliran semasa, lokasi tugasan, dan sejarah rondaan kumpulan.',
              ),
              icon: Icons.calendar_month_outlined,
              compact: true,
            ),
            const SizedBox(height: 18),
            _buildSquadBanner(
              settings,
              theme,
              colorScheme,
              squadName,
              userRole,
              hasSquad,
            ),
            const SizedBox(height: 24),

            CommandSectionHeader(
              title: settings.t('Jadual Rondaan Akan Datang'),
              subtitle: settings.t('Susunan tugasan paling hampir di atas.'),
              icon: Icons.event_note_outlined,
            ),
            const SizedBox(height: 12),

            // --- Schedule List ---
            upcomingSchedules.isEmpty
                ? _buildEmptyState(settings, theme)
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: upcomingSchedules.length,
                    itemBuilder: (context, index) {
                      final schedule = upcomingSchedules[index];
                      return AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          final double opacity = CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(
                              (index * 0.05).clamp(0.0, 0.99),
                              1.0,
                              curve: Curves.easeOut,
                            ),
                          ).value;

                          return Opacity(
                            opacity: opacity,
                            child: Transform.translate(
                              offset: Offset(0, 30 * (1.0 - opacity)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildScheduleCard(
                          settings,
                          theme,
                          colorScheme,
                          schedule,
                        ),
                      );
                    },
                  ),
            if (historySchedules.isNotEmpty) ...[
              const SizedBox(height: 24),
              CommandSectionHeader(
                title: settings.t('schedule_history'),
                subtitle: settings.t('Rekod tugasan rondaan terdahulu.'),
                icon: Icons.history_outlined,
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: historySchedules.length,
                itemBuilder: (context, index) => Opacity(
                  opacity: 0.72,
                  child: _buildScheduleCard(
                    settings,
                    theme,
                    colorScheme,
                    historySchedules[index],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<dynamic> _upcomingSchedules() {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final items = _schedules.where((schedule) {
      final date = DateTime.tryParse(schedule['shift_date']?.toString() ?? '');
      if (date == null) return false;
      return !DateTime(date.year, date.month, date.day).isBefore(todayOnly);
    }).toList();
    items.sort((a, b) => _scheduleDateTime(a).compareTo(_scheduleDateTime(b)));
    return items;
  }

  List<dynamic> _historySchedules() {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final items = _schedules.where((schedule) {
      final date = DateTime.tryParse(schedule['shift_date']?.toString() ?? '');
      if (date == null) return false;
      return DateTime(date.year, date.month, date.day).isBefore(todayOnly);
    }).toList();
    items.sort((a, b) => _scheduleDateTime(b).compareTo(_scheduleDateTime(a)));
    return items;
  }

  DateTime _scheduleDateTime(dynamic schedule) {
    final date = DateTime.tryParse(schedule['shift_date']?.toString() ?? '');
    final time = schedule['start_time']?.toString() ?? '00:00:00';
    if (date == null) return DateTime.fromMillisecondsSinceEpoch(0);
    final parts = time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  void _showSquadMembersDialog(
    BuildContext context,
    SettingsProvider settings,
  ) {
    if (_squad == null || _squad!['members'] == null) return;

    final members = _squad!['members'] as List<dynamic>;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 28,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: size.height * 0.76,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CommandIconBox(
                        icon: Icons.groups_2_outlined,
                        color: colorScheme.primary,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _squad!['squad_name'] ??
                                  settings.t('Kumpulan Rondaan Anda'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${members.length} ${settings.t('Ahli (Peranan)')}',
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.62),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: settings.t('Tutup'),
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: members.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Text(
                              settings.t('Tiada ahli dalam kumpulan ini.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.6),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: members.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final member = members[index];
                              final name = member['full_name'] ?? '';
                              final phone = member['phone_number'] ?? '';
                              final isLeader =
                                  (member['squad_role'] ?? '')
                                      .toString()
                                      .toUpperCase() ==
                                  'LEADER';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.dividerColor.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    UserAvatar(
                                      imageUrl:
                                          member['profile_image_url']
                                              as String?,
                                      initials: UserAvatar.initialsFromName(
                                        name,
                                        fallback: isLeader ? 'KP' : 'P',
                                      ),
                                      radius: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (phone.toString().isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              phone,
                                              style: TextStyle(
                                                color: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color
                                                    ?.withValues(alpha: 0.68),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLeader
                                            ? colorScheme.secondary.withValues(
                                                alpha: 0.14,
                                              )
                                            : theme.dividerColor.withValues(
                                                alpha: 0.08,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isLeader
                                              ? colorScheme.secondary
                                              : theme.dividerColor.withValues(
                                                  alpha: 0.18,
                                                ),
                                        ),
                                      ),
                                      child: Text(
                                        isLeader
                                            ? settings.t('Ketua')
                                            : settings.t('Ahli (Peranan)'),
                                        style: TextStyle(
                                          color: isLeader
                                              ? colorScheme.secondary
                                              : theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color
                                                    ?.withValues(alpha: 0.76),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(settings.t('Tutup')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSquadBanner(
    SettingsProvider settings,
    ThemeData theme,
    ColorScheme colorScheme,
    String squadName,
    String userRole,
    bool hasSquad,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasSquad
            ? () => _showSquadMembersDialog(context, settings)
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E3A8A), const Color(0xFF1D4ED8)]
                  : [const Color(0xFF0F3D87), const Color(0xFF1E40AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasSquad ? Icons.groups_2_outlined : Icons.group_off_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.t('Kumpulan Rondaan Anda'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      squadName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (hasSquad && userRole.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        userRole == 'ketua_peronda'
                            ? settings.t('Ketua Peronda')
                            : settings.t('Peronda'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasSquad) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                  size: 24,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(
    SettingsProvider settings,
    ThemeData theme,
    ColorScheme colorScheme,
    Map<String, dynamic> schedule,
  ) {
    final String dateStr = schedule['shift_date'] ?? '';
    final String startTime = schedule['start_time'] ?? '';
    final String endTime = schedule['end_time'] ?? '';
    final String location = _scheduleLocation(schedule);

    // Check if the shift is today
    bool isToday = false;
    try {
      final DateTime date = DateTime.parse(dateStr);
      final DateTime now = DateTime.now();
      isToday =
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? colorScheme.primary.withValues(alpha: 0.6)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Glowing highlight bar
              Container(
                width: 6,
                color: isToday
                    ? colorScheme.secondary
                    : colorScheme.primary.withValues(alpha: 0.7),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Date and Time info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                if (isToday) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondary.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      settings.t('HARI INI'),
                                      style: TextStyle(
                                        color: colorScheme.secondary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "$startTime - $endTime",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (location.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 14,
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      location,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Arrow indicator icon
                      Icon(
                        Icons.chevron_right,
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _scheduleLocation(Map<String, dynamic> schedule) {
    final parts = [
      schedule['state_name']?.toString().trim(),
      schedule['district_name']?.toString().trim(),
      schedule['zone_name']?.toString().trim(),
    ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();
    return parts.join(' • ');
  }

  Widget _buildEmptyState(SettingsProvider settings, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 60,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              settings.t('Tiada Jadual Ditugaskan'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              settings.t('Sila hubungi Ketua KRT untuk penetapan jadual.'),
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.6,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
