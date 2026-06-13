import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/widgets/image_viewer_screen.dart';

class IncidentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> incident;

  const IncidentDetailScreen({super.key, required this.incident});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  List<dynamic> _addendums = [];
  bool _isLoading = true;
  final TextEditingController _addendumController = TextEditingController();
  final List<File> _addendumImages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchAddendums();
  }

  Future<void> _fetchAddendums() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}incidents/get_addendums.php?incident_id=${widget.incident['id']}'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        setState(() {
          _addendums = body['data'];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load addendums');
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAddendumImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (image != null) {
      setState(() => _addendumImages.add(File(image.path)));
    }
  }

  List<String> _parseImages(dynamic imageUrlData) {
    if (imageUrlData == null || imageUrlData.toString().isEmpty) return [];
    try {
      if (imageUrlData.toString().trim().startsWith('[')) {
        List<dynamic> parsed = json.decode(imageUrlData);
        return parsed.map((e) => e.toString()).toList();
      }
    } catch (e) {}
    return [imageUrlData.toString()];
  }

  Future<void> _submitAddendum() async {
    if (_addendumController.text.trim().isEmpty && _addendumImages.isEmpty) return;

    try {
      var request = http.MultipartRequest('POST', Uri.parse('${ApiConstants.baseUrl}incidents/addendum.php'));
      request.fields['id'] = const Uuid().v4();
      request.fields['incident_id'] = widget.incident['id'];
      request.fields['text_content'] = _addendumController.text.trim();

      for (var file in _addendumImages) {
        request.files.add(await http.MultipartFile.fromPath(
          'images[]',
          file.path,
        ));
      }

      var response = await request.send();
      if (response.statusCode == 200) {
        _addendumController.clear();
        setState(() => _addendumImages.clear());
        _fetchAddendums(); // Refresh list
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(settings.t('Butiran Insiden')),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_parseImages(widget.incident['image_url']).isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _parseImages(widget.incident['image_url']).asMap().entries.map((entry) {
                        int index = entry.key;
                        String url = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(
                                imageUrls: _parseImages(widget.incident['image_url']),
                                initialIndex: index,
                              )));
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(url, fit: BoxFit.cover, width: 250),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(widget.incident['title'], style: TextStyle(color: theme.textTheme.titleLarge?.color, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(widget.incident['description'] ?? '', style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8))),
                Divider(color: theme.dividerColor.withValues(alpha: 0.2), height: 32),
                Text(settings.t('Catatan Tambahan'), style: TextStyle(color: theme.primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
                if (_isLoading)
                  Center(child: CircularProgressIndicator(color: theme.primaryColor))
                else if (_addendums.isEmpty)
                  Text(settings.t('Tiada catatan tambahan direkodkan.'), style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)))
                else
                  ..._addendums.map((a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (a['text_content'] != null && a['text_content'].isNotEmpty)
                          Text(a['text_content'], style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                        if (_parseImages(a['image_url']).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: SizedBox(
                              height: 120,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: _parseImages(a['image_url']).asMap().entries.map((entry) {
                                  int index = entry.key;
                                  String url = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(
                                          imageUrls: _parseImages(a['image_url']),
                                          initialIndex: index,
                                        )));
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(url, height: 120, width: 120, fit: BoxFit.cover),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(a['created_at'], style: TextStyle(color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6), fontSize: 12)),
                      ],
                    ),
                  )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ]
            ),
            child: SafeArea(
              child: Column(
                children: [
                  if (_addendumImages.isNotEmpty)
                    Container(
                      height: 80,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _addendumImages.map((file) => Stack(
                          children: [
                            Container(
                              height: 80,
                              width: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              right: 12,
                              top: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => _addendumImages.remove(file)),
                                child: Container(
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.6)),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        )).toList(),
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.camera_alt, color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6)),
                        onPressed: _pickAddendumImage,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _addendumController,
                          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                          decoration: InputDecoration(
                            hintText: settings.t('Tambah catatan...'),
                            hintStyle: TextStyle(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.4)),
                            filled: true,
                            fillColor: theme.inputDecorationTheme.fillColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.send, color: theme.primaryColor),
                        onPressed: _submitAddendum,
                      )
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
