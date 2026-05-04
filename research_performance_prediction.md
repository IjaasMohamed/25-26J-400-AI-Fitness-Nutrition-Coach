# Performance and Fatigue Prediction

## Overview
The Performance Prediction module acts as the brain behind the app's adaptive scheduling. By analyzing a user's recent workout history, repetition cadence, and rest times, the system forecasts whether the user will struggle or excel in their upcoming sets.

## 1. Predictive Architectures
The system utilizes two distinct methodologies exposed via a Python Flask backend:

### A. Standard Feature-Based Prediction
Uses a Random Forest algorithm (`performance_prediction_model.pkl`) to evaluate the user's general capability based on aggregated session metadata.
- **Inputs:** Encoded exercise type, current set number, total time, average rest per rep, and min/max reps achieved historically.
- **Outcome:** A baseline "Good" or "Average" capability score.

### B. Sequential Deep Learning (LSTM)
Because fatigue accumulates non-linearly over multiple sets, a Long Short-Term Memory (LSTM) network (`performance_lstm_model.h5`) processes time-series data.
- It examines the last 3 to 5 sets of a given exercise.
- It recognizes patterns of degradation (e.g., resting longer but achieving fewer reps).
- **Rule-Based Heuristics:** The backend also applies domain-knowledge mathematics to the LSTM output, analyzing Volume Influence, Trend Progression (rep delta), and Rest Influence to establish a probabilistic performance score.

## 2. Adaptive Scheduling
The outputs from these predictive models are directly utilized to alter the user's routine dynamically:
- **Volume Adjustments:** If the model predicts failure with high probability, the target repetitions for the next set are autonomously reduced.
- **Rest Period Modulation:** If fatigue indicators are high (e.g., `avg_rest_per_rep_secs` is increasing rapidly), the `RestTimerScreen` will automatically inject longer recovery intervals.
- **Insight Generation:** The API returns actionable coaching tips (e.g., "Keep up the steady pace!") and trend directions (e.g., "Improving" vs "Stable") to encourage the user.
