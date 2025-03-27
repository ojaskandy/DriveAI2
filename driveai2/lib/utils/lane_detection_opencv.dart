import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/lane_model.dart';

/// Utility class for lane detection using image processing
class LaneDetectionOpenCV {
  /// Flag to track if initialized
  static bool _isInitialized = false;
  
  /// Initialize
  static Future<bool> initialize() async {
    try {
      _isInitialized = true;
      return _isInitialized;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing: $e');
      }
      return false;
    }
  }
  
  /// Check if initialized
  static bool get isInitialized => _isInitialized;
  
  /// Process a camera image for lane detection
  static Future<Map<String, dynamic>> processCameraImage(img.Image inputImage) async {
    try {
      // Create a copy of the original image for visualization
      final resultImage = img.copyResize(inputImage, width: inputImage.width, height: inputImage.height);
      
      // 1. Convert to grayscale
      final grayImage = img.grayscale(inputImage);
      
      // 2. Apply Gaussian blur to reduce noise
      final blurredImage = img.gaussianBlur(grayImage, radius: 5);
      
      // 3. Apply edge detection using Sobel
      final edgesImage = img.sobel(blurredImage);
      
      // Apply threshold to get binary edges
      final thresholdImage = img.Image(width: edgesImage.width, height: edgesImage.height);
      for (int y = 0; y < edgesImage.height; y++) {
        for (int x = 0; x < edgesImage.width; x++) {
          final pixel = edgesImage.getPixel(x, y);
          final luminance = img.getLuminance(pixel);
          final color = luminance > 50 ? img.ColorRgb8(255, 255, 255) : img.ColorRgb8(0, 0, 0);
          thresholdImage.setPixel(x, y, color);
        }
      }
      
      // 4. Define region of interest (ROI)
      final height = inputImage.height;
      final width = inputImage.width;
      
      // Define ROI points (trapezoid)
      final roiPoints = [
        Offset(width * 0.1, height * 0.95),  // Bottom left
        Offset(width * 0.4, height * 0.6),   // Top left
        Offset(width * 0.6, height * 0.6),   // Top right
        Offset(width * 0.9, height * 0.95),  // Bottom right
      ];
      
      // Apply ROI mask
      final maskedImage = _applyROIMask(thresholdImage, roiPoints);
      
      // 5. Detect lines
      final lines = _detectLines(maskedImage, width, height);
      
      // 6. Filter and group lines to find lane lines
      final laneLines = _findLaneLines(lines, width, height);
      
      // 7. Convert to Lane objects and draw on result image
      final lanes = <Lane>[];
      
      // Process left lane lines
      if (laneLines['left'] != null) {
        final leftLine = laneLines['left']!;
        
        // Create a Lane object
        final leftLane = Lane(
          points: [leftLine.start, leftLine.end],
          color: const Color(0xFF00FF00),  // Green
          slope: leftLine.slope,
          intercept: leftLine.intercept,
        );
        
        lanes.add(leftLane);
        
        // Draw the left lane line
        _drawLine(
          resultImage,
          leftLine.start,
          leftLine.end,
          img.ColorRgb8(0, 255, 0),  // Green
          4,
        );
      }
      
      // Process right lane lines
      if (laneLines['right'] != null) {
        final rightLine = laneLines['right']!;
        
        // Create a Lane object
        final rightLane = Lane(
          points: [rightLine.start, rightLine.end],
          color: const Color(0xFF00FFFF),  // Cyan
          slope: rightLine.slope,
          intercept: rightLine.intercept,
        );
        
        lanes.add(rightLane);
        
        // Draw the right lane line
        _drawLine(
          resultImage,
          rightLine.start,
          rightLine.end,
          img.ColorRgb8(0, 255, 255),  // Cyan
          4,
        );
      }
      
      if (kDebugMode) {
        print('Lane detection completed with ${lanes.length} lanes detected');
      }
      
      return {
        'processed': resultImage,
        'lanes': lanes,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error processing camera image: $e');
      }
      
      // Return empty result in case of error
      return {
        'processed': null,
        'lanes': <Lane>[],
      };
    }
  }
  
  /// Apply a region of interest mask to an image
  static img.Image _applyROIMask(img.Image image, List<Offset> points) {
    // Create a mask image (black background)
    final maskImage = img.Image(width: image.width, height: image.height);
    img.fill(maskImage, color: img.ColorRgb8(0, 0, 0));
    
    // Draw the polygon on the mask (white)
    _drawPolygon(maskImage, points, img.ColorRgb8(255, 255, 255));
    
    // Create the result image
    final resultImage = img.Image(width: image.width, height: image.height);
    img.fill(resultImage, color: img.ColorRgb8(0, 0, 0));
    
    // Apply the mask
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        // If the mask pixel is white, copy the original pixel
        if (img.getLuminance(maskImage.getPixel(x, y)) > 128) {
          resultImage.setPixel(x, y, image.getPixel(x, y));
        }
      }
    }
    
    return resultImage;
  }
  
  /// Draw a filled polygon on an image
  static void _drawPolygon(img.Image image, List<Offset> points, img.ColorRgb8 color) {
    if (points.length < 3) return;
    
    // Find the bounding box of the polygon
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    
    for (final point in points) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }
    
    // Clamp to image boundaries
    final startX = math.max(0, minX.floor());
    final endX = math.min(image.width - 1, maxX.ceil());
    final startY = math.max(0, minY.floor());
    final endY = math.min(image.height - 1, maxY.ceil());
    
    // Fill the polygon
    for (int y = startY; y <= endY; y++) {
      for (int x = startX; x <= endX; x++) {
        if (_isPointInPolygon(Offset(x.toDouble(), y.toDouble()), points)) {
          image.setPixel(x, y, color);
        }
      }
    }
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
  
  /// Detect lines in an image
  static List<_Line> _detectLines(img.Image image, int width, int height) {
    final lines = <_Line>[];
    
    // Detect actual lane lines from the image
    // For now, we'll implement a simple edge detection and line finding algorithm
    
    // Step 1: Find edge points in the bottom half of the image
    final edgePoints = <Offset>[];
    
    // Only scan the bottom half of the image for edges
    for (int y = height ~/ 2; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Check if this is a white pixel (edge)
        if (img.getLuminance(image.getPixel(x, y)) > 200) {
          edgePoints.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }
    
    // Step 2: If we don't have enough edge points, return empty list (no lanes detected)
    if (edgePoints.length < 50) {
      if (kDebugMode) {
        print('Not enough edge points detected: ${edgePoints.length}');
      }
      return lines;
    }
    
    // Step 3: Separate left and right points based on position
    final leftPoints = <Offset>[];
    final rightPoints = <Offset>[];
    
    final midX = width / 2;
    for (final point in edgePoints) {
      if (point.dx < midX) {
        leftPoints.add(point);
      } else {
        rightPoints.add(point);
      }
    }
    
    // Step 4: Fit lines to the points if we have enough
    if (leftPoints.length > 20) {
      final leftLine = _fitLineToPoints(leftPoints);
      if (leftLine != null) {
        lines.add(leftLine);
      }
    }
    
    if (rightPoints.length > 20) {
      final rightLine = _fitLineToPoints(rightPoints);
      if (rightLine != null) {
        lines.add(rightLine);
      }
    }
    
    return lines;
  }
  
  /// Fit a line to a set of points using least squares
  static _Line? _fitLineToPoints(List<Offset> points) {
    if (points.length < 10) return null;
    
    // Calculate means
    double sumX = 0;
    double sumY = 0;
    
    for (final point in points) {
      sumX += point.dx;
      sumY += point.dy;
    }
    
    final meanX = sumX / points.length;
    final meanY = sumY / points.length;
    
    // Calculate slope and intercept
    double numerator = 0;
    double denominator = 0;
    
    for (final point in points) {
      numerator += (point.dx - meanX) * (point.dy - meanY);
      denominator += (point.dx - meanX) * (point.dx - meanX);
    }
    
    // If denominator is too small, line is vertical
    if (denominator.abs() < 0.001) return null;
    
    final slope = numerator / denominator;
    final intercept = meanY - slope * meanX;
    
    // Filter out lines with unreasonable slopes
    if (slope.abs() < 0.1 || slope.abs() > 10) return null;
    
    // Calculate endpoints
    final y1 = points.map((p) => p.dy).reduce(math.max);
    final x1 = (y1 - intercept) / slope;
    
    final y2 = points.map((p) => p.dy).reduce(math.min);
    final x2 = (y2 - intercept) / slope;
    
    return _Line(
      Offset(x1, y1),
      Offset(x2, y2),
      slope,
      intercept,
    );
  }
  
  /// Find lane lines from detected lines
  static Map<String, _Line> _findLaneLines(List<_Line> lines, int width, int height) {
    final result = <String, _Line>{};
    
    // Group lines by slope (negative slope = left lane, positive slope = right lane)
    final leftLines = <_Line>[];
    final rightLines = <_Line>[];
    
    for (final line in lines) {
      // Filter out horizontal and vertical lines
      if (line.slope.abs() < 0.1 || line.slope.abs() > 10) continue;
      
      // Filter out lines that are too short
      final length = (line.end - line.start).distance;
      if (length < 30) continue;
      
      // Group by slope
      if (line.slope < 0) {
        leftLines.add(line);
      } else {
        rightLines.add(line);
      }
    }
    
    // Process left lane lines
    if (leftLines.isNotEmpty) {
      // Calculate average slope and intercept
      double sumSlope = 0;
      double sumIntercept = 0;
      
      for (final line in leftLines) {
        sumSlope += line.slope;
        sumIntercept += line.intercept;
      }
      
      final avgSlope = sumSlope / leftLines.length;
      final avgIntercept = sumIntercept / leftLines.length;
      
      // Calculate line endpoints
      final y1 = height.toDouble();
      final x1 = (y1 - avgIntercept) / avgSlope;
      final y2 = height * 0.6;
      final x2 = (y2 - avgIntercept) / avgSlope;
      
      result['left'] = _Line(
        Offset(x1, y1),
        Offset(x2, y2),
        avgSlope,
        avgIntercept,
      );
    }
    
    // Process right lane lines
    if (rightLines.isNotEmpty) {
      // Calculate average slope and intercept
      double sumSlope = 0;
      double sumIntercept = 0;
      
      for (final line in rightLines) {
        sumSlope += line.slope;
        sumIntercept += line.intercept;
      }
      
      final avgSlope = sumSlope / rightLines.length;
      final avgIntercept = sumIntercept / rightLines.length;
      
      // Calculate line endpoints
      final y1 = height.toDouble();
      final x1 = (y1 - avgIntercept) / avgSlope;
      final y2 = height * 0.6;
      final x2 = (y2 - avgIntercept) / avgSlope;
      
      result['right'] = _Line(
        Offset(x1, y1),
        Offset(x2, y2),
        avgSlope,
        avgIntercept,
      );
    }
    
    return result;
  }
  
  /// Draw a line on an image
  static void _drawLine(img.Image image, Offset start, Offset end, img.ColorRgb8 color, int thickness) {
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
}

/// Helper class to represent a line
class _Line {
  final Offset start;
  final Offset end;
  final double slope;
  final double intercept;
  
  _Line(this.start, this.end, this.slope, this.intercept);
}
