# Eraser.io — System Architecture Diagram Prompts

Use these prompts in [eraser.io](https://app.eraser.io/) → **DiagramGPT** to generate architecture diagrams for the FitForge AI research paper.

---

## Prompt 1: Full System Architecture

```
Create a system architecture diagram for "FitForge AI" — a zero-interaction fitness coaching mobile app.

The diagram should have 3 main layers arranged top to bottom:

LAYER 1 — MOBILE DEVICE (Flutter App):
- "Camera Module" captures live video frames (NV21 / BGRA8888)
- Frames flow into "Google ML Kit Pose Detection" which outputs 33 skeletal landmarks
- Landmarks feed into 3 parallel modules:
  1. "ExerciseClassifier" — uses Law of Cosines angle calculation → outputs exercise type and rep count
  2. "FormAnalyzer" — rule-based form fault detection (hip sag, knee valgus, arm asymmetry, etc.) → outputs form quality score and detected issues
  3. "RiskAssessmentEngine" — tracks max depth angle and left/right imbalance continuously
- "FormAnalyzer" connects to two feedback outputs: "flutter_tts (Audio Cues)" and "FormOverlayPainter (Visual Overlay)"
- All 3 modules aggregate data into "RepData Accumulator" which batches data per set

LAYER 2 — DATABASE (Supabase / PostgreSQL):
- "RepData Accumulator" syncs to 3 database tables:
  1. "workout_schedules" (target sets, reps, rest time)
  2. "exercise_sets" (set summary: total_reps, duration, intensity, form_quality_score, muscle_asymmetry_score, heart_rate)
  3. "exercise_reps" (per-rep: max_depth_angle, left_right_imbalance, joint_angles, detected_issues)
- Also has "form_analyses" table connected from exercise_reps

LAYER 3 — PYTHON BACKEND (Flask API):
- Database feeds into 3 ML model endpoints:
  1. "/predict" — Random Forest Classifier → Performance label (Good/Average)
  2. "/predict_lstm" — LSTM Neural Network (TensorFlow) → Sequential fatigue forecast
  3. "/predict-injury-risk" — Scikit-Learn Classifier → Risk label (Low Risk / High Risk)
- All 3 endpoints return predictions back to the mobile app
- The risk prediction creates a feedback loop arrow back to the mobile app's "Adaptive Scheduler" which adjusts workout_schedules

Use a clean, professional style with rounded rectangles. Color code: blue for mobile layer, green for database layer, orange for backend/ML layer. Add directional arrows showing data flow.
```

---

## Prompt 2: Data Flow Pipeline

```
Create a data flow diagram for the FitForge AI data collection pipeline.

Flow from left to right:

1. "Smartphone Camera" → raw video frames
2. "Google ML Kit (BlazePose CNN)" → 33 2D skeletal keypoints (X, Y coordinates)
3. "Biomechanical Engine" → splits into:
   a. "Joint Angle Calculator (Law of Cosines)" → elbow angles, knee angles, torso angle, hip alignment
   b. "Temporal Tracker" → time_since_last_rep, actual_rest_time_seconds, duration_seconds
   c. "Form Quality Analyzer" → form_quality_score (0-100), detected_issues list, feedback_message
   d. "Asymmetry Calculator" → left_right_imbalance_degrees, max_depth_angle
4. All outputs merge into "Per-Rep Data Bundle"
5. "Per-Rep Data Bundle" → on set completion → "Supabase (exercise_sets + exercise_reps)"
6. "Supabase" → aggregated feature extraction → splits into:
   a. "Performance Feature Vector (12 features)" → "Random Forest / LSTM Models" → "Good or Average"
   b. "Injury Risk Feature Vector (12 features)" → "Risk Classifier" → "Low Risk or High Risk"

Use a horizontal pipeline style with clear data labels on arrows. Professional color scheme.
```

---

## Prompt 3: Form Analysis Feedback Loop

```
Create a flowchart diagram showing the real-time wrong pose detection and feedback loop in FitForge AI.

Start: "Camera Frame Captured"
→ "ML Kit Pose Detection" extracts landmarks
→ "FormAnalyzer.analyzeFrame()" evaluates pose
→ Decision: "Form fault detected?"
  - No → "Score = 100, No issues" → "Continue to next frame"
  - Yes → "Identify fault type" splits into:
    - "hip_sag (torso < 150°)"
    - "knee_cave (knee gap < 80% ankle gap)"
    - "forward_lean (shoulders > hips + 50px)"
    - "arm_asymmetry (elbow diff > 20°)"
    - "low_knees (knee not above hip)"
    - "leaning_back (torso < 140°)"
    - "plank_sag (hips > shoulders + 30px)"
    - "uneven_shoulders (diff > 25px)"
  → "Calculate form score (100 minus deductions)"
  → Decision: "Fault persists across N frames? (Debounce)"
    - No → "Buffer, wait for next frame"
    - Yes → splits into two parallel outputs:
      1. "flutter_tts: Speak corrective message" (e.g., "Keep your hips up!")
      2. "FormOverlayPainter: Red warning on skeleton"
  → "Log fault in _accumulatedIssues"
  → "On rep complete: fetchAndResetRepData()"
  → "Save to exercise_reps + form_analyses in Supabase"
  → "Feed into Injury Risk Model"
  → Decision: "Risk = High?"
    - No → "Continue workout normally"
    - Yes → "Adaptive Scheduler: extend rest, reduce target reps"

Use a vertical flowchart with decision diamonds. Color: green for normal flow, red for fault detection, orange for feedback actions.
```

---

## Prompt 4: ML Model Architecture

```
Create an architecture diagram showing the 3 machine learning models in FitForge AI.

Section 1 — ON-DEVICE MODEL:
- "Google ML Kit (BlazePose CNN)" — Pre-trained convolutional neural network
- Input: Camera frame (RGB image)
- Output: 33 skeletal keypoints in 2D space
- Runs locally on device, no internet required

Section 2 — PERFORMANCE PREDICTION (Python Backend):
Model A: "Random Forest Classifier (performance_prediction_model.pkl)"
- Input: 12 features [Name, Exercise, Sets, Total_Reps, Time_Mins, Rest_Between_Sets_Secs, Avg_Rest_Per_Rep_Secs, Day, Month, Avg_Reps, Max_Reps, Min_Reps]
- Output: "Good" or "Average" + probability score

Model B: "LSTM Neural Network (performance_lstm_model.h5)"
- Input: Sequence of 3-5 sets → each set has [name_encoded, exercise_encoded, 10 scaled numeric features]
- Processing: Sequential pattern recognition for fatigue trends
- Output: Performance probability (>0.5 = Good, <0.5 = Average)

Section 3 — INJURY RISK PREDICTION (Python Backend):
Model C: "Scikit-Learn Classifier (injury_risk_model.pkl)"
- Input: 12 features [Age, Gender, Height_cm, Weight_kg, BMI, Training_Frequency, Training_Duration, Warmup_Time, Flexibility_Score, Muscle_Asymmetry, Injury_History, Training_Intensity]
- Output: "Low Risk" (0) or "High Risk" (1) + probability

Show all 3 sections with their input/output arrows. Use a clean card-based layout. Blue for on-device, purple for performance models, red for risk model.
```

---

## Prompt 5: Exercise State Machine

```
Create a state machine diagram showing the exercise detection and workout flow in FitForge AI.

States:
1. "IDLE" — Camera initializing
2. "DETECTING" — Analyzing pose landmarks to identify exercise type
3. "COUNTING" — Exercise identified, counting reps using angle thresholds
4. "SET_COMPLETE" — Target reps reached or manual finish
5. "REST_TIMER" — Countdown rest period between sets
6. "NEXT_SET" — Reset counters, resume camera stream
7. "WORKOUT_COMPLETE" — All sets finished, save to database

Transitions:
- IDLE → DETECTING: Camera stream started
- DETECTING → COUNTING: Exercise posture matched (e.g., push-up plank detected for 5 consecutive frames)
- COUNTING → COUNTING: Rep threshold crossed (e.g., elbow < 90° then > 160°), increment counter
- COUNTING → SET_COMPLETE: currentCount == targetReps OR manual "Finish Set" button
- SET_COMPLETE → REST_TIMER: Save exercise_sets + exercise_reps to Supabase, show RestTimerScreen
- REST_TIMER → NEXT_SET: Timer expires, actual_rest_time recorded
- NEXT_SET → COUNTING: Camera stream resumed, counters reset
- SET_COMPLETE → WORKOUT_COMPLETE: currentSet >= targetSets (final set)
- WORKOUT_COMPLETE → IDLE: Navigate back, announce "Workout complete!"

Use circular state nodes with labeled transition arrows. Professional diagram style.
```
