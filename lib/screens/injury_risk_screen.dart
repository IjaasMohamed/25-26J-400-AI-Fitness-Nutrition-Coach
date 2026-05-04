import 'package:flutter/material.dart';
import '../models/injury_risk_request.dart';
import '../models/injury_risk_response.dart';
import '../models/risk_suggestion_response.dart';
import '../services/injury_risk_api_service.dart';
import '../services/grok_suggestion_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InjuryRiskScreen extends StatefulWidget {
  const InjuryRiskScreen({Key? key}) : super(key: key);

  @override
  _InjuryRiskScreenState createState() => _InjuryRiskScreenState();
}

class _InjuryRiskScreenState extends State<InjuryRiskScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _bmiController = TextEditingController();
  final _trainingFreqController = TextEditingController();
  final _trainingDurationController = TextEditingController();
  final _warmupTimeController = TextEditingController();
  final _flexibilityScoreController = TextEditingController();
  final _muscleAsymmetryController = TextEditingController();
  final _trainingIntensityController = TextEditingController();

  // Dropdown variables
  int _gender = 1; // 1 = Male, 0 = Female
  int _injuryHistory = 0; // 0 = No, 1 = Yes

  bool _isLoading = false;
  InjuryRiskResponse? _predictionResult;
  String? _errorMessage;

  // Grok AI Suggestions
  bool _isLoadingSuggestions = false;
  RiskSuggestionResponse? _suggestions;
  InjuryRiskRequest? _lastRequest;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // 1. Fetch Basic Bio Data
        final data = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', user.id)
            .single();

        if (mounted) {
          setState(() {
            _ageController.text = data['age']?.toString() ?? '';
            _heightController.text = data['height_cm']?.toString() ?? '';
            _weightController.text = data['weight_kg']?.toString() ?? '';
            _bmiController.text = data['bmi']?.toString() ?? '';
            
            final String dbGender = data['gender']?.toString().toLowerCase() ?? '';
            if (dbGender == 'male') {
              _gender = 1;
            } else if (dbGender == 'female') {
              _gender = 0;
            }

            // Store original injury count for calculation, dropdown uses value: _injuryHistory > 0 ? 1 : 0
            _injuryHistory = (data['injury_count'] ?? 0);
          });
        }

        // 2. Fetch Training Metrics from Workout History
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
        final setsData = await Supabase.instance.client
            .from('exercise_sets')
            .select('created_at, exercise_date, intensity')
            .eq('user_id', user.id)
            .gte('created_at', thirtyDaysAgo);

        if (setsData.isNotEmpty) {
          // Frequency: Count unique exercise_dates in last 30 days and normalize to sessions per week
          final uniqueDays = setsData.map((s) => s['exercise_date'] ?? (s['created_at'] as String).substring(0, 10)).toSet().length;
          final frequency = (uniqueDays / (30 / 7));

          // Duration: Avg daily duration (max - min created_at per day). Default 15m if 1 set.
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
              totalMinutes += 15; // Assume 15 min session if only one set was recorded
            }
          }
          final avgDuration = totalMinutes / setsByDay.length;

          // Calculate Average Intensity
          final intensities = setsData
              .where((s) => s['intensity'] != null)
              .map((s) => (s['intensity'] as num).toDouble())
              .toList();
          final avgIntensity = intensities.isEmpty ? 5.0 : intensities.reduce((a, b) => a + b) / intensities.length;

          if (mounted) {
            setState(() {
              _trainingFreqController.text = frequency.toStringAsFixed(1);
              _trainingDurationController.text = avgDuration.toStringAsFixed(1);
              _trainingIntensityController.text = avgIntensity.toStringAsFixed(1);
              _warmupTimeController.text = '10.0'; // Default reasonable value
              _flexibilityScoreController.text = '50.0'; // Default reasonable value (0-100)
              _muscleAsymmetryController.text = '0.0'; // Default reasonable value (0-20)
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load profile data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bmiController.dispose();
    _trainingFreqController.dispose();
    _trainingDurationController.dispose();
    _warmupTimeController.dispose();
    _flexibilityScoreController.dispose();
    _muscleAsymmetryController.dispose();
    _trainingIntensityController.dispose();
    super.dispose();
  }

  void _submitPrediction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _predictionResult = null;
    });

    try {
      final request = InjuryRiskRequest(
        age: double.parse(_ageController.text),
        gender: _gender,
        heightCm: double.parse(_heightController.text),
        weightKg: double.parse(_weightController.text),
        bmi: double.parse(_bmiController.text),
        trainingFrequency: double.parse(_trainingFreqController.text),
        trainingDuration: double.parse(_trainingDurationController.text),
        warmupTime: double.parse(_warmupTimeController.text),
        flexibilityScore: double.parse(_flexibilityScoreController.text),
        muscleAsymmetry: double.parse(_muscleAsymmetryController.text),
        injuryHistory: _injuryHistory,
        trainingIntensity: double.parse(_trainingIntensityController.text),
      );
      _lastRequest = request;

      final result = await InjuryRiskApiService.predictInjuryRisk(request);

      if (mounted) {
        setState(() {
          _predictionResult = result;
        });
      }

      // If High Risk is predicted, increment the injury history column
      if (result != null && result.prediction == 1) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final newInjuryCount = _injuryHistory + 1;
          
          await Supabase.instance.client.from('users').update({
            'injury_count': newInjuryCount,
          }).eq('id', user.id);

          if (mounted) {
            setState(() {
              _injuryHistory = newInjuryCount;
            });
          }
        }
      }

      // Fetch Grok AI suggestions after prediction
      if (result != null && _lastRequest != null) {
        _fetchGrokSuggestions(_lastRequest!, result);
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper builder for textual inputs
  Widget _buildTextField(TextEditingController controller, String label, {String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: validator ?? (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          if (double.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Predict Injury Risk'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter metrics to predict injury risk',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              _buildTextField(_ageController, 'Age'),
              
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownButtonFormField<int>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Male')),
                    DropdownMenuItem(value: 0, child: Text('Female')),
                  ],
                  onChanged: (val) => setState(() => _gender = val!),
                ),
              ),

              _buildTextField(_heightController, 'Height (cm)'),
              _buildTextField(_weightController, 'Weight (kg)'),
              _buildTextField(_bmiController, 'BMI'),
              _buildTextField(_trainingFreqController, 'Training Frequency (days/week)'),
              _buildTextField(_trainingDurationController, 'Training Duration (mins)'),
              _buildTextField(_warmupTimeController, 'Warmup Time (mins)'),
              _buildTextField(_flexibilityScoreController, 'Flexibility Score (0-100)'),
              _buildTextField(_muscleAsymmetryController, 'Muscle Asymmetry (0-20)'),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownButtonFormField<int>(
                  value: _injuryHistory > 0 ? 1 : 0,
                  decoration: const InputDecoration(labelText: 'Injury History', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('No')),
                    DropdownMenuItem(value: 1, child: Text('Yes')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      if (val == 0) {
                        _injuryHistory = 0;
                      } else if (val == 1 && _injuryHistory == 0) {
                        _injuryHistory = 1;
                      }
                    });
                  },
                ),
              ),

              _buildTextField(_trainingIntensityController, 'Training Intensity'),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitPrediction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading 
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text('Predict Injury Risk', style: TextStyle(fontSize: 16)),
              ),

              const SizedBox(height: 24),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              if (_predictionResult != null)
                Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(top: 16),
                  color: _predictionResult!.prediction == 1 ? Colors.red.shade50 : Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text('Prediction Result', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(
                          'Label: ${_predictionResult!.riskLabel}',
                          style: TextStyle(
                            fontSize: 18, 
                            color: _predictionResult!.prediction == 1 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Probability: ${(_predictionResult!.probability * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),

              // Grok AI Suggestions
              if (_isLoadingSuggestions)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('Getting AI suggestions...'),
                        ],
                      ),
                    ),
                  ),
                ),

              if (_suggestions != null)
                _buildSuggestionsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fetchGrokSuggestions(InjuryRiskRequest request, InjuryRiskResponse prediction) async {
    setState(() {
      _isLoadingSuggestions = true;
      _suggestions = null;
    });
    try {
      final result = await GrokSuggestionService.fetchSuggestions(
        riskRequest: request,
        prediction: prediction,
      );
      if (mounted) setState(() { _suggestions = result; _isLoadingSuggestions = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingSuggestions = false);
    }
  }

  Widget _buildSuggestionsCard() {
    final s = _suggestions!;
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(top: 16),
      color: Colors.deepPurple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text('AI Safety Suggestions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              ],
            ),
            const SizedBox(height: 8),
            Text(s.summary, style: const TextStyle(fontSize: 14, color: Colors.black87)),
            if (s.warning != null && s.warning!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.warning!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...s.suggestions.map((item) {
              Color pColor = item.priority == 'high' ? Colors.red : item.priority == 'medium' ? Colors.orange : Colors.green;
              String pIcon = item.priority == 'high' ? '🔴' : item.priority == 'medium' ? '🟡' : '🟢';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: pColor.withAlpha(60)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(pIcon),
                        const SizedBox(width: 6),
                        Expanded(child: Text(item.title, style: TextStyle(fontWeight: FontWeight.w600, color: pColor))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(item.description, style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
