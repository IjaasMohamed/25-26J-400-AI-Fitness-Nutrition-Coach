import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/injury_risk_request.dart';
import '../models/injury_risk_response.dart';

import 'package:pose_detection_realtime/utils/api_config.dart';

class InjuryRiskApiService {
  static const String _baseUrl = 'http://${ApiConfig.serverIp}:5000'; 
  
  static Future<InjuryRiskResponse?> predictInjuryRisk(InjuryRiskRequest request) async {
    final url = Uri.parse('$_baseUrl/predict-injury-risk');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return InjuryRiskResponse.fromJson(data);
      } else {
        // Handle API errors (400, 500, etc.)
        final errorMsg = jsonDecode(response.body)['detail'] ?? 'Unknown error';
        throw Exception('Failed to predict injury risk: $errorMsg');
      }
    } catch (e) {
      // Handle network errors, format exceptions, etc.
      throw Exception('API call failed: $e');
    }
  }
}
