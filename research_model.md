# AI and Machine Learning Models

## Overview
The architecture relies on a hybrid approach: deterministic mathematical models running directly on the mobile device for real-time rep counting, and probabilistic machine learning models running on a Python backend for predictive analytics (performance forecasting and injury risk).

## 1. On-Device Vision Model (Google ML Kit)
- **Model Type:** Pre-trained Convolutional Neural Network (BlazePose).
- **Function:** Real-time pose estimation.
- **Output:** 33 continuous skeletal keypoints in 2D space.
- **Advantages:** Runs entirely locally, requiring no internet connection for the core tracking functionality, ensuring absolute privacy and zero-latency inference.

## 2. Deterministic Biomechanical Models (App Logic)
Instead of training neural networks to classify "is this a push-up?", the system uses mathematical state machines.
- **Law of Cosines:** Calculates dynamic joint angles.
- **Threshold Triggers:** E.g., a push-up rep is counted specifically when the elbow angle drops below 90° (downward phase) and then extends beyond 160° (upward phase) while torso alignment remains between 160°-180°.

## 3. Simple Performance Prediction Model
- **Model Type:** Random Forest Classifier / Scikit-Learn (`performance_prediction_model.pkl`).
- **Input Features:** 12 numeric features including encoded exercise type, sets, reps, average rest per rep, and time of year.
- **Function:** Classifies expected performance into binary outcomes ("Good" vs "Average") to provide baseline estimations for the user's current capabilities.

## 4. Advanced Sequence Forecasting (LSTM Model)
- **Model Type:** Long Short-Term Memory (LSTM) Neural Network built with TensorFlow/Keras (`performance_lstm_model.h5`).
- **Function:** Analyzes sequential set data (e.g., the last 3 to 5 sets of an exercise) to understand fatigue degradation and temporal pacing.
- **Input:** Scaled arrays of historical volume and rest periods.

## 5. Injury Risk Classification Model
- **Model Type:** Scikit-Learn Classifier (`injury_risk_model.pkl`).
- **Input Features:** User biomechanical imbalances, historical workout intensity, BMI, and age.
- **Function:** Flags users as "High Risk" or "Low Risk" based on aggregated long-term physiological strain.
