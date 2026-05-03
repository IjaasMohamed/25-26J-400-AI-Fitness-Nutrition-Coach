class LSTMSessionData {
  final String name;
  final String exercise;
  final int sets;
  final int totalReps;
  final double timeMins;
  final double restBetweenSetsSecs;
  final double avgRestPerRepSecs;
  final int day;
  final int month;
  final double avgReps;
  final int maxReps;
  final int minReps;

  LSTMSessionData({
    required this.name,
    required this.exercise,
    required this.sets,
    required this.totalReps,
    required this.timeMins,
    required this.restBetweenSetsSecs,
    required this.avgRestPerRepSecs,
    required this.day,
    required this.month,
    required this.avgReps,
    required this.maxReps,
    required this.minReps,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'exercise': exercise,
    'sets': sets,
    'total_reps': totalReps,
    'time_mins': timeMins,
    'rest_between_sets_secs': restBetweenSetsSecs,
    'avg_rest_per_rep_secs': avgRestPerRepSecs,
    'day': day,
    'month': month,
    'avg_reps': avgReps,
    'max_reps': maxReps,
    'min_reps': minReps,
  };
}

class LSTMPredictionRequest {
  final List<LSTMSessionData> sessions;

  LSTMPredictionRequest({required this.sessions});

  Map<String, dynamic> toJson() => {
    'sessions': sessions.map((s) => s.toJson()).toList(),
  };
}

class LSTMPredictionResponse {
  final String prediction;
  final double confidence;
  final String trend;
  final List<int> volumeHistory;
  final double consistencyScore;
  final List<String> coachingTips;
  final List<String> historicalLabels;

  LSTMPredictionResponse({
    required this.prediction,
    required this.confidence,
    required this.trend,
    required this.volumeHistory,
    required this.consistencyScore,
    required this.coachingTips,
    required this.historicalLabels,
  });

  factory LSTMPredictionResponse.fromJson(Map<String, dynamic> json) {
    return LSTMPredictionResponse(
      prediction: json['prediction'] ?? 'Unknown',
      confidence: (json['probability'] ?? 0.0).toDouble(),
      trend: json['trend'] ?? 'Stable',
      volumeHistory: List<int>.from(json['volume_history'] ?? []),
      consistencyScore: (json['consistency_score'] ?? 0.0).toDouble(),
      coachingTips: List<String>.from(json['coaching_tips'] ?? []),
      historicalLabels: List<String>.from(json['historical_labels'] ?? []),
    );
  }
}
