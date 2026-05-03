class PerformanceSuggestion {
  final String exerciseName;
  final String suggestion;
  final bool canIncrease;
  final double confidence;
  final String trend; // 'up', 'down', 'stable'
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> latestSessionSets;
  final double formScore; // 0-100%
  final Map<String, double> weeklyProgress; // e.g. {'Week 10': 15.5}

  PerformanceSuggestion({
    required this.exerciseName,
    required this.suggestion,
    required this.canIncrease,
    required this.confidence,
    required this.trend,
    required this.stats,
    this.latestSessionSets = const [],
    this.formScore = 0.0,
    this.weeklyProgress = const {},
  });
}
