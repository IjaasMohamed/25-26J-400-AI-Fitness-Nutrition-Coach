import 'angle_calculator.dart';

class SquatAnalyzer {
  // Biomechanical standards mirroring your kinesiology research
  static const Map<String, Map<String, double>> standards = {
    'knee_angle': {'min': 70, 'max': 110, 'optimal_bottom': 90},
    'hip_angle': {'min': 60, 'max': 120, 'optimal_bottom': 90},
    'torso_angle': {'min': 45, 'max': 85, 'optimal': 65}
  };

  String currentState = 'standing'; // standing, descending, bottom, ascending
  int repCount = 0;
  List<String> formErrors = [];

  Map<String, dynamic> analyzeFrame(Map<String, List<double>> landmarks) {
    if (landmarks.isEmpty) {
      return {'status': 'no_pose_detected'};
    }

    // Calculate key angles
    Map<String, double> angles = _calculateAngles(landmarks);
    if (angles.isEmpty) {
       return {'status': 'no_pose_detected'};
    }

    // Evaluate form
    Map<String, dynamic> formEvaluation = _evaluateForm(angles);

    // Update state and count reps
    _updateState(angles);

    return {
      'status': 'analyzed',
      'angles': angles,
      'form_evaluation': formEvaluation,
      'rep_count': repCount,
      'current_state': currentState,
      'form_errors': formErrors
    };
  }

  Map<String, double> _calculateAngles(Map<String, List<double>> landmarks) {
    Map<String, double> angles = {};

    try {
      // Right side angles (use left if right not visible)
      if (landmarks.containsKey('right_hip') && landmarks.containsKey('right_knee') && landmarks.containsKey('right_ankle')) {
        angles['right_knee'] = AngleCalculator.calculateKneeAngle(
            landmarks['right_hip']!, landmarks['right_knee']!, landmarks['right_ankle']!);
      } else {
        return {}; // Missing critical landmarks
      }

      if (landmarks.containsKey('right_shoulder') && landmarks.containsKey('right_hip') && landmarks.containsKey('right_knee')) {
        angles['right_hip'] = AngleCalculator.calculateHipAngle(
            landmarks['right_shoulder']!, landmarks['right_hip']!, landmarks['right_knee']!);
      }

      if (landmarks.containsKey('right_shoulder') && landmarks.containsKey('right_hip')) {
        angles['torso'] = AngleCalculator.calculateTorsoAngle(
            landmarks['right_shoulder']!, landmarks['right_hip']!);
      }

      // Average left and right if both visible
      if (landmarks.containsKey('left_knee') && landmarks.containsKey('left_hip') && 
          landmarks.containsKey('left_ankle') && landmarks.containsKey('left_shoulder')) {
        
        double leftKneeAngle = AngleCalculator.calculateKneeAngle(
            landmarks['left_hip']!, landmarks['left_knee']!, landmarks['left_ankle']!);
            
        double leftHipAngle = AngleCalculator.calculateHipAngle(
            landmarks['left_shoulder']!, landmarks['left_hip']!, landmarks['left_knee']!);

        angles['left_knee'] = leftKneeAngle;
        angles['left_hip'] = leftHipAngle;
        angles['knee_avg'] = (angles['right_knee']! + leftKneeAngle) / 2;
        angles['hip_avg'] = (angles['right_hip']! + leftHipAngle) / 2;
      }
    } catch (e) {
      return {};
    }

    return angles;
  }

  Map<String, dynamic> _evaluateForm(Map<String, double> angles) {
    formErrors = [];
    int formScore = 100;

    // Check knee angle
    double kneeAngle = angles.containsKey('knee_avg') ? angles['knee_avg']! : (angles['right_knee'] ?? 180.0);
    if (kneeAngle < standards['knee_angle']!['min']!) {
      formErrors.add('Knees bent too much - risk of strain');
      formScore -= 20;
    } else if (kneeAngle > standards['knee_angle']!['max']!) {
      formErrors.add('Squat not deep enough');
      formScore -= 15;
    }

    // Check hip angle
    double hipAngle = angles.containsKey('hip_avg') ? angles['hip_avg']! : (angles['right_hip'] ?? 180.0);
    if (hipAngle < standards['hip_angle']!['min']!) {
      formErrors.add('Excessive hip flexion');
      formScore -= 15;
    }

    // Check torso angle
    double torsoAngle = angles['torso'] ?? 90.0;
    if (torsoAngle < standards['torso_angle']!['min']!) {
      formErrors.add('Leaning too far forward - back strain risk');
      formScore -= 25;
    } else if (torsoAngle > standards['torso_angle']!['max']!) {
      formErrors.add('Too upright - not engaging glutes properly');
      formScore -= 10;
    }

    return {
      'score': formScore < 0 ? 0 : formScore,
      'errors': formErrors,
      'status': formScore >= 80 ? 'good' : 'needs_correction'
    };
  }

  void _updateState(Map<String, double> angles) {
    if (angles.isEmpty) return;
    
    double kneeAngle = angles.containsKey('knee_avg') ? angles['knee_avg']! : (angles['right_knee'] ?? 180.0);

    // Simple state machine for rep counting
    if (currentState == 'standing' && kneeAngle < 130) {
      currentState = 'descending';
    } else if (currentState == 'descending' && kneeAngle < 100) {
      currentState = 'bottom';
    } else if (currentState == 'bottom' && kneeAngle > 110) {
      currentState = 'ascending';
    } else if (currentState == 'ascending' && kneeAngle > 150) {
      currentState = 'standing';
      repCount += 1; // Complete rep!
    }
  }
}