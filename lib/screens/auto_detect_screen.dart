import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/utils/exercise_classifier.dart';
import 'package:pose_detection_realtime/main.dart';

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
            });
          }
        } else {
          // Phase 2: Count reps for detected exercise
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

  @override
  void dispose() {
    controller?.dispose();
    poseDetector.close();
    _pulseController.dispose();
    super.dispose();
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
                      onTap: () => Navigator.pop(context),
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
      setState(() {});
    } else if (!isLeftKneeHigh) {
      leftKneeUp = false;
    }

    if (isRightKneeHigh && !rightKneeUp) {
      rightKneeUp = true;
      highKneeCount++;
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
