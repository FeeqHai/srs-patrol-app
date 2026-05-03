import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/incident_service.dart';
import 'incident_report_screen.dart';

class IncidentScreen extends StatelessWidget {
  const IncidentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Matches your Dark Theme
      appBar: AppBar(
        title: const Text(
          "SRS Incident Feed",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Connects to your Firestore 'incidents' collection
        stream: IncidentService().getIncidentStream(),
        builder: (context, snapshot) {
          // 1. Error Handling
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading incidents"));
          }

          // 2. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          // 3. Empty State
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security, size: 64, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  const Text(
                    "No incidents reported.\nYour neighborhood is secure.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // 4. The Feed
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // Padding for FAB
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _buildIncidentCard(data);
            },
          );
        },
      ),

      // Floating Action Button to launch the report form[cite: 1]
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const IncidentReportScreen()),
        ),
        icon: const Icon(Icons.add_a_photo, color: Colors.white),
        label: const Text("REPORT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  /// Refined UI Component for individual Incident items
  Widget _buildIncidentCard(Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      color: const Color(0xFF1E1E1E), // Slightly lighter than background
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Thumbnail
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(color: Colors.grey[900]),
                child: data['imageUrl'] != null
                    ? Image.network(data['imageUrl'], fit: BoxFit.cover)
                    : const Icon(Icons.image_not_supported, color: Colors.white24),
              ),

              // Text Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (data['category'] ?? "General").toUpperCase(),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['title'] ?? "Unnamed Incident",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['description'] ?? "No details provided.",
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Action Footer (Location & Time)
          const Divider(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.blueAccent),
                const SizedBox(width: 4),
                const Text(
                  "View Location",
                  style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  "Time: ${data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toString().substring(11, 16) : 'Just now'}",
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}