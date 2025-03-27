import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Service class for handling camera operations
class CameraService {
  /// List of available cameras
  List<CameraDescription>? cameras;
  
  /// Controller for the camera
  CameraController? controller;
  
  /// Flag to indicate if the camera is initialized
  bool isInitialized = false;
  
  /// Flag to indicate if the camera is processing frames
  bool isProcessing = false;
  
  /// Initialize the camera service
  Future<void> initialize() async {
    try {
      // Get available cameras
      cameras = await availableCameras();
      if (cameras == null || cameras!.isEmpty) {
        throw Exception('No cameras available');
      }
      
      if (kDebugMode) {
        print('Found ${cameras!.length} cameras');
        for (var camera in cameras!) {
          print('Camera: ${camera.name}, direction: ${camera.lensDirection}');
        }
      }
    
      // Initialize camera controller with the back camera
      final backCamera = cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras!.first,
      );
      
      controller = CameraController(
        backCamera,
        ResolutionPreset.low, // Lower resolution for better performance
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      
      // Initialize the controller
      await controller!.initialize();
      isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing camera: $e');
      }
      rethrow;
    }
  }
  
  /// Start the camera preview with a callback for image processing
  Future<void> startPreview(Function(CameraImage image)? onImage) async {
    if (!isInitialized || controller == null) {
      await initialize();
    }
    
    if (!controller!.value.isStreamingImages) {
      await controller!.startImageStream((image) {
        // This callback will be called for each frame
        if (!isProcessing && onImage != null) {
          isProcessing = true;
          try {
            onImage(image);
          } catch (e) {
            if (kDebugMode) {
              print('Error processing image: $e');
            }
          } finally {
            isProcessing = false;
          }
        }
      });
    }
  }
  
  /// Stop the camera preview
  Future<void> stopPreview() async {
    if (controller != null && controller!.value.isStreamingImages) {
      await controller!.stopImageStream();
    }
  }
  
  /// Dispose the camera controller
  Future<void> dispose() async {
    if (controller != null) {
      await stopPreview();
      await controller!.dispose();
      controller = null;
      isInitialized = false;
    }
  }
  
  /// Take a single image from the camera
  Future<XFile?> takePicture() async {
    if (!isInitialized || controller == null) {
      return null;
    }
    
    if (controller!.value.isTakingPicture) {
      return null;
    }
    
    try {
      final XFile file = await controller!.takePicture();
      return file;
    } catch (e) {
      if (kDebugMode) {
        print('Error taking picture: $e');
      }
      return null;
    }
  }
}
