class WorkoutFeatures {
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

  WorkoutFeatures({
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

  Map<String, dynamic> toMap() {
    return {
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
}
