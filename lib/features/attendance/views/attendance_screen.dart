import 'package:flutter/material.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text('Status: OFF DUTY', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.qr_code),
            label: const Text('SCAN QR TO CLOCK IN'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            ),
          ),
        ],
      ),
    );
  }
}