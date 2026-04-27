import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 80, color: Colors.lightBlue),
            SizedBox(height: 20),
            Text('Live GPS Map Placeholder', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}