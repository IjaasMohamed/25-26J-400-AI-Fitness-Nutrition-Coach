import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/screens/detection_screen.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';
import 'package:pose_detection_realtime/screens/manage_schedule_screen.dart';
import 'package:pose_detection_realtime/screens/injury_risk_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _aiWorkouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchAIWorkouts();
  }

  Future<void> _fetchAIWorkouts() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('workout_schedules')
            .select()
            .eq('user_id', user.id)
            .eq('is_ai', true)
            .order('created_at', ascending: true);
        
        if (mounted) {
          setState(() {
            _aiWorkouts = List<Map<String, dynamic>>.from(data);
          });
        }
      }
    } catch (e) {
      // Silent fail for AI workouts
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', user.id)
            .single();
        
        if (mounted) {
          setState(() {
            _userData = data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile data: $e')),
        );
      }
    }
  }

  void _startWorkout(BuildContext context) {
    // Start with Squats as a quick workout
    final exercise = ExerciseDataModel(
      "Squats",
      "squat.gif",
      const Color(0xFFDF5089),
      ExcerciseType.Squats,
      difficulty: "Easy",
      caloriesPerRep: 3,
      description: "Strengthen your legs & glutes",
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withAlpha(38),
                    Colors.white.withAlpha(13),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withAlpha(51),
                ),
              ),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withAlpha(102),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userData?['email'] ?? 'Fitness User',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userData?['gender'] ?? 'AI Powered Workouts',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  // Stats Grid
                  _isLoading 
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      )
                    : Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildProfileStat(_userData?['age']?.toString() ?? '--', 'Age'),
                              Container(height: 40, width: 1, color: Colors.white.withAlpha(51)),
                              _buildProfileStat(_userData?['weight_kg']?.toString() ?? '--', 'Weight (kg)'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildProfileStat(_userData?['height_cm']?.toString() ?? '--', 'Height (cm)'),
                              Container(height: 40, width: 1, color: Colors.white.withAlpha(51)),
                              _buildProfileStat(_userData?['bmi']?.toString() ?? '--', 'BMI'),
                            ],
                          ),
                        ],
                      ),
                  const SizedBox(height: 24),
                  // Start Workout Button
                  GestureDetector(
                    onTap: () => _startWorkout(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow, color: Colors.white, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Quick Start Workout',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
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
            
            if (_aiWorkouts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.cardGlass,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.secondary.withAlpha(80)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.secondary.withAlpha(26),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AppTheme.secondary, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'AI Recommended Plan',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._aiWorkouts.map((workout) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.bgDarkSecondary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: AppTheme.success, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  workout['exercise_name'],
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${workout['target_sets']} Sets • ${workout['target_reps']} Reps',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            // Menu Items
            _buildMenuItem(
              icon: Icons.health_and_safety,
              title: 'Predict Injury Risk',
              subtitle: 'AI Assessment based on metrics',
              color: Colors.blueAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InjuryRiskScreen()),
                );
              },
            ),
            _buildMenuItem(
              icon: Icons.calendar_month,
              title: 'Manage Schedule',
              subtitle: 'Plan your targeted workouts',
              color: AppTheme.secondary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageScheduleScreen()),
                );
              },
            ),
            _buildMenuItem(
              icon: Icons.settings,
              title: 'Settings',
              subtitle: 'App preferences',
              color: AppTheme.secondary,
            ),
            _buildMenuItem(
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: 'Manage alerts',
              color: Colors.orange,
            ),
            _buildMenuItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'Get assistance',
              color: AppTheme.success,
            ),
            _buildMenuItem(
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'Version 1.0.0',
              color: AppTheme.primary,
            ),
            const SizedBox(height: 24),
            // Logout Button
            _buildMenuItem(
              icon: Icons.logout,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              color: Colors.redAccent,
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                // We don't need to manually navigate here because AuthGateway 
                // is listening to auth state changes at the app root and will 
                // automatically pop us out to the login screen!
              },
            ),
            const SizedBox(height: 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withAlpha(26),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha(51),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

}
