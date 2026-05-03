import 'package:flutter/material.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/screens/detection_screen.dart';
import 'package:pose_detection_realtime/services/workout_service.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';

/// A reusable bottom sheet that asks the user to configure Sets, Reps, and
/// Rest Time before launching a scheduled [DetectionScreen].
///
/// Usage (from anywhere):
/// ```dart
/// WorkoutConfigSheet.show(context, exerciseModel: myExercise);
/// ```
class WorkoutConfigSheet {
  static void show(
    BuildContext context, {
    required ExerciseDataModel exercise,
    // Optional: pass remaining exercises for multi-exercise flow
    List<Map<String, dynamic>> remainingSchedule = const [],
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WorkoutConfigSheetBody(
        exercise: exercise,
        remainingSchedule: remainingSchedule,
      ),
    );
  }
}

class _WorkoutConfigSheetBody extends StatefulWidget {
  final ExerciseDataModel exercise;
  final List<Map<String, dynamic>> remainingSchedule;

  const _WorkoutConfigSheetBody({
    required this.exercise,
    required this.remainingSchedule,
  });

  @override
  State<_WorkoutConfigSheetBody> createState() => _WorkoutConfigSheetBodyState();
}

class _WorkoutConfigSheetBodyState extends State<_WorkoutConfigSheetBody> {
  final _setsCtrl = TextEditingController(text: '3');
  final _repsCtrl = TextEditingController(text: '10');
  final _restCtrl = TextEditingController(text: '60');

  @override
  void dispose() {
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _restCtrl.dispose();
    super.dispose();
  }

  void _launch() async {
    final sets = int.tryParse(_setsCtrl.text) ?? 3;
    final reps = int.tryParse(_repsCtrl.text) ?? 10;
    final rest = int.tryParse(_restCtrl.text) ?? 60;

    final scheduleItem = {
      'exercise_name': widget.exercise.title,
      'target_sets': sets,
      'target_reps': reps,
      'rest_time_seconds': rest,
    };

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    
    nav.pop(); // close the sheet
    
    final result = await nav.push(
      MaterialPageRoute(
        builder: (_) => DetectionScreen(
          exerciseDataModel: widget.exercise,
          scheduleItem: scheduleItem,
          remainingSchedule: widget.remainingSchedule,
        ),
      ),
    );

    // Handle the result after DetectionScreen pops
    if (result is Map && result['action'] == 'save_workout') {
      final String? setId = result['setId'];
      debugPrint('[WorkoutConfigSheet] DetectionScreen returned save_workout result. setId: $setId');
      
      // Use the context of the screen that was behind (e.g. ExercisesScreen/Home)
      if (!mounted) return;
      final int? heartRate = await WorkoutService.showHeartRateDialog(context);
      
      if (setId != null && heartRate != null) {
        await WorkoutService.updateHeartRate(setId, heartRate);
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Workout data updated!'), backgroundColor: AppTheme.success),
      );

      // Handle next exercise in multi-exercise flow
      final List<dynamic>? remaining = result['remainingSchedule'];
      if (remaining != null && remaining.isNotEmpty) {
        final nextItem = remaining.first;
        final String nextName = nextItem['exercise_name'] as String;
        
        // Find the model for the next exercise
        final allExercises = ExerciseDataModel.allExercises();
        final nextModel = allExercises.firstWhere(
          (e) => e.title.toLowerCase() == nextName.toLowerCase(),
          orElse: () => allExercises.first,
        );

        if (!mounted) return;
        // Launch next directly or show config sheet again
        WorkoutConfigSheet.show(
          context, 
          exercise: nextModel, 
          remainingSchedule: remaining.sublist(1).cast<Map<String, dynamic>>(),
        );
      }
    }
  }

  Widget _buildField(String label, TextEditingController ctrl, {IconData? icon}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: AppTheme.bgDarkSecondary,
        prefixIcon: icon != null ? Icon(icon, color: Colors.white54) : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withAlpha(40)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.secondary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Exercise title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.exercise.color.withAlpha(60),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.fitness_center, color: widget.exercise.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.exercise.title,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Configure your target', style: TextStyle(color: Colors.white.withAlpha(140), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(children: [
            Expanded(child: _buildField('Sets', _setsCtrl, icon: Icons.layers)),
            const SizedBox(width: 12),
            Expanded(child: _buildField('Reps per Set', _repsCtrl, icon: Icons.repeat)),
          ]),
          const SizedBox(height: 14),
          _buildField('Rest Time (seconds)', _restCtrl, icon: Icons.timer),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _launch,
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            label: const Text('Start Workout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 6,
              shadowColor: AppTheme.primary.withAlpha(100),
            ),
          ),
        ],
      ),
    );
  }
}
