import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_detection_realtime/form_analysis/squat_analyzer.dart';
import 'package:pose_detection_realtime/main.dart'; // To access the cameras list

class BiomechanicsDemoScreen extends StatefulWidget {
  const BiomechanicsDemoScreen({super.key});

  @override
  State<BiomechanicsDemoScreen> createState() => _BiomechanicsDemoScreenState();
}

class _BiomechanicsDemoScreenState extends State<BiomechanicsDemoScreen> {
  CameraController? _cameraController;
  late PoseDetector _poseDetector;
  bool _isBusy = false;
  
  // Your Biomechanical Brain!
  final SquatAnalyzer _squatAnalyzer = SquatAnalyzer();
  
  // UI State Variables to show the panel
  int _repCount = 0;
  String _currentState = 'standing';
  List<String> _currentErrors = [];
  double _currentKneeAngle = 180.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
    _poseDetector = PoseDetector(options: options);

    _cameraController = CameraController(
      cameras[0], // Uses the first camera
      ResolutionPreset.medium,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    if (!mounted) return;
    
    setState(() {});
    _cameraController!.startImageStream((image) {
      if (!_isBusy) {
        _isBusy = true;
        _processFrame(image);
      }
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage != null) {
      final poses = await _poseDetector.processImage(inputImage);
      
      if (poses.isNotEmpty) {
        final landmarks = poses.first.landmarks;
        
        // 1. Map Google ML Kit landmarks to your SquatAnalyzer format
        Map<String, List<double>> formattedLandmarks = {};
        void addLandmark(String name, PoseLandmarkType type) {
          if (landmarks[type] != null) {
            formattedLandmarks[name] = [landmarks[type]!.x, landmarks[type]!.y];
          }
        }

        addLandmark('left_shoulder', PoseLandmarkType.leftShoulder);
        addLandmark('right_shoulder', PoseLandmarkType.rightShoulder);
        addLandmark('left_hip', PoseLandmarkType.leftHip);
        addLandmark('right_hip', PoseLandmarkType.rightHip);
        addLandmark('left_knee', PoseLandmarkType.leftKnee);
        addLandmark('right_knee', PoseLandmarkType.rightKnee);
        addLandmark('left_ankle', PoseLandmarkType.leftAnkle);
        addLandmark('right_ankle', PoseLandmarkType.rightAnkle);

        // 2. Feed the data to YOUR engine
        final analysis = _squatAnalyzer.analyzeFrame(formattedLandmarks);

        if (analysis['status'] == 'analyzed') {
          setState(() {
            _repCount = analysis['rep_count'];
            _currentState = analysis['current_state'];
            _currentErrors = List<String>.from(analysis['form_errors'] ?? []);
            
            // Extract the angle to show on screen
            if (analysis['angles'] != null && analysis['angles']['knee_avg'] != null) {
              _currentKneeAngle = analysis['angles']['knee_avg'];
            }
          });
        }
      }
    }
    _isBusy = false;
  }

  // Camera orientation helper (same as main app)
  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = cameras[0];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isAndroid) {
      var rotationCompensation = _orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Biomechanical AI Demo"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Stack(
        children: [
          // 1. Camera Feed
          if (_cameraController != null && _cameraController!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),

          // 2. Data Overlay Panel (Perfect for the Viva Panel!)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blueAccent, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Squat Reps: $_repCount", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text("Phase: ${_currentState.toUpperCase()}", style: const TextStyle(color: Colors.orangeAccent, fontSize: 18)),
                  Text("Knee Angle: ${_currentKneeAngle.toStringAsFixed(1)}°", style: const TextStyle(color: Colors.greenAccent, fontSize: 18)),
                  
                  if (_currentErrors.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    const Text("Form Feedback:", style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                    ..._currentErrors.map((e) => Text("⚠️ $e", style: const TextStyle(color: Colors.white, fontSize: 14))),
                  ]
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}