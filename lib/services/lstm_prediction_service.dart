import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pose_detection_realtime/utils/api_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pose_detection_realtime/models/lstm_prediction_models.dart';
import 'package:pose_detection_realtime/utils/lstm_session_mapper.dart';

class LSTMPredictionResult {
  final LSTMPredictionResponse? data;
  final String? error;

  LSTMPredictionResult({this.data, this.error});
}

class LSTMPredictionService {
  final _supabase = Supabase.instance.client;
  final String _apiUrl = ApiConfig.lstmPerformanceApiUrl;

  Future<LSTMPredictionResult> getLSTMPrediction({String? exerciseName}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return LSTMPredictionResult(error: "User session not found.");
    }

    try {
      // 1. Fetch latest 5 sets for this specific exercise
      var query = _supabase
          .from('exercise_sets')
          .select('id, exercise_name, total_reps, exercise_date, actual_rest_time_seconds, created_at')
          .eq('user_id', user.id);
      
      if (exerciseName != null) {
        query = query.eq('exercise_name', exerciseName);
      }
      
      final setsData = await query
          .order('created_at', ascending: false)
          .limit(5);

      if (setsData == null || (setsData as List).isEmpty) {
        return LSTMPredictionResult(error: "No workout data found for ${exerciseName ?? 'this exercise'}.");
      }

      final List<Map<String, dynamic>> sets = List<Map<String, dynamic>>.from(setsData);
      
      // Since we want 5 SETS now, we don't group by session. 
      // We treat each set as a data point.
      
      // 2. Fetch reps for these specific sets
      final List<String> setIds = sets.map((s) => s['id'].toString()).toList();
      final repsData = await _supabase
          .from('exercise_reps')
          .select('time_since_last_rep, set_id, created_at')
          .inFilter('set_id', setIds);

      final List<Map<String, dynamic>> reps = repsData != null ? List<Map<String, dynamic>>.from(repsData) : [];

      // 3. Map to LSTMPredictionRequest
      // We'll modify the mapper or just map directly here for simplicity
      // Treat each set as its own "session" for the API
      final List<LSTMSessionData> sessions = [];
      for (var set in sets.reversed) { // chronological order
        var setReps = reps.where((r) => r['set_id'] == set['id']).toList();
        
        DateTime date = DateTime.parse(set['exercise_date'] ?? set['created_at']);
        double avgRestPerRep = setReps.isEmpty ? 0.0 :
            setReps.map((r) => (r['time_since_last_rep'] as num).toDouble()).reduce((a, b) => a + b) / setReps.length;

        sessions.add(LSTMSessionData(
          name: user.email?.split('@')[0] ?? "User",
          exercise: set['exercise_name'] ?? "Unknown",
          sets: 1,
          totalReps: (set['total_reps'] as num).toInt(),
          timeMins: 0.5, // estimate
          restBetweenSetsSecs: (set['actual_rest_time_seconds'] as num?)?.toDouble() ?? 0.0,
          avgRestPerRepSecs: avgRestPerRep,
          day: date.day,
          month: date.month,
          avgReps: (set['total_reps'] as num).toDouble(),
          maxReps: (set['total_reps'] as num).toInt(),
          minReps: (set['total_reps'] as num).toInt(),
        ));
      }

      final request = LSTMPredictionRequest(sessions: sessions);
      
      // 4. Call Backend API
      print("Calling Performance Prediction API for ${exerciseName ?? 'General'}...");
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final predictionResponse = LSTMPredictionResponse.fromJson(data);
        
        return LSTMPredictionResult(
          data: predictionResponse,
        );
      } else {
        return LSTMPredictionResult(error: "Backend error: ${response.statusCode}");
      }
    } catch (e) {
      print("LSTM Prediction Service Error: $e");
      return LSTMPredictionResult(error: "Connection to Prediction API failed: $e");
    }
  }
}
