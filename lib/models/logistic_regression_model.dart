import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pose_detection_realtime/models/base_prediction_model.dart';
import 'package:pose_detection_realtime/models/workout_features.dart';
import 'package:pose_detection_realtime/utils/api_config.dart';

class LogisticRegressionModel implements BasePredictionModel {
  final String _apiUrl = ApiConfig.performanceApiUrl;
  double _lastConfidence = 0.0;

  @override
  Future<int> predict(WorkoutFeatures features) async {
    try {
      print("Calling Prediction API at $_apiUrl...");
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(features.toMap()),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prediction = data['prediction'];
        
        // Update confidence (if the API provides it, otherwise use a placeholder)
        _lastConfidence = data['probability'] ?? 0.88;

        // Map string response back to int as defined in BasePredictionModel
        if (prediction == "Good") {
          return 1;
        } else {
          return 0;
        }
      } else {
        print("API Error: ${response.statusCode} - ${response.body}");
        return 0; // Default to average on error
      }
    } catch (e) {
      print("Connection to Prediction API failed: $e");
      return 0; // Default to average on error
    }
  }

  @override
  double getConfidence() {
    return _lastConfidence;
  }
}
