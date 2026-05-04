# Exercise Detection & Performance Tracking - Task List

1. Analysis of Google ML Kit Pose Detection capabilities and landmark mapping.
2. Mathematical modeling of joint angles (Law of Cosines) for biomechanical analysis.
3. Comparative study of state-machine vs. threshold-based rep counting algorithms.
4. Architectural design of ExerciseClassifier for real-time inference.
5. Defining rule sets for Push-up detection (horizontal torso, arm flexion).
6. Defining rule sets for Squat detection (upright torso, knee flexion, depth).
7. Defining rule sets for Jumping Jack detection (limb extension, vertical movement).
8. Defining rule sets for High Knees detection (standing posture, knee height relative to hip).
9. Integration of camera package with google_mlkit_pose_detection in Flutter.
10. Establishing coordinate system normalization for different screen resolutions.
11. Development of ExerciseClassifier.isPushUpPose using consecutive frame validation.
12. Development of ExerciseClassifier.isSquatPose using knee angle thresholds.
13. Development of ExerciseClassifier.isJumpingJackPose using width-to-height ratios.
14. Development of ExerciseClassifier.isHighKneesPose using vertical landmark comparisons.
15. Development of ExerciseClassifier.isPlankPose for Plank to Downward Dog detection.
16. Unit testing landmark visibility thresholds (minimum confidence scores).
17. Implementing the auto-detect state machine in AutoDetectScreen.
18. Reducing jitter in detection using a sliding window of 5 frames.
19. Designing the "Detecting..." overlay with pulsing animations.
20. Integrating Text-to-Speech (TTS) for exercise confirmation.
21. Implementing Push-up rep logic (Down: angle < 90°, Up: angle > 160°).
22. Implementing Squat rep logic (Down: hip Y > knee Y, Up: knee angle > 150°).
23. Implementing Jumping Jack rep logic (Open: arms up & legs apart, Close: back to neutral).
24. Implementing High Knees rep logic (Individual leg counting based on hip height).
25. Implementing Plank to Downward Dog logic (V-shape detection vs. horizontal plank).
26. Developing the _recordRep() function to capture biomechanical snapshots.
27. Integration of RiskAssessmentEngine to track left/right symmetry during reps.
28. Integration of FormAnalyzer to detect specific posture issues per rep.
29. Implementing the currentCount getter to dynamically display reps.
30. Creating the circular rep counter UI with gradient effects.
31. Designing the _lookupSchedule function to fetch user targets from Supabase.
32. Mapping UI exercise titles to database schema keys for schedule matching.
33. Implementing _checkScheduledTarget to monitor rep goals in real-time.
34. Developing the between-set transition logic for multiple sets.
35. Designing the RestTimerScreen for countdown intervals.
36. Triggering automatic screen transitions upon set completion.
37. Final set detection logic to trigger workout summary and exit.
38. Validating schedule adherence (ensuring rep count resets after each set).
39. Handling "Free Workout" mode when no schedule is found.
40. Implementing the "Finish Set" manual override button.
41. Implementing time_since_last_rep calculation using DateTime differences.
42. Tracking duration_seconds for entire sets for intensity calculation.
43. Developing the actual_rest_time_seconds tracker for recovery analysis.
44. Database schema design for exercise_reps and exercise_sets tables.
45. Implementing Supabase upsert logic for persisting workout data.
46. Real-time display of calorie burn estimation based on rep counts.
47. End-to-end testing of the full workout flow (Detect -> Count -> Rest -> Save).
48. Memory management: ensuring PoseDetector is closed on screen dispose.
49. Improving frame rate by offloading heavy math to doPoseEstimationOnFrame.
50. Finalizing the implementation notes for the detection and tracking modules.
