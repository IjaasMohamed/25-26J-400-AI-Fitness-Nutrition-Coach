import 'package:supabase_flutter/supabase_flutter.dart';

class PerformanceSuggestion {
  final String exerciseName;
  final String suggestion;
  final bool canIncrease;
  final double confidence;
  final String trend; // 'up', 'down', 'stable'
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> latestSessionSets;

  PerformanceSuggestion({
    required this.exerciseName,
    required this.suggestion,
    required this.canIncrease,
    required this.confidence,
    required this.trend,
    required this.stats,
    this.latestSessionSets = const [],
  });
}

class PerformancePredictor {
  final _supabase = Supabase.instance.client;

  Future<List<PerformanceSuggestion>> getSuggestions() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      
      // 1. Fetch data sorted by date to analyze trends
      final setsData = await _supabase
          .from('exercise_sets')
          .select('id, exercise_name, total_reps, exercise_date, actual_rest_time_seconds')
          .eq('user_id', user.id)
          .gte('created_at', thirtyDaysAgo)
          .order('exercise_date', ascending: true);

      if (setsData == null || (setsData as List).isEmpty) return [];
      final List<Map<String, dynamic>> sets = List<Map<String, dynamic>>.from(setsData);

      // 2. Fetch reps
      final repsData = await _supabase
          .from('exercise_reps')
          .select('time_since_last_rep, set_id')
          .eq('user_id', user.id)
          .gte('created_at', thirtyDaysAgo);

      final List<Map<String, dynamic>> reps = repsData != null ? List<Map<String, dynamic>>.from(repsData) : [];

      // 3. Group by exercise and keep chronological order
      Map<String, List<Map<String, dynamic>>> exerciseSessions = {};
      for (var set in sets) {
        String name = set['exercise_name'];
        exerciseSessions.putIfAbsent(name, () => []).add(set);
      }

      List<PerformanceSuggestion> suggestions = [];

      for (var entry in exerciseSessions.entries) {
        String name = entry.key;
        List<Map<String, dynamic>> sessions = entry.value;
        
        // Require at least 2 sessions to compare Day N vs History
        if (sessions.length < 2) {
          suggestions.add(_buildBaselineSuggestion(name, sessions.length));
          continue;
        }

       
        
        // 1. Overall Metrics (All sessions)
        double totalRepsAll = sessions.map((s) => (s['total_reps'] as num).toDouble()).reduce((a, b) => a + b);
        double overallAvgReps = totalRepsAll / sessions.length;
        
        var allRestSeconds = sessions.where((s) => s['actual_rest_time_seconds'] != null)
            .map((s) => (s['actual_rest_time_seconds'] as num).toDouble())
            .toList();
        double overallAvgRest = allRestSeconds.isEmpty ? 0.0 : allRestSeconds.reduce((a, b) => a + b) / allRestSeconds.length;

        // 2. Latest Session (Day N) - Get all sets for that day
        var latestSessionDate = sessions.last['exercise_date'];
        var latestSessionSets = sessions.where((s) => s['exercise_date'] == latestSessionDate).toList();
        
        double dayNReps = latestSessionSets.map((s) => (s['total_reps'] as num).toDouble()).reduce((a, b) => a + b) / latestSessionSets.length;
        
        var latestRestSeconds = latestSessionSets.where((s) => s['actual_rest_time_seconds'] != null)
            .map((s) => (s['actual_rest_time_seconds'] as num).toDouble())
            .toList();
        double dayNRest = latestRestSeconds.isEmpty ? overallAvgRest : latestRestSeconds.reduce((a, b) => a + b) / latestRestSeconds.length;
        
        // 3. Historical Baseline (Average of all sessions before today)
        var history = sessions.sublist(0, sessions.length - 1);
        double historyAvgReps = history.map((s) => (s['total_reps'] as num).toDouble()).reduce((a, b) => a + b) / history.length;
        
        // 4. Performance Deltas
        double repDelta = dayNReps - historyAvgReps;

        // 5. Intensity (Current Tempo)
        var latestSessionIds = latestSessionSets.map((s) => s['id']).toList();
        var latestRepsList = reps.where((r) => latestSessionIds.contains(r['set_id'])).toList();
        double currentTempo = latestRepsList.isEmpty ? 3.0 : 
            latestRepsList.map((r) => (r['time_since_last_rep'] as num).toDouble()).reduce((a, b) => a + b) / latestRepsList.length;

        // --- LOGIC RULES ---
        bool canIncrease = false;
        String message = "";
        double confidence = 0.5;
        String trend = 'stable';

        // --- REFINED LOGIC RULES (Defining the Average Point) ---

        // 1. High Performance (Goal Up)
        if (repDelta >= 2.0 || (repDelta > 0 && currentTempo < 2.2)) {
          canIncrease = true;
          message = "AI Analysis: Performance Peak. You are significantly above your ${overallAvgReps.toStringAsFixed(1)} average. Goal increase is highly recommended.";
          confidence = 0.95;
          trend = 'up';
        } 
        // 2. Average / Maintenance Point (Consistent)
        else if (repDelta.abs() <= 1.0) {
          message = "AI Insight: Perfect Consistency. You are hitting your average point of ${overallAvgReps.toStringAsFixed(1)} reps perfectly. Try to decrease rest time to spark new growth.";
          confidence = 0.85;
          trend = 'stable';
        }
        // 3. Low Performance (Warning)
        else if (repDelta < -1.0) {
          message = "AI Warning: Recovery Needed. Performance is ${repDelta.abs().toStringAsFixed(1)} reps below your average. Focus on sleep and nutrition today.";
          confidence = 0.80;
          trend = 'down';
        } 
        // 4. Fallback / Steady
        else {
          message = "AI Maintenance: Performance is stable. You are on track with your mathematical baseline.";
          confidence = 0.70;
          trend = 'stable';
        }

        suggestions.add(PerformanceSuggestion(
          exerciseName: _formatName(name),
          suggestion: message,
          canIncrease: canIncrease,
          confidence: confidence,
          trend: trend,
          stats: {
            'latest_avg_reps': dayNReps.toStringAsFixed(1),
            'overall_avg': overallAvgReps.toStringAsFixed(1),
            'velocity': (repDelta >= 0 ? "+" : "") + repDelta.toStringAsFixed(1),
            'avg_rest': dayNRest.toStringAsFixed(0),
            'rep_tempo': currentTempo.toStringAsFixed(2),
            'excess_rest': (dayNRest > 90) ? (dayNRest - 60).toInt().toString() : "0",
            'consistency': sessions.length,
          },
          latestSessionSets: latestSessionSets,
        ));
      }

      return suggestions;
    } catch (e) {
      print("Trend Predictor Error: $e");
      return [];
    }
  }

  PerformanceSuggestion _buildBaselineSuggestion(String name, int count) {
    return PerformanceSuggestion(
      exerciseName: _formatName(name),
      suggestion: "Establishing baseline. Need 3 days of history to calculate your growth velocity.",
      canIncrease: false,
      confidence: 0.4,
      trend: 'stable',
      stats: {'latest_reps': '-', 'overall_avg': '-', 'velocity': '-', 'avg_rest': '-', 'rep_tempo': '-', 'excess_rest': '-', 'consistency': count},
    );
  }

  String _formatName(String raw) {
    if (raw.isEmpty) return "";
    return raw.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }
}
