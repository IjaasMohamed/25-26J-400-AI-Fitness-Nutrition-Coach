import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/screens/components/workout_config_sheet.dart';
import 'package:pose_detection_realtime/screens/auto_detect_screen.dart';
import 'package:pose_detection_realtime/utils/performance_predictor.dart';
import 'package:pose_detection_realtime/screens/ai_performance_screen.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';
import 'package:pose_detection_realtime/screens/biomechanics_demo_screen.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  List<ExerciseDataModel> exerciseList = [];
  PerformanceSuggestion? _topSuggestion;
  bool _isSuggestionLoading = true;

  @override
  void initState() {
    super.initState();
    loadData();
    _fetchTopSuggestion();
  }

  Future<void> _fetchTopSuggestion() async {
    try {
      final predictor = PerformancePredictor();
      final results = await predictor.getSuggestions();
      if (mounted && results.isNotEmpty) {
        setState(() {
          // Find the one with highest confidence or an 'up' trend
          _topSuggestion = results.firstWhere(
            (s) => s.trend == 'up',
            orElse: () => results.first,
          );
          _isSuggestionLoading = false;
        });
      } else {
        if (mounted) setState(() => _isSuggestionLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isSuggestionLoading = false);
    }
  }

  void _startRandomWorkout() {
    if (exerciseList.isEmpty) return;
    final random = Random();
    final randomExercise = exerciseList[random.nextInt(exerciseList.length)];
    WorkoutConfigSheet.show(context, exercise: randomExercise);
  }

  void loadData() {
    exerciseList = [
      ExerciseDataModel(
        "Push Ups",
        "pushup.gif",
        const Color(0xFF6C63FF),
        ExcerciseType.PushUps,
        difficulty: "Medium",
        caloriesPerRep: 5,
        description: "Build upper body strength",
      ),
      ExerciseDataModel(
        "Squats",
        "squat.gif",
        const Color(0xFFDF5089),
        ExcerciseType.Squats,
        difficulty: "Easy",
        caloriesPerRep: 3,
        description: "Strengthen your legs & glutes",
      ),
      ExerciseDataModel(
        "Plank to Downward Dog",
        "plank.gif",
        const Color(0xFFFD8636),
        ExcerciseType.PlankToDownwardDog,
        difficulty: "Hard",
        caloriesPerRep: 8,
        description: "Full body core workout",
      ),
      ExerciseDataModel(
        "Jumping Jack",
        "jumping.gif",
        const Color(0xFF00D9FF),
        ExcerciseType.JumpingJack,
        difficulty: "Easy",
        caloriesPerRep: 2,
        description: "Cardio & coordination",
      ),
      ExerciseDataModel(
        "High Knees",
        "jumping.gif",
        const Color(0xFF8B5CF6),
        ExcerciseType.HighKnees,
        difficulty: "Medium",
        caloriesPerRep: 4,
        description: "Boost your heart rate",
      ),
    ];
    setState(() {});
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppTheme.success;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.redAccent;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withAlpha(102),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.fitness_center,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Exercise',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              Text(
                                'Choose your workout',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Start Random Workout Button
                      GestureDetector(
                        onTap: _startRandomWorkout,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: AppTheme.secondaryGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.secondary.withAlpha(102),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shuffle,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Stats Row
                  Row(
                    children: [
                      _buildStatCard(
                        icon: Icons.local_fire_department,
                        value: '${exerciseList.length}',
                        label: 'Exercises',
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        icon: Icons.timer,
                        value: '15',
                        label: 'min avg',
                        color: AppTheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        icon: Icons.bolt,
                        value: 'AI',
                        label: 'Powered',
                        color: AppTheme.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Auto-Detect Workout Button
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AutoDetectScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.success.withAlpha(200),
                            AppTheme.success.withAlpha(100),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.success.withAlpha(80),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Free Workout',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Auto-detect any exercise',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // --- Realtime pose Ijaz Fouzer ---
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BiomechanicsDemoScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blueAccent.withAlpha(200),
                            Colors.blueAccent.withAlpha(100),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withAlpha(80),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.science, // A cool science icon for your math engine!
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Automatic Form Detection',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Isolated Biomechanics Engine (Mohamed)',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // --- Real Time Pose - Ijaz Fouzer ---

                  // New AI Insight Card
                  if (!_isSuggestionLoading && _topSuggestion != null) ...[
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AIPerformanceScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardGlass,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.secondary.withAlpha(80)),
                          gradient: LinearGradient(
                            colors: [AppTheme.secondary.withAlpha(20), Colors.transparent],
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: AppTheme.secondary, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AI Performance Insight',
                                    style: TextStyle(color: AppTheme.secondary, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _topSuggestion!.suggestion.length > 60 
                                      ? '${_topSuggestion!.suggestion.substring(0, 57)}...'
                                      : _topSuggestion!.suggestion,
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.white38),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  Text(
                    'Available Workouts',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          // Exercise List
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final exercise = exerciseList[index];
                  return _buildExerciseCard(exercise, index);
                },
                childCount: exerciseList.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardGlass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withAlpha(26),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(ExerciseDataModel exercise, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          WorkoutConfigSheet.show(context, exercise: exercise);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                exercise.color.withAlpha(204),
                exercise.color.withAlpha(102),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: exercise.color.withAlpha(77),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Background pattern
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(26),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Text Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Difficulty Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(77),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.speed,
                                    size: 14,
                                    color: _getDifficultyColor(exercise.difficulty),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    exercise.difficulty,
                                    style: TextStyle(
                                      color: _getDifficultyColor(exercise.difficulty),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Title
                            Text(
                              exercise.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Description
                            Text(
                              exercise.description,
                              style: TextStyle(
                                color: Colors.white.withAlpha(204),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Calories
                            Row(
                              children: [
                                Icon(
                                  Icons.local_fire_department,
                                  size: 16,
                                  color: Colors.white.withAlpha(230),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '~${exercise.caloriesPerRep} cal/rep',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(230),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Exercise Image
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withAlpha(26),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/${exercise.image}',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Play Icon
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
