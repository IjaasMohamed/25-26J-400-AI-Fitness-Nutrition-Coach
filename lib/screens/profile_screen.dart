import 'package:flutter/material.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/screens/detection_screen.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
                    'Fitness User',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI Powered Workouts',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildProfileStat('0', 'Workouts'),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.white.withAlpha(51),
                      ),
                      _buildProfileStat('0', 'Calories'),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.white.withAlpha(51),
                      ),
                      _buildProfileStat('0', 'Minutes'),
                    ],
                  ),
                  const SizedBox(height: 20),
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
            const SizedBox(height: 24),
            // Menu Items
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
