import 'package:flutter/material.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/screens/detection_screen.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // Map of Date String (e.g. '2026-03-08') to List of sets done that day
  Map<String, List<Map<String, dynamic>>> _groupedHistory = {};

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('exercise_sets')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      // Group the data by exercise_date
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      
      for (var row in data) {
        // Fallback to substring of created_at if exercise_date constraint was missed
        final String date = row['exercise_date'] ?? (row['created_at'] as String).substring(0, 10);
        if (!grouped.containsKey(date)) {
          grouped[date] = [];
        }
        grouped[date]!.add(row);
      }

      if (mounted) {
        setState(() {
          _groupedHistory = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _startWorkout(BuildContext context) {
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

  IconData _getIconForExercise(String type) {
    switch (type) {
      case 'PushUps': return Icons.push_pin; // generic
      case 'Squats': return Icons.airline_seat_legroom_extra;
      case 'PlankToDownwardDog': return Icons.accessibility_new;
      case 'JumpingJack': return Icons.accessibility;
      case 'HighKnees': return Icons.directions_run;
      default: return Icons.fitness_center;
    }
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
            const SizedBox(height: 24),
            
            // Content Body
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppTheme.secondary))
                : _groupedHistory.isEmpty 
                  ? _buildEmptyState(context)
                  : _buildHistoryList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.cardGlass,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(26)),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow, color: Colors.white),
                SizedBox(width: 8),
                Text('Start Workout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    final dates = _groupedHistory.keys.toList();
    
    return ListView.builder(
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final date = dates[index];
        final sets = _groupedHistory[date]!;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Header
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Text(
                  date,
                  style: const TextStyle(
                    color: AppTheme.secondary, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 18,
                    letterSpacing: 1.2
                  ),
                ),
              ),
              
              // List of Exercises for that day
              ...sets.map((setData) {
                final exName = setData['exercise_name'] as String;
                final reps = setData['total_reps'];
                final setNum = setData['set_number'];
                final time = setData['exercise_time'] ?? '-';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardGlass,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.bgDarkSecondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_getIconForExercise(exName), color: Colors.white70),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exName == "High Knees" ? "high \$0nees" : exName.replaceAll(RegExp(r'(?<=[a-z])[A-Z]'), r' $0'), // add spaces
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Set $setNum • $reps Reps',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        time.toString(),
                        style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                );
              }).toList()
            ],
          ),
        );
      },
    );
  }
}
