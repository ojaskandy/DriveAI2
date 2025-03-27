import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/image_utils.dart';

/// Widget for displaying the camera preview
class CameraView extends StatelessWidget {
  /// Constructor
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (!appState.isCameraInitialized) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (appState.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error: ${appState.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Reinitialize the app state
                    final appState = Provider.of<AppState>(context, listen: false);
                    appState.reinitialize();
                  },
                  child: const Text('Retry Camera Access'),
                ),
              ],
            ),
          );
        }

        final controller = appState.cameraController;
        if (controller == null || !controller.value.isInitialized) {
          return const Center(
            child: Text('Camera not initialized'),
          );
        }

        // If we have a processed image, show it
        if (appState.processedImage != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FutureBuilder<Uint8List?>(
              future: _convertImageToBytes(appState.processedImage!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: CameraPreview(controller),
                  );
                }

                if (snapshot.hasError || snapshot.data == null) {
                  return AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: CameraPreview(controller),
                  );
                }

                return AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          );
        }

        // Otherwise, show the regular camera preview
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        );
      },
    );
  }

  /// Convert img.Image to bytes for display
  Future<Uint8List?> _convertImageToBytes(img.Image image) async {
    try {
      // Convert image to PNG format
      final pngBytes = img.encodePng(image);
      return Uint8List.fromList(pngBytes);
    } catch (e) {
      debugPrint('Error converting image to bytes: $e');
      return null;
    }
  }
}
