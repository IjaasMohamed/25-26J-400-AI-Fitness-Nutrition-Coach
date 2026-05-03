import 'package:pose_detection_realtime/models/performance_suggestion.dart';
import 'package:pose_detection_realtime/services/prediction_service.dart';

// RE-EXPORT for backward compatibility during refactoring
export 'package:pose_detection_realtime/models/performance_suggestion.dart';

class PerformancePredictor {
  final _predictionService = PredictionService();

  Future<List<PerformanceSuggestion>> getSuggestions() async {
    return _predictionService.getSuggestions();
  }
}

