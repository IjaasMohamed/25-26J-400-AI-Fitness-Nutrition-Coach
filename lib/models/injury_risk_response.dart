class InjuryRiskResponse {
  final int prediction;
  final String riskLabel;
  final double probability;

  InjuryRiskResponse({
    required this.prediction,
    required this.riskLabel,
    required this.probability,
  });

  factory InjuryRiskResponse.fromJson(Map<String, dynamic> json) {
    return InjuryRiskResponse(
      prediction: json['prediction'] as int,
      riskLabel: json['risk_label'] as String,
      probability: (json['probability'] as num).toDouble(),
    );
  }
}
