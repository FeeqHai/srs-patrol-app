import 'package:flutter/material.dart';

class IncidentScreen extends StatelessWidget {
  const IncidentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.camera),
          label: const Text('SNAP NEW INCIDENT (Auto-Blur)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[800],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
          ),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.image, color: Colors.grey),
          title: Text('Suspicious Vehicle'),
          subtitle: Text('Plates Redacted'),
        ),
      ],
    );
  }
}