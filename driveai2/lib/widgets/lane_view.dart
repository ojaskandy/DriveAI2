import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../models/lane_model.dart';
import '../providers/app_state.dart';
import '../utils/image_utils.dart';

/// Widget for displaying the original camera image with lane detection overlay
class LaneView extends StatelessWidget {
  /// Constructor
  const LaneView({super.key});

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
            child: Text(
              'Error: ${appState.errorMessage}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final originalImage = appState.originalImage;
        final lanes = appState.lanes;
        
        if (originalImage == null) {
          return const Center(
            child: Text('No camera image available'),
          );
        }
        
        // Create a copy of the original image and draw lane lines on it
        final displayImage = _createDisplayImage(originalImage, lanes);

        return FutureBuilder<Uint8List?>(
          future: _convertImageToBytes(displayImage),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError || snapshot.data == null) {
              return const Center(
                child: Text('Error converting image'),
              );
            }

            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
              ),
            );
          },
        );
      },
    );
  }

  /// Create a display image with lane lines drawn on the original image
  img.Image _createDisplayImage(img.Image originalImage, List<Lane> lanes) {
    // Create a copy of the original image
    final displayImage = img.copyResize(originalImage, width: originalImage.width, height: originalImage.height);
    
    // Only draw lane lines if they are actually detected
    if (lanes.isNotEmpty) {
      // Draw lane lines on the image
      for (final lane in lanes) {
        if (lane.points.length >= 2) {
          // Convert Color to img.ColorRgb8
          final r = lane.color.red;
          final g = lane.color.green;
          final b = lane.color.blue;
          final color = img.ColorRgb8(r, g, b);
          
          // Draw the lane line with thicker width for better visibility
          ImageUtils.drawLine(
            displayImage,
            lane.points.first,
            lane.points.last,
            color,
            4, // Increased line width
          );
          
          if (kDebugMode) {
            print('Drawing lane line from (${lane.points.first.dx}, ${lane.points.first.dy}) to (${lane.points.last.dx}, ${lane.points.last.dy})');
          }
        }
      }
    }
    
    return displayImage;
  }
  
  /// Convert img.Image to bytes for display
  Future<Uint8List?> _convertImageToBytes(img.Image image) async {
    try {
      // Convert image to PNG format
      final pngBytes = await ImageUtils.imageToBytes(image);
      if (pngBytes == null) {
        return null;
      }
      return Uint8List.fromList(pngBytes);
    } catch (e) {
      debugPrint('Error converting image to bytes: $e');
      return null;
    }
  }
}
