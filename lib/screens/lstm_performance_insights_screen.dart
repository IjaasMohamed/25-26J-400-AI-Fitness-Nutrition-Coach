import 'package:flutter/material.dart';
import 'package:pose_detection_realtime/models/lstm_prediction_models.dart';
import 'package:pose_detection_realtime/services/lstm_prediction_service.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';

class LSTMAdvancedInsightsScreen extends StatefulWidget {
  final String? exerciseName;
  const LSTMAdvancedInsightsScreen({super.key, this.exerciseName});

  @override
  State<LSTMAdvancedInsightsScreen> createState() => _LSTMAdvancedInsightsScreenState();
}

class _LSTMAdvancedInsightsScreenState extends State<LSTMAdvancedInsightsScreen> {
  final LSTMPredictionService _service = LSTMPredictionService();
  LSTMPredictionResponse? _data;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInsights();
  }

  Future<void> _fetchInsights() async {
    setState(() => _isLoading = true);
    final result = await _service.getLSTMPrediction(exerciseName: widget.exerciseName);
    if (mounted) {
      setState(() {
        _data = result.data;
        _error = result.error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.exerciseName != null ? '${widget.exerciseName} Forecast' : 'Performance Forecast', 
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchInsights,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _buildErrorView()
              : _buildInsightsView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 60, color: Colors.white38),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchInsights,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retry Analysis'),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsView() {
    if (_data == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPerformancePrimaryCard(),
          const SizedBox(height: 20),
          _buildMetricsGrid(),
          const SizedBox(height: 20),
          _buildPerformanceForecastCard(),
          const SizedBox(height: 20),
          _buildCoachingTipsCard(),
          const SizedBox(height: 100), // Space for bottom nav
        ],
      ),
    );
  }

  Widget _buildPerformancePrimaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Predicted Next Performance',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  _data!.prediction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Confidence: ${(_data!.confidence * 100).toStringAsFixed(1)}%',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on your last ${_data!.historicalLabels.length} sets',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt, color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricItem(
            'Performance Trend',
            _data!.trend,
            Icons.trending_up,
            _data!.trend == "Improving" ? AppTheme.success : AppTheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricItem(
            'Consistency',
            '${_data!.consistencyScore.toStringAsFixed(0)}%',
            Icons.event_available,
            Colors.orangeAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }



  Widget _buildPerformanceForecastCard() {
    if (_data == null || _data!.historicalLabels.isEmpty) return const SizedBox();

    int historyCount = _data!.historicalLabels.length;

    // Convert labels to points (Average = 0, Good = 1)
    List<double> points = [];
    for (String label in _data!.historicalLabels) {
      points.add(label.toLowerCase() == 'good' ? 1.0 : 0.0);
    }
    // Add the predicted point
    points.add(_data!.prediction.toLowerCase() == 'good' ? 1.0 : 0.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Trend (Last 5 Sets)',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on your recent sets for ${widget.exerciseName ?? "this exercise"}, your next performance is predicted as ${_data!.prediction}.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (idx < historyCount) {
                          return Text('Set ${idx + 1}', style: const TextStyle(color: Colors.white38, fontSize: 9));
                        } else if (idx == historyCount) {
                          return const Text('Next', style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('Average', style: TextStyle(color: Colors.white38, fontSize: 10));
                        if (value == 1) return const Text('Good', style: TextStyle(color: AppTheme.success, fontSize: 10));
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: historyCount.toDouble(),
                minY: -0.2,
                maxY: 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true,
                    gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.success]),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        bool isLast = index == historyCount;
                        return FlDotCirclePainter(
                          radius: isLast ? 6 : 4,
                          color: isLast ? AppTheme.primary : Colors.white,
                          strokeWidth: 2,
                          strokeColor: AppTheme.cardGlass,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [AppTheme.primary.withOpacity(0.2), AppTheme.success.withOpacity(0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachingTipsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.yellowAccent, size: 24),
              SizedBox(width: 8),
              Text(
                'Personalized Performance Coaching',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _data!.coachingTips.isEmpty
              ? const Text(
                  'Great job on your sessions! Consistency is key. Keep maintaining your current pace to see more specific tips.',
                  style: TextStyle(color: Colors.white54, fontSize: 14, fontStyle: FontStyle.italic),
                )
              : Column(
                  children: _data!.coachingTips.map((tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppTheme.primary, fontSize: 20)),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
        ],
      ),
    );
  }
}
