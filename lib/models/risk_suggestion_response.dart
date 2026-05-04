class RiskSuggestion {
  final String title;
  final String description;
  final String priority; // "high", "medium", "low"

  RiskSuggestion({
    required this.title,
    required this.description,
    required this.priority,
  });

  factory RiskSuggestion.fromJson(Map<String, dynamic> json) {
    return RiskSuggestion(
      title: json['title'] as String? ?? 'Suggestion',
      description: json['description'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
    );
  }
}

class RiskSuggestionResponse {
  final String summary;
  final String? warning;
  final List<RiskSuggestion> suggestions;

  RiskSuggestionResponse({
    required this.summary,
    this.warning,
    required this.suggestions,
  });

  factory RiskSuggestionResponse.fromJson(Map<String, dynamic> json) {
    return RiskSuggestionResponse(
      summary: json['summary'] as String? ?? 'Risk analysis complete.',
      warning: json['warning'] as String?,
      suggestions: (json['suggestions'] as List<dynamic>?)
              ?.map((s) => RiskSuggestion.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
