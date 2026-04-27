import 'package:flutter/material.dart';

class RadioScreen extends StatelessWidget {
  const RadioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('KRT Sector A Channel', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 60),
          GestureDetector(
            onTapDown: (_) {},
            onTapUp: (_) {},
            child: Container(
              height: 200, width: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueGrey[700],
                border: Border.all(color: Colors.lightBlueAccent, width: 4),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, size: 80, color: Colors.white),
                  Text('HOLD TO SPEAK', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}