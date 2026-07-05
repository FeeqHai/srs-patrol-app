import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/command_center_widgets.dart';
import '../providers/incident_provider.dart';
import '../../auth/providers/auth_provider.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String? _selectedCategory;
  String? _selectedReportedTo;
  final List<String> _jpninIncidentTypes = [
    'Jenayah Kekerasan - Pembunuhan',
    'Jenayah Kekerasan - Rogol',
    'Jenayah Kekerasan - Cabul Kehormatan',
    'Jenayah Kekerasan - Samun',
    'Jenayah Kekerasan - Peras Ugut',
    'Jenayah Kekerasan - Merusuh',
    'Jenayah Kekerasan - Mencedera / Penderaan',
    'Jenayah Harta Benda - Curi Kenderaan',
    'Jenayah Harta Benda - Curi Harta Benda',
    'Jenayah Harta Benda - Pecah Rumah',
    'Jenayah Narkotik - Pengedaran Dadah',
    'Jenayah Narkotik - Memiliki Dadah',
    'Gejala Sosial - Pertengkaran',
    'Gejala Sosial - Lepak',
    'Gejala Sosial - Vandalisme',
    'Gejala Sosial - Khalwat / Maksiat',
    'Gejala Sosial - Pergaduhan',
    'Gejala Sosial - Pendatang Tanpa Izin',
    'Gejala Sosial - Lumba Haram',
    'Gejala Sosial - Penagihan Dadah',
    'Gejala Sosial - Masalah Rumah Tangga',
    'Gejala Sosial - Ponteng',
    'Gejala Sosial - Kutu Rayau',
    'Gejala Sosial - Buang Bayi',
    'Lain-lain',
  ];

  final List<File> _images = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLocating = true;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLocating = false);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _currentPosition = position;

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = [
          place.street,
          place.subLocality,
          place.locality,
        ].where((e) => e != null && e.isNotEmpty).join(', ');

        if (mounted) {
          setState(() {
            _locationController.text = address;
          });
        }
      }
    } catch (e) {
      // Location fetch failed
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (photo != null) {
      setState(() => _images.add(File(photo.path)));
    }
  }

  Future<void> _submitReport() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      _showSnackBar(
        context.read<SettingsProvider>().t('Sila pilih kategori insiden.'),
        Colors.redAccent,
      );
      return;
    }

    if (_selectedReportedTo == null || _selectedReportedTo!.isEmpty) {
      _showSnackBar(
        context.read<SettingsProvider>().t('Sila pilih agensi rujukan.'),
        Colors.redAccent,
      );
      return;
    }

    // Images are now OPTIONAL! No validation check here.

    final String? currentUserId = context.read<AuthProvider>().userId;
    if (currentUserId == null) {
      _showSnackBar(
        context.read<SettingsProvider>().t(
          'Ralat Sesi: Sila log masuk semula.',
        ),
        Colors.redAccent,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              context.read<SettingsProvider>().t('Preparing note...'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    final provider = context.read<IncidentProvider>();
    final bool success = await provider.createIncidentReport(
      userId: currentUserId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _selectedCategory!,
      locationName: _locationController.text.trim(),
      reportedTo: _selectedReportedTo!,
      imageFiles: _images,
      location: _currentPosition,
    );

    if (!mounted) return;

    Navigator.pop(context); // close dialog

    if (success) {
      Navigator.pop(context, true);
    } else {
      _showSnackBar(
        '${context.read<SettingsProvider>().t('RALAT:')} ${provider.errorMessage}',
        Colors.red,
      );
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool isOptional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          if (isOptional)
            const Text(
              ' (Pilihan)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(settings.t('Nota Harian')), elevation: 0),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final horizontalPadding = isMobile ? 12.0 : 24.0;
            final cardPadding = isMobile ? 16.0 : 20.0;
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            final menuWidth = (constraints.maxWidth - (horizontalPadding * 2))
                .clamp(260.0, 420.0);

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                24 + bottomInset,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CommandHeader(
                          title: settings.t('Nota Harian Rondaan'),
                          subtitle: settings.t(
                            'Rekod pemerhatian, lokasi, agensi rujukan, dan bukti gambar secara tersusun.',
                          ),
                          icon: Icons.edit_note_rounded,
                          compact: true,
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 4,
                          shadowColor: Colors.black.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(cardPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSectionTitle(
                                  settings.t('Kategori Insiden'),
                                ),
                                Autocomplete<String>(
                                  optionsBuilder:
                                      (TextEditingValue textEditingValue) {
                                        if (textEditingValue.text.isEmpty) {
                                          return _jpninIncidentTypes;
                                        }
                                        return _jpninIncidentTypes.where(
                                          (String option) =>
                                              option.toLowerCase().contains(
                                                textEditingValue.text
                                                    .toLowerCase(),
                                              ),
                                        );
                                      },
                                  onSelected: (String selection) => setState(
                                    () => _selectedCategory = selection,
                                  ),
                                  fieldViewBuilder:
                                      (
                                        context,
                                        controller,
                                        focusNode,
                                        onEditingComplete,
                                      ) {
                                        return TextFormField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          onEditingComplete: onEditingComplete,
                                          decoration: InputDecoration(
                                            hintText: settings.t(
                                              'Cari kategori (cth: Samun)...',
                                            ),
                                            suffixIcon: const Icon(
                                              Icons.search,
                                            ),
                                            filled: true,
                                            errorMaxLines: 3,
                                            helperMaxLines: 2,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                          validator: (value) =>
                                              value == null || value.isEmpty
                                              ? settings.t(
                                                  'Sila pilih kategori',
                                                )
                                              : null,
                                        );
                                      },
                                  optionsViewBuilder:
                                      (context, onSelected, options) {
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Material(
                                            elevation: 4.0,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxHeight: 250,
                                                maxWidth: menuWidth,
                                              ),
                                              child: ListView.builder(
                                                padding: EdgeInsets.zero,
                                                shrinkWrap: true,
                                                itemCount: options.length,
                                                itemBuilder:
                                                    (
                                                      BuildContext context,
                                                      int index,
                                                    ) {
                                                      final String option =
                                                          options.elementAt(
                                                            index,
                                                          );
                                                      return InkWell(
                                                        onTap: () =>
                                                            onSelected(option),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                16.0,
                                                              ),
                                                          child: Text(
                                                            option,
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                ),

                                _buildSectionTitle(
                                  settings.t('Agensi Dirujuk (Lampiran 6)'),
                                ),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedReportedTo,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    hintText: settings.t('Pilih agensi'),
                                    filled: true,
                                    errorMaxLines: 3,
                                    helperMaxLines: 2,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  items:
                                      [
                                            'Tiada',
                                            'Polis',
                                            'Jabatan Agama / JAKIM',
                                            'PBT',
                                            'JKM',
                                            'Lain-lain',
                                          ]
                                          .map(
                                            (String value) =>
                                                DropdownMenuItem<String>(
                                                  value: value,
                                                  child: Text(
                                                    value,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                          )
                                          .toList(),
                                  selectedItemBuilder: (context) =>
                                      [
                                            'Tiada',
                                            'Polis',
                                            'Jabatan Agama / JAKIM',
                                            'PBT',
                                            'JKM',
                                            'Lain-lain',
                                          ]
                                          .map(
                                            (value) => Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                value,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (newValue) => setState(
                                    () => _selectedReportedTo = newValue,
                                  ),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? settings.t('Sila pilih agensi dirujuk')
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Card(
                          elevation: 4,
                          shadowColor: Colors.black.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(cardPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSectionTitle(settings.t('Tajuk Laporan')),
                                TextFormField(
                                  controller: _titleController,
                                  decoration: InputDecoration(
                                    hintText: settings.t('Cth: Pagar rosak'),
                                    filled: true,
                                    errorMaxLines: 3,
                                    helperMaxLines: 2,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? settings.t('Sila masukkan tajuk')
                                      : null,
                                ),

                                _buildSectionTitle(
                                  settings.t('Lokasi Rondaan'),
                                ),
                                TextFormField(
                                  controller: _locationController,
                                  decoration: InputDecoration(
                                    hintText: settings.t(
                                      'Cth: Lorong 39, Scientex',
                                    ),
                                    filled: true,
                                    errorMaxLines: 3,
                                    helperMaxLines: 2,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    suffixIcon: _isLocating
                                        ? const Padding(
                                            padding: EdgeInsets.all(12.0),
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.location_on,
                                            color: Colors.redAccent,
                                          ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? settings.t('Sila masukkan lokasi')
                                      : null,
                                ),

                                _buildSectionTitle(
                                  settings.t(
                                    'Peristiwa Berlaku Semasa Rondaan',
                                  ),
                                ),
                                TextFormField(
                                  controller: _descController,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText: settings.t(
                                      'Terangkan butiran...',
                                    ),
                                    filled: true,
                                    errorMaxLines: 3,
                                    helperMaxLines: 2,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? settings.t('Sila terangkan butiran')
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Card(
                          elevation: 4,
                          shadowColor: Colors.black.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(cardPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSectionTitle(
                                  settings.t('Gambar Bukti'),
                                  isOptional: true,
                                ),
                                Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: theme.scaffoldBackgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.dividerColor.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.all(12),
                                    children: [
                                      ..._images.map(
                                        (file) => Stack(
                                          children: [
                                            Container(
                                              width: 100,
                                              margin: const EdgeInsets.only(
                                                right: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                image: DecorationImage(
                                                  image: FileImage(file),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              right: 16,
                                              top: 4,
                                              child: GestureDetector(
                                                onTap: () => setState(
                                                  () => _images.remove(file),
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.black54,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _takePhoto,
                                        child: Container(
                                          width: 100,
                                          decoration: BoxDecoration(
                                            color: theme.dividerColor
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: theme.dividerColor
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.add_a_photo,
                                                size: 32,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(height: 8),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                    ),
                                                child: Text(
                                                  settings.t('Tambah'),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        SizedBox(
                          height: 55,
                          child: ElevatedButton.icon(
                            onPressed: _submitReport,
                            icon: const Icon(Icons.save),
                            label: Text(
                              settings.t('HANTAR NOTA HARIAN'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2DA44E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
