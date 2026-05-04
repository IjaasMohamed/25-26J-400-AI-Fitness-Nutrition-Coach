# Mobile Application Architecture

## Overview
FitForge AI is built as a cross-platform mobile application using the **Flutter (Dart)** framework. The application serves as the primary sensor array, processing engine, and user interface for the zero-interaction fitness tracking system.

## 1. Core Principles
- **Zero-Interaction:** The UI is designed to require no manual input during the workout. The camera acts as the primary input mechanism, managing state transitions automatically.
- **On-Device Processing:** Video frames are processed locally without network round-trips to preserve battery, reduce latency, and ensure privacy.

## 2. Technical Stack
- **Framework:** Flutter SDK (Cross-platform compilation to iOS and Android).
- **Vision Integration:** `camera` plugin for frame acquisition; `google_mlkit_pose_detection` for skeletal tracking.
- **Backend Sync:** Supabase SDK for secure, authenticated data persistence.
- **Feedback:** Custom canvas rendering (`PosePainter`) and `flutter_tts` for audio cues.

## 3. Application State Flow
1. **Camera Initialization:** The device allocates the camera resource and begins streaming frames (`NV21` on Android, `BGRA8888` on iOS).
2. **Detection Loop:** An asynchronous loop processes one frame at a time. A boolean lock (`isBusy`) prevents memory overflow.
3. **Classification & Tracking:** `ExerciseClassifier` continuously parses the 33 ML Kit landmarks, applying trigonometric functions to calculate joint angles.
4. **State Machine:** 
   - Enters "Detecting" phase.
   - Recognizes specific exercise posture.
   - Enters "Counting" phase.
   - Reps are incremented based on geometric thresholds.
5. **Transition & Sync:** Once an exercise motion stops or the target schedule is reached, the app automatically transitions to a `RestTimerScreen` and asynchronously syncs the `exercise_sets` and `exercise_reps` payload to the Supabase backend.
