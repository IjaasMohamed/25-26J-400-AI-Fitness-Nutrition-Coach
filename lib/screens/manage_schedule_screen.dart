import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/screens/detection_screen.dart';
import 'package:pose_detection_realtime/utils/performance_predictor.dart';

class ManageScheduleScreen extends StatefulWidget {
  const ManageScheduleScreen({super.key});

  @override
  State<ManageScheduleScreen> createState() => _ManageScheduleScreenState();
}

class _ManageScheduleScreenState extends State<ManageScheduleScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;

  // Form Controllers
  final _setsController = TextEditingController(text: '3');
  final _repsController = TextEditingController(text: '10');
  final _restController = TextEditingController(text: '60');
  
  String _selectedExercise = 'Push Ups';
  final List<String> _availableExercises =
      ExerciseDataModel.allExercises().map((e) => e.title).toList();

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  Future<void> _fetchSchedules() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('workout_schedules')
          .select()
          .eq('user_id', user.id)
          .or('is_ai.eq.false,is_ai.is.null') // Only manual
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _schedules = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load schedule: $e')),
        );
      }
    }
  }


  Future<void> _addSchedule() async {
    final sets = int.tryParse(_setsController.text);
    final reps = int.tryParse(_repsController.text);
    final rest = int.tryParse(_restController.text);

    if (sets == null || reps == null || rest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numbers')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      await _supabase.from('workout_schedules').insert({
        'user_id': user!.id,
        'exercise_name': _selectedExercise,
        'target_sets': sets,
        'target_reps': reps,
        'rest_time_seconds': rest,
        'is_ai': false,
      });

      // Clear simple defaults
      _setsController.text = '3';
      _repsController.text = '10';
      _restController.text = '60';

      await _fetchSchedules();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled successfully!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding schedule: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteSchedule(String id) async {
    setState(() => _isLoading = true);
    try {
      await _supabase.from('workout_schedules').delete().eq('id', id);
      await _fetchSchedules();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting schedule: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _setsController.dispose();
    _repsController.dispose();
    _restController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Workout Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildMyPlanTab(),
    );
  }

  Widget _buildMyPlanTab() {
    return SafeArea(
      child: Column(
        children: [
          // Add New Schedule Form
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardGlass,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(26)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Add to Schedule', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                GestureDetector(
                  onTap: () async {
                    final picked = await showModalBottomSheet<String>(
                      context: context,
                      backgroundColor: const Color(0xFF1A1A2E),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(height: 16),
                          const Text('Select Exercise', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          ..._availableExercises.map((e) => ListTile(
                            title: Text(e, style: const TextStyle(color: Colors.white)),
                            trailing: _selectedExercise == e
                                ? const Icon(Icons.check, color: AppTheme.secondary)
                                : null,
                            onTap: () => Navigator.of(context).pop(e),
                          )),
                          const SizedBox(height: 16),
                        ],
                      ),
                    );
                    if (picked != null) setState(() => _selectedExercise = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgDarkSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(40)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fitness_center, color: Colors.white54, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedExercise,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                        const Icon(Icons.expand_more, color: Colors.white70),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _setsController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Sets',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: AppTheme.bgDarkSecondary,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _repsController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Reps',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: AppTheme.bgDarkSecondary,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _restController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Rest Time (Seconds)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AppTheme.bgDarkSecondary,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.timer, color: Colors.white70),
                  ),
                  keyboardType: TextInputType.number,
                ),
                
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _addSchedule,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add to Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Your Daily Plan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          
          // List of active schedules
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _schedules.isEmpty
                ? const Center(child: Text("Your schedule is empty. Add a workout!", style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _schedules.length,
                    itemBuilder: (context, index) {
                      final schedule = _schedules[index];
                      return Card(
                        color: AppTheme.bgDarkSecondary,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryGradient.colors.first,
                            child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(
                            schedule['exercise_name'],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${schedule['target_sets']} Sets x ${schedule['target_reps']} Reps\nRest: ${schedule['rest_time_seconds']}s',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white38),
                            onPressed: () => _deleteSchedule(schedule['id']),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

}
