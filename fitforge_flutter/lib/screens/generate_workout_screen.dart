import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GenerateWorkoutScreen extends StatefulWidget {
  const GenerateWorkoutScreen({super.key});

  @override
  State<GenerateWorkoutScreen> createState() => _GenerateWorkoutScreenState();
}

class _GenerateWorkoutScreenState extends State<GenerateWorkoutScreen> {
  bool _isLoading = false;
  String _experienceLevel = 'Beginner';
  String _targetMuscle = 'Full Body';
  double _initialWeight = 70.0;
  int _weeklyGoalDays = 3;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.auto_awesome, size: 60, color: AppTheme.secondary),
              const SizedBox(height: 16),
              const Text(
                'AI Workout Generator',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell us your goals and let our AI create the perfect weekly plan for you.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // Settings Form
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.cardGlass,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withAlpha(26)),
                ),
                child: Column(
                  children: [
                    _buildDropdownField(
                      label: 'Experience Level',
                      value: _experienceLevel,
                      items: ['Beginner', 'Intermediate', 'Advanced'],
                      onChanged: (val) => setState(() => _experienceLevel = val),
                    ),
                    const SizedBox(height: 20),
                    _buildDropdownField(
                      label: 'Target Muscle Focus',
                      value: _targetMuscle,
                      items: ['Full Body', 'Chest', 'Arms', 'Legs', 'Core', 'Back'],
                      onChanged: (val) => setState(() => _targetMuscle = val),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Initial Weight',
                            value: _initialWeight.toString(),
                            prefix: 'kg',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) => _initialWeight = double.tryParse(val) ?? 70.0,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInputField(
                            label: 'Days Per Week',
                            value: _weeklyGoalDays.toString(),
                            prefix: 'Days',
                            keyboardType: TextInputType.number,
                            onChanged: (val) => _weeklyGoalDays = int.tryParse(val) ?? 3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _generateAISchedule,
                icon: const Icon(Icons.flash_on, color: Colors.white),
                label: const Text('Generate AI Schedule', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: AppTheme.secondary.withAlpha(100),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.bgDarkSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(40)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1A2E),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              items: items.map((String val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(val),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String value,
    required String prefix,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgDarkSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(40)),
          ),
          child: TextField(
            onChanged: onChanged,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: value,
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text(prefix, style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold)),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generateAISchedule() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final difficulty = _experienceLevel;
      final muscle = _targetMuscle;

      final String response = await DefaultAssetBundle.of(context).loadString('assets/workout_data.json');
      final data = await json.decode(response);
      final allData = List<Map<String, dynamic>>.from(data);

      var filtered = allData.where((item) {
        return item['Difficulty Level_Cleaned']?.toString().toLowerCase() == difficulty.toLowerCase();
      }).toList();

      if (muscle != 'Full Body') {
        final muscleFiltered = filtered.where((item) {
          return item['Target Muscle Group_Cleaned']?.toString().toLowerCase().contains(muscle.toLowerCase()) ?? false;
        }).toList();
        if (muscleFiltered.isNotEmpty) filtered = muscleFiltered;
      }

      filtered.shuffle();
      final recs = filtered.take(_weeklyGoalDays).toList();

      // Clear previous AI schedule ONLY (keep manual)
      await Supabase.instance.client.from('workout_schedules').delete().eq('user_id', user.id).eq('is_ai', true);

      final List<Map<String, dynamic>> insertData = [];
      for (var rec in recs) {
        insertData.add({
          'user_id': user.id,
          'exercise_name': rec['Name of Exercise'],
          'target_sets': 3,
          'target_reps': 12,
          'rest_time_seconds': 60,
          'is_ai': true, // Mark as AI
        });
      }

      if (insertData.isNotEmpty) {
        await Supabase.instance.client.from('workout_schedules').insert(insertData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI Schedule Generated Successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
