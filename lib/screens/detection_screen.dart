import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/screens/rest_timer_screen.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';
import 'package:pose_detection_realtime/main.dart';
import 'package:pose_detection_realtime/utils/risk_assessment_engine.dart';
import 'package:pose_detection_realtime/utils/form_analyzer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:pose_detection_realtime/services/workout_service.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({
    super.key,
    required this.exerciseDataModel,
    this.scheduleItem,
    this.remainingSchedule = const [],
  });
  final ExerciseDataModel exerciseDataModel;
  // Optional: current schedule item being worked out
  final Map<String, dynamic>? scheduleItem;
  // Optional: remaining schedule after current exercise completes
  final List<Map<String, dynamic>> remainingSchedule;

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> with SingleTickerProviderStateMixin {
  dynamic controller;
  bool isBusy = false;
  late Size size;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late PoseDetector poseDetector;
  
  // Custom Tracking Variables
  int currentSetNumber = 1;
  String? currentSetId;
  DateTime? lastRepTime;
  List<Map<String, dynamic>> repDataToSave = [];
  bool isSaving = false;
  bool _scheduleTriggered = false; // prevents double-trigger per rep-milestone
  late FlutterTts _tts;
  DateTime? lastSetEndTime;
  double? lastActualRestTime;
  DateTime? setStartTime;
  
  final riskEngine = RiskAssessmentEngine();
  final formAnalyzer = FormAnalyzer();
  FormAnalysisResult? _currentFormResult;
  DateTime? _lastFeedbackSpokenTime;
  String? _lastSpokenIssue;
  
  @override
  void initState() {
    super.initState();
    setStartTime = DateTime.now();
    _tts = FlutterTts();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.5);
    _tts.awaitSpeakCompletion(true); // <--- Add this so speak() returns a Future that waits
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    initializeCamera();
  }

  initializeCamera() async {
    final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
    poseDetector = PoseDetector(options: options);

    controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      controller.startImageStream(
        (image) => {
          if (!isBusy) {isBusy = true, img = image, doPoseEstimationOnFrame()},
        },
      );
    });
  }

  dynamic _scanResults;
  CameraImage? img;
  
  doPoseEstimationOnFrame() async {
    var inputImage = _inputImageFromCameraImage();
    if (inputImage != null) {
      final List<Pose> poses = await poseDetector.processImage(inputImage);
      _scanResults = poses;
      if (poses.isNotEmpty) {
        // Pass global angles to the Risk Engine constantly regardless of exercise specific triggers
        _processGlobalRiskMetrics(poses.first);

        // Real-time form analysis
        final formResult = formAnalyzer.analyzeFrame(
          widget.exerciseDataModel.type,
          poses.first.landmarks,
        );
        _currentFormResult = formResult;
        _speakFormFeedback(formResult);

        if (widget.exerciseDataModel.type == ExcerciseType.PushUps) {
          detectPushUp(poses.first.landmarks);
        } else if (widget.exerciseDataModel.type == ExcerciseType.Squats) {
          detectSquat(poses.first.landmarks);
        } else if (widget.exerciseDataModel.type == ExcerciseType.PlankToDownwardDog) {
          detectPlankToDownwardDog(poses.first);
        } else if (widget.exerciseDataModel.type == ExcerciseType.JumpingJack) {
          detectJumpingJack(poses.first);
        } else if (widget.exerciseDataModel.type == ExcerciseType.HighKnees) {
          detectHighKnees(poses.first.landmarks);
        }
      }
    }
    if (mounted) {
      setState(() {
        isBusy = false;
      });
    }
  }

  // --- ML Tracking Helper ---
  void _processGlobalRiskMetrics(Pose pose) {

    // This runs on every frame
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    final le = pose.landmarks[PoseLandmarkType.leftElbow];
    final re = pose.landmarks[PoseLandmarkType.rightElbow];
    final lw = pose.landmarks[PoseLandmarkType.leftWrist];
    final rw = pose.landmarks[PoseLandmarkType.rightWrist];
    final lh = pose.landmarks[PoseLandmarkType.leftHip];
    final rh = pose.landmarks[PoseLandmarkType.rightHip];
    final lk = pose.landmarks[PoseLandmarkType.leftKnee];
    final rk = pose.landmarks[PoseLandmarkType.rightKnee];
    final la = pose.landmarks[PoseLandmarkType.leftAnkle];
    final ra = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (ls != null && rs != null && le != null && re != null && 
        lw != null && rw != null && lh != null && rh != null && 
        lk != null && rk != null && la != null && ra != null) {
      
      // Calculate all 6 angles for the composite score
      double lElbow = calculateAngle(ls, le, lw);
      double rElbow = calculateAngle(rs, re, rw);
      double lKnee = calculateAngle(lh, lk, la);
      double rKnee = calculateAngle(rh, rk, ra);
      double lShoulder = calculateAngle(le, ls, lh);
      double rShoulder = calculateAngle(re, rs, rh);
      
      riskEngine.updateMetrics(
        leftElbow: lElbow,
        rightElbow: rElbow,
        leftKnee: lKnee,
        rightKnee: rKnee,
        leftShoulder: lShoulder,
        rightShoulder: rShoulder,
      );
    }
  }

  /// Speak form correction via TTS, throttled to avoid spam.
  void _speakFormFeedback(FormAnalysisResult result) {
    if (result.issues.isEmpty) return;
    final now = DateTime.now();
    final topIssue = result.issues.first;
    // Don't speak any feedback within 4 seconds of the last one
    if (_lastFeedbackSpokenTime != null &&
        now.difference(_lastFeedbackSpokenTime!).inSeconds < 4) return;
    // Don't repeat the same issue within 7 seconds
    if (_lastSpokenIssue == topIssue.issue &&
        _lastFeedbackSpokenTime != null &&
        now.difference(_lastFeedbackSpokenTime!).inSeconds < 7) return;
    _lastFeedbackSpokenTime = now;
    _lastSpokenIssue = topIssue.issue;
    _tts.speak(topIssue.message);
  }

  @override
  void dispose() {
    controller?.dispose();
    poseDetector.close();
    _pulseController.dispose();
    _tts.stop();
    super.dispose();
  }

  int get currentCount {
    switch (widget.exerciseDataModel.type) {
      case ExcerciseType.PushUps:
        return pushUpCount;
      case ExcerciseType.Squats:
        return squatCount;
      case ExcerciseType.PlankToDownwardDog:
        return plankToDownwardDogCount;
      case ExcerciseType.JumpingJack:
        return jumpingJackCount;
      case ExcerciseType.HighKnees:
        return highKneeCount;
    }
  }

  // --- Start Tracking Logic ---
  
  void _recordRep() {
    DateTime now = DateTime.now();
    double timeSinceLastRep = 0.0;
    
    if (lastRepTime != null) {
      timeSinceLastRep = now.difference(lastRepTime!).inMilliseconds / 1000.0;
    }
    
    lastRepTime = now;
    
    // Fetch ML metrics and reset memory for the next rep
    final metrics = riskEngine.fetchAndResetMetrics();
    final formData = formAnalyzer.fetchAndResetRepData();
    
    // Add to local list to save when set finishes
    repDataToSave.add({
      'rep_number': currentCount,
      'time_since_last_rep': timeSinceLastRep,
      'max_depth_angle': metrics['max_depth_angle'],
      'left_right_imbalance_degrees': metrics['left_right_imbalance_degrees'],
      'form_quality_score': formData['form_quality_score'],
      'joint_angles': formData['joint_angles'],
      'detected_issues': formData['detected_issues'],
      'feedback_message': formData['feedback_message'],
      'created_at': DateTime.now().toIso8601String(),
    });

    // 🔔 Schedule-aware check
    _checkScheduledTarget();
  }

  void _checkScheduledTarget() {
    final schedule = widget.scheduleItem;
    if (schedule == null) return;

    // ✅ Safe type parsing — Supabase can return num instead of int
    final int targetReps = (schedule['target_reps'] as num).toInt();
    final int targetSets = (schedule['target_sets'] as num).toInt();
    final int restSecs   = (schedule['rest_time_seconds'] as num).toInt();
    final String exerciseName = schedule['exercise_name']?.toString() ?? '';

    if (currentCount == targetReps && !_scheduleTriggered) {
      _scheduleTriggered = true;
      debugPrint('[Detection] Scheduled target reached: $currentCount reps.');
      
      // Update UI to hide buttons
      if (mounted) setState(() {});

      // Use a standard async block instead of microtask for better predictability
      () async {
        debugPrint('[Detection] Stopping camera stream...');
        await controller?.stopImageStream();
        
        final int completedSet = currentSetNumber;
        final bool isLastSet = completedSet >= targetSets;
        lastSetEndTime = DateTime.now();

        if (isLastSet) {
          debugPrint('[Detection] Final set complete ($completedSet/$targetSets). Popping with data.');
          
          _tts.speak('Your $exerciseName sets are complete. Well done!');
          
          // Small delay to let the UI settle after stopping the stream
          await Future.delayed(const Duration(milliseconds: 600));
          
          if (!mounted) return;
          final String? savedSetId = await _finishSet(showDialog: false);
          
          if (!mounted) return;
          Navigator.of(context).pop({
            'action': 'save_workout',
            'setId': savedSetId,
            'exerciseName': widget.exerciseDataModel.type.toString().split('.').last,
            'setNumber': completedSet,
            'reps': currentCount,
            'remainingSchedule': widget.remainingSchedule,
          });
        } else {
          debugPrint('[Detection] Set $completedSet/$targetSets complete. Showing rest timer.');
          await _finishSet(showDialog: false);
          
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RestTimerScreen(
                restSeconds: restSecs,
                message: 'Set $completedSet complete!\nRest ${restSecs}s before next set.',
                onRestComplete: () async {
                  debugPrint('[Detection] Rest complete. Restarting stream for next set.');
                  double? actualRest;
                  if (lastSetEndTime != null) {
                    actualRest = DateTime.now().difference(lastSetEndTime!).inSeconds.toDouble();
                    lastActualRestTime = actualRest;
                    final supabase = Supabase.instance.client;
                    await supabase.from('exercise_sets').update({
                      'actual_rest_time_seconds': actualRest
                    }).eq('user_id', supabase.auth.currentUser!.id)
                      .eq('set_number', completedSet)
                      .eq('exercise_date', '${lastSetEndTime!.year}-${lastSetEndTime!.month.toString().padLeft(2, '0')}-${lastSetEndTime!.day.toString().padLeft(2, '0')}');
                  }
                  if (mounted) {
                    Navigator.of(context).pop();
                    _scheduleTriggered = false;
                    controller?.startImageStream(
                      (image) => { if (!isBusy) { isBusy = true, img = image, doPoseEstimationOnFrame() } },
                    );
                  }
                },
              ),
            ),
          );
        }
      }();
    }
  }

  // Holds the set number before _finishSet increments it
  int get _currentPreviousSet => currentSetNumber;

  void _launchNextScheduleItem() {
    final nextSchedule = widget.remainingSchedule;
    if (nextSchedule.isEmpty) {
      // All exercises done!
      _tts.speak('Congratulations! Workout complete!');
      Navigator.of(context).pop();
      return;
    }

    final nextItem = nextSchedule.first;
    final String exerciseName = nextItem['exercise_name'] as String;

    // Map exercise name → ExerciseDataModel
    final allExercises = ExerciseDataModel.allExercises();
    final nextModel = allExercises.firstWhere(
      (e) => e.title.toLowerCase() == exerciseName.toLowerCase(),
      orElse: () => allExercises.first,
    );

    _tts.speak('Starting $exerciseName!');

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DetectionScreen(
          exerciseDataModel: nextModel,
          scheduleItem: nextItem,
          remainingSchedule: nextSchedule.skip(1).toList(),
        ),
      ),
    );
  }

  Future<String?> _finishSet({int? heartRate, bool showDialog = true}) async {
    if (currentCount == 0 || isSaving) return null;

    final int completedSetNumber = currentSetNumber;

    // If heartRate is not provided (manual finish), show the dialog (unless showDialog is false)
    int? finalHeartRate = heartRate;
    if (finalHeartRate == null && showDialog) {
      debugPrint('[Detection] Manual Finish Set triggered. Showing Heart Rate Dialog.');
      finalHeartRate = await _showHeartRateDialog(context);
      debugPrint('[Detection] Heart Rate selected: $finalHeartRate');
    }
    
    setState(() {
      isSaving = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final String setId = const Uuid().v4();
      final String userId = supabase.auth.currentUser!.id;
      
      final now = DateTime.now();
      final double durationSeconds = setStartTime != null 
          ? now.difference(setStartTime!).inSeconds.toDouble().clamp(1, 3600)
          : 30.0;
      
      final double intensity = WorkoutService.calculateIntensity(
        reps: currentCount,
        durationSeconds: durationSeconds,
        heartRate: finalHeartRate,
      );
      
      // Calculate set-level form metrics
      double avgFormScore = 100.0;
      double avgAsymmetry = 0.0;
      if (repDataToSave.isNotEmpty) {
        avgFormScore = repDataToSave
            .map((r) => (r['form_quality_score'] as num?)?.toDouble() ?? 100.0)
            .reduce((a, b) => a + b) / repDataToSave.length;
        avgAsymmetry = repDataToSave
            .map((r) => (r['left_right_imbalance_degrees'] as num?)?.toDouble() ?? 0.0)
            .reduce((a, b) => a + b) / repDataToSave.length;
      }

      // 1. Save Set (with form data)
      await supabase.from('exercise_sets').insert({
        'id': setId,
        'user_id': userId,
        'exercise_name': widget.exerciseDataModel.type.toString().split('.').last,
        'set_number': completedSetNumber,
        'total_reps': currentCount,
        'duration_seconds': durationSeconds,
        'intensity': intensity,
        'exercise_date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'exercise_time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'heart_rate': finalHeartRate,
        'form_quality_score': double.parse(avgFormScore.toStringAsFixed(1)),
        'muscle_asymmetry_score': double.parse(avgAsymmetry.toStringAsFixed(1)).clamp(0, 20),
        'created_at': now.toIso8601String(),
      });
      
      // 2. Save Reps (with form data + joint angles)
      if (repDataToSave.isNotEmpty) {
        final repsToInsert = repDataToSave.map((rep) => {
          'id': const Uuid().v4(),
          'user_id': userId,
          'set_id': setId,
          'rep_number': rep['rep_number'],
          'time_since_last_rep': rep['time_since_last_rep'],
          'max_depth_angle': rep['max_depth_angle'],
          'left_right_imbalance_degrees': rep['left_right_imbalance_degrees'],
          'form_quality_score': rep['form_quality_score'],
          'joint_angles': rep['joint_angles'],
          'created_at': rep['created_at'],
        }).toList();
        
        await supabase.from('exercise_reps').insert(repsToInsert);

        // 3. Save form analyses for reps with detected issues
        final formAnalyses = repDataToSave
            .where((r) => (r['detected_issues'] as List?)?.isNotEmpty ?? false)
            .map((rep) => {
              'set_id': setId,
              'form_quality_score': rep['form_quality_score'],
              'muscle_asymmetry_score': rep['left_right_imbalance_degrees'],
              'joint_angles': rep['joint_angles'],
              'detected_issues': rep['detected_issues'],
              'feedback_message': rep['feedback_message'],
            }).toList();
        if (formAnalyses.isNotEmpty) {
          try {
            await supabase.from('form_analyses').insert(formAnalyses);
          } catch (e) {
            debugPrint('[Detection] form_analyses save error: $e');
          }
        }
      }
      
      // Reset for next set
      setState(() {
        currentSetNumber++;
        setStartTime = DateTime.now(); // Reset timer for the next set
        pushUpCount = 0;
        squatCount = 0;
        plankToDownwardDogCount = 0;
        jumpingJackCount = 0;
        highKneeCount = 0;
        
        lastRepTime = null;
        repDataToSave.clear();
        isSaving = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Set $completedSetNumber completed & saved!'),
            backgroundColor: AppTheme.success,
          )
        );
      }
      return setId;
    } catch (error) {
       setState(() {
        isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving set: $error'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  Future<int?> _showHeartRateDialog(BuildContext context) async {
    int? heartRate;
    final controller = TextEditingController();
    
    return showDialog<int?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgDarkSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Workout Complete!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Great job! All sets completed.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            const Text('What is your Heart Rate (BPM)?', style: TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. 120',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.favorite, color: Colors.redAccent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Skip', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              Navigator.pop(context, val);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Workout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview - Full Screen
          if (controller != null && controller.value.isInitialized)
            Positioned(
              top: 0.0,
              left: 0.0,
              width: size.width,
              height: size.height,
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            ),
          
          // Pose Overlay
          if (controller != null && controller.value.isInitialized)
            Positioned(
              top: 0.0,
              left: 0.0,
              width: size.width,
              height: size.height,
              child: buildResult(),
            ),
          
          // Gradient Overlay Top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 150,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(204),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // Gradient Overlay Bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withAlpha(230),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // Header with Exercise Info
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () async {
                      if (currentCount > 0 && widget.scheduleItem == null) {
                        // For Free workouts, offer to save on back press
                        final bool? confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppTheme.bgDarkSecondary,
                            title: const Text('Finish workout?', style: TextStyle(color: Colors.white)),
                            content: const Text('Would you like to save your progress before leaving?', style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Discard')),
                              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save & Exit')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          // Signal to save on pop
                          if (mounted) {
                            final String? savedId = await _finishSet(showDialog: false);
                            Navigator.pop(context, {
                              'action': 'save_workout',
                              'setId': savedId,
                              'exerciseName': widget.exerciseDataModel.type.toString().split('.').last,
                              'setNumber': currentSetNumber,
                              'reps': currentCount,
                              'remainingSchedule': widget.remainingSchedule,
                            });
                          }
                        } else if (confirm == false) {
                          if (mounted) Navigator.pop(context);
                        }
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(38),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withAlpha(51),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Exercise Info
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                widget.exerciseDataModel.color.withAlpha(153),
                                widget.exerciseDataModel.color.withAlpha(77),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withAlpha(51),
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/${widget.exerciseDataModel.image}',
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.exerciseDataModel.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      widget.exerciseDataModel.difficulty,
                                      style: TextStyle(
                                        color: Colors.white.withAlpha(204),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
          
          // Rep Counter
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.exerciseDataModel.color,
                        widget.exerciseDataModel.color.withAlpha(153),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.exerciseDataModel.color.withAlpha(128),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withAlpha(77),
                      width: 3,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$currentCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'REPS',
                        style: TextStyle(
                          color: Colors.white.withAlpha(204),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Finish Set Button - Only show for manual finish if scheduled (though redundant now with auto-stop)
          // Removing for Free workouts as requested
          if (currentCount > 0 && !_scheduleTriggered && widget.scheduleItem != null)
            Positioned(
              bottom: 40,
              left: 20,
              child: InkWell(
                onTap: isSaving ? null : _finishSet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withAlpha(51),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSaving)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      else
                        const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        ),
                      const SizedBox(width: 6),
                      const Text(
                        'Finish Set',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Form Feedback Banner
          if (_currentFormResult != null && _currentFormResult!.issues.isNotEmpty)
            Positioned(
              top: 110,
              left: 20,
              right: 20,
              child: AnimatedOpacity(
                opacity: _currentFormResult!.issues.isNotEmpty ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _currentFormResult!.issues.first.severity == 'danger'
                        ? Colors.red.withAlpha(180)
                        : Colors.orange.withAlpha(180),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _currentFormResult!.issues.first.severity == 'danger'
                            ? Icons.error
                            : Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _currentFormResult!.issues.first.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Form score badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(100),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_currentFormResult!.formScore.toInt()}%',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Calories Burned Indicator
          Positioned(
            bottom: 50,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(38),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withAlpha(51),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${currentCount * widget.exerciseDataModel.caloriesPerRep}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    ' cal',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
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

  // ============ POSE DETECTION LOGIC ============
  
  int pushUpCount = 0;
  bool isLowered = false;
  void detectPushUp(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null ||
        leftHip == null ||
        rightHip == null) {
      return;
    }

    double leftElbowAngle = calculateAngle(leftShoulder, leftElbow, leftWrist);
    double rightElbowAngle = calculateAngle(rightShoulder, rightElbow, rightWrist);
    double avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2;

    double torsoAngle = calculateAngle(leftShoulder, leftHip, leftKnee ?? rightKnee!);
    bool inPlankPosition = torsoAngle > 160 && torsoAngle < 180;

    if (avgElbowAngle < 90 && inPlankPosition) {
      isLowered = true;
    } else if (avgElbowAngle > 160 && isLowered && inPlankPosition) {
      pushUpCount++;
      isLowered = false;
      _recordRep();
      setState(() {});
    }
  }

  int squatCount = 0;
  bool isSquatting = false;
  void detectSquat(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return;
    }

    double leftKneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle);
    double rightKneeAngle = calculateAngle(rightHip, rightKnee, rightAnkle);
    double avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2;

    double hipY = (leftHip.y + rightHip.y) / 2;
    double kneeY = (leftKnee.y + rightKnee.y) / 2;

    bool deepSquat = avgKneeAngle < 90;

    if (deepSquat && hipY > kneeY) {
      if (!isSquatting) {
        isSquatting = true;
      }
    } else if (!deepSquat && isSquatting) {
      squatCount++;
      isSquatting = false;
      _recordRep();
      setState(() {});
    }
  }

  int plankToDownwardDogCount = 0;
  bool isInDownwardDog = false;
  void detectPlankToDownwardDog(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (leftHip == null ||
        rightHip == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return;
    }

    bool isPlank = (leftHip.y - leftShoulder.y).abs() < 30 &&
        (rightHip.y - rightShoulder.y).abs() < 30 &&
        (leftHip.y - leftAnkle.y).abs() > 100 &&
        (rightHip.y - rightAnkle.y).abs() > 100;

    bool isDownwardDog = (leftHip.y < leftShoulder.y - 50) &&
        (rightHip.y < rightShoulder.y - 50) &&
        (leftAnkle.y > leftHip.y) &&
        (rightAnkle.y > rightHip.y);

    if (isDownwardDog && !isInDownwardDog) {
      isInDownwardDog = true;
    } else if (isPlank && isInDownwardDog) {
      plankToDownwardDogCount++;
      isInDownwardDog = false;
      _recordRep();
      setState(() {});
    }
  }

  int jumpingJackCount = 0;
  bool isJumpingJackOpen = false;
  void detectJumpingJack(Pose pose) {
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if (leftAnkle == null ||
        rightAnkle == null ||
        leftHip == null ||
        rightHip == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftWrist == null ||
        rightWrist == null) {
      return;
    }

    double legSpread = (rightAnkle.x - leftAnkle.x).abs();
    double armHeight = (leftWrist.y + rightWrist.y) / 2;
    double hipHeight = (leftHip.y + rightHip.y) / 2;
    double shoulderWidth = (rightShoulder.x - leftShoulder.x).abs();

    double legThreshold = shoulderWidth * 1.2;
    double armThreshold = hipHeight - shoulderWidth * 0.5;

    bool armsUp = armHeight < armThreshold;
    bool legsApart = legSpread > legThreshold;

    if (armsUp && legsApart && !isJumpingJackOpen) {
      isJumpingJackOpen = true;
    } else if (!armsUp && !legsApart && isJumpingJackOpen) {
      jumpingJackCount++;
      isJumpingJackOpen = false;
      _recordRep();
      setState(() {});
    }
  }

  int highKneeCount = 0;
  bool leftKneeUp = false;
  bool rightKneeUp = false;

  void detectHighKnees(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return;
    }

    double leftHipY = leftHip.y;
    double rightHipY = rightHip.y;
    double leftKneeY = leftKnee.y;
    double rightKneeY = rightKnee.y;

    double leftKneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle);
    double rightKneeAngle = calculateAngle(rightHip, rightKnee, rightAnkle);

    bool isLeftKneeHigh = leftKneeY < leftHipY && leftKneeAngle < 120;
    bool isRightKneeHigh = rightKneeY < rightHipY && rightKneeAngle < 120;

    if (isLeftKneeHigh && !leftKneeUp) {
      leftKneeUp = true;
      highKneeCount++;
      _recordRep();
      setState(() {});
    } else if (!isLeftKneeHigh) {
      leftKneeUp = false;
    }

    if (isRightKneeHigh && !rightKneeUp) {
      rightKneeUp = true;
      highKneeCount++;
      _recordRep();
      setState(() {});
    } else if (!isRightKneeHigh) {
      rightKneeUp = false;
    }
  }

  double calculateAngle(PoseLandmark shoulder, PoseLandmark elbow, PoseLandmark wrist) {
    double a = distance(elbow, wrist);
    double b = distance(shoulder, elbow);
    double c = distance(shoulder, wrist);

    double angle = acos((b * b + a * a - c * c) / (2 * b * a)) * (180 / pi);
    return angle;
  }

  double distance(PoseLandmark p1, PoseLandmark p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage() {
    if (img == null) return null;
    
    final camera = cameras[0];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(img!.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (img!.planes.length != 1) return null;
    final plane = img!.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(img!.width.toDouble(), img!.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Widget buildResult() {
    if (_scanResults == null || controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final Size imageSize = Size(
      controller.value.previewSize!.height,
      controller.value.previewSize!.width,
    );
    CustomPainter painter = PosePainter(imageSize, _scanResults);
    return CustomPaint(painter: painter);
  }
}

// Pose Painter
class PosePainter extends CustomPainter {
  PosePainter(this.absoluteImageSize, this.poses);

  final Size absoluteImageSize;
  final List<Pose> poses;

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = AppTheme.success;

    final leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = AppTheme.secondary;

    final rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = AppTheme.primary;

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(
          Offset(landmark.x * scaleX, landmark.y * scaleY),
          4,
          paint,
        );
      });

      void paintLine(
        PoseLandmarkType type1,
        PoseLandmarkType type2,
        Paint paintType,
      ) {
        final joint1 = pose.landmarks[type1];
        final joint2 = pose.landmarks[type2];
        if (joint1 == null || joint2 == null) return;
        canvas.drawLine(
          Offset(joint1.x * scaleX, joint1.y * scaleY),
          Offset(joint2.x * scaleX, joint2.y * scaleY),
          paintType,
        );
      }

      // Draw arms
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, leftPaint);
      paintLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, rightPaint);
      paintLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rightPaint);

      // Draw Body
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, rightPaint);

      // Draw legs
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
      paintLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, leftPaint);
      paintLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, rightPaint);
      paintLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, rightPaint);
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.poses != poses;
  }
}
