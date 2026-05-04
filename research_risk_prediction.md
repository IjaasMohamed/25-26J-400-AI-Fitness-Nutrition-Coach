# Injury Risk Prediction System

## Overview
Preventing injury is paramount in autonomous fitness coaching. The Injury Risk Prediction component aggregates both physiological user data and biomechanical tracking metrics to quantify the probability of musculoskeletal strain. 

## 1. Data Dimensions
The risk prediction relies on combining static user profiles with dynamic, real-time measurements:
- **Static / Historical Traits:** Age, Gender, Height, Weight, BMI, Flexibility Score, Injury History.
- **Dynamic Session Traits:** Training Frequency, Training Duration, Warmup Time.
- **Biomechanical Metrics:** Form degradation derived from the camera, specifically `Muscle_Asymmetry` (e.g., uneven pushing in push-ups) and `Training_Intensity`.

## 2. Model Implementation
The backend exposes an API endpoint (`/predict-injury-risk`) serviced by a Scikit-Learn machine learning model (`injury_risk_model.pkl`).
- The model ingests a 12-dimensional feature vector.
- It calculates the multi-dimensional correlation between fatigue, physical characteristics, and form breakdown.

## 3. Output and Interpretation
The system returns a binary classification:
- **Low Risk:** The user is operating within safe physiological boundaries.
- **High Risk:** The combination of factors indicates an elevated chance of injury. 

## 4. Integration into Coaching Flow
When a user is flagged as "High Risk," the system can automatically adjust subsequent workout schedules. It might mandate longer rest periods, decrease target repetition volumes, or suggest mobility and flexibility exercises instead of heavy resistance training. This predictive capability transforms the application from a passive tracker into a proactive safety mechanism.
