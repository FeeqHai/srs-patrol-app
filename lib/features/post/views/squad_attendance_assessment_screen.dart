import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/command_center_widgets.dart';

class SquadAttendanceAssessmentScreen extends StatefulWidget {
  const SquadAttendanceAssessmentScreen({super.key, this.scheduleId});

  final String? scheduleId;

  @override
  State<SquadAttendanceAssessmentScreen> createState() =>
      _SquadAttendanceAssessmentScreenState();
}

class _SquadAttendanceAssessmentScreenState
    extends State<SquadAttendanceAssessmentScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _squad;
  Map<String, dynamic>? _schedule;
  List<Map<String, dynamic>> _members = [];
  final Set<String> _savingMembers = {};
  final Map<String, String> _selectedStatuses = {};
  final Map<String, TextEditingController> _noteControllers = {};

  static const Map<String, String> _statusLabels = {
    'present': 'Hadir',
    'late': 'Lewat',
    'absent': 'Tidak Hadir',
    'excused': 'Dikecualikan',
  };

  @override
  void initState() {
    super.initState();
    _loadAssessment();
  }

  @override
  void dispose() {
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAssessment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final scheduleQuery =
          widget.scheduleId != null && widget.scheduleId!.trim().isNotEmpty
          ? '?schedule_id=${Uri.encodeQueryComponent(widget.scheduleId!)}'
          : '';
      final response = await ApiClient.getData(
        'attendance/get_squad_attendance_assessment.php$scheduleQuery',
      );
      if (response['status'] != 'success') {
        throw Exception(
          response['message'] ?? 'Unable to load attendance assessment.',
        );
      }

      final members = List<Map<String, dynamic>>.from(
        (response['members'] ?? const []).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
      _syncMemberInputs(members);

      if (!mounted) return;
      setState(() {
        _squad = response['squad'] is Map
            ? Map<String, dynamic>.from(response['squad'])
            : null;
        _schedule = response['schedule'] is Map
            ? Map<String, dynamic>.from(response['schedule'])
            : null;
        _members = members;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _syncMemberInputs(List<Map<String, dynamic>> members) {
    final seen = <String>{};
    for (final member in members) {
      final userId = member['user_id']?.toString() ?? '';
      if (userId.isEmpty) continue;
      seen.add(userId);
      _selectedStatuses[userId] =
          member['effective_status']?.toString() ?? 'absent';
      final noteText = member['assessment_notes']?.toString() ?? '';
      final controller = _noteControllers.putIfAbsent(
        userId,
        () => TextEditingController(),
      );
      if (!_savingMembers.contains(userId) && controller.text != noteText) {
        controller.text = noteText;
      }
    }

    final unused = _noteControllers.keys
        .where((userId) => !seen.contains(userId))
        .toList();
    for (final userId in unused) {
      _noteControllers.remove(userId)?.dispose();
      _selectedStatuses.remove(userId);
    }
  }

  Future<void> _saveAssessment(Map<String, dynamic> member) async {
    final scheduleId = _schedule?['id']?.toString();
    final userId = member['user_id']?.toString();
    if (scheduleId == null || userId == null || userId.isEmpty) return;

    setState(() => _savingMembers.add(userId));

    try {
      final response = await ApiClient.postData(
        'attendance/save_attendance_assessment.php',
        {
          'schedule_id': scheduleId,
          'user_id': userId,
          'status': _selectedStatuses[userId] ?? 'absent',
          'notes': _noteControllers[userId]?.text.trim() ?? '',
        },
      );

      if (response['status'] != 'success') {
        throw Exception(response['message'] ?? 'Unable to save assessment.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Berjaya disimpan.')),
      );
      await _loadAssessment();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingMembers.remove(userId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(settings.t('Penilaian Kehadiran'))),
      body: RefreshIndicator(
        onRefresh: _loadAssessment,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            CommandHeader(
              title: settings.t('Penilaian Kehadiran'),
              subtitle: settings.t(
                'Sahkan status kehadiran ahli skuad untuk jadual rondaan ini.',
              ),
              icon: Icons.fact_check_outlined,
              compact: true,
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _buildErrorPanel(theme)
            else if (_schedule == null)
              _buildEmptyPanel(settings, theme)
            else ...[
              _buildSummary(settings, theme),
              const SizedBox(height: 12),
              ..._members.map((member) => _buildMemberCard(member, settings)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(SettingsProvider settings, ThemeData theme) {
    final squadName =
        _squad?['squad_name']?.toString() ??
        _squad?['name']?.toString() ??
        settings.t('Skuad belum ditetapkan');
    final scheduleText =
        '${_schedule?['shift_date'] ?? '-'}  ${_schedule?['start_time'] ?? '-'} - ${_schedule?['end_time'] ?? '-'}';
    final acknowledged = _members
        .where((member) => member['is_acknowledged'] == true)
        .length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: commandCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            squadName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            scheduleText,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: _members.isEmpty ? 0 : acknowledged / _members.length,
            minHeight: 7,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 8),
          Text(
            '${settings.t("Disahkan")}: $acknowledged/${_members.length}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(
    Map<String, dynamic> member,
    SettingsProvider settings,
  ) {
    final theme = Theme.of(context);
    final userId = member['user_id']?.toString() ?? '';
    final isSaving = _savingMembers.contains(userId);
    final hasClockIn = member['has_clock_in'] == true;
    final hasClockOut = member['has_clock_out'] == true;
    final isAcknowledged = member['is_acknowledged'] == true;
    final selectedStatus = _selectedStatuses[userId] ?? 'absent';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  child: Icon(
                    member['squad_role'] == 'leader'
                        ? Icons.shield_outlined
                        : Icons.person_outline,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member['full_name']?.toString() ?? settings.t('Ahli'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasClockIn
                            ? '${settings.t("Imbas Masuk")}: ${member['clock_in_time']}${hasClockOut ? " | ${settings.t("Imbas Keluar")}: ${member['clock_out_time']}" : ""}'
                            : settings.t('Tiada rekod imbas QR.'),
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.72,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isAcknowledged
                      ? Icons.verified_outlined
                      : Icons.pending_actions_outlined,
                  color: isAcknowledged ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedStatus,
              isExpanded: true,
              decoration: InputDecoration(labelText: settings.t('Status')),
              items: _statusLabels.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(settings.t(entry.value)),
                    ),
                  )
                  .toList(),
              onChanged: isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _selectedStatuses[userId] = value);
                    },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteControllers[userId],
              enabled: !isSaving,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: settings.t('Catatan'),
                hintText: settings.t('Contoh: hadir tetapi lewat 10 minit'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isSaving ? null : () => _saveAssessment(member),
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.task_alt_outlined),
              label: Text(settings.t('Sahkan Kehadiran')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.24)),
      ),
      child: Text(
        _errorMessage!,
        style: TextStyle(
          color: theme.brightness == Brightness.dark
              ? Colors.red.shade100
              : Colors.red.shade800,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyPanel(SettingsProvider settings, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: commandCardDecoration(context),
      child: Column(
        children: [
          Icon(Icons.event_busy_outlined, size: 42, color: theme.disabledColor),
          const SizedBox(height: 12),
          Text(
            settings.t('Tiada jadual rondaan untuk dinilai.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.disabledColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
