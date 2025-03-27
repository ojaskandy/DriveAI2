import 'package:flutter/material.dart';

import '../widgets/camera_view.dart';

/// Home screen of the application
class HomeScreen extends StatelessWidget {
  /// Constructor
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DriveAI Camera'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Camera view in top half
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: const CameraView(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
