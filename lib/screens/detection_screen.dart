import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';
import 'package:pose_detection_realtime/main.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key, required this.exerciseDataModel});
  final ExerciseDataModel exerciseDataModel;

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

  @override
  void dispose() {
    controller?.dispose();
    poseDetector.close();
    _pulseController.dispose();
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

  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview - Full Screen
          if (controller != null)
            Positioned(
              top: 0.0,
              left: 0.0,
              width: size.width,
              height: size.height,
              child: Container(
                child: (controller.value.isInitialized)
                    ? AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: CameraPreview(controller),
                      )
                    : Container(),
              ),
            ),
          
          // Pose Overlay
          if (controller != null)
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
          SafeArea(
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
