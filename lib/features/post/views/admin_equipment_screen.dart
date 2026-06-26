// File: lib/features/post/views/admin_equipment_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/settings_provider.dart';

class AdminEquipmentScreen extends StatefulWidget {
  const AdminEquipmentScreen({super.key});

  @override
  State<AdminEquipmentScreen> createState() => _AdminEquipmentScreenState();
}

class _AdminEquipmentScreenState extends State<AdminEquipmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> _inventory = [];
  List<dynamic> _logs = [];
  List<dynamic> _pendingReturns = [];

  bool _isLoadingInventory = false;
  bool _isLoadingLogs = false;
  bool _isLoadingReturns = false;

  String? _inventoryError;
  String? _logsError;
  String? _returnsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchInventory();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      if (mounted) setState(() {});
      return;
    }
    if (mounted) setState(() {});
    switch (_tabController.index) {
      case 0:
        _fetchInventory();
        break;
      case 1:
        _fetchLogs();
        break;
      case 2:
        _fetchPendingReturns();
        break;
    }
  }

  Future<void> _fetchInventory() async {
    if (mounted) {
      setState(() {
        _isLoadingInventory = true;
        _inventoryError = null;
      });
    }

    try {
      final response = await ApiClient.getData('equipment/get_inventory.php');
      if (response['status'] == 'success') {
        if (mounted) {
          setState(() {
            _inventory = response['data'] ?? [];
            _isLoadingInventory = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _inventoryError =
                response['message'] ?? 'Ralat memuatkan inventori.';
            _isLoadingInventory = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inventoryError = 'Ralat Rangkaian: $e';
          _isLoadingInventory = false;
        });
      }
    }
  }

  Future<void> _fetchLogs() async {
    if (mounted) {
      setState(() {
        _isLoadingLogs = true;
        _logsError = null;
      });
    }

    try {
      final response = await ApiClient.getData('equipment/get_logs.php');
      if (response['status'] == 'success') {
        if (mounted) {
          setState(() {
            _logs = response['data'] ?? [];
            _isLoadingLogs = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _logsError = response['message'] ?? 'Ralat memuatkan log.';
            _isLoadingLogs = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logsError = 'Ralat Rangkaian: $e';
          _isLoadingLogs = false;
        });
      }
    }
  }

  Future<void> _fetchPendingReturns() async {
    if (mounted) {
      setState(() {
        _isLoadingReturns = true;
        _returnsError = null;
      });
    }

    try {
      final response = await ApiClient.getData(
        'attendance/get_pending_returns.php',
      );
      if (response['status'] == 'success') {
        if (mounted) {
          setState(() {
            _pendingReturns = response['data'] ?? [];
            _isLoadingReturns = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _returnsError =
                response['message'] ?? 'Gagal memuatkan pemulangan.';
            _isLoadingReturns = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _returnsError = 'Ralat Rangkaian: $e';
          _isLoadingReturns = false;
        });
      }
    }
  }

  Future<void> _acknowledgeReturn(
    Map<String, dynamic> pendingReturn,
    SettingsProvider settings,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isLoadingReturns = true);

    try {
      final response = await ApiClient.postData(
        'attendance/acknowledge_return.php',
        {'attendance_id': pendingReturn['id'].toString()},
      );

      if (!mounted) return;
      if (response['status'] == 'success') {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(settings.t('Pemulangan peronda telah disahkan.')),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchPendingReturns();
        await _fetchLogs();
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ??
                  settings.t('Gagal mengesahkan pemulangan.'),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${settings.t('Ralat Rangkaian')}: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingReturns = false);
      }
    }
  }

  Future<void> _showAddEquipmentDialog(SettingsProvider settings) async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(
            Icons.add_box_outlined,
            color: Colors.lightBlueAccent,
            size: 40,
          ),
          title: Text(settings.t('Tambah Peralatan')),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: settings.t('Nama Peralatan'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return settings.t('Nama peralatan tidak boleh kosong');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: settings.t('Kuantiti'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return settings.t('Kuantiti tidak boleh kosong');
                    }
                    final qty = int.tryParse(value);
                    if (qty == null || qty < 0) {
                      return settings.t('Sila masukkan kuantiti yang sah');
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(settings.t('Batal')),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final navigator = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);

                  final Map<String, String> payload = {
                    'action': 'add',
                    'item_name': nameController.text.trim(),
                    'total_quantity': quantityController.text,
                  };

                  try {
                    final response = await ApiClient.postData(
                      'equipment/manage_equipment.php',
                      payload,
                    );
                    if (response['status'] == 'success') {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            settings.t(
                              response['message'] ?? 'Berjaya ditambah!',
                            ),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                      navigator.pop();
                      _fetchInventory();
                    } else {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            settings.t(
                              response['message'] ?? 'Gagal menambah.',
                            ),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(settings.t('Tambah')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditEquipmentDialog(
    Map<String, dynamic> item,
    SettingsProvider settings,
  ) async {
    final nameController = TextEditingController(text: item['item_name']);
    final quantityController = TextEditingController(
      text: item['total_quantity'].toString(),
    );
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(
            Icons.edit_note_outlined,
            color: Colors.orangeAccent,
            size: 40,
          ),
          title: Text(settings.t('Kemaskini Peralatan')),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: settings.t('Nama Peralatan'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return settings.t('Nama peralatan tidak boleh kosong');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: settings.t('Kuantiti'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return settings.t('Kuantiti tidak boleh kosong');
                    }
                    final qty = int.tryParse(value);
                    if (qty == null || qty < 0) {
                      return settings.t('Sila masukkan kuantiti yang sah');
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(settings.t('Batal')),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final navigator = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);

                  final Map<String, String> payload = {
                    'action': 'update',
                    'id': item['id'].toString(),
                    'item_name': nameController.text.trim(),
                    'total_quantity': quantityController.text,
                  };

                  try {
                    final response = await ApiClient.postData(
                      'equipment/manage_equipment.php',
                      payload,
                    );
                    if (response['status'] == 'success') {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            settings.t(
                              response['message'] ?? 'Berjaya dikemaskini!',
                            ),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                      navigator.pop();
                      _fetchInventory();
                    } else {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            settings.t(
                              response['message'] ?? 'Gagal mengemaskini.',
                            ),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(settings.t('Simpan')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteEquipmentConfirm(
    Map<String, dynamic> item,
    SettingsProvider settings,
  ) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.redAccent,
            size: 40,
          ),
          title: Text(settings.t('Padam Peralatan')),
          content: Text(
            '${settings.t('Adakah anda pasti mahu memadam peralatan')} "${item['item_name']}"? \n\n${settings.t('Ini juga akan memadam semua log yang berkaitan.')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(settings.t('Batal')),
            ),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                final Map<String, String> payload = {
                  'action': 'delete',
                  'id': item['id'].toString(),
                };

                try {
                  final response = await ApiClient.postData(
                    'equipment/manage_equipment.php',
                    payload,
                  );
                  if (response['status'] == 'success') {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          settings.t(response['message'] ?? 'Berjaya dipadam!'),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    navigator.pop();
                    _fetchInventory();
                  } else {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          settings.t(response['message'] ?? 'Gagal memadam.'),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text(settings.t('Padam')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: settings.t('Inventori')),
                    Tab(text: settings.t('Rekod Log')),
                    Tab(text: settings.t('Pemulangan')),
                  ],
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.unselectedWidgetColor,
                  indicatorColor: theme.colorScheme.primary,
                ),
              ),
              if (_tabController.index == 0)
                IconButton(
                  icon: Icon(
                    Icons.add_box_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  tooltip: settings.t('Tambah Peralatan'),
                  onPressed: () => _showAddEquipmentDialog(settings),
                ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Inventory
          RefreshIndicator(
            onRefresh: _fetchInventory,
            child: _buildInventoryTab(settings, theme),
          ),
          // Tab 2: Logs
          RefreshIndicator(
            onRefresh: _fetchLogs,
            child: _buildLogsTab(settings, theme),
          ),
          // Tab 3: Pending return acknowledgements
          RefreshIndicator(
            onRefresh: _fetchPendingReturns,
            child: _buildPendingReturnsTab(settings, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTab(SettingsProvider settings, ThemeData theme) {
    if (_isLoadingInventory && _inventory.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.lightBlueAccent),
      );
    }

    if (_inventoryError != null && _inventory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                _inventoryError!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchInventory,
                icon: const Icon(Icons.refresh),
                label: Text(settings.t('Cuba Lagi')),
              ),
            ],
          ),
        ),
      );
    }

    if (_inventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              settings.t('Tiada peralatan direkodkan.'),
              style: TextStyle(color: theme.disabledColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _inventory.length,
      itemBuilder: (context, index) {
        final item = _inventory[index];
        final name = item['item_name'] ?? '';
        final total = int.tryParse(item['total_quantity'].toString()) ?? 0;
        final available =
            int.tryParse(item['available_quantity'].toString()) ?? 0;
        final borrowed = total - available;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: (available > 0 ? Colors.green : Colors.red)
                      .withValues(alpha: 0.1),
                  radius: 24,
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: available > 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildInventoryBadge(
                            settings.t('Tinggal'),
                            '$available/$total',
                            available > 0 ? Colors.green : Colors.red,
                          ),
                          _buildInventoryBadge(
                            settings.t('Dipinjam'),
                            borrowed.toString(),
                            borrowed > 0 ? Colors.orange : Colors.grey,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Colors.blueAccent,
                  ),
                  onPressed: () => _showEditEquipmentDialog(item, settings),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => _showDeleteEquipmentConfirm(item, settings),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInventoryBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildLogsTab(SettingsProvider settings, ThemeData theme) {
    if (_isLoadingLogs && _logs.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.lightBlueAccent),
      );
    }

    if (_logsError != null && _logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                _logsError!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchLogs,
                icon: const Icon(Icons.refresh),
                label: Text(settings.t('Cuba Lagi')),
              ),
            ],
          ),
        ),
      );
    }

    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_edu_outlined,
              size: 64,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              settings.t('Tiada rekod penggunaan peralatan.'),
              style: TextStyle(color: theme.disabledColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        final patrollerName = log['patroller_name'] ?? 'Peronda';
        final phone = log['phone_number'] ?? '';
        final borrowedAtStr = log['borrowed_at'] ?? '';
        final returnedAtStr = log['returned_at'];
        final String rawItems = log['items'] ?? '';
        final List<String> itemList = rawItems.isEmpty
            ? []
            : rawItems.split(', ');

        final DateTime borrowedTime = DateTime.parse(borrowedAtStr);
        final String borrowedFormatted = DateFormat(
          'dd MMM yyyy, hh:mm a',
        ).format(borrowedTime);

        String returnedFormatted = '';
        bool isReturned = returnedAtStr != null;
        if (isReturned) {
          final DateTime returnedTime = DateTime.parse(returnedAtStr);
          returnedFormatted = DateFormat(
            'dd MMM yyyy, hh:mm a',
          ).format(returnedTime);
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        patrollerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    _buildStatusBadge(isReturned, settings),
                  ],
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.6,
                      ),
                      fontSize: 12,
                    ),
                  ),
                ],
                const Divider(height: 24),
                _buildBorrowedItemsSection(itemList, settings, theme),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 16,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${settings.t('Diambil')}: $borrowedFormatted',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (isReturned) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.arrow_downward_rounded,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${settings.t('Dipulangkan')}: $returnedFormatted',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingReturnsTab(SettingsProvider settings, ThemeData theme) {
    if (_isLoadingReturns && _pendingReturns.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.lightBlueAccent),
      );
    }

    if (_returnsError != null && _pendingReturns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                _returnsError!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchPendingReturns,
                icon: const Icon(Icons.refresh),
                label: Text(settings.t('Cuba Lagi')),
              ),
            ],
          ),
        ),
      );
    }

    if (_pendingReturns.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),
          Icon(Icons.fact_check_outlined, size: 64, color: theme.disabledColor),
          const SizedBox(height: 16),
          Center(
            child: Text(
              settings.t('Tiada pemulangan menunggu pengesahan.'),
              style: TextStyle(color: theme.disabledColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _pendingReturns.length,
      itemBuilder: (context, index) {
        final pendingReturn = _pendingReturns[index] as Map<String, dynamic>;
        final equipment = List<String>.from(
          pendingReturn['equipment'] ?? const [],
        );
        final requestedAt =
            pendingReturn['return_requested_at']?.toString() ?? '';
        String requestedAtText = requestedAt;
        if (requestedAt.isNotEmpty) {
          try {
            requestedAtText = DateFormat(
              'dd MMM yyyy, hh:mm a',
            ).format(DateTime.parse(requestedAt));
          } catch (_) {
            requestedAtText = requestedAt;
          }
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.orange.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.assignment_return_outlined,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pendingReturn['full_name'] ?? settings.t('Peronda'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (requestedAtText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${settings.t('Diminta pada')}: $requestedAtText',
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.65),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildBorrowedItemsSection(equipment, settings, theme),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLoadingReturns
                        ? null
                        : () => _acknowledgeReturn(pendingReturn, settings),
                    icon: const Icon(Icons.task_alt_rounded),
                    label: Text(settings.t('Sahkan Pemulangan')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBorrowedItemsSection(
    List<String> itemList,
    SettingsProvider settings,
    ThemeData theme,
  ) {
    if (itemList.isEmpty) {
      return Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 16,
            color: theme.disabledColor,
          ),
          const SizedBox(width: 8),
          Text(
            settings.t('Tiada peralatan direkodkan.'),
            style: TextStyle(fontSize: 13, color: theme.disabledColor),
          ),
        ],
      );
    }

    final bool isALot = itemList.length > 2;
    final displayItems = isALot ? itemList.take(2).toList() : itemList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 16,
              color: theme.primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${settings.t("Peralatan")}: ${displayItems.join(", ")}${isALot ? "..." : ""}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (isALot) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () =>
                          _showBorrowedItemsDrawer(itemList, settings, theme),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${settings.t("Lihat Semua")} (${itemList.length})',
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: theme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showBorrowedItemsDrawer(
    List<String> itemList,
    SettingsProvider settings,
    ThemeData theme,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.inventory_2, color: theme.primaryColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      settings.t('Senarai Peralatan Dipinjam'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: itemList.length,
                  itemBuilder: (context, idx) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            itemList[idx],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(settings.t('Tutup')),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(bool isReturned, SettingsProvider settings) {
    final bgColor = (isReturned ? Colors.green : Colors.orange).withValues(
      alpha: 0.15,
    );
    final textColor = isReturned
        ? Colors.green.shade800
        : Colors.orange.shade800;
    final text = isReturned
        ? settings.t('Telah Dipulangkan')
        : settings.t('Sedang Digunakan');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
