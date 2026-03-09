import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';

/// Utility class to classify exercises from pose data using rule-based analysis
class ExerciseClassifier {
  // Confidence threshold for detection
  static const double confidenceThreshold = 0.7;
  
  // Track consecutive detections for stability
  static final Map<ExcerciseType, int> _detectionCounts = {};
  static const int requiredConsecutiveDetections = 5;
  
  /// Analyze pose and return detected exercise type
  /// Returns null if no exercise is confidently detected
  static ExcerciseType? classifyExercise(Pose pose) {
    final landmarks = pose.landmarks;
    
    // Check each exercise type
    if (isPushUpPose(landmarks)) {
      return _incrementAndCheck(ExcerciseType.PushUps);
    } else if (isSquatPose(landmarks)) {
      return _incrementAndCheck(ExcerciseType.Squats);
    } else if (isJumpingJackPose(landmarks)) {
      return _incrementAndCheck(ExcerciseType.JumpingJack);
    } else if (isHighKneesPose(landmarks)) {
      return _incrementAndCheck(ExcerciseType.HighKnees);
    } else if (isPlankPose(landmarks)) {
      return _incrementAndCheck(ExcerciseType.PlankToDownwardDog);
    }
    
    // Reset counts if no pattern detected
    _detectionCounts.clear();
    return null;
  }
  
  /// Increment detection count and check if threshold reached
  static ExcerciseType? _incrementAndCheck(ExcerciseType type) {
    _detectionCounts[type] = (_detectionCounts[type] ?? 0) + 1;
    
    // Clear other exercise counts
    _detectionCounts.keys.where((k) => k != type).toList().forEach((k) {
      _detectionCounts[k] = 0;
    });
    
    if (_detectionCounts[type]! >= requiredConsecutiveDetections) {
      return type;
    }
    return null;
  }
  
  /// Reset classifier state
  static void reset() {
    _detectionCounts.clear();
  }
  
  /// Check if pose indicates Push-Up position
  /// Criteria: Body horizontal, hands below shoulders, plank-like position
  static bool isPushUpPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    
    if (leftShoulder == null || rightShoulder == null || 
        leftHip == null || rightHip == null || 
        leftWrist == null || rightWrist == null ||
        leftAnkle == null) {
      return false;
    }
    
    // Check if body is roughly horizontal (shoulder and hip at similar Y levels)
    double shoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    double hipY = (leftHip.y + rightHip.y) / 2;
    bool isHorizontal = (shoulderY - hipY).abs() < 100;
    
    // Check if wrists are below shoulders (supporting body)
    double wristY = (leftWrist.y + rightWrist.y) / 2;
    bool handsDown = wristY > shoulderY - 50;
    
    // Check if body is extended (not standing)
    bool isExtended = (leftAnkle.x - leftShoulder.x).abs() > 200;
    
    return isHorizontal && handsDown && isExtended;
  }
  
  /// Check if pose indicates Squat position
  /// Criteria: Body upright, knees bent
  static bool isSquatPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    
    if (leftHip == null || rightHip == null || 
        leftKnee == null || rightKnee == null ||
        leftAnkle == null || rightAnkle == null ||
        leftShoulder == null) {
      return false;
    }
    
    // Check if body is upright (shoulders above hips)
    bool isUpright = leftShoulder.y < leftHip.y;
    
    // Calculate knee angle
    double kneeAngle = _calculateAngle(leftHip, leftKnee, leftAnkle);
    bool kneesBent = kneeAngle < 150; // Bent knees
    
    // Check hip is lowered (below normal standing)
    double hipY = (leftHip.y + rightHip.y) / 2;
    double kneeY = (leftKnee.y + rightKnee.y) / 2;
    bool hipLowered = hipY > kneeY - 100;
    
    return isUpright && kneesBent && hipLowered;
  }
  
  /// Check if pose indicates Jumping Jack position
  /// Criteria: Arms raised above shoulders, legs spread apart
  static bool isJumpingJackPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    
    if (leftShoulder == null || rightShoulder == null ||
        leftWrist == null || rightWrist == null ||
        leftAnkle == null || rightAnkle == null ||
        leftHip == null || rightHip == null) {
      return false;
    }
    
    // Check if arms are raised (wrists above shoulders)
    bool armsUp = leftWrist.y < leftShoulder.y && rightWrist.y < rightShoulder.y;
    
    // Check if legs are spread
    double shoulderWidth = (rightShoulder.x - leftShoulder.x).abs();
    double legSpread = (rightAnkle.x - leftAnkle.x).abs();
    bool legsApart = legSpread > shoulderWidth * 1.2;
    
    return armsUp && legsApart;
  }
  
  /// Check if pose indicates High Knees position
  /// Criteria: Standing, one knee raised above hip level
  static bool isHighKneesPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    
    if (leftHip == null || rightHip == null ||
        leftKnee == null || rightKnee == null ||
        leftShoulder == null) {
      return false;
    }
    
    // Check if body is upright
    bool isUpright = leftShoulder.y < leftHip.y;
    
    // Check if either knee is raised above hip level
    bool leftKneeHigh = leftKnee.y < leftHip.y;
    bool rightKneeHigh = rightKnee.y < rightHip.y;
    
    return isUpright && (leftKneeHigh || rightKneeHigh);
  }
  
  /// Check if pose indicates Plank/Downward Dog position
  /// Criteria: Body horizontal or inverted V shape
  static bool isPlankPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    
    if (leftShoulder == null || rightShoulder == null ||
        leftHip == null || rightHip == null ||
        leftAnkle == null || leftWrist == null) {
      return false;
    }
    
    // Check if body is horizontal (plank) or hips raised (downward dog)
    double shoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    double hipY = (leftHip.y + rightHip.y) / 2;
    
    bool isPlank = (shoulderY - hipY).abs() < 50;
    bool isDownwardDog = hipY < shoulderY - 50;
    
    // Check if hands are on ground (wrists below or near shoulders)
    bool handsDown = leftWrist.y > shoulderY - 100;
    
    return (isPlank || isDownwardDog) && handsDown;
  }
  
  /// Calculate angle between three landmarks
  static double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    double ab = _distance(a, b);
    double bc = _distance(b, c);
    double ac = _distance(a, c);
    
    double angle = acos((ab * ab + bc * bc - ac * ac) / (2 * ab * bc)) * (180 / pi);
    return angle;
  }
  
  /// Calculate distance between two landmarks
  static double _distance(PoseLandmark p1, PoseLandmark p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }
}
