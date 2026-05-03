import 'package:pose_detection_realtime/models/workout_features.dart';

abstract class BasePredictionModel {
  /// Predicts whether the performance is 'Good' (1) or 'Average' (0).
  Future<int> predict(WorkoutFeatures features);
  
  /// Returns the confidence of the prediction.
  double getConfidence();
}
