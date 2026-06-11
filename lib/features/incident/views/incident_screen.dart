// File: lib/features/incident/views/incident_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import 'incident_report_screen.dart';
import 'incident_detail_screen.dart';

class IncidentScreen extends StatefulWidget {
  final String? patrollerIdFilter;

  const IncidentScreen({super.key, this.patrollerIdFilter});

  @override
  State<IncidentScreen> createState() => _IncidentScreenState();
}

class _IncidentScreenState extends State<IncidentScreen> {
  final List<dynamic> _incidents = [];
  int _page = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchIncidents();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _fetchIncidents();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchIncidents() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      String url =
          '${ApiConstants.baseUrl}incidents/fetch_incidents.php?page=$_page&limit=10';
      if (widget.patrollerIdFilter != null) {
        url += '&user_id=${widget.patrollerIdFilter}';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> newIncidents = body['data'];

        setState(() {
          _page++;
          _isLoading = false;
          if (newIncidents.length < 10) {
            _hasMore = false;
          }
          _incidents.addAll(newIncidents);
        });
      } else {
        throw Exception('Failed to load incidents: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      // DIRECTIVE E: EXCEPTION UNMASKING
      print("=== CRITICAL NETWORK EXCEPTION ===");
      print("Exception: $e");
      print("Target URI: ${ApiConstants.baseUrl}incidents/fetch_incidents.php");
      print("==================================");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ralat rangkaian: $e',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _page = 1;
      _incidents.clear();
      _hasMore = true;
    });
    await _fetchIncidents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: Colors.redAccent,
        child: _incidents.isEmpty && _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              )
            : _incidents.isEmpty && !_isLoading
            ? ListView(
                children: const [
                  SizedBox(height: 300),
                  Center(
                    child: Text(
                      "Tiada insiden direkodkan.",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 10, bottom: 80),
                itemCount: _incidents.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _incidents.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.redAccent,
                        ),
                      ),
                    );
                  }
                  return _buildIncidentCard(_incidents[index]);
                },
              ),
      ),
      floatingActionButton: widget.patrollerIdFilter == null
          ? FloatingActionButton.extended(
              backgroundColor: Colors.redAccent,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IncidentReportScreen(),
                  ),
                );
                await _refresh(); // Fix: Refresh list upon return
              },
              icon: const Icon(Icons.add_a_photo, color: Colors.white),
              label: const Text(
                "LAPOR INSIDEN",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> data) {
    String? imageUrl;
    if (data['image_url'] != null && data['image_url'].toString().isNotEmpty) {
      try {
        if (data['image_url'].toString().trim().startsWith('[')) {
          List<dynamic> parsed = json.decode(data['image_url']);
          if (parsed.isNotEmpty) imageUrl = parsed.first.toString();
        } else {
          imageUrl = data['image_url'];
        }
      } catch (e) {
        imageUrl = data['image_url'];
      }
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IncidentDetailScreen(incident: data),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null)
                  Container(
                    width: 110,
                    height: 110,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(15),
                        bottomLeft: Radius.circular(15),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        bottomLeft: Radius.circular(15),
                      ),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image,
                          color: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (data['category'] ?? "UMUM").toUpperCase(),
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['title'] ?? "Tiada Tajuk",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['description'] ?? "",
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
