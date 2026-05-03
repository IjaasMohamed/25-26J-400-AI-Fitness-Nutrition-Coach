import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pose_detection_realtime/models/workout_features.dart';
import 'package:pose_detection_realtime/models/base_prediction_model.dart';
import 'package:pose_detection_realtime/models/logistic_regression_model.dart';
import 'package:pose_detection_realtime/models/performance_suggestion.dart';
import 'package:pose_detection_realtime/utils/api_config.dart';

class PredictionService {
  final _supabase = Supabase.instance.client;
  final BasePredictionModel _model = LogisticRegressionModel();

  Future<List<PerformanceSuggestion>> getSuggestions() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      
      // 1. Fetch data
      final setsData = await _supabase
          .from('exercise_sets')
          .select('id, exercise_name, total_reps, exercise_date, actual_rest_time_seconds, created_at')
          .eq('user_id', user.id)
          .gte('created_at', thirtyDaysAgo)
          .order('exercise_date', ascending: true);

      if (setsData == null || (setsData as List).isEmpty) {
        print("PredictionService: No workout data found in Supabase. Returning welcome suggestion.");
        return [_getWelcomeSuggestion()];
      }
      final List<Map<String, dynamic>> sets = List<Map<String, dynamic>>.from(setsData);

      final repsData = await _supabase
          .from('exercise_reps')
          .select('time_since_last_rep, set_id, max_depth_angle, left_right_imbalance_degrees, created_at')
          .eq('user_id', user.id)
          .gte('created_at', thirtyDaysAgo);

      final List<Map<String, dynamic>> reps = repsData != null ? List<Map<String, dynamic>>.from(repsData) : [];

      // 2. Group by exercise
      Map<String, List<Map<String, dynamic>>> exerciseSessions = {};
      for (var set in sets) {
        String name = set['exercise_name'];
        exerciseSessions.putIfAbsent(name, () => []).add(set);
      }

      List<PerformanceSuggestion> suggestions = [];

      for (var entry in exerciseSessions.entries) {
        String exerciseName = entry.key;
        List<Map<String, dynamic>> sessions = entry.value;
        
        if (sessions.length < 1) continue;

        // 3. Extract Latest Session Features
        final latestSessionDate = sessions.last['exercise_date'] ?? sessions.last['created_at'];
        final latestSessionSets = sessions.where((s) => (s['exercise_date'] ?? s['created_at']) == latestSessionDate).toList();
        final latestSessionIds = latestSessionSets.map((s) => s['id']).toList();
        final latestRepsList = reps.where((r) => latestSessionIds.contains(r['set_id'])).toList();

        final features = _extractFeatures(user.email ?? "User", exerciseName, latestSessionSets, latestRepsList);
        
        // 4. Run Prediction
        final predictionResult = await _model.predict(features);
        final confidence = _model.getConfidence();

        // 5. Build Suggestion (reusing some logic from the old predictor)
        suggestions.add(_buildSuggestion(exerciseName, features, predictionResult, confidence, latestSessionSets, latestRepsList, sessions));
      }

      return suggestions;
    } catch (e) {
      print("Prediction Service Error: $e");
      return [_getConnectionErrorSuggestion(e.toString())];
    }
  }

  PerformanceSuggestion _getConnectionErrorSuggestion(String error) {
    return PerformanceSuggestion(
      exerciseName: "Connection Error",
      suggestion: "AI Analysis: Could not connect to the Prediction API at ${ApiConfig.performanceApiUrl}. Is your Flask backend running and is the IP address correct in 'api_config.dart'?",
      canIncrease: false,
      confidence: 0.0,
      trend: "stable",
      formScore: 0,
      weeklyProgress: {},
      latestSessionSets: [],
      stats: {
        'latest_avg_reps': 'Error',
        'overall_avg': 'Error',
        'velocity': '0',
        'avg_rest': '0',
        'rep_tempo': '0',
        'excess_rest': '0',
        'consistency': '0',
        'form_quality': '0',
      },
    );
  }

  WorkoutFeatures _extractFeatures(String userName, String exercise, List<Map<String, dynamic>> sessionSets, List<Map<String, dynamic>> sessionReps) {
    int totalReps = sessionSets.map((s) => (s['total_reps'] as num).toInt()).reduce((a, b) => a + b);
    int sets = sessionSets.length;
    
    double avgRest = sessionSets.where((s) => s['actual_rest_time_seconds'] != null)
        .map((s) => (s['actual_rest_time_seconds'] as num).toDouble())
        .fold(0.0, (a, b) => a + b) / (sets > 0 ? sets : 1);

    double avgRestPerRep = sessionReps.isEmpty ? 0.0 :
        sessionReps.map((r) => (r['time_since_last_rep'] as num).toDouble()).reduce((a, b) => a + b) / sessionReps.length;

    DateTime date = DateTime.parse(sessionSets.last['exercise_date'] ?? sessionSets.last['created_at']);

    List<int> repsPerSet = sessionSets.map((s) => (s['total_reps'] as num).toInt()).toList();
    int maxReps = repsPerSet.reduce((a, b) => a > b ? a : b);
    int minReps = repsPerSet.reduce((a, b) => a < b ? a : b);

    // Time_Mins estimate: assuming a set takes ~30s plus rest time
    double estimatedTimeMins = (sets * 0.5) + (avgRest * (sets - 1) / 60.0);

    return WorkoutFeatures(
      name: userName,
      exercise: exercise,
      sets: sets,
      totalReps: totalReps,
      timeMins: estimatedTimeMins,
      restBetweenSetsSecs: avgRest,
      avgRestPerRepSecs: avgRestPerRep,
      day: date.day,
      month: date.month,
      avgReps: totalReps / (sets > 0 ? sets : 1),
      maxReps: maxReps,
      minReps: minReps,
    );
  }

  PerformanceSuggestion _buildSuggestion(
    String exerciseName, 
    WorkoutFeatures features, 
    int prediction, 
    double confidence,
    List<Map<String, dynamic>> latestSessionSets,
    List<Map<String, dynamic>> latestRepsList,
    List<Map<String, dynamic>> allSessions,
  ) {
    bool isGood = prediction == 1;
    String trend = isGood ? 'up' : 'stable';
    String message = isGood 
        ? "AI Analysis: Performance Peak. Predicted as 'Good'. Goal increase is recommended."
        : "AI Insight: Predicted as 'Average'. Maintain consistency and focus on recovery.";

    double formScore = _calculateFormScore(latestRepsList);

    // Weekly progress logic (reused)
    Map<String, double> weeklyProgress = {};
    Map<int, List<Map<String, dynamic>>> setsByWeek = {};
    for (var s in allSessions) {
      final date = DateTime.parse(s['exercise_date'] ?? s['created_at']);
      final weekNum = ((date.day + (date.month - 1) * 30) / 7).floor(); 
      setsByWeek.putIfAbsent(weekNum, () => []).add(s);
    }
    setsByWeek.forEach((week, setsInWeek) {
      double avgReps = setsInWeek.map((s) => (s['total_reps'] as num).toDouble()).reduce((a, b) => a + b) / setsInWeek.length;
      weeklyProgress['Week $week'] = avgReps;
    });

    return PerformanceSuggestion(
      exerciseName: _formatName(exerciseName),
      suggestion: message,
      canIncrease: isGood,
      confidence: confidence,
      trend: trend,
      formScore: formScore,
      weeklyProgress: weeklyProgress,
      latestSessionSets: latestSessionSets,
      stats: {
        'latest_avg_reps': features.avgReps.toStringAsFixed(1),
        'overall_avg': (allSessions.isEmpty ? 0 : allSessions.map((s) => (s['total_reps'] as num).toDouble()).reduce((a, b) => a + b) / allSessions.length).toStringAsFixed(1),
        'velocity': isGood ? "+1.0" : "0.0",
        'avg_rest': features.restBetweenSetsSecs.toStringAsFixed(0),
        'rep_tempo': features.avgRestPerRepSecs.toStringAsFixed(2),
        'excess_rest': (features.restBetweenSetsSecs > 90) ? (features.restBetweenSetsSecs - 60).toInt().toString() : "0",
        'consistency': allSessions.length,
        'form_quality': formScore.toStringAsFixed(0),
      },
    );
  }

  String _formatName(String raw) {
    if (raw.isEmpty) return "";
    return raw.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  double _calculateFormScore(List<Map<String, dynamic>> setReps) {
    if (setReps.isEmpty) return 0.0;
    double avgDepth = setReps.map((r) => (r['max_depth_angle'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / setReps.length;
    double depthScore = (avgDepth / 90.0 * 100).clamp(0, 100);
    double avgImbalance = setReps.map((r) => (r['left_right_imbalance_degrees'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / setReps.length;
    double symmetryScore = (100 - (avgImbalance * 5)).clamp(0, 100);
    return (depthScore * 0.4 + symmetryScore * 0.6);
  }

  PerformanceSuggestion _getWelcomeSuggestion() {
    return PerformanceSuggestion(
      exerciseName: "Your First Insight",
      suggestion: "Welcome! Complete your first workout to see AI-powered performance analysis here.",
      canIncrease: false,
      confidence: 1.0,
      trend: "up",
      formScore: 100,
      weeklyProgress: {},
      latestSessionSets: [],
      stats: {
        'latest_avg_reps': '0',
        'overall_avg': '0',
        'velocity': '0',
        'avg_rest': '0',
        'rep_tempo': '0',
        'excess_rest': '0',
        'consistency': '0',
        'form_quality': '100',
      },
    );
  }
}
