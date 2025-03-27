import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/lane_model.dart';
import '../utils/opencv_utils.dart';

/// Service class for lane detection using Dart image processing
class LaneDetectionService {
  /// Flag to indicate if the service is initialized
  bool _isInitialized = true;
  
  /// Constructor
  LaneDetectionService();
  
  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;
  
  /// Process an image and detect lanes using OpenCV
  Future<Map<String, dynamic>> processImage(img.Image image) async {
    try {
      if (kDebugMode) {
        print('Starting lane detection on image: ${image.width}x${image.height}');
      }
      
      // Create a smaller version of the original image for better performance
      final smallerImage = img.copyResize(image, width: image.width ~/ 2, height: image.height ~/ 2);
      
      // Keep a copy of the original image (but smaller for performance)
      final originalImage = img.copyResize(smallerImage, width: smallerImage.width, height: smallerImage.height);
      
      // Initialize OpenCV if needed
      if (!OpenCVUtils.isInitialized) {
        final initialized = await OpenCVUtils.initialize();
        if (!initialized) {
          throw Exception('Failed to initialize OpenCV');
        }
      }
      
      // Use OpenCV to detect lanes
      final result = await OpenCVUtils.detectLanes(smallerImage);
      final processedImage = result['processed'] as img.Image;
      final lanes = result['lanes'] as List<Lane>;
      
      if (kDebugMode) {
        print('Lane detection completed successfully with ${lanes.length} lanes detected');
        if (lanes.isNotEmpty) {
          for (final lane in lanes) {
            print('Lane detected with slope: ${lane.slope.toStringAsFixed(2)}, intercept: ${lane.intercept.toStringAsFixed(2)}');
          }
        }
      }
      
      return {
        'original': originalImage,
        'processed': processedImage,
        'lanes': lanes,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error processing image: $e');
      }
      return {
        'original': null,
        'processed': null,
        'lanes': <Lane>[],
      };
    }
  }
  
  /// Dispose resources
  void dispose() {
    _isInitialized = false;
  }
}
