import 'package:flutter/material.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/screens/detection_screen.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  void _startWorkout(BuildContext context) {
    // Start with the first exercise (Push Ups)
    final exercise = ExerciseDataModel(
      "Push Ups",
      "pushup.gif",
      const Color(0xFF6C63FF),
      ExcerciseType.PushUps,
      difficulty: "Medium",
      caloriesPerRep: 5,
      description: "Build upper body strength",
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetectionScreen(exerciseDataModel: exercise),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.secondaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.secondary.withAlpha(102),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.history,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workout History',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      'Track your progress',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            // Empty State
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppTheme.cardGlass,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(26),
                      ),
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      size: 64,
                      color: AppTheme.textSecondary.withAlpha(128),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No workouts yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete your first exercise to\nsee your history here!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => _startWorkout(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withAlpha(102),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Start Workout',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const SizedBox(height: 80), // Space for bottom nav
          ],
        ),
      ),
    );
  }
}
