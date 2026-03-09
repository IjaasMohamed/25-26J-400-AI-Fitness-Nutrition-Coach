import 'angle_calculator.dart';

class SitupAnalyzer {
  static const Map<String, Map<String, double>> standards = {
    'hip_angle': {'down': 140, 'up': 70} 
  };

  String currentState = 'down'; // down, ascending, up, descending
  int repCount = 0;
  List<String> formErrors = [];

  Map<String, dynamic> analyzeFrame(Map<String, List<double>> landmarks) {
    if (landmarks.isEmpty) return {'status': 'no_pose_detected'};
    
    Map<String, double> angles = _calculateAngles(landmarks);
    if (angles.isEmpty) return {'status': 'no_pose_detected'};

    Map<String, dynamic> formEvaluation = _evaluateForm(angles);
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
      if (landmarks.containsKey('left_shoulder') && landmarks.containsKey('left_hip') && landmarks.containsKey('left_knee')) {
        angles['hip_flexion'] = AngleCalculator.calculateHipAngle(
            landmarks['left_shoulder']!, landmarks['left_hip']!, landmarks['left_knee']!);
      } else if (landmarks.containsKey('right_shoulder') && landmarks.containsKey('right_hip') && landmarks.containsKey('right_knee')) {
        angles['hip_flexion'] = AngleCalculator.calculateHipAngle(
            landmarks['right_shoulder']!, landmarks['right_hip']!, landmarks['right_knee']!);
      }
    } catch (e) {
      return {};
    }
    return angles;
  }

  Map<String, dynamic> _evaluateForm(Map<String, double> angles) {
    formErrors = [];
    int formScore = 100;

    double hipAngle = angles['hip_flexion'] ?? 180.0;
    if (currentState == 'up' && hipAngle > standards['hip_angle']!['up']! + 20) {
      formErrors.add('Sit up all the way!');
      formScore -= 20;
    }

    return {
      'score': formScore < 0 ? 0 : formScore,
      'errors': formErrors,
      'status': formScore >= 80 ? 'good' : 'needs_correction'
    };
  }

  void _updateState(Map<String, double> angles) {
    if (angles.isEmpty) return;
    double hipAngle = angles['hip_flexion'] ?? 180.0;

    if (currentState == 'down' && hipAngle < 130) {
      currentState = 'ascending';
    } else if (currentState == 'ascending' && hipAngle < 80) {
      currentState = 'up';
    } else if (currentState == 'up' && hipAngle > 90) {
      currentState = 'descending';
    } else if (currentState == 'descending' && hipAngle > 140) {
      currentState = 'down';
      repCount += 1;
    }
  }
}