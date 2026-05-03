import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';

/// A single form issue detected in a frame.
class FormFeedback {
  final String issue;
  final String message;
  final String severity; // 'warning' or 'danger'
  final double deduction;

  const FormFeedback({
    required this.issue,
    required this.message,
    this.severity = 'warning',
    this.deduction = 10,
  });
}

/// Result of analyzing a single frame.
class FormAnalysisResult {
  final List<FormFeedback> issues;
  final double formScore;
  final Map<String, double> jointAngles;

  const FormAnalysisResult({
    required this.issues,
    required this.formScore,
    required this.jointAngles,
  });
}

/// On-device, rule-based form analyzer.
/// Accumulates worst-case data per rep, resets on fetchAndResetRepData().
class FormAnalyzer {
  double _worstScore = 100.0;
  final Set<String> _accumulatedIssues = {};
  Map<String, double> _latestAngles = {};
  String? _latestFeedback;

  /// Unique issue names detected in the most recent frames.
  List<String> get currentIssues => _accumulatedIssues.toList();

  /// Analyze one camera frame. Returns issues + score + angles.
  FormAnalysisResult analyzeFrame(
    ExcerciseType type,
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    FormAnalysisResult result;
    switch (type) {
      case ExcerciseType.PushUps:
        result = _pushUp(landmarks);
        break;
      case ExcerciseType.Squats:
        result = _squat(landmarks);
        break;
      case ExcerciseType.HighKnees:
        result = _highKnees(landmarks);
        break;
      case ExcerciseType.JumpingJack:
        result = _jumpingJack(landmarks);
        break;
      case ExcerciseType.PlankToDownwardDog:
        result = _plankDog(landmarks);
        break;
    }
    _accumulate(result);
    return result;
  }

  /// Call when a rep is completed. Returns accumulated data and resets.
  Map<String, dynamic> fetchAndResetRepData() {
    final data = {
      'form_quality_score': _worstScore,
      'joint_angles': Map<String, double>.from(_latestAngles),
      'detected_issues': _accumulatedIssues.toList(),
      'feedback_message': _latestFeedback,
    };
    _worstScore = 100.0;
    _accumulatedIssues.clear();
    _latestAngles = {};
    _latestFeedback = null;
    return data;
  }

  void _accumulate(FormAnalysisResult r) {
    if (r.formScore < _worstScore) _worstScore = r.formScore;
    if (r.jointAngles.isNotEmpty) _latestAngles = r.jointAngles;
    for (var i in r.issues) {
      _accumulatedIssues.add(i.issue);
      _latestFeedback = i.message;
    }
  }

  // ==================== PUSH UPS ====================
  FormAnalysisResult _pushUp(Map<PoseLandmarkType, PoseLandmark> lm) {
    final issues = <FormFeedback>[];
    final angles = <String, double>{};

    final ls = lm[PoseLandmarkType.leftShoulder];
    final rs = lm[PoseLandmarkType.rightShoulder];
    final le = lm[PoseLandmarkType.leftElbow];
    final re = lm[PoseLandmarkType.rightElbow];
    final lw = lm[PoseLandmarkType.leftWrist];
    final rw = lm[PoseLandmarkType.rightWrist];
    final lh = lm[PoseLandmarkType.leftHip];
    final rh = lm[PoseLandmarkType.rightHip];
    final lk = lm[PoseLandmarkType.leftKnee];

    if (ls == null || rs == null || le == null || re == null ||
        lw == null || rw == null || lh == null || rh == null) {
      return const FormAnalysisResult(issues: [], formScore: 100, jointAngles: {});
    }

    double lAngle = _angle(ls, le, lw);
    double rAngle = _angle(rs, re, rw);
    angles['left_elbow'] = _r(lAngle);
    angles['right_elbow'] = _r(rAngle);

    double torso = lk != null ? _angle(ls, lh, lk) : 180;
    angles['torso'] = _r(torso);

    double score = 100.0;

    // Hip sag
    if (torso < 150) {
      issues.add(const FormFeedback(issue: 'hip_sag', message: 'Keep your hips up!', severity: 'danger', deduction: 20));
      score -= 20;
    }

    // Hip pike
    double hipY = (lh.y + rh.y) / 2;
    double shoulderY = (ls.y + rs.y) / 2;
    if (torso > 175 && hipY < shoulderY - 30) {
      issues.add(const FormFeedback(issue: 'hip_pike', message: 'Lower your hips!', severity: 'warning', deduction: 10));
      score -= 10;
    }

    // Arm asymmetry
    double diff = (lAngle - rAngle).abs();
    angles['elbow_diff'] = _r(diff);
    if (diff > 20) {
      issues.add(const FormFeedback(issue: 'arm_asymmetry', message: 'Keep both arms even!', severity: 'warning', deduction: 10));
      score -= 10;
    }

    return FormAnalysisResult(issues: issues, formScore: score.clamp(0, 100), jointAngles: angles);
  }

  // ==================== SQUATS ====================
  FormAnalysisResult _squat(Map<PoseLandmarkType, PoseLandmark> lm) {
    final issues = <FormFeedback>[];
    final angles = <String, double>{};

    final lh = lm[PoseLandmarkType.leftHip];
    final rh = lm[PoseLandmarkType.rightHip];
    final lk = lm[PoseLandmarkType.leftKnee];
    final rk = lm[PoseLandmarkType.rightKnee];
    final la = lm[PoseLandmarkType.leftAnkle];
    final ra = lm[PoseLandmarkType.rightAnkle];
    final ls = lm[PoseLandmarkType.leftShoulder];
    final rs = lm[PoseLandmarkType.rightShoulder];

    if (lh == null || rh == null || lk == null || rk == null || la == null || ra == null) {
      return const FormAnalysisResult(issues: [], formScore: 100, jointAngles: {});
    }

    double lAngle = _angle(lh, lk, la);
    double rAngle = _angle(rh, rk, ra);
    angles['left_knee'] = _r(lAngle);
    angles['right_knee'] = _r(rAngle);

    double score = 100.0;

    // Knee cave — knees closer together than ankles
    double kneeGap = (rk.x - lk.x).abs();
    double ankleGap = (ra.x - la.x).abs();
    if (ankleGap > 10 && kneeGap < ankleGap * 0.80) {
      issues.add(const FormFeedback(issue: 'knee_cave', message: 'Push your knees out!', severity: 'danger', deduction: 20));
      score -= 20;
    }

    // Forward lean
    if (ls != null && rs != null) {
      double shoulderY = (ls.y + rs.y) / 2;
      double hipY = (lh.y + rh.y) / 2;
      if (shoulderY > hipY + 50) {
        issues.add(const FormFeedback(issue: 'forward_lean', message: 'Keep your chest up!', severity: 'warning', deduction: 15));
        score -= 15;
      }
      double torso = _angle(ls, lh, lk);
      angles['torso'] = _r(torso);
    }

    // Leg asymmetry
    double diff = (lAngle - rAngle).abs();
    angles['knee_diff'] = _r(diff);
    if (diff > 20) {
      issues.add(const FormFeedback(issue: 'leg_asymmetry', message: 'Balance both legs!', severity: 'warning', deduction: 10));
      score -= 10;
    }

    return FormAnalysisResult(issues: issues, formScore: score.clamp(0, 100), jointAngles: angles);
  }

  // ==================== HIGH KNEES ====================
  FormAnalysisResult _highKnees(Map<PoseLandmarkType, PoseLandmark> lm) {
    final issues = <FormFeedback>[];
    final angles = <String, double>{};

    final lh = lm[PoseLandmarkType.leftHip];
    final rh = lm[PoseLandmarkType.rightHip];
    final lk = lm[PoseLandmarkType.leftKnee];
    final rk = lm[PoseLandmarkType.rightKnee];
    final la = lm[PoseLandmarkType.leftAnkle];
    final ra = lm[PoseLandmarkType.rightAnkle];
    final ls = lm[PoseLandmarkType.leftShoulder];

    if (lh == null || rh == null || lk == null || rk == null || la == null || ra == null) {
      return const FormAnalysisResult(issues: [], formScore: 100, jointAngles: {});
    }

    double lAngle = _angle(lh, lk, la);
    double rAngle = _angle(rh, rk, ra);
    angles['left_knee'] = _r(lAngle);
    angles['right_knee'] = _r(rAngle);

    double score = 100.0;

    // Knee height check — at least one knee should be near hip level
    bool leftHigh = lk.y < lh.y;
    bool rightHigh = rk.y < rh.y;
    if (!leftHigh && !rightHigh) {
      // Only flag when actively running (angle suggests motion)
      double avgAngle = (lAngle + rAngle) / 2;
      if (avgAngle < 150) {
        issues.add(const FormFeedback(issue: 'low_knees', message: 'Lift your knees higher!', severity: 'warning', deduction: 15));
        score -= 15;
      }
    }

    // Leaning back
    if (ls != null) {
      double torso = _angle(ls, lh, la);
      angles['torso'] = _r(torso);
      if (torso < 140) {
        issues.add(const FormFeedback(issue: 'leaning_back', message: 'Stay upright!', severity: 'warning', deduction: 10));
        score -= 10;
      }
    }

    return FormAnalysisResult(issues: issues, formScore: score.clamp(0, 100), jointAngles: angles);
  }

  // ==================== JUMPING JACKS ====================
  FormAnalysisResult _jumpingJack(Map<PoseLandmarkType, PoseLandmark> lm) {
    final issues = <FormFeedback>[];
    final angles = <String, double>{};

    final la = lm[PoseLandmarkType.leftAnkle];
    final ra = lm[PoseLandmarkType.rightAnkle];
    final ls = lm[PoseLandmarkType.leftShoulder];
    final rs = lm[PoseLandmarkType.rightShoulder];
    final lw = lm[PoseLandmarkType.leftWrist];
    final rw = lm[PoseLandmarkType.rightWrist];
    final lh = lm[PoseLandmarkType.leftHip];
    final rh = lm[PoseLandmarkType.rightHip];

    if (la == null || ra == null || ls == null || rs == null ||
        lw == null || rw == null || lh == null || rh == null) {
      return const FormAnalysisResult(issues: [], formScore: 100, jointAngles: {});
    }

    double legSpread = (ra.x - la.x).abs();
    double shoulderWidth = (rs.x - ls.x).abs();
    double armHeight = (lw.y + rw.y) / 2;
    double shoulderHeight = (ls.y + rs.y) / 2;

    angles['leg_spread'] = _r(legSpread);
    angles['shoulder_width'] = _r(shoulderWidth);

    double score = 100.0;

    // Arms not reaching high enough during open phase
    bool legsApart = legSpread > shoulderWidth * 1.0;
    if (legsApart && armHeight > shoulderHeight) {
      issues.add(const FormFeedback(issue: 'arms_low', message: 'Reach your arms higher!', severity: 'warning', deduction: 10));
      score -= 10;
    }

    // Legs not spreading enough during open phase
    if (legsApart && legSpread < shoulderWidth * 1.1) {
      issues.add(const FormFeedback(issue: 'legs_narrow', message: 'Spread your legs wider!', severity: 'warning', deduction: 10));
      score -= 10;
    }

    return FormAnalysisResult(issues: issues, formScore: score.clamp(0, 100), jointAngles: angles);
  }

  // ==================== PLANK TO DOWNWARD DOG ====================
  FormAnalysisResult _plankDog(Map<PoseLandmarkType, PoseLandmark> lm) {
    final issues = <FormFeedback>[];
    final angles = <String, double>{};

    final ls = lm[PoseLandmarkType.leftShoulder];
    final rs = lm[PoseLandmarkType.rightShoulder];
    final lh = lm[PoseLandmarkType.leftHip];
    final rh = lm[PoseLandmarkType.rightHip];
    final lk = lm[PoseLandmarkType.leftKnee];

    if (ls == null || rs == null || lh == null || rh == null) {
      return const FormAnalysisResult(issues: [], formScore: 100, jointAngles: {});
    }

    double hipY = (lh.y + rh.y) / 2;
    double shoulderY = (ls.y + rs.y) / 2;
    angles['hip_shoulder_diff'] = _r((hipY - shoulderY).abs());

    double score = 100.0;

    // Sagging plank — hips much below shoulders (in plank position)
    bool roughlyLevel = (hipY - shoulderY).abs() < 60;
    if (roughlyLevel && hipY > shoulderY + 30) {
      issues.add(const FormFeedback(issue: 'plank_sag', message: 'Tighten your core!', severity: 'danger', deduction: 20));
      score -= 20;
    }

    // Torso alignment
    if (lk != null) {
      double torso = _angle(ls, lh, lk);
      angles['torso'] = _r(torso);
    }

    // Arm asymmetry in plank
    double shoulderDiff = (ls.y - rs.y).abs();
    angles['shoulder_diff'] = _r(shoulderDiff);
    if (shoulderDiff > 25) {
      issues.add(const FormFeedback(issue: 'uneven_shoulders', message: 'Level your shoulders!', severity: 'warning', deduction: 10));
      score -= 10;
    }

    return FormAnalysisResult(issues: issues, formScore: score.clamp(0, 100), jointAngles: angles);
  }

  // ==================== HELPERS ====================
  static double _angle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    double ab = _dist(a, b);
    double bc = _dist(b, c);
    double ac = _dist(a, c);
    double cosVal = ((ab * ab + bc * bc - ac * ac) / (2 * ab * bc)).clamp(-1.0, 1.0);
    return acos(cosVal) * (180 / pi);
  }

  static double _dist(PoseLandmark p1, PoseLandmark p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }

  static double _r(double v) => double.parse(v.toStringAsFixed(1));
}

/// Draws red warning labels on top of the camera preview for form corrections.
class FormOverlayPainter extends CustomPainter {
  final List<String> issues;
  final Size absoluteImageSize;

  FormOverlayPainter(this.issues, this.absoluteImageSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (issues.isEmpty) return;

    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.redAccent.withAlpha(200),
    );

    double yOffset = 100.0;
    for (var issue in issues) {
      final textSpan = TextSpan(
        text: " ⚠️ ${issue.replaceAll('_', ' ').toUpperCase()} ",
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(
        minWidth: 0,
        maxWidth: size.width,
      );
      
      // Draw background box for text
      final rect = Rect.fromLTWH(20.0, yOffset, textPainter.width, textPainter.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = Colors.redAccent.withAlpha(200),
      );

      textPainter.paint(canvas, Offset(20, yOffset));
      yOffset += textPainter.height + 10;
    }
  }

  @override
  bool shouldRepaint(FormOverlayPainter oldDelegate) {
    return oldDelegate.issues != issues;
  }
}
