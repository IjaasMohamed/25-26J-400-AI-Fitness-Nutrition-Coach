class InjuryRiskRequest {
  final double age;
  final int gender;
  final double heightCm;
  final double weightKg;
  final double bmi;
  final double trainingFrequency;
  final double trainingDuration;
  final double warmupTime;
  final double flexibilityScore;
  final double muscleAsymmetry;
  final int injuryHistory;
  final double trainingIntensity;

  InjuryRiskRequest({
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.bmi,
    required this.trainingFrequency,
    required this.trainingDuration,
    required this.warmupTime,
    required this.flexibilityScore,
    required this.muscleAsymmetry,
    required this.injuryHistory,
    required this.trainingIntensity,
  });

  Map<String, dynamic> toJson() {
    return {
      'Age': age,
      'Gender': gender,
      'Height_cm': heightCm,
      'Weight_kg': weightKg,
      'BMI': bmi,
      'Training_Frequency': trainingFrequency,
      'Training_Duration': trainingDuration,
      'Warmup_Time': warmupTime,
      'Flexibility_Score': flexibilityScore,
      'Muscle_Asymmetry': muscleAsymmetry,
      'Injury_History': injuryHistory,
      'Training_Intensity': trainingIntensity,
    };
  }
}
