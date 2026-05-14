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
51. Implementing time_since_last_rep tracking using precise DateTime differentials in _recordRep.
52. Developing _checkScheduledTarget logic to automate set transitions based on Supabase schedule parameters.
53. Integration of actual_rest_time_seconds update logic to track real-world recovery between sets.
54. Implementing _launchNextScheduleItem for automated exercise chaining in scheduled workouts.
55. Developing the FormAnalyzer state machine to track worst-case form scores and issues per rep.
56. Implementing rule-sets for "Hip Sag" and "Hip Pike" detection in Push-ups using torso angle thresholds.
57. Developing "Knee Cave" detection for Squats based on relative horizontal distance between knees and ankles.
58. Implementing "Low Knees" detection for High Knees using vertical landmark comparisons.
59. Developing "Arms Low" and "Legs Narrow" feedback logic for Jumping Jacks.
60. Configuration of Google Gemini API credentials (API key, model selection: gemini-2.5-flash-lite) and REST API URL construction in unified_backend.py.
61. Design of the `/risk-suggestions` endpoint prompt engineering: crafting the FitForge AI Safety Advisor system prompt with user metrics context injection.
62. Implementation of structured JSON output enforcement using Gemini's `responseMimeType: "application/json"` generation config parameter.
63. Development of the risk profile context builder transforming raw API features into human-readable metric descriptions for LLM comprehension.
64. Implementation of JSON response parsing with markdown fence stripping, missing-field defaults, and graceful fallback suggestions on parse failure.
65. Design of the `/risk-chat` follow-up endpoint for conversational AI interaction with injected risk profile context and concise response constraints.
66. Implementation of rate-limiting strategy through model tier selection (gemini-2.5-flash-lite) and 30-second backend timeout configuration.
67. Development of GrokSuggestionService.fetchSuggestions() combining 12 risk metrics + prediction result into a single POST request to `/risk-suggestions`.
68. Development of GrokSuggestionService.sendChatMessage() for follow-up conversations with optional risk_context injection for personalized AI responses.
69. Implementation of the AI Safety Advisor section in RiskDashboardScreen with gradient header, loading spinner, error retry, and suggestion card rendering.
70. Development of priority-based suggestion cards with color-coded indicators (🔴 High / 🟡 Medium / 🟢 Low), priority badges, and detailed descriptions.
71. Implementation of the interactive chat section with scrollable message list, user/AI message bubble styling, and real-time loading state management.
72. Integration of auto-triggered AI suggestions on RiskDashboardScreen: automatically calling _fetchGrokSuggestions() after successful risk prediction completion.
73. Implementation of the AI suggestion card in InjuryRiskScreen (manual input flow) with warning banner, priority-colored suggestion items, and icon-labeled header.
74. End-to-end testing of the Gemini AI chatbot pipeline: verifying prompt delivery, response parsing, error recovery, and UI rendering across both dashboard and manual screens.
75. Preparing the final project presentation slide deck covering system architecture, methodology, results, and live demonstration plan.
76. Designing presentation diagrams illustrating the end-to-end data flow from pose detection through ML prediction to AI chatbot feedback.
77. Creating live demonstration scripts and pre-recorded backup videos showcasing real-time exercise detection, injury risk prediction, and AI chatbot interaction.
78. Conducting mock viva sessions to rehearse technical defense of design decisions, model evaluation metrics, and system integration choices.
79. Compiling and organizing the complete source code repository, research documentation, and supplementary materials for final submission.
80. Performing a final verification of all project deliverables against the initial research objectives and marking criteria.
