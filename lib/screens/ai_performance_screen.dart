import 'package:flutter/material.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';
import 'package:pose_detection_realtime/models/performance_suggestion.dart';
import 'package:pose_detection_realtime/services/prediction_service.dart';

class AIPerformanceScreen extends StatefulWidget {
  const AIPerformanceScreen({super.key});

  @override
  State<AIPerformanceScreen> createState() => _AIPerformanceScreenState();
}

class _AIPerformanceScreenState extends State<AIPerformanceScreen> {
  List<PerformanceSuggestion> _suggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPerformanceData();
  }

  Future<void> _fetchPerformanceData() async {
    final predictor = PredictionService();
    final results = await predictor.getSuggestions();
    if (mounted) {
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: _isLoading
                ? SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: AppTheme.secondary)),
                  )
                : _suggestions.isEmpty
                    ? _buildEmptyState()
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildExerciseInsightCard(_suggestions[index]),
                          childCount: _suggestions.length,
                        ),
                      ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppTheme.bgDark,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'AI Performance Insights',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.secondary.withAlpha(50),
                    AppTheme.bgDark,
                  ],
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: 40,
              child: Icon(
                Icons.auto_awesome,
                size: 150,
                color: Colors.white.withAlpha(13),
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.query_stats, size: 80, color: Colors.white.withAlpha(26)),
          const SizedBox(height: 24),
          const Text(
            'No Data Available Yet',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete a few workouts to see your\nmathematical performance trends here!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseInsightCard(PerformanceSuggestion suggestion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppTheme.cardGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.exerciseName,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildTrendIcon(suggestion.trend),
                          const SizedBox(width: 8),
                          Text(
                            suggestion.trend.toUpperCase(),
                            style: TextStyle(
                              color: _getTrendColor(suggestion.trend),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (suggestion.canIncrease)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'GOAL UP',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),

          // Message, Confidence & Form Quality
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(51),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    suggestion.suggestion,
                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.psychology, size: 14, color: Colors.white38),
                      const SizedBox(width: 8),
                      const Text('AI Confidence ', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: suggestion.confidence,
                          backgroundColor: Colors.white.withAlpha(13),
                          color: suggestion.canIncrease ? AppTheme.success : AppTheme.secondary,
                          minHeight: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${(suggestion.confidence * 100).toInt()}%', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.verified_user, size: 14, color: AppTheme.success),
                      const SizedBox(width: 8),
                      const Text('Form Quality ', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: suggestion.formScore / 100,
                          backgroundColor: Colors.white.withAlpha(13),
                          color: AppTheme.success,
                          minHeight: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${suggestion.formScore.toInt()}%', style: const TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Latest Session Breakdown Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'LATEST SESSION DETAILS',
                  style: TextStyle(color: AppTheme.secondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                Text(
                  suggestion.latestSessionSets.isNotEmpty 
                      ? suggestion.latestSessionSets.first['exercise_date']
                      : '',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),

          // Set breakdown list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildSetBreakdown(suggestion),
          ),

          const SizedBox(height: 24),

          // Weekly Progress Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text(
              'WEEKLY PROGRESS TREND',
              style: TextStyle(color: AppTheme.secondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildWeeklyProgressChart(suggestion),
          ),

          const SizedBox(height: 20),

          // Performance Metrics Bottom Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(13),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricItem('Historical Avg', suggestion.stats['overall_avg']),
                _buildMetricItem('Velocity', suggestion.stats['velocity']),
                _buildMetricItem('Avg Tempo', '${suggestion.stats['rep_tempo']}s'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetBreakdown(PerformanceSuggestion suggestion) {
    if (suggestion.latestSessionSets.isEmpty) {
      return const Text('No recent sets recorded', style: TextStyle(color: Colors.white38));
    }

    int totalReps = 0;
    double totalRest = 0;
    int restCount = 0;

    for (var setData in suggestion.latestSessionSets) {
      totalReps += (setData['total_reps'] as num).toInt();
      final rest = (setData['actual_rest_time_seconds'] as num?)?.toDouble() ?? 0;
      if (rest > 0) {
        totalRest += rest;
        restCount++;
      }
    }

    final avgRest = restCount > 0 ? (totalRest / restCount).round() : 0;
    final isExcessRest = avgRest > 90;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(13)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOTAL REPS', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$totalReps', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(width: 1, height: 30, color: Colors.white.withAlpha(13)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AVG REST', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${avgRest}s', 
                      style: TextStyle(
                        color: isExcessRest ? Colors.redAccent : Colors.white, 
                        fontSize: 18, 
                        fontWeight: FontWeight.bold
                      )
                    ),
                    if (isExcessRest) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.redAccent),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTrendIcon(String trend) {
    if (trend == 'up') return const Icon(Icons.trending_up, color: AppTheme.success, size: 16);
    if (trend == 'down') return const Icon(Icons.trending_down, color: Colors.redAccent, size: 16);
    return const Icon(Icons.trending_flat, color: Colors.white38, size: 16);
  }

  Color _getTrendColor(String trend) {
    if (trend == 'up') return AppTheme.success;
    if (trend == 'down') return Colors.redAccent;
    return Colors.white38;
  }

  Widget _buildWeeklyProgressChart(PerformanceSuggestion suggestion) {
    if (suggestion.weeklyProgress.isEmpty) {
      return const Text('Collecting more data for weekly trends...', style: TextStyle(color: Colors.white38, fontSize: 12));
    }

    final weeks = suggestion.weeklyProgress.keys.toList();
    final values = suggestion.weeklyProgress.values.toList();
    
    return Container(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: weeks.length,
        itemBuilder: (context, index) {
          final isLast = index == weeks.length - 1;
          final val = values[index];
          // Simple bar chart representation
          return Container(
            margin: const EdgeInsets.only(right: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(val.toStringAsFixed(1), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                const SizedBox(height: 4),
                Container(
                  width: 30,
                  height: (val * 2).clamp(10, 60), // scale for viz
                  decoration: BoxDecoration(
                    color: isLast ? AppTheme.secondary : Colors.white12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(weeks[index], style: const TextStyle(color: Colors.white38, fontSize: 9)),
              ],
            ),
          );
        },
      ),
    );
  }
}
