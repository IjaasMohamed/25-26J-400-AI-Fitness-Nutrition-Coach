import 'dart:math';

class RiskAssessmentEngine {
  // Depth Tracking
  double? maxDepthAngle; // E.g. Lowest angle achieved in a squat/pushup
  
  // Imbalance Tracking
  double? maxImbalanceDegrees; // E.g. The largest difference between left/right sides during the rep
  
  void updateMetrics({
    required double leftAngle,
    required double rightAngle,
    bool isExtending = false, // false for squatting down, true for standing up
  }) {
    // 1. Calculate Imbalance
    double currentImbalance = (leftAngle - rightAngle).abs();
    
    if (maxImbalanceDegrees == null || currentImbalance > maxImbalanceDegrees!) {
      maxImbalanceDegrees = currentImbalance;
    }
    
    // 2. Calculate Depth (Average of both sides)
    double currentAvgAngle = (leftAngle + rightAngle) / 2;
    
    // We typically want to find the MINIMUM angle for depth (e.g. deep squat)
    // If the exercise requires finding the MAXIMUM angle (extension), we flip logic
    if (isExtending) {
       if (maxDepthAngle == null || currentAvgAngle > maxDepthAngle!) {
         maxDepthAngle = currentAvgAngle;
       }
    } else {
       if (maxDepthAngle == null || currentAvgAngle < maxDepthAngle!) {
         maxDepthAngle = currentAvgAngle;
       }
    }
  }

  // To be called when _recordRep fires
  Map<String, dynamic> fetchAndResetMetrics() {
    double finalDepth = maxDepthAngle ?? 0.0;
    double finalImbalance = maxImbalanceDegrees ?? 0.0;
    
    // Reset for the next repetition
    maxDepthAngle = null;
    maxImbalanceDegrees = null;
    
    return {
      'max_depth_angle': finalDepth,
      'left_right_imbalance_degrees': finalImbalance,
    };
  }
}
