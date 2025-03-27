import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/lane_model.dart';
import '../services/camera_service.dart';
import '../services/lane_detection_service_new.dart';
import '../utils/image_utils.dart';

/// Provider class for managing application state
class AppState extends ChangeNotifier {
  /// Camera service instance
  final CameraService _cameraService = CameraService();
  
  /// Lane detection service instance
  final LaneDetectionServiceNew _laneDetectionService = LaneDetectionServiceNew();
  
  /// Original camera image
  img.Image? _originalImage;
  
  /// Processed image with lane detection
  img.Image? _processedImage;
  
  /// Detected lanes
  List<Lane> _lanes = [];
  
  /// Flag to indicate if the camera is initialized
  bool _isCameraInitialized = false;
  
  /// Flag to indicate if lane detection is running
  bool _isDetectionRunning = false;
  
  /// Flag to indicate if there was an error
  bool _hasError = false;
  
  /// Error message
  String _errorMessage = '';
  
  /// Frame counter for frame skipping
  int _frameCount = 0;
  
  /// Process every N frames (adjust for performance)
  final int _frameSkip = 2;
  
  /// Constructor
  AppState() {
    _initialize();
  }
  
  /// Initialize the app state
  Future<void> _initialize() async {
    try {
      // Initialize camera
      await _cameraService.initialize();
      _isCameraInitialized = true;
      
      // Start processing frames
      _startProcessing();
      
      notifyListeners();
    } catch (e) {
      _hasError = true;
      
      // Provide a more user-friendly error message
      if (e.toString().contains('Camera permission')) {
        _errorMessage = 'Camera permission is required for this app to work. Please grant camera permission in your device settings.';
      } else if (e.toString().contains('No cameras available')) {
        _errorMessage = 'No cameras available on this device.';
      } else {
        _errorMessage = 'Error initializing camera: ${e.toString()}';
      }
      
      if (kDebugMode) {
        print('AppState initialization error: $e');
      }
      
      notifyListeners();
    }
  }
  
  /// Start processing camera frames
  void _startProcessing() {
    if (!_isCameraInitialized) {
      return;
    }
    
    _isDetectionRunning = true;
    
    // Start camera preview with a callback for image processing
    _cameraService.startPreview((cameraImage) async {
      try {
        // Process only every N frames for better performance
        if (_frameCount++ % _frameSkip != 0) {
          return;
        }
        
        if (kDebugMode) {
          print('Processing camera frame: ${cameraImage.width}x${cameraImage.height}');
        }
        
        // Convert CameraImage to img.Image
        final image = await ImageUtils.cameraImageToImage(cameraImage);
        if (image == null) {
          if (kDebugMode) {
            print('Failed to convert camera image to img.Image');
          }
          return;
        }
        
        if (kDebugMode) {
          print('Successfully converted camera image to img.Image: ${image.width}x${image.height}');
        }
        
        // Process the image with lane detection
        final result = await _laneDetectionService.processImage(image);
        
        if (kDebugMode) {
          print('Lane detection completed. Processed: ${result['processed'] != null}');
        }
        
        _originalImage = result['original'];
        _processedImage = result['processed'];
        _lanes = result['lanes'] as List<Lane>;
        
        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          print('Error processing frame: $e');
        }
      }
    });
    
    notifyListeners();
  }
  
  /// Stop processing camera frames
  void stopProcessing() {
    _isDetectionRunning = false;
    _cameraService.stopPreview();
    notifyListeners();
  }
  
  /// Resume processing camera frames
  void resumeProcessing() {
    if (!_isDetectionRunning) {
      _startProcessing();
    }
  }
  
  /// Reinitialize the app state after permission changes
  Future<void> reinitialize() async {
    // Reset error state
    _hasError = false;
    _errorMessage = '';
    
    // Dispose existing resources
    stopProcessing();
    _cameraService.dispose();
    
    // Reinitialize
    await _initialize();
  }
  
  /// Get the camera controller
  CameraController? get cameraController => _cameraService.controller;
  
  /// Get the original image
  img.Image? get originalImage => _originalImage;
  
  /// Get the processed image
  img.Image? get processedImage => _processedImage;
  
  /// Get the detected lanes
  List<Lane> get lanes => _lanes;
  
  /// Check if the camera is initialized
  bool get isCameraInitialized => _isCameraInitialized;
  
  /// Check if lane detection is running
  bool get isDetectionRunning => _isDetectionRunning;
  
  /// Check if there was an error
  bool get hasError => _hasError;
  
  /// Get the error message
  String get errorMessage => _errorMessage;
  
  @override
  void dispose() {
    stopProcessing();
    _cameraService.dispose();
    super.dispose();
  }
}
