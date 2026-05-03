import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

class WorkoutService {
  static Future<void> saveSet({
    required String exerciseName,
    required int setNumber,
    required int reps,
    int? heartRate,
    double? actualRestTime,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final setId = const Uuid().v4();

      await supabase.from('exercise_sets').insert({
        'id': setId,
        'user_id': user.id,
        'exercise_name': exerciseName,
        'set_number': setNumber,
        'total_reps': reps,
        'exercise_date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'exercise_time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'heart_rate': heartRate,
        'actual_rest_time_seconds': actualRestTime,
        'created_at': now.toIso8601String(),
      });
      debugPrint('[WorkoutService] Set saved successfully: $exerciseName (Set $setNumber)');
    } catch (e) {
      debugPrint('[WorkoutService] Error saving set: $e');
    }
  }

  static Future<void> updateHeartRate(String setId, int? heartRate) async {
    try {
      if (heartRate == null) return;
      final supabase = Supabase.instance.client;
      
      // Fetch the set to get reps and duration for final intensity calculation
      final setData = await supabase.from('exercise_sets').select().eq('id', setId).single();
      final int reps = setData['total_reps'] ?? 0;
      final double duration = (setData['duration_seconds'] as num?)?.toDouble() ?? 30.0;
      
      final double intensity = calculateIntensity(
        reps: reps,
        durationSeconds: duration,
        heartRate: heartRate,
      );

      await supabase.from('exercise_sets').update({
        'heart_rate': heartRate,
        'intensity': intensity,
      }).eq('id', setId);
      
      debugPrint('[WorkoutService] Heart rate and Intensity ($intensity) updated for set $setId');
    } catch (e) {
      debugPrint('[WorkoutService] Error updating heart rate: $e');
    }
  }

  static double calculateIntensity({
    required int reps,
    required double durationSeconds,
    int? heartRate,
  }) {
    // 1. Rep Pace Intensity (1.0 - 10.0)
    // RPM (Reps Per Minute)
    double rpm = (reps / (durationSeconds / 60)).clamp(0, 60);
    double paceScore = (rpm / 40 * 10).clamp(1.0, 10.0); // 40 RPM = 10 intensity

    if (heartRate == null) return paceScore;

    // 2. Heart Rate Intensity (1.0 - 10.0)
    // Assume 70 is resting, 190 is max.
    double hrScore = ((heartRate - 70) / (190 - 70) * 10).clamp(1.0, 10.0);

    // 3. Blend them (Pace 40%, HR 60%)
    return (paceScore * 0.4 + hrScore * 0.6).clamp(1.0, 10.0);
  }

  static Future<int?> showHeartRateDialog(BuildContext context) async {
    int? heartRate;
    final controller = TextEditingController();
    
    return showDialog<int?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E), // AppTheme.bgDarkSecondary fallback
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Workout Complete!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Great job! All sets completed.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            const Text('What is your Heart Rate (BPM)?', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. 120',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.favorite, color: Colors.redAccent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Skip', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              Navigator.pop(context, val);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676), // AppTheme.secondary fallback
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Workout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
