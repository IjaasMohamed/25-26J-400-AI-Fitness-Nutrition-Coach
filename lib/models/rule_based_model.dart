import 'package:pose_detection_realtime/models/base_prediction_model.dart';
import 'package:pose_detection_realtime/models/workout_features.dart';

class RuleBasedPerformanceModel implements BasePredictionModel {
  @override
  Future<int> predict(WorkoutFeatures features) async {
    // 1 -> Good, 0 -> Average
    // Simple heuristic: if avgReps > 5 and avgRestPerRepSecs < 10, it's good.
    // This is just a placeholder until the Logistic Regression model is integrated.
    if (features.avgReps >= 8 && features.avgRestPerRepSecs <= 5.0) {
      return 1;
    }
    return 0;
  }

  @override
  double getConfidence() {
    return 0.85; // Fixed confidence for the rule-based model.
  }
}
