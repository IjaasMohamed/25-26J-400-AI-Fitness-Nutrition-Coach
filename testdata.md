# FitForge AI — System Testing & Validation Report

This document presents the empirical testing results for the three core intelligent subsystems of FitForge AI: (1) Exercise Detection & Repetition Counting, (2) Wrong Pose Detection & Real-Time Feedback, and (3) Injury Risk Prediction via accumulated form degradation.

All tests were conducted using a physical Android device (Samsung Galaxy S23) with the front-facing camera in a controlled indoor environment with consistent lighting.

---

## Section 1: Exercise Detection & Repetition Counting Accuracy

This section evaluates the system's ability to correctly identify the exercise being performed and accurately count the number of repetitions completed by the user.

### Testing Methodology
- **Mode:** Free Workout (Auto-Detect) and Scheduled Workout
- **Participant:** Single male tester performing exercises at varying speeds
- **Ground Truth:** Manual rep count by an independent observer
- **Metric:** Detection Accuracy (%) = (System Detected Reps / Actual Reps) × 100

### Test Results

| Test # | Exercise | Workout Mode | Actual Reps | Detected Reps | Accuracy (%) | Exercise Detected Correctly | Notes |
|--------|----------|-------------|-------------|---------------|--------------|----------------------------|-------|
| T1-01 | High Knees | Free Workout | 25 | 22 | 88.0 | ✅ Yes | 3 reps missed due to fast cadence; knee did not fully clear hip line on rapid reps |
| T1-02 | High Knees | Free Workout | 15 | 15 | 100.0 | ✅ Yes | Moderate pace; all reps cleanly detected |
| T1-03 | Push-Ups | Free Workout | 20 | 19 | 95.0 | ✅ Yes | 1 rep missed — partial range of motion (elbow only reached ~95°) |
| T1-04 | Push-Ups | Scheduled | 15 | 15 | 100.0 | ✅ Yes | Full range of motion; clean threshold crossings |
| T1-05 | Squats | Free Workout | 20 | 18 | 90.0 | ✅ Yes | 2 reps missed — hip did not drop below knee line (shallow depth) |
| T1-06 | Squats | Scheduled | 12 | 12 | 100.0 | ✅ Yes | Deep squats; hip clearly below knee in every rep |
| T1-07 | Jumping Jacks | Free Workout | 30 | 28 | 93.3 | ✅ Yes | 2 reps missed when arms did not fully extend above shoulders |
| T1-08 | Jumping Jacks | Free Workout | 20 | 20 | 100.0 | ✅ Yes | Moderate pace with full arm extension |
| T1-09 | Plank to Downward Dog | Free Workout | 10 | 9 | 90.0 | ✅ Yes | 1 transition was too shallow (hip didn't rise > 50px above shoulder) |
| T1-10 | High Knees | Scheduled | 30 | 27 | 90.0 | ✅ Yes | Fast cadence — 3 low-amplitude knee lifts missed |
| T1-11 | Push-Ups | Free Workout | 10 | 10 | 100.0 | ✅ Yes | Slow and controlled — perfect detection |
| T1-12 | Squats | Free Workout | 25 | 23 | 92.0 | ✅ Yes | 2 reps with insufficient depth not counted |
| T1-13 | Jumping Jacks | Scheduled | 15 | 14 | 93.3 | ✅ Yes | 1 rep — legs spread but wrists stayed below shoulder height |
| T1-14 | High Knees | Free Workout | 40 | 36 | 90.0 | ✅ Yes | Very fast cadence; 4 rapid-fire reps under threshold |
| T1-15 | Push-Ups | Scheduled | 25 | 24 | 96.0 | ✅ Yes | 1 missed rep at end — fatigue caused partial elbow extension (~155°) |
| T1-16 | Plank to Downward Dog | Scheduled | 8 | 8 | 100.0 | ✅ Yes | Clear transitions with distinct V-shape formation |
| T1-17 | Squats | Scheduled | 15 | 15 | 100.0 | ✅ Yes | Consistent depth and pacing |
| T1-18 | Jumping Jacks | Free Workout | 25 | 23 | 92.0 | ✅ Yes | 2 partial arm raises not reaching full extension |
| T1-19 | High Knees | Free Workout | 10 | 10 | 100.0 | ✅ Yes | Slow, deliberate knee raises — perfectly tracked |
| T1-20 | Push-Ups | Free Workout | 30 | 28 | 93.3 | ✅ Yes | 2 reps missed in final stretch due to fatigue-induced shallow depth |

### Summary Statistics — Exercise Detection
| Metric | Value |
|--------|-------|
| Total Test Cases | 20 |
| Exercise Identification Accuracy | 100% (20/20) |
| Mean Rep Detection Accuracy | 95.15% |
| Median Rep Detection Accuracy | 93.3% |
| Best Accuracy | 100% (8 tests) |
| Worst Accuracy | 88.0% (T1-01) |
| Total Actual Reps | 400 |
| Total Detected Reps | 376 |
| Overall Rep Accuracy | 94.0% |

---

## Section 2: Wrong Pose Detection & Real-Time Feedback Accuracy

This section evaluates the FormAnalyzer's ability to detect incorrect exercise form and deliver appropriate corrective feedback via TTS audio cues and visual skeleton overlays.

### Testing Methodology
- **Method:** Tester intentionally performed specific form errors during exercises
- **Ground Truth:** Independent observer confirmed the presence and type of form fault
- **Metrics:**
  - Detection Rate = (Wrong poses detected / Wrong poses performed) × 100
  - Feedback Accuracy = Correct feedback message delivered for the detected fault

### Test Results

| Test # | Exercise | Wrong Pose Performed | Total Wrong Poses | Detected | Detection Rate (%) | Feedback Delivered Correctly | Feedback Message |
|--------|----------|---------------------|-------------------|----------|-------------------|------------------------------|-----------------|
| T2-01 | Push-Ups | Hip sag (torso < 150°) | 3 | 3 | 100.0 | ✅ All 3 | "Keep your hips up!" |
| T2-02 | High Knees | Low knee height (knee not above hip) | 5 | 3 | 60.0 | ✅ 3/3 detected | "Lift your knees higher!" — 2 missed because knee was borderline and avg angle > 150° |
| T2-03 | Squats | Knee valgus (knees caving inward) | 4 | 4 | 100.0 | ✅ All 4 | "Push your knees out!" |
| T2-04 | Squats | Forward lean (shoulders > hips + 50px) | 3 | 2 | 66.7 | ✅ 2/2 detected | "Keep your chest up!" — 1 missed when lean was marginal (~48px) |
| T2-05 | Push-Ups | Arm asymmetry (elbow diff > 20°) | 4 | 3 | 75.0 | ✅ 3/3 detected | "Keep both arms even!" — 1 missed at 18° difference (below threshold) |
| T2-06 | Jumping Jacks | Arms not high enough (wrists below shoulders during open phase) | 3 | 3 | 100.0 | ✅ All 3 | "Reach your arms higher!" |
| T2-07 | Jumping Jacks | Legs not spreading wide enough | 4 | 3 | 75.0 | ✅ 3/3 detected | "Spread your legs wider!" — 1 missed when spread was 1.08× shoulder width (threshold 1.1×) |
| T2-08 | High Knees | Leaning back (torso angle < 140°) | 3 | 3 | 100.0 | ✅ All 3 | "Stay upright!" |
| T2-09 | Plank to Downward Dog | Plank sag (hips below shoulders + 30px) | 3 | 3 | 100.0 | ✅ All 3 | "Tighten your core!" |
| T2-10 | Plank to Downward Dog | Uneven shoulders (diff > 25px) | 4 | 4 | 100.0 | ✅ All 4 | "Level your shoulders!" |
| T2-11 | Push-Ups | Hip pike (hips too high) | 3 | 2 | 66.7 | ✅ 2/2 detected | "Lower your hips!" — 1 missed when hip elevation was only 28px above shoulder |
| T2-12 | Squats | Leg asymmetry (knee angle diff > 20°) | 5 | 4 | 80.0 | ✅ 4/4 detected | "Balance both legs!" — 1 missed at 17° difference |
| T2-13 | High Knees | Low knees + Leaning back (combined) | 4 | 3 | 75.0 | ✅ 3/3 detected | Both "Lift your knees higher!" and "Stay upright!" triggered simultaneously |
| T2-14 | Push-Ups | Hip sag + Arm asymmetry (combined) | 3 | 3 | 100.0 | ✅ All 3 | Both "Keep your hips up!" and "Keep both arms even!" triggered |
| T2-15 | Squats | Knee valgus + Forward lean (combined) | 4 | 3 | 75.0 | ✅ 3/3 detected | "Push your knees out!" and "Keep your chest up!" — 1 forward lean was marginal |
| T2-16 | Jumping Jacks | Arms low + Legs narrow (combined) | 3 | 3 | 100.0 | ✅ All 3 | Both feedback messages triggered |
| T2-17 | Push-Ups | Hip sag (intentional throughout set) | 5 | 5 | 100.0 | ✅ All 5 | Consistent detection across entire set |
| T2-18 | Squats | Knee valgus (progressive worsening) | 5 | 4 | 80.0 | ✅ 4/4 detected | 1st rep was marginal (knees at 82% of ankle gap) |
| T2-19 | High Knees | Low knees (fast cadence) | 6 | 4 | 66.7 | ✅ 4/4 detected | 2 missed at very fast cadence — detection window too short |
| T2-20 | Plank to Downward Dog | Plank sag + Uneven shoulders | 3 | 3 | 100.0 | ✅ All 3 | Both "Tighten your core!" and "Level your shoulders!" |

### Summary Statistics — Wrong Pose Detection
| Metric | Value |
|--------|-------|
| Total Test Cases | 20 |
| Total Wrong Poses Performed | 77 |
| Total Wrong Poses Detected | 65 |
| Overall Detection Rate | 84.4% |
| Feedback Accuracy (when detected) | 100% (65/65) |
| Best Detection Rate | 100% (10 tests) |
| Worst Detection Rate | 60.0% (T2-02) |
| Most Reliable Detection | Hip sag, Knee valgus, Plank sag, Arms low |
| Least Reliable Detection | Low knees at fast cadence, Marginal forward lean |

### Root Cause Analysis — Missed Detections
| Reason | Occurrences | Affected Exercises |
|--------|-------------|-------------------|
| Value below detection threshold (borderline) | 5 | Push-Ups (arm asymmetry), Squats (forward lean, leg asymmetry), Jumping Jacks (leg spread) |
| Fast cadence reducing detection window | 4 | High Knees (low knees at high speed) |
| Marginal elevation difference | 2 | Push-Ups (hip pike), High Knees (borderline knee height) |
| Combined faults masking individual | 1 | Squats (forward lean masked by dominant knee valgus) |

---

## Section 3: Injury Risk Prediction via Accumulated Form Degradation

This section evaluates the system's ability to escalate injury risk scores as a user accumulates more wrong poses across consecutive sets. The test simulates a realistic workout session where fatigue causes progressive form breakdown.

### Testing Methodology
- **Scenario:** User performs multiple consecutive sets of the same exercise
- **Progressive Degradation:** Each subsequent set contains more form errors than the previous
- **Metrics Tracked:** Form Quality Score (per set), Muscle Asymmetry Score, Cumulative Wrong Poses, and the system's Risk Classification output
- **Risk Model Input:** The accumulated biomechanical data (form scores, asymmetry, training intensity) is fed into the `/predict-injury-risk` endpoint after each set

### Test Results

| Test # | Exercise | Set # | Total Reps | Wrong Poses in Set | Cumulative Wrong Poses | Avg Form Score | Muscle Asymmetry (°) | Training Intensity | Risk Classification | Risk Probability |
|--------|----------|-------|------------|-------------------|----------------------|----------------|----------------------|-------------------|-------------------|-----------------|
| T3-01 | Push-Ups | Set 1 | 15 | 0 | 0 | 98.5 | 2.1 | 3.2 | Low Risk | 0.12 |
| T3-02 | Push-Ups | Set 2 | 15 | 1 (hip sag) | 1 | 91.0 | 3.5 | 4.1 | Low Risk | 0.22 |
| T3-03 | Push-Ups | Set 3 | 12 | 3 (hip sag ×2, arm asymmetry) | 4 | 72.3 | 8.4 | 5.8 | Low Risk | 0.41 |
| T3-04 | Push-Ups | Set 4 | 10 | 5 (hip sag ×3, arm asymmetry ×2) | 9 | 58.0 | 14.2 | 7.3 | High Risk | 0.68 |
| T3-05 | Push-Ups | Set 5 | 8 | 6 (hip sag ×4, arm asymmetry ×2) | 15 | 42.5 | 18.7 | 8.9 | High Risk | 0.87 |
| T3-06 | Squats | Set 1 | 15 | 0 | 0 | 97.0 | 1.8 | 3.5 | Low Risk | 0.14 |
| T3-07 | Squats | Set 2 | 15 | 1 (forward lean) | 1 | 88.5 | 2.9 | 4.4 | Low Risk | 0.25 |
| T3-08 | Squats | Set 3 | 13 | 3 (knee valgus ×2, forward lean) | 4 | 68.0 | 9.1 | 6.2 | Low Risk | 0.44 |
| T3-09 | Squats | Set 4 | 10 | 5 (knee valgus ×3, forward lean, leg asymmetry) | 9 | 52.0 | 15.8 | 7.8 | High Risk | 0.73 |
| T3-10 | Squats | Set 5 | 7 | 6 (knee valgus ×4, forward lean, leg asymmetry) | 15 | 38.0 | 19.2 | 9.1 | High Risk | 0.91 |
| T3-11 | High Knees | Set 1 | 20 | 0 | 0 | 96.0 | 1.5 | 3.0 | Low Risk | 0.10 |
| T3-12 | High Knees | Set 2 | 18 | 2 (low knees) | 2 | 85.0 | 3.2 | 4.8 | Low Risk | 0.28 |
| T3-13 | High Knees | Set 3 | 15 | 4 (low knees ×3, leaning back) | 6 | 65.0 | 7.5 | 6.5 | Low Risk | 0.47 |
| T3-14 | High Knees | Set 4 | 12 | 6 (low knees ×4, leaning back ×2) | 12 | 48.0 | 12.3 | 8.0 | High Risk | 0.72 |
| T3-15 | High Knees | Set 5 | 8 | 7 (low knees ×5, leaning back ×2) | 19 | 35.0 | 16.8 | 9.4 | High Risk | 0.89 |
| T3-16 | Jumping Jacks | Set 1 | 20 | 0 | 0 | 99.0 | 1.2 | 2.8 | Low Risk | 0.08 |
| T3-17 | Jumping Jacks | Set 2 | 20 | 1 (arms low) | 1 | 92.0 | 2.0 | 3.9 | Low Risk | 0.18 |
| T3-18 | Jumping Jacks | Set 3 | 18 | 3 (arms low ×2, legs narrow) | 4 | 75.0 | 5.5 | 5.5 | Low Risk | 0.38 |
| T3-19 | Jumping Jacks | Set 4 | 14 | 5 (arms low ×3, legs narrow ×2) | 9 | 55.0 | 10.8 | 7.2 | High Risk | 0.65 |
| T3-20 | Jumping Jacks | Set 5 | 10 | 7 (arms low ×4, legs narrow ×3) | 16 | 40.0 | 15.5 | 8.8 | High Risk | 0.85 |

### Summary Statistics — Injury Risk Prediction
| Metric | Value |
|--------|-------|
| Total Test Cases | 20 |
| Total Sets Tested | 20 (5 sets × 4 exercises) |
| Low Risk Classifications | 12 (Sets 1–3 of each exercise) |
| High Risk Classifications | 8 (Sets 4–5 of each exercise) |
| Risk Escalation Correlation | Strong positive — Risk probability increases with cumulative wrong poses |
| Average Risk Probability (Set 1) | 0.11 |
| Average Risk Probability (Set 3) | 0.43 |
| Average Risk Probability (Set 5) | 0.88 |
| Threshold for High Risk Trigger | ~0.55 probability (typically reached at Set 4) |

### Risk Escalation Pattern (Cross-Exercise Composite)

| Set Number | Avg Cumulative Wrong Poses | Avg Form Score | Avg Asymmetry (°) | Avg Risk Probability | Classification |
|------------|---------------------------|----------------|-------------------|---------------------|----------------|
| Set 1 | 0.0 | 97.6 | 1.65 | 0.11 | Low Risk |
| Set 2 | 1.25 | 89.1 | 2.90 | 0.23 | Low Risk |
| Set 3 | 4.5 | 70.1 | 7.63 | 0.43 | Low Risk |
| Set 4 | 9.75 | 53.3 | 13.28 | 0.70 | **High Risk** |
| Set 5 | 16.25 | 38.9 | 17.55 | 0.88 | **High Risk** |

### Key Observations
1. **Progressive Degradation Pattern:** Form quality degrades consistently across all exercises as sets increase, confirming that fatigue is the primary driver of form breakdown.
2. **Risk Threshold:** The system transitions from "Low Risk" to "High Risk" reliably between Set 3 and Set 4, when cumulative wrong poses exceed ~8 and form score drops below ~55.
3. **Asymmetry Correlation:** Muscle asymmetry shows the strongest correlation with risk classification. Users with asymmetry scores exceeding 12° were invariably classified as High Risk.
4. **Adaptive Response:** When High Risk was triggered at Set 4, the system recommended extending rest periods and reducing target reps for Set 5, demonstrating the closed-loop feedback mechanism.

---

## Consolidated Test Summary

| Subsystem | Total Tests | Key Metric | Result |
|-----------|------------|------------|--------|
| Exercise Detection & Rep Counting | 20 | Overall Rep Accuracy | **94.0%** |
| Exercise Identification | 20 | Identification Accuracy | **100%** |
| Wrong Pose Detection | 20 | Detection Rate | **84.4%** |
| Real-Time Feedback | 20 | Feedback Accuracy (when detected) | **100%** |
| Injury Risk Prediction | 20 | Risk Escalation Correlation | **Strong Positive** |

---

*Testing conducted on May 2026 — FitForge AI Research Team*
