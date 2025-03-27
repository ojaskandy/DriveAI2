import 'dart:ui';

/// Model class representing a detected lane
class Lane {
  /// Points that define the lane line
  final List<Offset> points;
  
  /// Color of the lane line for visualization
  final Color color;
  
  /// Slope of the lane line
  final double slope;
  
  /// Intercept of the lane line
  final double intercept;
  
  /// Constructor
  Lane({
    required this.points,
    required this.color,
    required this.slope,
    required this.intercept,
  });
  
  /// Create a lane from a list of points and calculate slope and intercept
  factory Lane.fromPoints(List<Offset> points, Color color) {
    // Calculate slope and intercept using linear regression
    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;
    
    for (var point in points) {
      sumX += point.dx;
      sumY += point.dy;
      sumXY += point.dx * point.dy;
      sumX2 += point.dx * point.dx;
    }
    
    final n = points.length;
    double slope = 0;
    double intercept = 0;
    
    if (n > 1) {
      slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
      intercept = (sumY - slope * sumX) / n;
    }
    
    return Lane(
      points: points,
      color: color,
      slope: slope,
      intercept: intercept,
    );
  }
  
  /// Get a point on the line at a given x coordinate
  Offset getPointAtX(double x) {
    return Offset(x, slope * x + intercept);
  }
  
  /// Get a point on the line at a given y coordinate
  Offset getPointAtY(double y) {
    // Avoid division by zero
    if (slope == 0) {
      return Offset(0, intercept);
    }
    return Offset((y - intercept) / slope, y);
  }
}
