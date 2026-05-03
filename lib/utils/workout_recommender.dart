import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class WorkoutRecommender {
  static List<Map<String, dynamic>>? _cachedData;

  static Future<void> init() async {
    if (_cachedData != null) return;
    try {
      final String response = await rootBundle.loadString('assets/workout_data.json');
      final data = await json.decode(response);
      _cachedData = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error loading workout data: $e');
      _cachedData = [];
    }
  }

  static List<Map<String, dynamic>> getRecommendations({
    required String difficulty,
    String? targetMuscle,
    int count = 5,
  }) {
    if (_cachedData == null || _cachedData!.isEmpty) return [];

    // Filter by difficulty (case insensitive)
    var filtered = _cachedData!.where((item) {
      final itemDiff = item['Difficulty Level_Cleaned']?.toString().toLowerCase() ?? '';
      return itemDiff == difficulty.toLowerCase();
    }).toList();

    // If target muscle is provided, try to filter or prioritize
    if (targetMuscle != null && targetMuscle.isNotEmpty) {
      final muscleFiltered = filtered.where((item) {
        final itemMuscle = item['Target Muscle Group_Cleaned']?.toString().toLowerCase() ?? '';
        return itemMuscle.contains(targetMuscle.toLowerCase());
      }).toList();

      if (muscleFiltered.isNotEmpty) {
        filtered = muscleFiltered;
      }
    }

    if (filtered.isEmpty) return [];

    // Simple categorization by calories (as done in the python model)
    filtered.sort((a, b) => (a['Calories_Burned'] ?? 0).compareTo(b['Calories_Burned'] ?? 0));

    final int len = filtered.length;
    if (len <= count) return filtered;

    // Pick a spread of intensities
    final List<Map<String, dynamic>> result = [];
    final random = Random();

    // Pick 1 from lower 1/3
    result.add(filtered[random.nextInt(len ~/ 3)]);
    
    // Pick 2 from middle 1/3
    final midStart = len ~/ 3;
    final midEnd = (2 * len) ~/ 3;
    if (midEnd > midStart) {
      result.add(filtered[midStart + random.nextInt(midEnd - midStart)]);
      if (count > 2) result.add(filtered[midStart + random.nextInt(midEnd - midStart)]);
    }

    // Pick remaining from top 1/3
    final topStart = (2 * len) ~/ 3;
    while (result.length < count && result.length < len) {
      final item = filtered[topStart + random.nextInt(len - topStart)];
      if (!result.contains(item)) {
        result.add(item);
      } else if (len < 10) { // Safety for small lists
        result.add(item);
        break;
      }
    }

    // Shuffle final result
    result.shuffle();
    return result.take(count).toList();
  }

  static Future<void> generateSchedule() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final userData = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', user.id)
        .single();

    final difficulty = userData['experience_level'] ?? 'Beginner';
    final muscle = userData['target_muscle'];

    final recs = getRecommendations(
      difficulty: difficulty,
      targetMuscle: muscle,
      count: 7, // One for each day if possible
    );

    if (recs.isEmpty) return;

    // Clear existing schedule (Optional: user might prefer this)
    // await Supabase.instance.client.from('workout_schedules').delete().eq('user_id', user.id);

    // Insert new schedule items
    final List<Map<String, dynamic>> insertData = [];
    for (var i = 0; i < recs.length; i++) {
       insertData.add({
        'user_id': user.id,
        'exercise_name': recs[i]['Name of Exercise'],
        'target_sets': 3,
        'target_reps': 12,
        'rest_time_seconds': 60,
      });
    }

    if (insertData.isNotEmpty) {
      await Supabase.instance.client.from('workout_schedules').insert(insertData);
    }
  }
}
