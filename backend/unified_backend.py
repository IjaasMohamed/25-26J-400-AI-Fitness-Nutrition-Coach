from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import pandas as pd
import numpy as np
import os
import tensorflow as tf

app = Flask(__name__)
CORS(app)


# --- PATH CONFIGURATION ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, "..", "model")
INJURY_MODELS_DIR = os.path.join(BASE_DIR, "models")

# --- MODEL LOADING (SIMPLE PERFORMANCE) ---
simple_perf_model = None
ex_enc = None
perf_enc = None
try:
    simp_path = os.path.join(MODEL_DIR, "performance_prediction_model (1).pkl")
    if os.path.exists(simp_path):
        simple_perf_model = joblib.load(simp_path)
        ex_enc = joblib.load(os.path.join(BASE_DIR, "..", "exercise_encoder.pkl"))
        perf_enc = joblib.load(os.path.join(BASE_DIR, "..", "performance_encoder.pkl"))
        print("Simple Performance Model loaded.")
except Exception as e:
    print(f"Simple Perf Load Error: {e}")

# --- MODEL LOADING (LSTM PERFORMANCE) ---
lstm_model = None
lstm_name_enc = None
lstm_ex_enc = None
lstm_scaler = None
try:
    lstm_model = tf.keras.models.load_model(os.path.join(MODEL_DIR, "performance_lstm_model.h5"))
    lstm_name_enc = joblib.load(os.path.join(MODEL_DIR, "lstm_name_encoder.pkl"))
    lstm_ex_enc = joblib.load(os.path.join(MODEL_DIR, "lstm_exercise_encoder.pkl"))
    lstm_scaler = joblib.load(os.path.join(MODEL_DIR, "lstm_scaler.pkl"))
    print("LSTM Performance Model loaded.")
except Exception as e:
    print(f"LSTM Perf Load Error: {e}")

# --- MODEL LOADING (INJURY RISK) ---
injury_model = None
try:
    inj_path = os.path.join(BASE_DIR, "..", "injury_risk_model.pkl")
    if os.path.exists(inj_path):
        injury_model = joblib.load(inj_path)
        print("Injury Risk Model loaded from root directory.")
except Exception as e:
    print(f"Injury Risk Load Error: {e}")
# --- ENDPOINT: SIMPLE PERFORMANCE ---
@app.route('/predict', methods=['POST'])
def predict_simple():
    if simple_perf_model is None:
        return jsonify({"error": "Simple Performance Model not loaded"}), 500
    try:
        data = request.get_json()
        ex_name = data.get('exercise', 'Push Ups')
        ex_encoded = ex_enc.transform([ex_name])[0] if ex_enc else 0
        
        feats = {
            'Sets': data.get('sets', 0),
            'Total_Reps': data.get('total_reps', 0),
            'Time_Mins': data.get('time_mins', 0.0),
            'Rest_Between_Sets_Secs': data.get('rest_between_sets_secs', 0.0),
            'Avg_Rest_Per_Rep_Secs': data.get('avg_rest_per_rep_secs', 0.0),
            'Exercise_Encoded': ex_encoded,
            'Day': data.get('day', 1),
            'Month': data.get('month', 1),
            'Avg_Reps': data.get('avg_reps', 0.0),
            'Max_Reps': data.get('max_reps', 0),
            'Min_Reps': data.get('min_reps', 0)
        }
        
        input_df = pd.DataFrame([feats])
        pred_encoded = simple_perf_model.predict(input_df)[0]
        
        prob = 0.88
        if hasattr(simple_perf_model, "predict_proba"):
            proba = simple_perf_model.predict_proba(input_df)[0]
            prob = float(proba[int(pred_encoded)]) if len(proba) > 1 else float(proba[0])

        label = perf_enc.inverse_transform([pred_encoded])[0] if perf_enc else ("Good" if pred_encoded == 1 else "Average")
        
        return jsonify({"prediction": label, "probability": prob})
    except Exception as e:
        return jsonify({"error": str(e)}), 400


# --- ENDPOINT: LSTM PERFORMANCE ---
@app.route('/predict_lstm', methods=['POST'])
def predict_lstm():
    if lstm_model is None:
        return jsonify({"error": "LSTM Model not loaded"}), 500
    try:
        data = request.get_json()
        sessions = data.get('sessions', [])
        if len(sessions) != 3:
            return jsonify({"error": "Exactly 3 sessions required"}), 400

        processed = []
        for s in sessions:
            name_enc = lstm_name_enc.transform([s.get('name', 'Hasintha')])[0] if lstm_name_enc else 0
            ex_enc_val = lstm_ex_enc.transform([s.get('exercise', 'Push Ups')])[0] if lstm_ex_enc else 0
            
            num_feats = {
                'Sets': s.get('sets', 0), 'Total_Reps': s.get('total_reps', 0),
                'Time_Mins': s.get('time_mins', 0.0), 'Rest_Between_Sets_Secs': s.get('rest_between_sets_secs', 0.0),
                'Avg_Rest_Per_Rep_Secs': s.get('avg_rest_per_rep_secs', 0.0), 'Day': s.get('day', 1),
                'Month': s.get('month', 1), 'Avg_Reps': s.get('avg_reps', 0.0),
                'Max_Reps': s.get('max_reps', 0), 'Min_Reps': s.get('min_reps', 0)
            }
            
            # Scaler expects ordered numeric features
            num_df = pd.DataFrame([num_feats])
            if hasattr(lstm_scaler, "feature_names_in_"):
                num_df = num_df[list(lstm_scaler.feature_names_in_)]
            
            scaled = lstm_scaler.transform(num_df)[0]
            processed.append(np.concatenate(([name_enc, ex_enc_val], scaled)))

        lstm_input = np.array([processed])
        prob = lstm_model.predict(lstm_input)[0][0]
        return jsonify({"prediction": "Good" if prob >= 0.5 else "Average", "probability": float(prob)})
    except Exception as e:
        return jsonify({"error": str(e)}), 400


# --- ENDPOINT: INJURY RISK ---
@app.route('/predict-injury-risk', methods=['POST'])
def predict_injury():
    if injury_model is None:
        return jsonify({"error": "Injury Risk Model not loaded"}), 500
    try:
        data = request.get_json()
        
        # Expected feature order exactly as the user specified
        feature_names = [
            "Age", "Gender", "Height_cm", "Weight_kg", "BMI", 
            "Training_Frequency", "Training_Duration", "Warmup_Time", 
            "Flexibility_Score", "Muscle_Asymmetry", "Injury_History", "Training_Intensity"
        ]
        
        # Extract features ensuring they match
        features = [[data.get(feat, 0) for feat in feature_names]]
        input_df = pd.DataFrame(features, columns=feature_names)
        
        prediction = int(injury_model.predict(input_df)[0])
        
        prob = 1.0
        if hasattr(injury_model, "predict_proba"):
            proba = injury_model.predict_proba(input_df)[0]
            prob = float(proba[1]) if len(proba) > 1 else float(proba[0])

        return jsonify({
            "prediction": prediction,
            "risk_label": "High Risk" if prediction == 1 else "Low Risk",
            "probability": prob
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
