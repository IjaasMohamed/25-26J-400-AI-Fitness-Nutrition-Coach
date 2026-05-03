import 'dart:math';

class RiskAssessmentEngine {
  // Depth Tracking
  double? maxDepthAngle; // E.g. Lowest angle achieved in a squat/pushup
  
  // Imbalance Tracking
  double? maxImbalanceDegrees; // E.g. The largest difference between left/right sides during the rep
  
  void updateMetrics({
    required double leftElbow,
    required double rightElbow,
    required double leftKnee,
    required double rightKnee,
    required double leftShoulder,
    required double rightShoulder,
  }) {
    // 1. Calculate Composite Imbalance per your dataset requirement
    double elbowDiff = (leftElbow - rightElbow).abs();
    double kneeDiff = (leftKnee - rightKnee).abs();
    double shoulderDiff = (leftShoulder - rightShoulder).abs();
    
    double currentImbalance = (elbowDiff + kneeDiff + shoulderDiff) / 3.0;
    
    if (maxImbalanceDegrees == null || currentImbalance > maxImbalanceDegrees!) {
      maxImbalanceDegrees = currentImbalance;
    }
    
    // 2. Calculate Depth (Average of knees for general depth tracking)
    double currentAvgKnee = (leftKnee + rightKnee) / 2;
    if (maxDepthAngle == null || currentAvgKnee < maxDepthAngle!) {
      maxDepthAngle = currentAvgKnee;
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
