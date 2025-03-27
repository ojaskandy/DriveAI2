import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/lane_model.dart';

/// Utility class for image processing operations
class ImageUtils {
  /// Convert CameraImage to img.Image
  static Future<img.Image?> cameraImageToImage(CameraImage cameraImage) async {
    try {
      // This is a simplified conversion - in a real app, you'd need to handle
      // different image formats (YUV, NV21, etc.) properly
      
      // For YUV420 format (simplified)
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        final width = cameraImage.width;
        final height = cameraImage.height;
        
        // Create a grayscale image from the Y plane
        final yPlane = cameraImage.planes[0].bytes;
        final image = img.Image(width: width, height: height);
        
        // Copy Y plane data to the image (as grayscale)
        // Process all pixels for better accuracy
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final yValue = yPlane[y * width + x];
            // Set the same value for R, G, B to create grayscale
            final color = img.ColorRgb8(yValue, yValue, yValue);
            image.setPixel(x, y, color);
          }
        }
        
        if (kDebugMode) {
          print('Converted YUV420 image to grayscale: ${image.width}x${image.height}');
        }
        
        return image;
      } else {
        // For other formats, create a simple placeholder image
        return img.Image(width: cameraImage.width, height: cameraImage.height);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error converting camera image to Image: $e');
      }
      return null;
    }
  }
  
  /// Convert img.Image to Uint8List for display
  static Future<List<int>?> imageToBytes(img.Image image) async {
    try {
      // Convert image to PNG format with compression for better performance
      final pngBytes = img.encodePng(image, level: 3); // Higher compression
      return pngBytes;
    } catch (e) {
      if (kDebugMode) {
        print('Error converting image to bytes: $e');
      }
      return null;
    }
  }
  
  /// Apply Gaussian blur to an image
  static img.Image applyGaussianBlur(img.Image src, {int radius = 3}) {
    return img.gaussianBlur(src, radius: radius);
  }
  
  /// Improved edge detection using Sobel operator
  static img.Image detectEdges(img.Image image) {
    // Use the built-in Sobel operator from the image package
    final sobelImage = img.sobel(image);
    
    // Apply thresholding to get binary edges
    final result = img.Image(width: image.width, height: image.height);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = sobelImage.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        
        // Apply threshold (adjust as needed)
        final isEdge = luminance > 50;
        final color = isEdge ? img.ColorRgb8(255, 255, 255) : img.ColorRgb8(0, 0, 0);
        
        result.setPixel(x, y, color);
      }
    }
    
    return result;
  }
  
  /// Apply a region of interest mask
  static img.Image applyROIMask(img.Image image, List<Offset> points) {
    final result = img.Image(width: image.width, height: image.height);
    
    // Fill with black
    img.fill(result, color: img.ColorRgb8(0, 0, 0));
    
    // Calculate bounding box of the polygon for optimization
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    
    for (var point in points) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }
    
    // Convert to integers and clamp to image bounds
    final startX = math.max(0, minX.floor());
    final endX = math.min(image.width - 1, maxX.ceil());
    final startY = math.max(0, minY.floor());
    final endY = math.min(image.height - 1, maxY.ceil());
    
    // Copy pixels from the original image only within the ROI bounding box
    // and check if they're in the polygon
    for (int y = startY; y <= endY; y++) {
      for (int x = startX; x <= endX; x++) {
        if (_isPointInPolygon(Offset(x.toDouble(), y.toDouble()), points)) {
          result.setPixel(x, y, image.getPixel(x, y));
        }
      }
    }
    
    return result;
  }
  
  /// Check if a point is inside a polygon
  static bool _isPointInPolygon(Offset point, List<Offset> polygon) {
    bool isInside = false;
    int i = 0, j = polygon.length - 1;
    
    for (i = 0; i < polygon.length; i++) {
      if ((polygon[i].dy > point.dy) != (polygon[j].dy > point.dy) &&
          (point.dx < (polygon[j].dx - polygon[i].dx) * (point.dy - polygon[i].dy) / 
          (polygon[j].dy - polygon[i].dy) + polygon[i].dx)) {
        isInside = !isInside;
      }
      j = i;
    }
    
    return isInside;
  }
  
  /// Draw a line on an image
  static void drawLine(img.Image image, Offset start, Offset end, img.ColorRgb8 color, int thickness) {
    img.drawLine(
      image,
      x1: start.dx.toInt(),
      y1: start.dy.toInt(),
      x2: end.dx.toInt(),
      y2: end.dy.toInt(),
      color: color,
      thickness: thickness,
    );
  }
  
  /// Detect lane lines in an image using sliding window approach
  static Map<String, dynamic> detectLaneLines(img.Image inputImage) {
    try {
      // Create a copy of the original image for visualization
      final resultImage = img.copyResize(inputImage, width: inputImage.width, height: inputImage.height);
      
      // 1. Convert to grayscale
      final grayImage = img.grayscale(inputImage);
      
      // 2. Apply Gaussian blur to reduce noise
      final blurredImage = applyGaussianBlur(grayImage);
      
      // 3. Apply edge detection
      final edgesImage = detectEdges(blurredImage);
      
      // 4. Create a region of interest (ROI) mask
      // Define the polygon points (bottom left, bottom right, top right, top left)
      final height = edgesImage.height;
      final width = edgesImage.width;
      final points = [
        Offset(0, height.toDouble()),                    // Bottom left
        Offset(width.toDouble(), height.toDouble()),     // Bottom right
        Offset(width * 0.65, height * 0.5),              // Top right
        Offset(width * 0.35, height * 0.5),              // Top left
      ];
      final maskedImage = applyROIMask(edgesImage, points);
      
      // 5. Use sliding window approach to find lane lines
      final lanes = _findLanesWithSlidingWindows(maskedImage, resultImage);
      
      return {
        'processed': resultImage,
        'lanes': lanes,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error detecting lane lines: $e');
      }
      return {
        'processed': inputImage,
        'lanes': <Lane>[],
      };
    }
  }
  
  /// Find lanes using sliding window approach
  static List<Lane> _findLanesWithSlidingWindows(img.Image edgeImage, img.Image resultImage) {
    final height = edgeImage.height;
    final width = edgeImage.width;
    
    // Sliding window parameters
    final numWindows = 9;
    final windowHeight = height ~/ numWindows;
    final margin = 50; // Window width around center
    final minpix = 50; // Minimum pixels to recenter
    
    // Find initial lane base positions by looking at the bottom quarter of the image
    final bottomQuarter = height * 3 ~/ 4;
    final histogram = List<int>.filled(width, 0);
    
    // Create histogram of bottom quarter
    for (int y = bottomQuarter; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (img.getLuminance(edgeImage.getPixel(x, y)) > 200) {
          histogram[x]++;
        }
      }
    }
    
    // Find peaks in left and right halves
    int leftxBase = 0;
    int rightxBase = 0;
    int leftMax = 0;
    int rightMax = 0;
    
    for (int x = 0; x < width ~/ 2; x++) {
      if (histogram[x] > leftMax) {
        leftMax = histogram[x];
        leftxBase = x;
      }
    }
    
    for (int x = width ~/ 2; x < width; x++) {
      if (histogram[x] > rightMax) {
        rightMax = histogram[x];
        rightxBase = x;
      }
    }
    
    // If no clear peaks, use default positions
    if (leftMax < 10) leftxBase = width ~/ 4;
    if (rightMax < 10) rightxBase = width * 3 ~/ 4;
    
    int leftxCurrent = leftxBase;
    int rightxCurrent = rightxBase;
    
    final leftLaneInds = <int>[];
    final rightLaneInds = <int>[];
    
    // For debugging, draw the initial base positions
    drawLine(
      resultImage,
      Offset(leftxBase.toDouble(), height.toDouble()),
      Offset(leftxBase.toDouble(), height - 20.0),
      img.ColorRgb8(255, 0, 0),
      2,
    );
    
    drawLine(
      resultImage,
      Offset(rightxBase.toDouble(), height.toDouble()),
      Offset(rightxBase.toDouble(), height - 20.0),
      img.ColorRgb8(255, 0, 0),
      2,
    );
    
    // Slide windows from bottom to top
    for (int window = 0; window < numWindows; window++) {
      final winYLow = height - (window + 1) * windowHeight;
      final winYHigh = height - window * windowHeight;
      
      final winXLeftLow = leftxCurrent - margin;
      final winXLeftHigh = leftxCurrent + margin;
      final winXRightLow = rightxCurrent - margin;
      final winXRightHigh = rightxCurrent + margin;
      
      // Draw the windows on the result image for visualization
      _drawRectangle(
        resultImage,
        winXLeftLow,
        winYLow,
        winXLeftHigh,
        winYHigh,
        img.ColorRgb8(0, 255, 0),
        1,
      );
      
      _drawRectangle(
        resultImage,
        winXRightLow,
        winYLow,
        winXRightHigh,
        winYHigh,
        img.ColorRgb8(0, 255, 255),
        1,
      );
      
      // Collect edge pixels in windows
      final windowLeftInds = <int>[];
      final windowRightInds = <int>[];
      
      for (int y = winYLow; y < winYHigh; y++) {
        for (int x = 0; x < width; x++) {
          if (img.getLuminance(edgeImage.getPixel(x, y)) > 200) {
            if (x >= winXLeftLow && x < winXLeftHigh) {
              windowLeftInds.add(y * width + x);
              leftLaneInds.add(y * width + x);
            }
            if (x >= winXRightLow && x < winXRightHigh) {
              windowRightInds.add(y * width + x);
              rightLaneInds.add(y * width + x);
            }
          }
        }
      }
      
      // Recenter windows based on mean position
      if (windowLeftInds.length >= minpix) {
        int sumX = 0;
        for (int ind in windowLeftInds) {
          sumX += ind % width;
        }
        leftxCurrent = sumX ~/ windowLeftInds.length;
      }
      
      if (windowRightInds.length >= minpix) {
        int sumX = 0;
        for (int ind in windowRightInds) {
          sumX += ind % width;
        }
        rightxCurrent = sumX ~/ windowRightInds.length;
      }
    }
    
    final lanes = <Lane>[];
    
    // Fit left lane
    if (leftLaneInds.isNotEmpty) {
      final leftX = <double>[];
      final leftY = <double>[];
      
      for (int ind in leftLaneInds) {
        leftX.add((ind % width).toDouble());
        leftY.add((ind ~/ width).toDouble());
      }
      
      final m = _fitLine(leftX, leftY);
      final slope = m['m']!;
      final intercept = m['b']!;
      
      // Calculate line endpoints
      final y1 = height.toDouble();
      final x1 = (y1 - intercept) / slope;
      final y2 = height * 0.6;
      final x2 = (y2 - intercept) / slope;
      
      // Clamp x values to image boundaries
      final x1Clamped = x1.clamp(0.0, width - 1.0);
      final x2Clamped = x2.clamp(0.0, width - 1.0);
      
      // Draw the left lane line
      drawLine(
        resultImage,
        Offset(x1Clamped, y1),
        Offset(x2Clamped, y2),
        img.ColorRgb8(0, 255, 0),  // Green
        4,
      );
      
      // Create a Lane object
      final leftLane = Lane(
        points: [Offset(x1Clamped, y1), Offset(x2Clamped, y2)],
        color: const Color(0xFF00FF00),  // Green
        slope: slope,
        intercept: intercept,
      );
      
      lanes.add(leftLane);
    }
    
    // Fit right lane
    if (rightLaneInds.isNotEmpty) {
      final rightX = <double>[];
      final rightY = <double>[];
      
      for (int ind in rightLaneInds) {
        rightX.add((ind % width).toDouble());
        rightY.add((ind ~/ width).toDouble());
      }
      
      final m = _fitLine(rightX, rightY);
      final slope = m['m']!;
      final intercept = m['b']!;
      
      // Calculate line endpoints
      final y1 = height.toDouble();
      final x1 = (y1 - intercept) / slope;
      final y2 = height * 0.6;
      final x2 = (y2 - intercept) / slope;
      
      // Clamp x values to image boundaries
      final x1Clamped = x1.clamp(0.0, width - 1.0);
      final x2Clamped = x2.clamp(0.0, width - 1.0);
      
      // Draw the right lane line
      drawLine(
        resultImage,
        Offset(x1Clamped, y1),
        Offset(x2Clamped, y2),
        img.ColorRgb8(0, 255, 255),  // Cyan
        4,
      );
      
      // Create a Lane object
      final rightLane = Lane(
        points: [Offset(x1Clamped, y1), Offset(x2Clamped, y2)],
        color: const Color(0xFF00FFFF),  // Cyan
        slope: slope,
        intercept: intercept,
      );
      
      lanes.add(rightLane);
    }
    
    return lanes;
  }
  
  /// Helper function for linear regression
  static Map<String, double> _fitLine(List<double> x, List<double> y) {
    if (x.isEmpty || y.isEmpty || x.length != y.length) {
      return {'m': 0.0, 'b': 0.0};
    }
    
    final meanX = x.fold(0.0, (a, b) => a + b) / x.length;
    final meanY = y.fold(0.0, (a, b) => a + b) / y.length;
    
    double num = 0.0;
    double den = 0.0;
    
    for (int i = 0; i < x.length; i++) {
      num += (x[i] - meanX) * (y[i] - meanY);
      den += (x[i] - meanX) * (x[i] - meanX);
    }
    
    final m = den != 0 ? num / den : 0.0;
    final b = meanY - m * meanX;
    
    return {'m': m, 'b': b};
  }
  
  /// Draw a rectangle on an image
  static void _drawRectangle(
    img.Image image,
    int x1,
    int y1,
    int x2,
    int y2,
    img.ColorRgb8 color,
    int thickness,
  ) {
    // Clamp coordinates to image boundaries
    x1 = x1.clamp(0, image.width - 1);
    y1 = y1.clamp(0, image.height - 1);
    x2 = x2.clamp(0, image.width - 1);
    y2 = y2.clamp(0, image.height - 1);
    
    // Draw the four sides of the rectangle
    drawLine(image, Offset(x1.toDouble(), y1.toDouble()), Offset(x2.toDouble(), y1.toDouble()), color, thickness);
    drawLine(image, Offset(x2.toDouble(), y1.toDouble()), Offset(x2.toDouble(), y2.toDouble()), color, thickness);
    drawLine(image, Offset(x2.toDouble(), y2.toDouble()), Offset(x1.toDouble(), y2.toDouble()), color, thickness);
    drawLine(image, Offset(x1.toDouble(), y2.toDouble()), Offset(x1.toDouble(), y1.toDouble()), color, thickness);
  }
}

/// Helper class to represent a line
class _Line {
  final Offset start;
  final Offset end;
  final double slope;
  final double intercept;
  
  _Line(this.start, this.end, this.slope, this.intercept);
}
