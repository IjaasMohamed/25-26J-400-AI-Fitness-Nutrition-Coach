# Dataset Architecture and Data Collection Pipeline

## Overview
The FitForge AI system relies on a multi-tiered data collection architecture. It transitions from raw visual sensor data to processed biomechanical features, and finally to aggregated historical datasets used for training predictive machine learning models. The emphasis is on zero-interaction, fully automated data capture.

## 1. Raw Sensor Input
The primary data source is the device's camera stream (front or rear), configured to capture real-time frames at a medium resolution to ensure a balance between processing latency and clarity.
- **Android:** Captured in `NV21` format.
- **iOS:** Captured in `BGRA8888` format.

## 2. On-Device Biomechanical Feature Extraction
Instead of transmitting raw video frames to a server (which introduces latency and privacy concerns), the system extracts metadata on-device using Google ML Kit Pose Detection. 
- Each frame yields a `Pose` object comprising **33 2D skeletal landmarks** (e.g., shoulders, elbows, wrists, hips, knees, ankles).
- Each landmark provides an $(X, Y)$ spatial coordinate.

## 3. Real-Time Calculated Features
Using the Law of Cosines, the system continuously converts the spatial $(X, Y)$ coordinates into meaningful biomechanical angles and distances:
- **Joint Angles:** Elbow extension, knee flexion, hip alignment.
- **Temporal Metrics:** `time_since_last_rep`, `actual_rest_time_seconds`.
- **Form Metrics:** `max_depth_angle` and `left_right_imbalance_degrees`.

## 4. Persistent Database Schema (Supabase)
The structured data is aggregated into a relational schema hosted on Supabase, establishing the long-term dataset for machine learning:
1. **workout_schedules**: Stores intended workout volume (Target Sets, Target Reps).
2. **exercise_sets**: The parent record containing set-level summaries (`total_reps`, `actual_rest_time_seconds`, `heart_rate`).
3. **exercise_reps**: High-granularity table storing the exact biomechanical state of every individual repetition, including asymmetry and pacing.

## 5. Machine Learning Feature Sets
For the Python-based predictive models (Risk and Performance), the structured database is transformed into specific feature arrays.
- **Performance Dataset:** Includes features such as `Sets`, `Total_Reps`, `Time_Mins`, `Rest_Between_Sets_Secs`, `Avg_Rest_Per_Rep_Secs`.
- **Injury Risk Dataset:** Includes physiological baseline data mixed with training metrics: `Age`, `Gender`, `Height_cm`, `Weight_kg`, `BMI`, `Muscle_Asymmetry`, `Training_Intensity`, etc.
