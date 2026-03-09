import 'angle_calculator.dart';

class PushupAnalyzer {
  // Biomechanical standards
  static const Map<String, Map<String, double>> standards = {
    'elbow_angle': {'min': 70, 'max': 160, 'optimal_bottom': 90},
    'torso_alignment': {'min': 150, 'max': 180, 'optimal': 170}
  };

  String currentState = 'up'; // up, descending, bottom, ascending
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
      // Calculate elbow angles
      if (landmarks.containsKey('left_shoulder') && landmarks.containsKey('left_elbow') && landmarks.containsKey('left_wrist')) {
        angles['left_elbow'] = AngleCalculator.calculateElbowAngle(
            landmarks['left_shoulder']!, landmarks['left_elbow']!, landmarks['left_wrist']!);
      }
      if (landmarks.containsKey('right_shoulder') && landmarks.containsKey('right_elbow') && landmarks.containsKey('right_wrist')) {
        angles['right_elbow'] = AngleCalculator.calculateElbowAngle(
            landmarks['right_shoulder']!, landmarks['right_elbow']!, landmarks['right_wrist']!);
      }
      
      // Average the elbow angles
      if (angles.containsKey('left_elbow') && angles.containsKey('right_elbow')) {
        angles['elbow_avg'] = (angles['left_elbow']! + angles['right_elbow']!) / 2;
      } else {
        angles['elbow_avg'] = angles['left_elbow'] ?? (angles['right_elbow'] ?? 180.0);
      }

      // Torso alignment (Shoulder -> Hip -> Ankle)
      if (landmarks.containsKey('left_shoulder') && landmarks.containsKey('left_hip') && landmarks.containsKey('left_ankle')) {
        angles['body_alignment'] = AngleCalculator.calculateAngle(
            landmarks['left_shoulder']!, landmarks['left_hip']!, landmarks['left_ankle']!);
      }
    } catch (e) {
      return {};
    }
    return angles;
  }

  Map<String, dynamic> _evaluateForm(Map<String, double> angles) {
    formErrors = [];
    int formScore = 100;

    double elbowAngle = angles['elbow_avg'] ?? 180.0;
    if (currentState == 'bottom' && elbowAngle > standards['elbow_angle']!['max']!) {
      formErrors.add('Go lower! Chest closer to the floor.');
      formScore -= 20;
    }

    double bodyAlignment = angles['body_alignment'] ?? 180.0;
    if (bodyAlignment < standards['torso_alignment']!['min']!) {
      formErrors.add('Keep your back straight and core tight!');
      formScore -= 30;
    }

    return {
      'score': formScore < 0 ? 0 : formScore,
      'errors': formErrors,
      'status': formScore >= 80 ? 'good' : 'needs_correction'
    };
  }

  void _updateState(Map<String, double> angles) {
    if (angles.isEmpty) return;
    double elbowAngle = angles['elbow_avg'] ?? 180.0;

    if (currentState == 'up' && elbowAngle < 150) {
      currentState = 'descending';
    } else if (currentState == 'descending' && elbowAngle < 100) {
      currentState = 'bottom';
    } else if (currentState == 'bottom' && elbowAngle > 110) {
      currentState = 'ascending';
    } else if (currentState == 'ascending' && elbowAngle > 160) {
      currentState = 'up';
      repCount += 1;
    }
  }
}