import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pose_detection_realtime/models/injury_risk_request.dart';
import 'package:pose_detection_realtime/models/injury_risk_response.dart';
import 'package:pose_detection_realtime/models/risk_suggestion_response.dart';
import 'package:pose_detection_realtime/utils/api_config.dart';

class GrokSuggestionService {
  /// Fetches AI-powered risk reduction suggestions from Grok via the backend proxy.
  /// Sends all 12 risk metrics + the prediction result to get personalized advice.
  static Future<RiskSuggestionResponse?> fetchSuggestions({
    required InjuryRiskRequest riskRequest,
    required InjuryRiskResponse prediction,
  }) async {
    final url = Uri.parse(ApiConfig.riskSuggestionsApiUrl);

    // Combine the risk metrics with the prediction result
    final body = {
      ...riskRequest.toJson(),
      'risk_label': prediction.riskLabel,
      'probability': prediction.probability,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 35)); // Grok can take a few seconds

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Check for error in response
        if (data.containsKey('error')) {
          throw Exception(data['error']);
        }
        
        return RiskSuggestionResponse.fromJson(data);
      } else {
        throw Exception('Failed to fetch suggestions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Grok suggestions failed: $e');
    }
  }

  /// Sends a follow-up chat message about risk suggestions.
  /// Returns the AI's text reply.
  static Future<String> sendChatMessage({
    required String message,
    Map<String, dynamic>? riskContext,
  }) async {
    final url = Uri.parse(ApiConfig.riskChatApiUrl);

    final body = {
      'message': message,
      if (riskContext != null) 'risk_context': riskContext,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 35));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['reply'] as String? ?? 'No response received.';
      } else {
        throw Exception('Chat failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Chat error: $e');
    }
  }
}
