import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pose_detection_realtime/models/forecasting_result.dart';
import 'package:pose_detection_realtime/utils/api_config.dart';

class XGBoostForecastingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<ForecastingResult?> predictNextReps(String? exerciseName) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    
    final String safeName = exerciseName ?? "Unknown";

    try {
      // 1. Get the last 100 sets (enough to form up to 10 sessions)
      final setsData = await _supabase
          .from('exercise_sets')
          .select('total_reps, intensity, exercise_date, created_at')
          .eq('user_id', user.id)
          .eq('exercise_name', safeName)
          .order('exercise_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(100);

      if (setsData == null || (setsData as List).isEmpty) {
        return null; // Not enough data
      }

      final List<Map<String, dynamic>> allSets = List<Map<String, dynamic>>.from(setsData);

      // Group by exercise_date
      Map<String, List<Map<String, dynamic>>> sessionsByDate = {};
      for (var s in allSets) {
        String date = s['exercise_date'] ?? s['created_at'].toString().split('T')[0];
        sessionsByDate.putIfAbsent(date, () => []).add(s);
      }

      // Sort dates descending
      List<String> sortedDates = sessionsByDate.keys.toList()..sort((a, b) => b.compareTo(a));
      
      // We only care about the last 10 sessions.
      final latestSessions = sortedDates.take(10).map((date) => sessionsByDate[date]!).toList();

      if (latestSessions.isEmpty) return null;

      // Helper to calculate session stats
      Map<String, double> getSessionStats(List<Map<String, dynamic>> sessionSets) {
        double totalReps = 0;
        double sumIntensity = 0;
        int validIntensityCount = 0;

        for (var s in sessionSets) {
          totalReps += (s['total_reps'] as num?)?.toDouble() ?? 0.0;
          final intensity = (s['intensity'] as num?)?.toDouble();
          if (intensity != null) {
            sumIntensity += intensity;
            validIntensityCount++;
          }
        }
        double avgIntensity = validIntensityCount > 0 ? sumIntensity / validIntensityCount : 0.0;
        return {'total_reps': totalReps, 'avg_intensity': avgIntensity};
      }

      // Calculate features
      List<Map<String, double>> sessionStats = latestSessions.map(getSessionStats).toList();

      // The most recent session is at index 0
      final lastSession = sessionStats[0];
      final intensity = lastSession['avg_intensity']!;
      final totalReps = lastSession['total_reps']!;

      // 2nd last session is at index 1
      double prevReps = 0.0;
      double prevIntensity = 0.0;
      if (sessionStats.length > 1) {
        prevReps = sessionStats[1]['total_reps']!;
        prevIntensity = sessionStats[1]['avg_intensity']!;
      }

      // Last 3 sessions for rolling average
      int numSessionsForRolling3 = sessionStats.length < 3 ? sessionStats.length : 3;
      double rollingAvgReps3 = 0.0;
      double rollingAvgIntensity3 = 0.0;
      for (int i = 0; i < numSessionsForRolling3; i++) {
        rollingAvgReps3 += sessionStats[i]['total_reps']!;
        rollingAvgIntensity3 += sessionStats[i]['avg_intensity']!;
      }
      rollingAvgReps3 /= numSessionsForRolling3;
      rollingAvgIntensity3 /= numSessionsForRolling3;

      // Last 7 sessions for rolling volume
      int numSessionsForRolling7 = sessionStats.length < 7 ? sessionStats.length : 7;
      double rollingVolume7d = 0.0;
      for (int i = 0; i < numSessionsForRolling7; i++) {
        rollingVolume7d += (sessionStats[i]['total_reps']! * sessionStats[i]['avg_intensity']!);
      }
      rollingVolume7d /= numSessionsForRolling7;

      // Days since last session
      String lastSessionDateStr = sortedDates[0];
      DateTime lastSessionDate = DateTime.parse(lastSessionDateStr);
      DateTime today = DateTime.now();
      double daysSinceLast = today.difference(lastSessionDate).inDays.toDouble();

      // Week of year
      int weekOfYear = _getWeekOfYear(today);

      Map<String, dynamic> features = {
        'intensity': intensity,
        'total_reps': totalReps,
        'prev_reps': prevReps,
        'prev_intensity': prevIntensity,
        'rolling_avg_reps_3': rollingAvgReps3,
        'rolling_avg_intensity_3': rollingAvgIntensity3,
        'rolling_volume_7d': rollingVolume7d,
        'days_since_last': daysSinceLast,
        'week_of_year': weekOfYear,
      };

      // Call API
      final String endpointUrl = "http://${ApiConfig.serverIp}:5000/forecast_performance";

      final response = await http.post(
        Uri.parse(endpointUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(features),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return ForecastingResult.fromJson(data, safeName, features);
      } else {
        print("Error from XGBoost API: \${response.statusCode} - \${response.body}");
        return null;
      }
    } catch (e, stacktrace) {
      print("Exception calling XGBoost API: $e");
      print("XGBoost Stacktrace: $stacktrace");
      return null;
    }
  }

  int _getWeekOfYear(DateTime date) {
    int dayOfYear = int.parse(date.difference(DateTime(date.year, 1, 1)).inDays.toString());
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }
}
