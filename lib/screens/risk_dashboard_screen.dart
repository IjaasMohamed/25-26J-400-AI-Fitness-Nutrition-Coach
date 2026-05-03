import 'package:flutter/material.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';
import 'package:pose_detection_realtime/services/injury_risk_api_service.dart';
import 'package:pose_detection_realtime/models/injury_risk_request.dart';
import 'package:pose_detection_realtime/models/injury_risk_response.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RiskDashboardScreen extends StatefulWidget {
  const RiskDashboardScreen({super.key});

  @override
  State<RiskDashboardScreen> createState() => _RiskDashboardScreenState();
}

class _RiskDashboardScreenState extends State<RiskDashboardScreen> {
  bool _isLoading = true;
  InjuryRiskResponse? _prediction;
  String? _error;
  
  // Stats to show
  double _frequency = 0;
  double _avgDuration = 0;
  double _avgIntensity = 0;
  int _injuryCount = 0;
  String _lastHeartRate = '-';

  @override
  void initState() {
    super.initState();
    _fetchAndPredict();
  }

  Future<void> _fetchAndPredict() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'User not logged in';

      // 1. Fetch User Profile
      final userData = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      _injuryCount = userData['injury_count'] ?? 0;
      final double age = (userData['age'] ?? 25).toDouble();
      final double height = (userData['height_cm'] ?? 175).toDouble();
      final double weight = (userData['weight_kg'] ?? 70).toDouble();
      final double bmi = (userData['bmi'] ?? 22.8).toDouble();
      final String genderStr = userData['gender']?.toString().toLowerCase() ?? 'male';
      final int gender = genderStr == 'male' ? 1 : 0;

      // 2. Fetch Training Stats
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      
      try {
      final setsDataRaw = await Supabase.instance.client
          .from('exercise_sets')
          .select('created_at, exercise_date, intensity, heart_rate')
          .eq('user_id', user.id)
          .gte('created_at', thirtyDaysAgo);
        
        final List<Map<String, dynamic>> setsData = List<Map<String, dynamic>>.from(setsDataRaw);

        if (setsData.isNotEmpty) {
          final uniqueDays = setsData.map((s) => s['exercise_date'] ?? (s['created_at'] as String).substring(0, 10)).toSet().length;
          _frequency = (uniqueDays / (30 / 7));

          Map<String, List<DateTime>> setsByDay = {};
          for (var s in setsData) {
            final date = s['exercise_date'] ?? (s['created_at'] as String).substring(0, 10);
            final createdAt = DateTime.parse(s['created_at']);
            setsByDay.putIfAbsent(date, () => []).add(createdAt);
          }

          double totalMinutes = 0;
          for (var times in setsByDay.values) {
            if (times.length > 1) {
              times.sort();
              totalMinutes += times.last.difference(times.first).inMinutes.toDouble();
            } else {
              totalMinutes += 15;
            }
          }
          _avgDuration = totalMinutes / setsByDay.length;

          // Calculate Average Intensity with fallback
          final intensities = setsData
              .where((s) => s.containsKey('intensity') && s['intensity'] != null)
              .map((s) => (s['intensity'] as num).toDouble())
              .toList();
          _avgIntensity = intensities.isEmpty ? 5.0 : intensities.reduce((a, b) => a + b) / intensities.length;

          // Get last heart rate
          final hrSets = setsData.where((s) => s['heart_rate'] != null).toList();
          if (hrSets.isNotEmpty) {
            hrSets.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
            _lastHeartRate = hrSets.first['heart_rate'].toString();
          }
        }
      } catch (e) {
        debugPrint('Stats Fetch Error (likely missing column): $e');
        // If intensity column is missing, we still want the dashboard to work
        try {
          final setsDataRaw = await Supabase.instance.client
              .from('exercise_sets')
              .select('created_at, exercise_date')
              .eq('user_id', user.id)
              .gte('created_at', thirtyDaysAgo);
          
          final List<Map<String, dynamic>> setsData = List<Map<String, dynamic>>.from(setsDataRaw);
          
          if (setsData.isNotEmpty) {
            final uniqueDays = setsData.map((s) => s['exercise_date'] ?? (s['created_at'] as String).substring(0, 10)).toSet().length;
            _frequency = (uniqueDays / (30 / 7));
            _avgIntensity = 5.0; // Default fallback
            
            // Calculate average duration roughly
            _avgDuration = (setsData.length * 10) / 4.2; // Very rough estimation
          }
        } catch (innerE) {
          debugPrint('Fallback Stats Fetch Error: $innerE');
        }
      }

      // 3. Call Prediction API
      debugPrint('Calling Prediction API...');
      final request = InjuryRiskRequest(
        age: age,
        gender: gender,
        heightCm: height,
        weightKg: weight,
        bmi: bmi,
        trainingFrequency: _frequency,
        trainingDuration: _avgDuration,
        warmupTime: 10.0,
        flexibilityScore: 50.0,
        muscleAsymmetry: 0.0,
        injuryHistory: _injuryCount,
        trainingIntensity: _avgIntensity,
      );

      final result = await InjuryRiskApiService.predictInjuryRisk(request);
      debugPrint('Prediction result received: ${result != null}');
      
      if (mounted) {
        setState(() {
          _prediction = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Injury Risk Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Auto-calculated based on your history',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 30),
          
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.secondary)))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _fetchAndPredict,
                      child: const Text('Retry'),
                    )
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildRiskCard(),
                    const SizedBox(height: 24),
                    _buildStatsGrid(),
                    const SizedBox(height: 30),
                    _buildInfoCard(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRiskCard() {
    final bool isHighRisk = _prediction?.prediction == 1;
    final color = isHighRisk ? Colors.redAccent : AppTheme.success;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withAlpha(80)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withAlpha(40), Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          Icon(isHighRisk ? Icons.warning_rounded : Icons.check_circle_rounded, color: color, size: 80),
          const SizedBox(height: 16),
          Text(
            _prediction?.riskLabel ?? 'Unknown',
            style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'AI Confidence: ${(_prediction!.probability * 100).toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 20),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _prediction!.probability,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatItem('Frequency', '${_frequency.toStringAsFixed(1)}', 'days/wk', Icons.calendar_today),
        _buildStatItem('Duration', '${_avgDuration.toStringAsFixed(0)}', 'mins', Icons.timer),
        _buildStatItem('Last HR', _lastHeartRate, 'bpm', Icons.favorite),
        _buildStatItem('Intensity', '${_avgIntensity.toStringAsFixed(1)}', 'avg', Icons.bolt),
      ],
    );
  }

  Widget _buildStatItem(String title, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.secondary, size: 16),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withAlpha(80)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your risk is calculated based on consistency, intensity, and historical injury data. Keep working out to refresh your score!',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
