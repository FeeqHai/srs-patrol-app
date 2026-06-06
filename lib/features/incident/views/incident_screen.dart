// File: lib/features/incident/views/incident_screen.dart
import 'package:flutter/material.dart';
import '../services/incident_service.dart';
import 'incident_report_screen.dart';

class IncidentScreen extends StatefulWidget {
  const IncidentScreen({super.key});

  @override
  State<IncidentScreen> createState() => _IncidentScreenState();
}

class _IncidentScreenState extends State<IncidentScreen> {
  late Future<List<dynamic>> _incidentFuture;

  @override
  void initState() {
    super.initState();
    _incidentFuture = IncidentService().fetchAllIncidents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: FutureBuilder<List<dynamic>>(
        future: _incidentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
          }
          final incidents = snapshot.data!;
          if (incidents.isEmpty) {
            return const Center(child: Text("Tiada insiden ditemui.", style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 80),
            itemCount: incidents.length,
            itemBuilder: (context, index) => _buildIncidentCard(incidents[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const IncidentReportScreen()),
        ),
        icon: const Icon(Icons.add_a_photo, color: Colors.white),
        label: const Text("LAPOR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
          child: data['image_url'] != null 
            ? Image.network(data['image_url'], fit: BoxFit.cover) 
            : const Icon(Icons.broken_image, color: Colors.grey),
        ),
        title: Text(data['title'] ?? 'Tiada Tajuk', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(data['category'] ?? 'General', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            const SizedBox(height: 4),
            Text(data['description'] ?? '', style: const TextStyle(color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}