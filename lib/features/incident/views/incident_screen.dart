// File: lib/features/incident/views/incident_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import 'incident_report_screen.dart';

class IncidentScreen extends StatefulWidget {
  const IncidentScreen({super.key});

  @override
  State<IncidentScreen> createState() => _IncidentScreenState();
}

class _IncidentScreenState extends State<IncidentScreen> {
  // Fetching method
  Future<List<dynamic>> _fetchIncidents() async {
    final response = await http.get(Uri.parse(ApiConstants.baseUrl + 'incidents/fetch_incidents.php'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(response.body);
      return body['data'];
    } else {
      throw Exception('Failed to load incidents');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: FutureBuilder<List<dynamic>>(
        future: _fetchIncidents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          } else if (snapshot.hasError) {
            return Center(child: Text("Ralat memuat data: ${snapshot.error}", style: const TextStyle(color: Colors.white70)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Tiada insiden direkodkan.", style: TextStyle(color: Colors.white54)));
          }

          final incidents = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 80),
            itemCount: incidents.length,
            itemBuilder: (context, index) => _buildIncidentCard(incidents[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const IncidentReportScreen()));
          setState(() {}); // Refresh list upon return
        },
        icon: const Icon(Icons.add_a_photo, color: Colors.white),
        label: const Text("LAPOR INSIDEN", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 110, height: 110,
                color: Colors.black,
                child: data['image_url'] != null 
                    ? Image.network(data['image_url'], fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image, color: Colors.white24))
                    : const Icon(Icons.image_not_supported, color: Colors.white24),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text((data['category'] ?? "UMUM").toUpperCase(), style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      Text(data['title'] ?? "Tiada Tajuk", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(data['description'] ?? "", style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}