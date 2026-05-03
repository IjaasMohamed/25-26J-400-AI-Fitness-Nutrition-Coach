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
import 'package:pose_detection_realtime/utils/exercise_classifier.dart';
import 'package:pose_detection_realtime/utils/form_analyzer.dart';
import 'package:pose_detection_realtime/utils/risk_assessment_engine.dart';
import 'package:pose_detection_realtime/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';
import 'package:pose_detection_realtime/services/workout_service.dart';

class AutoDetectScreen extends StatefulWidget {
  const AutoDetectScreen({super.key});

  @override
  State<AutoDetectScreen> createState() => _AutoDetectScreenState();
}

class _AutoDetectScreenState extends State<AutoDetectScreen> with SingleTickerProviderStateMixin {
  CameraController? controller;
  bool isBusy = false;
  late Size size;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late PoseDetector poseDetector;
  
  // Detection state
  ExcerciseType? detectedExercise;
  bool isDetecting = true;
  
  // Rep counting (same variables as DetectionScreen)
  int pushUpCount = 0;
  int squatCount = 0;
  int plankToDownwardDogCount = 0;
  int jumpingJackCount = 0;
  int highKneeCount = 0;
  
  // State tracking for rep counting
  bool isLowered = false;
  bool isSquatting = false;
  bool isInDownwardDog = false;
  bool isJumpingJackOpen = false;
  bool leftKneeUp = false;
  bool rightKneeUp = false;

  // Custom Tracking Variables
  int currentSetNumber = 1;
  String? currentSetId;
  String? lastCompletedSetId;
  DateTime? lastRepTime;
  List<Map<String, dynamic>> repDataToSave = [];
  bool isSaving = false;
  DateTime? setStartTime;

  final riskEngine = RiskAssessmentEngine();
  final formAnalyzer = FormAnalyzer();

  // TTS Feedback State
  String? _lastSpokenIssue;
  DateTime _lastSpokenTime = DateTime.now();

  // Rest timer tracking
  bool isRestTimerActive = false;
  DateTime? restTimerStart;
  double actualRestTimeSeconds = 0.0;
  int restSecsForSet = 0;

  // Save actual rest time to DB for the previous set
  Future<void> _saveActualRestTime(double seconds) async {
    if (_scheduleItem == null || lastCompletedSetId == null) return;
    final supabase = Supabase.instance.client;
    await supabase.from('exercise_sets').update({
      'actual_rest_time_seconds': seconds,
    }).eq('id', lastCompletedSetId!);
  }

  // 🔔 Schedule-aware fields
  Map<String, dynamic>? _scheduleItem; // set when exercise detected & found in schedule
  bool _scheduleTriggered = false;
  late FlutterTts _tts;

  int get currentCount {
    if (detectedExercise == null) return 0;
    switch (detectedExercise!) {
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
  
  String get exerciseTitle {
    if (detectedExercise == null) return "Detecting...";
    switch (detectedExercise!) {
      case ExcerciseType.PushUps:
        return "Push Ups";
      case ExcerciseType.Squats:
        return "Squats";
      case ExcerciseType.PlankToDownwardDog:
        return "Plank to Downward Dog";
      case ExcerciseType.JumpingJack:
        return "Jumping Jack";
      case ExcerciseType.HighKnees:
        return "High Knees";
    }
  }
  
  Color get exerciseColor {
    if (detectedExercise == null) return const Color(0xFF6C63FF);
    switch (detectedExercise!) {
      case ExcerciseType.PushUps:
        return const Color(0xFF6C63FF);
      case ExcerciseType.Squats:
        return const Color(0xFFDF5089);
      case ExcerciseType.PlankToDownwardDog:
        return const Color(0xFFFD8636);
      case ExcerciseType.JumpingJack:
        return const Color(0xFF00D9FF);
      case ExcerciseType.HighKnees:
        return const Color(0xFF8B5CF6);
    }
  }
  
  @override
  void initState() {
    super.initState();
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
    
    ExerciseClassifier.reset();
    initializeCamera();
  }

  initializeCamera() async {
    final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
    poseDetector = PoseDetector(options: options);

    controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    await controller!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      controller!.startImageStream((image) => {
        if (!isBusy) {isBusy = true, img = image, doPoseEstimationOnFrame()},
      });
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
        if (isDetecting) {
          // Phase 1: Auto-detect exercise
          ExcerciseType? detected = ExerciseClassifier.classifyExercise(poses.first);
          if (detected != null) {
            setState(() {
              detectedExercise = detected;
              isDetecting = false;
              setStartTime = DateTime.now(); // Start workout timer
            });
            // 🔍 Look up schedule for this exercise
            _lookupSchedule(detected);
          }
        } else {
          // Pass global angles to the Risk Engine constantly regardless of exercise specific triggers
          _processGlobalRiskMetrics(poses.first);
          
          // Form Analysis
          final formResult = formAnalyzer.analyzeFrame(detectedExercise!, poses.first.landmarks);
          _speakFormFeedback(formResult);

          switch (detectedExercise!) {
            case ExcerciseType.PushUps:
              detectPushUp(poses.first.landmarks);
              break;
            case ExcerciseType.Squats:
              detectSquat(poses.first.landmarks);
              break;
            case ExcerciseType.PlankToDownwardDog:
              detectPlankToDownwardDog(poses.first);
              break;
            case ExcerciseType.JumpingJack:
              detectJumpingJack(poses.first);
              break;
            case ExcerciseType.HighKnees:
              detectHighKnees(poses.first.landmarks);
              break;
          }
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
    if (now.difference(_lastSpokenTime).inSeconds < 4) return;
    // Don't repeat the same issue within 7 seconds
    if (_lastSpokenIssue == topIssue.issue &&
        now.difference(_lastSpokenTime).inSeconds < 7) return;
    _lastSpokenTime = now;
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

  // --- Start Tracking Logic ---
  
  void _recordRep() {
    DateTime now = DateTime.now();
    double timeSinceLastRep = 0.0;
    
    // Stop the rest timer and save the actual rest time taken
    if (isRestTimerActive) {
      isRestTimerActive = false;
      if (restTimerStart != null) {
        double actualRest = now.difference(restTimerStart!).inSeconds.toDouble();
        _saveActualRestTime(actualRest);
      }
    }

    if (lastRepTime != null) {
      timeSinceLastRep = now.difference(lastRepTime!).inMilliseconds / 1000.0;
    }
    
    lastRepTime = now;
    
    // Fetch ML metrics and reset memory for the next rep
    final metrics = riskEngine.fetchAndResetMetrics();
    final formData = formAnalyzer.fetchAndResetRepData();
    
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

    // 🔔 Check if we hit the schedule target
    _checkScheduledTarget();
  }

  /// Queries Supabase for a schedule matching the detected exercise.
  Future<void> _lookupSchedule(ExcerciseType type) async {
    final title = ExerciseDataModel.allExercises()
        .firstWhere((e) => e.type == type,
            orElse: () => ExerciseDataModel.allExercises().first)
        .title;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final result = await Supabase.instance.client
          .from('workout_schedules')
          .select()
          .eq('user_id', userId)
          .ilike('exercise_name', title)
          .limit(1);
      if (result.isNotEmpty && mounted) {
        setState(() => _scheduleItem = Map<String, dynamic>.from(result.first));
        _tts.speak('Schedule found for $title. ${_scheduleItem!['target_reps']} reps, ${_scheduleItem!['target_sets']} sets. Go!');
      }
    } catch (_) {
      // No schedule - free workout, ignore
    }
  }

  void _checkScheduledTarget() {
    if (_scheduleItem == null) return;

    // ✅ Safe type parsing — Supabase can return num instead of int
    final int targetReps = (_scheduleItem!['target_reps'] as num).toInt();
    final int targetSets = (_scheduleItem!['target_sets'] as num).toInt();
    final int restSecs   = (_scheduleItem!['rest_time_seconds'] as num).toInt();
    final String exerciseName = _scheduleItem!['exercise_name']?.toString() ?? exerciseTitle;

    if (currentCount == targetReps && !_scheduleTriggered) {
      _scheduleTriggered = true;
      controller?.stopImageStream();

      // Capture set number NOW before _finishSet() increments it
      final int completedSet = currentSetNumber;
      final bool isLastSet = completedSet >= targetSets;

      if (isLastSet) {
        debugPrint('[AutoDetect] Final set complete ($completedSet/$targetSets). Popping with data.');
        _tts.speak('Your $exerciseName sets are complete. Well done!');
        
        Future.delayed(const Duration(milliseconds: 600), () async {
          if (!mounted) return;
          final String? savedId = await _finishSet(showDialog: false);
          if (!mounted) return;
          Navigator.of(context).pop({
            'action': 'save_workout',
            'setId': savedId,
            'exerciseName': detectedExercise.toString().split('.').last,
            'setNumber': completedSet,
            'reps': currentCount,
          });
        });
      } else {
        // 🔁 Between sets → show countdown rest timer (RestTimerScreen speaks)
        _finishSet().then((_) {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RestTimerScreen(
                restSeconds: restSecs,
                message: 'Set $completedSet complete!\nRest ${restSecs}s before next set.',
                onRestComplete: () {
                  Navigator.of(context).pop();
                  _scheduleTriggered = false;
                  // Keep same exercise — just resume counting (reps already reset by _finishSet)
                  controller?.startImageStream(
                    (image) => { if (!isBusy) { isBusy = true, img = image, doPoseEstimationOnFrame() } },
                  );
                },
              ),
            ),
          );
        });
      }
    }
  }

  Future<String?> _finishSet({bool showDialog = true}) async {
    if (currentCount == 0 || isSaving) return null;
    
    final int completedSetNumber = currentSetNumber;
    
    setState(() {
      isSaving = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final String setId = const Uuid().v4();
      currentSetId = setId;
      lastCompletedSetId = setId;
      final String userId = supabase.auth.currentUser!.id;
      
      final now = DateTime.now();
      final double durationSeconds = setStartTime != null 
          ? now.difference(setStartTime!).inSeconds.toDouble().clamp(1, 3600)
          : 30.0;
      
      final double intensity = WorkoutService.calculateIntensity(
        reps: currentCount,
        durationSeconds: durationSeconds,
      );

      // Calculate average form quality and asymmetry
      double avgFormQuality = 0;
      double avgAsymmetry = 0;
      if (repDataToSave.isNotEmpty) {
        avgFormQuality = repDataToSave.map((r) => (r['form_quality_score'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / repDataToSave.length;
        avgAsymmetry = repDataToSave.map((r) => (r['left_right_imbalance_degrees'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / repDataToSave.length;
      }

      // 1. Save Set
      await supabase.from('exercise_sets').insert({
        'id': setId,
        'user_id': userId,
        'exercise_name': detectedExercise.toString().split('.').last,
        'set_number': currentSetNumber,
        'total_reps': currentCount,
        'duration_seconds': durationSeconds,
        'intensity': intensity,
        'form_quality_score': avgFormQuality,
        'muscle_asymmetry_score': avgAsymmetry,
        'exercise_date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'exercise_time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'created_at': now.toIso8601String(),
      });
      
      // 2. Save Reps
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
          'detected_issues': rep['detected_issues'],
          'feedback_message': rep['feedback_message'],
          'created_at': rep['created_at'],
        }).toList();
        
        await supabase.from('exercise_reps').insert(repsToInsert);

        // 3. Save Form Analyses (for reps with issues)
        final issuesToInsert = repDataToSave
            .where((r) => (r['detected_issues'] as List?)?.isNotEmpty ?? false)
            .map((rep) => {
              'id': const Uuid().v4(),
              'set_id': setId,
              'form_quality_score': rep['form_quality_score'],
              'muscle_asymmetry_score': rep['left_right_imbalance_degrees'],
              'joint_angles': rep['joint_angles'],
              'detected_issues': rep['detected_issues'],
              'feedback_message': rep['feedback_message'],
              'created_at': DateTime.now().toIso8601String(),
            }).toList();
            
        if (issuesToInsert.isNotEmpty) {
          await supabase.from('form_analyses').insert(issuesToInsert);
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
        
        // Start tracking rest time
        if (_scheduleItem != null) {
          isRestTimerActive = true;
          restTimerStart = DateTime.now();
          restSecsForSet = (_scheduleItem!['rest_time_seconds'] as num).toInt();
        }

        // Only re-enter auto-detect mode if there's NO active schedule
        if (_scheduleItem == null) {
          detectedExercise = null;
          isDetecting = true;
          _scanResults = null;
          ExerciseClassifier.reset(); // Wipe old history so strict 5-frame detection starts fresh
        }
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

  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          if (controller != null && controller!.value.isInitialized)
            Positioned(
              top: 0.0,
              left: 0.0,
              width: size.width,
              height: size.height,
              child: AspectRatio(
                aspectRatio: controller!.value.aspectRatio,
                child: CameraPreview(controller!),
              ),
            ),
          
          // Pose Overlay
          if (controller != null && controller!.value.isInitialized)
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
          
          // Rest timer overlay (only after first set, before next set starts, not last set)
          if (isRestTimerActive && currentCount == 0 && currentSetNumber > 1 && (_scheduleItem?['target_sets'] == null || currentSetNumber <= (_scheduleItem!['target_sets'] as num).toInt()))
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const Text(
                    'Rest Countdown',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<int>(
                    stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
                    builder: (context, snapshot) {
                      int elapsed = 0;
                      if (restTimerStart != null) {
                        elapsed = DateTime.now().difference(restTimerStart!).inSeconds;
                      }
                      int countdown = restSecsForSet - elapsed;
                      countdown = countdown < 0 ? 0 : countdown;
                      int exceeded = elapsed - restSecsForSet;
                      exceeded = exceeded < 0 ? 0 : exceeded;
                      return Column(
                        children: [
                          Text(
                            'Time Left: $countdown s',
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          if (exceeded > 0)
                            Text(
                              'Exceeded: $exceeded s',
                              style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

          // Header
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
                        if (currentCount > 0) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: AppTheme.bgDarkSecondary,
                              title: const Text('Exit Workout?', style: TextStyle(color: Colors.white)),
                              content: const Text('Do you want to save your progress before leaving?', style: TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Discard')),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
                                  child: const Text('Save & Exit'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            if (mounted) {
                              final String? savedId = await _finishSet(showDialog: false);
                              Navigator.pop(context, {
                                'action': 'save_workout',
                                'setId': savedId,
                                'exerciseName': detectedExercise.toString().split('.').last,
                                'setNumber': currentSetNumber,
                                'reps': currentCount,
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
                          border: Border.all(color: Colors.white.withAlpha(51)),
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Exercise Info / Detection Status
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  exerciseColor.withAlpha(153),
                                  exerciseColor.withAlpha(77),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withAlpha(51)),
                            ),
                            child: Row(
                              children: [
                                if (isDetecting)
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  const Icon(Icons.check_circle, color: Colors.white, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isDetecting ? "Auto-Detecting..." : exerciseTitle,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        isDetecting ? "Start any exercise" : "Exercise Detected!",
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
          
          // Detection Message (when still detecting)
          if (isDetecting)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(180),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withAlpha(51)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fitness_center, color: Colors.white, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      "Start Exercising!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Perform any supported exercise\nand I'll detect it automatically",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Rep Counter (when exercise detected)
          if (!isDetecting)
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
                          exerciseColor,
                          exerciseColor.withAlpha(153),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: exerciseColor.withAlpha(128),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                      border: Border.all(color: Colors.white.withAlpha(77), width: 3),
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
          
          // Finish Set Button
          if (!isDetecting && currentCount > 0)
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

          // Calories (when exercise detected)
          if (!isDetecting)
            Positioned(
              bottom: 50,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(38),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withAlpha(51)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '${currentCount * 5}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      ' cal',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============ REP DETECTION LOGIC (copied from DetectionScreen) ============

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

    if (leftShoulder == null || rightShoulder == null ||
        leftElbow == null || rightElbow == null ||
        leftWrist == null || rightWrist == null ||
        leftHip == null || rightHip == null) return;

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

  void detectSquat(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (leftHip == null || rightHip == null ||
        leftKnee == null || rightKnee == null ||
        leftAnkle == null || rightAnkle == null) return;

    double leftKneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle);
    double rightKneeAngle = calculateAngle(rightHip, rightKnee, rightAnkle);
    double avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2;

    double hipY = (leftHip.y + rightHip.y) / 2;
    double kneeY = (leftKnee.y + rightKnee.y) / 2;
    bool deepSquat = avgKneeAngle < 90;

    if (deepSquat && hipY > kneeY) {
      if (!isSquatting) isSquatting = true;
    } else if (!deepSquat && isSquatting) {
      squatCount++;
      isSquatting = false;
      _recordRep();
      setState(() {});
    }
  }

  void detectPlankToDownwardDog(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (leftHip == null || rightHip == null ||
        leftShoulder == null || rightShoulder == null ||
        leftAnkle == null || rightAnkle == null) return;

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

  void detectJumpingJack(Pose pose) {
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if (leftAnkle == null || rightAnkle == null ||
        leftHip == null || rightHip == null ||
        leftShoulder == null || rightShoulder == null ||
        leftWrist == null || rightWrist == null) return;

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

  void detectHighKnees(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (leftHip == null || rightHip == null ||
        leftKnee == null || rightKnee == null ||
        leftAnkle == null || rightAnkle == null) return;

    double leftKneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle);
    double rightKneeAngle = calculateAngle(rightHip, rightKnee, rightAnkle);

    bool isLeftKneeHigh = leftKnee.y < leftHip.y && leftKneeAngle < 120;
    bool isRightKneeHigh = rightKnee.y < rightHip.y && rightKneeAngle < 120;

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

  double calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    double ab = distance(a, b);
    double bc = distance(b, c);
    double ac = distance(a, c);
    double angle = acos((ab * ab + bc * bc - ac * ac) / (2 * ab * bc)) * (180 / pi);
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
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

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
    if (_scanResults == null || controller == null || !controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final Size imageSize = Size(
      controller!.value.previewSize!.height,
      controller!.value.previewSize!.width,
    );
    CustomPainter painter = PosePainter(imageSize, _scanResults);
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: painter),
        if (formAnalyzer.currentIssues.isNotEmpty)
          CustomPaint(
            painter: FormOverlayPainter(formAnalyzer.currentIssues, imageSize),
          ),
      ],
    );
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
      ..color = Colors.green;

    final leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellow;

    final rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.blueAccent;

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(
          Offset(landmark.x * scaleX, landmark.y * scaleY),
          4,
          paint,
        );
      });

      void paintLine(PoseLandmarkType type1, PoseLandmarkType type2, Paint paintType) {
        final joint1 = pose.landmarks[type1];
        final joint2 = pose.landmarks[type2];
        if (joint1 == null || joint2 == null) return;
        canvas.drawLine(
          Offset(joint1.x * scaleX, joint1.y * scaleY),
          Offset(joint2.x * scaleX, joint2.y * scaleY),
          paintType,
        );
      }

      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, leftPaint);
      paintLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, rightPaint);
      paintLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rightPaint);
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, rightPaint);
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
      paintLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, leftPaint);
      paintLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, rightPaint);
      paintLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, rightPaint);
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize || oldDelegate.poses != poses;
  }
}
