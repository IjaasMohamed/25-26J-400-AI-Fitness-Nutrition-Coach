import 'package:flutter/material.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';
import 'package:pose_detection_realtime/services/injury_risk_api_service.dart';
import 'package:pose_detection_realtime/services/grok_suggestion_service.dart';
import 'package:pose_detection_realtime/models/injury_risk_request.dart';
import 'package:pose_detection_realtime/models/injury_risk_response.dart';
import 'package:pose_detection_realtime/models/risk_suggestion_response.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RiskDashboardScreen extends StatefulWidget {
  const RiskDashboardScreen({super.key});

  @override
  State<RiskDashboardScreen> createState() => _RiskDashboardScreenState();
}

class _RiskDashboardScreenState extends State<RiskDashboardScreen> {
  bool _isLoading = true;
  InjuryRiskResponse? _prediction;
  InjuryRiskRequest? _lastRequest;
  String? _error;
  
  // Stats to show
  double _frequency = 0;
  double _avgDuration = 0;
  double _avgIntensity = 0;
  int _injuryCount = 0;
  String _lastHeartRate = '-';

  // Grok AI Suggestions
  bool _isLoadingSuggestions = false;
  RiskSuggestionResponse? _suggestions;
  String? _suggestionsError;

  // Chat
  final TextEditingController _chatController = TextEditingController();
  final List<_ChatMessage> _chatMessages = [];
  bool _isChatLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchAndPredict();
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndPredict() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _suggestions = null;
      _suggestionsError = null;
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
            _avgIntensity = 5.0;
            _avgDuration = (setsData.length * 10) / 4.2;
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
          _lastRequest = request;
          _isLoading = false;
        });

        // 4. Auto-fetch Grok suggestions if risk detected
        if (result != null) {
          _fetchGrokSuggestions(request, result);
        }
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

  Future<void> _fetchGrokSuggestions(InjuryRiskRequest request, InjuryRiskResponse prediction) async {
    setState(() {
      _isLoadingSuggestions = true;
      _suggestionsError = null;
    });

    try {
      final result = await GrokSuggestionService.fetchSuggestions(
        riskRequest: request,
        prediction: prediction,
      );
      if (mounted) {
        setState(() {
          _suggestions = result;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestionsError = e.toString();
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessages.add(_ChatMessage(text: text, isUser: true));
      _isChatLoading = true;
    });
    _chatController.clear();

    try {
      final reply = await GrokSuggestionService.sendChatMessage(
        message: text,
        riskContext: _lastRequest?.toJson(),
      );
      if (mounted) {
        setState(() {
          _chatMessages.add(_ChatMessage(text: reply, isUser: false));
          _isChatLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatMessages.add(_ChatMessage(text: 'Error: $e', isUser: false));
          _isChatLoading = false;
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
                    const SizedBox(height: 24),
                    _buildAiSuggestionsSection(),
                    const SizedBox(height: 24),
                    _buildChatSection(),
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

  // --- AI SUGGESTIONS SECTION ---
  Widget _buildAiSuggestionsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withAlpha(60)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary.withAlpha(20), Colors.transparent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Safety Advisor', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Powered by Grok AI', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoadingSuggestions)
            _buildLoadingIndicator()
          else if (_suggestionsError != null)
            _buildSuggestionsError()
          else if (_suggestions != null)
            _buildSuggestionsList()
          else
            const Text('Waiting for risk analysis...', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
          SizedBox(width: 12),
          Text('Analyzing your risk profile...', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSuggestionsError() {
    return Column(
      children: [
        Text('Could not load suggestions', style: TextStyle(color: Colors.red.shade300)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            if (_lastRequest != null && _prediction != null) {
              _fetchGrokSuggestions(_lastRequest!, _prediction!);
            }
          },
          child: const Text('Retry', style: TextStyle(color: AppTheme.secondary)),
        ),
      ],
    );
  }

  Widget _buildSuggestionsList() {
    final s = _suggestions!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary
        Text(s.summary, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 12),

        // Warning banner
        if (s.warning != null && s.warning!.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(s.warning!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
              ],
            ),
          ),

        // Suggestion cards
        ...s.suggestions.map((item) => _buildSuggestionCard(item)),
      ],
    );
  }

  Widget _buildSuggestionCard(RiskSuggestion item) {
    Color priorityColor;
    String priorityIcon;
    switch (item.priority.toLowerCase()) {
      case 'high':
        priorityColor = Colors.redAccent;
        priorityIcon = '🔴';
        break;
      case 'medium':
        priorityColor = Colors.orangeAccent;
        priorityIcon = '🟡';
        break;
      default:
        priorityColor = AppTheme.success;
        priorityIcon = '🟢';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: priorityColor.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: priorityColor.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(priorityIcon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(color: priorityColor, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: priorityColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.priority.toUpperCase(),
                  style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.description, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  // --- CHAT SECTION ---
  Widget _buildChatSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: AppTheme.secondary, size: 18),
              SizedBox(width: 8),
              Text('Ask AI Follow-up', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),

          // Chat messages
          if (_chatMessages.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _chatMessages.length,
                itemBuilder: (ctx, i) {
                  final msg = _chatMessages[i];
                  return Align(
                    alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                      decoration: BoxDecoration(
                        color: msg.isUser ? AppTheme.primary.withAlpha(60) : Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                    ),
                  );
                },
              ),
            ),

          if (_isChatLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondary)),
                  SizedBox(width: 8),
                  Text('Thinking...', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),

          // Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. "How should I warm up?"',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withAlpha(10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendChatMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isChatLoading ? null : _sendChatMessage,
                icon: const Icon(Icons.send_rounded, color: AppTheme.secondary),
              ),
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

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}
