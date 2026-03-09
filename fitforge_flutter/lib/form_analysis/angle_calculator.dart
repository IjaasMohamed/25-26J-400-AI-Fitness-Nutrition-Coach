import 'dart:math' as math;

class AngleCalculator {
  /// Calculate angle between three points. Returns angle in degrees (0-180)
  static double calculateAngle(
      List<double> point1, List<double> point2, List<double> point3) {
    
    // Calculate vectors
    List<double> vector1 = [point1[0] - point2[0], point1[1] - point2[1]];
    List<double> vector2 = [point3[0] - point2[0], point3[1] - point2[1]];

    // Dot product
    double dotProduct = (vector1[0] * vector2[0]) + (vector1[1] * vector2[1]);
    
    // Magnitudes
    double mag1 = math.sqrt((vector1[0] * vector1[0]) + (vector1[1] * vector1[1]));
    double mag2 = math.sqrt((vector2[0] * vector2[0]) + (vector2[1] * vector2[1]));

    if (mag1 * mag2 == 0) return 0;

    // Calculate Cosine Angle
    double cosAngle = dotProduct / (mag1 * mag2);
    
    // Clip to handle numerical errors (-1.0 to 1.0)
    cosAngle = cosAngle.clamp(-1.0, 1.0);

    // Convert to degrees
    double angle = math.acos(cosAngle) * (180 / math.pi);
    return angle;
  }

  static double calculateKneeAngle(List<double> hip, List<double> knee, List<double> ankle) {
    return calculateAngle(hip, knee, ankle);
  }
  
  static double calculateHipAngle(List<double> shoulder, List<double> hip, List<double> knee) {
    return calculateAngle(shoulder, hip, knee);
  }

  static double calculateElbowAngle(List<double> shoulder, List<double> elbow, List<double> wrist) {
    return calculateAngle(shoulder, elbow, wrist);
  }

  static double calculateTorsoAngle(List<double> shoulder, List<double> hip) {
    // Create vertical reference point directly below the hip
    List<double> verticalRef = [hip[0], hip[1] + 100]; 
    return calculateAngle(shoulder, hip, verticalRef);
  }
}