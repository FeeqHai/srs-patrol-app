
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/widgets/image_viewer_screen.dart';
import 'addendum_report_screen.dart';

class IncidentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> incident;

  const IncidentDetailScreen({super.key, required this.incident});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  List<dynamic> _addendums = [];
  bool _isLoading = true;

  bool _isShiftActive = false;

  @override
  void initState() {
    super.initState();
    _fetchAddendums();
    _checkShiftStatus();
  }

  Future<void> _checkShiftStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isActive = prefs.getBool('shiftActive') ?? false;
    final String? startTimeStr = prefs.getString('shiftStartTime');
    
    if (isActive && startTimeStr != null) {
      final DateTime startTime = DateTime.parse(startTimeStr);
      final Duration diff = DateTime.now().difference(startTime);
      setState(() {
        _isShiftActive = diff.inHours < 4;
      });
    } else {
      setState(() {
        _isShiftActive = false;
      });
    }
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
      // DIRECTIVE E: EXCEPTION UNMASKING
      print("=== CRITICAL NETWORK EXCEPTION ===");
      print("Exception: $e");
      print("Target URI: ${ApiConstants.baseUrl}incidents/get_addendums.php");
      print("==================================");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Butiran Insiden', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
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
                Text(widget.incident['title'], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(widget.incident['description'] ?? '', style: const TextStyle(color: Colors.white70)),
                const Divider(color: Colors.white24, height: 32),
                const Text('Catatan Tambahan', style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                else if (_addendums.isEmpty)
                  const Text('Tiada catatan tambahan direkodkan.', style: TextStyle(color: Colors.white54))
                else
                  ..._addendums.map((a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (a['category'] != null && a['category'].toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              a['category'].toString().toUpperCase(), 
                              style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        if (a['title'] != null && a['title'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(a['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                          ),
                        if (a['text_content'] != null && a['text_content'].toString().isNotEmpty)
                          Text(a['text_content'], style: const TextStyle(color: Colors.white)),
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
                        Text(a['created_at'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: const Color(0xFF1E1E1E),
            child: ElevatedButton.icon(
              onPressed: () async {
                if (!_isShiftActive) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Anda mesti berada dalam shif aktif untuk menambah catatan.', style: TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.redAccent,
                  ));
                  return;
                }
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddendumReportScreen(incident: widget.incident))
                );
                if (result == true) {
                  _fetchAddendums();
                }
              },
              icon: const Icon(Icons.add_comment),
              label: const Text('Add additional note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isShiftActive ? Colors.redAccent : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          )
        ],
      ),
    );
  }
}
