class ForecastingResult {
  final String exerciseName;
  final double predictedNextReps;
  final Map<String, dynamic> inputFeatures;

  ForecastingResult({
    required this.exerciseName,
    required this.predictedNextReps,
    required this.inputFeatures,
  });

  factory ForecastingResult.fromJson(Map<String, dynamic> json, String exerciseName, Map<String, dynamic> inputFeatures) {
    return ForecastingResult(
      exerciseName: exerciseName,
      predictedNextReps: (json['predicted_next_reps'] as num).toDouble(),
      inputFeatures: inputFeatures,
    );
  }
}
