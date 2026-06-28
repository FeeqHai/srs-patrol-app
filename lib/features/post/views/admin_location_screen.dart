import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/settings_provider.dart';

class AdminLocationScreen extends StatefulWidget {
  const AdminLocationScreen({super.key});

  @override
  State<AdminLocationScreen> createState() => _AdminLocationScreenState();
}

class _AdminLocationScreenState extends State<AdminLocationScreen> {
  List<Map<String, dynamic>> _states = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<void> _fetchLocations({bool showLoading = true}) async {
    if (showLoading || _states.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final data =
          await ApiClient.getData('admin/locations.php?action=list')
              as Map<String, dynamic>;
      if (data['status'] != 'success') {
        throw Exception(data['message'] ?? 'Unable to load locations.');
      }
      if (!mounted) return;
      setState(() {
        _states = (data['data'] as List<dynamic>? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Ralat Rangkaian: $e';
      });
    }
  }

  Future<bool> _post(Map<String, String> body) async {
    final settings = context.read<SettingsProvider>();

    try {
      final data = await ApiClient.postData('admin/locations.php', body);

      if (!mounted) return false;

      final ok = data['status'] == 'success';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? settings.t('Kemas kini selesai')),
          backgroundColor: ok ? Colors.green : Colors.redAccent,
        ),
      );

      if (ok) {
        await _fetchLocations(showLoading: false);
      }
      return ok;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.t('Ralat Rangkaian')}: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }
  }

  String _locationKeyValue(
    String type,
    Map<String, dynamic> item,
    int index,
    String parentKey,
  ) {
    final rawId = item['id']?.toString().trim();
    final id = rawId == null || rawId.isEmpty || rawId == 'null'
        ? 'missing-id'
        : rawId;
    return '$type-$parentKey-$index-$id';
  }

  Future<void> _popDialogSafely(BuildContext dialogContext) async {
    FocusScope.of(dialogContext).unfocus();
    await Future<void>.delayed(Duration.zero);
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
  }

  Future<void> _showCreateDialog({
    required String action,
    required String title,
    String? parentKey,
    String? parentId,
    bool includeCode = false,
  }) async {
    final settings = context.read<SettingsProvider>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _LocationFormDialog(
        title: title,
        includeCode: includeCode,
        codeLabel: settings.t('Kod Negeri'),
        nameLabel: includeCode ? settings.t('Nama Negeri') : settings.t('Nama'),
        requiredMessage: settings.t('Medan ini diperlukan'),
        cancelLabel: settings.t('Batal'),
        submitLabel: settings.t('Tambah'),
        loadingLabel: settings.t('Menyimpan...'),
        onSubmit: (name, code) {
          return _post({
            'action': action,
            'name': name,
            if (includeCode && code != null) 'code': code,
            if (parentKey != null && parentId != null) parentKey: parentId,
          });
        },
      ),
    );
  }

  Future<void> _showRenameDialog({
    required String type,
    required Map<String, dynamic> item,
    bool includeCode = false,
  }) async {
    final settings = context.read<SettingsProvider>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _LocationFormDialog(
        title: settings.t('Namakan Semula'),
        includeCode: includeCode,
        initialName: item['name']?.toString() ?? '',
        initialCode: item['code']?.toString() ?? '',
        codeLabel: settings.t('Kod Negeri'),
        nameLabel: includeCode ? settings.t('Nama Negeri') : settings.t('Nama'),
        requiredMessage: settings.t('Medan ini diperlukan'),
        cancelLabel: settings.t('Batal'),
        submitLabel: settings.t('Simpan'),
        loadingLabel: settings.t('Menyimpan...'),
        onSubmit: (name, code) {
          return _post({
            'action': 'update',
            'type': type,
            'id': item['id'].toString(),
            'name': name,
            if (includeCode && code != null) 'code': code,
          });
        },
      ),
    );
  }

  Future<void> _confirmToggle({
    required String type,
    required Map<String, dynamic> item,
    required bool isActive,
  }) async {
    final settings = context.read<SettingsProvider>();
    if (!isActive) {
      await _post({
        'action': 'activate',
        'type': type,
        'id': item['id'].toString(),
      });
      return;
    }

    final usageCount = int.tryParse('${item['usage_count'] ?? 0}') ?? 0;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var isSaving = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(settings.t('Nyahaktifkan Lokasi')),
              content: Text(
                usageCount > 0
                    ? '${settings.t('Lokasi ini digunakan oleh rekod sedia ada')}: $usageCount. ${settings.t('Rekod lama akan dikekalkan, tetapi lokasi ini tidak akan muncul untuk pendaftaran baharu.')}'
                    : settings.t(
                        'Lokasi ini tidak akan muncul untuk pendaftaran baharu.',
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => _popDialogSafely(dialogContext),
                  child: Text(settings.t('Batal')),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final ok = await _post({
                            'action': 'deactivate',
                            'type': type,
                            'id': item['id'].toString(),
                          });
                          if (!dialogContext.mounted) return;
                          if (ok) {
                            await _popDialogSafely(dialogContext);
                          } else {
                            setDialogState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(
                                  dialogContext,
                                ).colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(settings.t('Menyimpan...')),
                          ],
                        )
                      : Text(settings.t('Nyahaktifkan')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusChip(dynamic active, SettingsProvider settings) {
    final isActive = active.toString() == '1';
    return Chip(
      label: Text(settings.t(isActive ? 'Aktif' : 'Nyahaktif')),
      visualDensity: VisualDensity.compact,
      backgroundColor: (isActive ? Colors.green : Colors.redAccent).withValues(
        alpha: 0.12,
      ),
    );
  }

  PopupMenuButton<String> _itemMenu({
    required String type,
    required Map<String, dynamic> item,
    bool includeCode = false,
  }) {
    final settings = context.read<SettingsProvider>();
    final isActive = item['is_active'].toString() == '1';
    return PopupMenuButton<String>(
      onSelected: (value) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;

          // Give PopupMenuButton enough time to fully close.
          await Future<void>.delayed(const Duration(milliseconds: 120));

          if (!mounted) return;

          if (value == 'rename') {
            await _showRenameDialog(
              type: type,
              item: item,
              includeCode: includeCode,
            );
          } else {
            await _confirmToggle(type: type, item: item, isActive: isActive);
          }
        });
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'rename',
          child: Text(settings.t('Namakan Semula')),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Text(settings.t(isActive ? 'Nyahaktifkan' : 'Aktifkan')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Column(
      children: [
        Material(
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    settings.t('Pengurusan Lokasi'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showCreateDialog(
                    action: 'create_state',
                    title: settings.t('Tambah Negeri'),
                    includeCode: true,
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(settings.t('Negeri')),
                ),
              ],
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchLocations,
            child: _isLoading
                ? ListView(
                    children: [
                      const SizedBox(height: 180),
                      Center(
                        child: CircularProgressIndicator(
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _states.length,
                    itemBuilder: (context, index) {
                      final state = _states[index];
                      final stateKey = _locationKeyValue(
                        'state',
                        state,
                        index,
                        'root',
                      );
                      final districts =
                          (state['districts'] as List<dynamic>? ?? [])
                              .cast<Map<String, dynamic>>();
                      return Card(
                        child: ExpansionTile(
                          title: Text(state['name']?.toString() ?? '-'),
                          key: PageStorageKey(stateKey),
                          subtitle: Text(state['code']?.toString() ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _statusChip(state['is_active'], settings),
                              _itemMenu(
                                type: 'state',
                                item: state,
                                includeCode: true,
                              ),
                            ],
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _showCreateDialog(
                                  action: 'create_district',
                                  title: settings.t('Tambah Daerah'),
                                  parentKey: 'state_id',
                                  parentId: state['id'].toString(),
                                ),
                                icon: const Icon(Icons.add),
                                label: Text(settings.t('Tambah Daerah')),
                              ),
                            ),
                            ...districts.asMap().entries.map((districtEntry) {
                              final district = districtEntry.value;
                              final districtKey = _locationKeyValue(
                                'district',
                                district,
                                districtEntry.key,
                                stateKey,
                              );
                              final zones =
                                  (district['zones'] as List<dynamic>? ?? [])
                                      .cast<Map<String, dynamic>>();
                              return ExpansionTile(
                                key: PageStorageKey(districtKey),
                                title: Text(
                                  district['name']?.toString() ?? '-',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _statusChip(
                                      district['is_active'],
                                      settings,
                                    ),
                                    _itemMenu(type: 'district', item: district),
                                  ],
                                ),
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => _showCreateDialog(
                                        action: 'create_zone',
                                        title: settings.t('Tambah Zon'),
                                        parentKey: 'district_id',
                                        parentId: district['id'].toString(),
                                      ),
                                      icon: const Icon(Icons.add),
                                      label: Text(settings.t('Tambah Zon')),
                                    ),
                                  ),
                                  ...zones.asMap().entries.map((zoneEntry) {
                                    final zone = zoneEntry.value;
                                    final zoneKey = _locationKeyValue(
                                      'zone',
                                      zone,
                                      zoneEntry.key,
                                      districtKey,
                                    );
                                    return ListTile(
                                      key: ValueKey(zoneKey),
                                      title: Text(
                                        zone['name']?.toString() ?? '-',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _statusChip(
                                            zone['is_active'],
                                            settings,
                                          ),
                                          _itemMenu(type: 'zone', item: zone),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _LocationFormDialog extends StatefulWidget {
  const _LocationFormDialog({
    required this.title,
    required this.includeCode,
    required this.codeLabel,
    required this.nameLabel,
    required this.requiredMessage,
    required this.cancelLabel,
    required this.submitLabel,
    required this.loadingLabel,
    required this.onSubmit,
    this.initialName = '',
    this.initialCode = '',
  });

  final String title;
  final bool includeCode;
  final String codeLabel;
  final String nameLabel;
  final String requiredMessage;
  final String cancelLabel;
  final String submitLabel;
  final String loadingLabel;
  final String initialName;
  final String initialCode;
  final Future<bool> Function(String name, String? code) onSubmit;

  @override
  State<_LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<_LocationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _codeController = TextEditingController(text: widget.initialCode);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _closeSafely() async {
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(Duration.zero);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    final ok = await widget.onSubmit(
      _nameController.text.trim(),
      widget.includeCode ? _codeController.text.trim() : null,
    );

    if (!mounted) return;
    if (ok) {
      await _closeSafely();
    } else {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(widget.title),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.includeCode) ...[
                TextFormField(
                  controller: _codeController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: widget.codeLabel),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? widget.requiredMessage
                      : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nameController,
                enabled: !_isSaving,
                decoration: InputDecoration(labelText: widget.nameLabel),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? widget.requiredMessage
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _closeSafely,
            child: Text(widget.cancelLabel),
          ),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(widget.loadingLabel),
                    ],
                  )
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}
