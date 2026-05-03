import 'package:pose_detection_realtime/models/lstm_prediction_models.dart';

class LSTMSessionMapper {
  static List<LSTMSessionData> mapToSessions(
    String userName,
    List<Map<String, dynamic>> sets,
    List<Map<String, dynamic>> reps,
  ) {
    // 1. Group sets by date/session
    // Assuming a 'session' is defined by a unique date or a common identifier if the app has it. 
    // If not, we can use the exercise_date as the key.
    Map<String, List<Map<String, dynamic>>> sessionsMap = {};
    for (var set in sets) {
      String dateKey = set['exercise_date'] ?? set['created_at'].toString().substring(0, 10);
      sessionsMap.putIfAbsent(dateKey, () => []).add(set);
    }

    // 2. Sort sessions by date descending
    var sortedDates = sessionsMap.keys.toList()..sort((a, b) => b.compareTo(a));
    
    // We only need the latest 3
    var latestDates = sortedDates.take(3).toList();
    
    List<LSTMSessionData> sessions = [];
    
    for (var date in latestDates) {
      var sessionSets = sessionsMap[date]!;
      var sessionIds = sessionSets.map((s) => s['id']).toList();
      var sessionReps = reps.where((r) => sessionIds.contains(r['set_id'])).toList();
      
      sessions.add(_extractSessionData(userName, sessionSets, sessionReps));
    }

    // 3. Return (already in descending order from latest to oldest, but LSTM might expect chronological)
    // Most LSTM models expect chronological sequence (Session 1, 2, 3), so we reverse.
    return sessions.reversed.toList();
  }

  static LSTMSessionData _extractSessionData(
    String userName,
    List<Map<String, dynamic>> sessionSets,
    List<Map<String, dynamic>> sessionReps,
  ) {
    int totalReps = sessionSets.map((s) => (s['total_reps'] as num).toInt()).reduce((a, b) => a + b);
    int sets = sessionSets.length;
    String exercise = sessionSets.last['exercise_name'] ?? "Unknown";
    
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

    return LSTMSessionData(
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
}
