from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import pandas as pd
import numpy as np
import os
import tensorflow as tf
import traceback

app = Flask(__name__)
CORS(app)

# Define paths
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, "..", "model")

# Standard Model Artifacts
STD_MODEL_PATH = os.path.join(MODEL_DIR, "performance_prediction_model (1).pkl")
STD_EXERCISE_ENC_PATH = os.path.join(BASE_DIR, "..", "exercise_encoder.pkl")
STD_PERFORMANCE_ENC_PATH = os.path.join(BASE_DIR, "..", "performance_encoder.pkl")

# LSTM Model Artifacts
LSTM_MODEL_PATH = os.path.join(MODEL_DIR, "performance_lstm_model.h5")
LSTM_NAME_ENC_PATH = os.path.join(MODEL_DIR, "lstm_name_encoder.pkl")
LSTM_EXERCISE_ENC_PATH = os.path.join(MODEL_DIR, "lstm_exercise_encoder.pkl")
LSTM_SCALER_PATH = os.path.join(MODEL_DIR, "lstm_scaler.pkl")

# Global Variables for Models
std_model = None
std_exercise_enc = None
std_performance_enc = None
shared_name_enc = None # Re-used by both if possible

lstm_model = None
lstm_exercise_enc = None
lstm_scaler = None
lstm_numeric_features = ['Sets', 'Total_Reps', 'Time_Mins', 'Rest_Between_Sets_Secs', 'Avg_Rest_Per_Rep_Secs', 'Day', 'Month', 'Avg_Reps', 'Max_Reps', 'Min_Reps']

def load_models():
    global std_model, std_exercise_enc, std_performance_enc, shared_name_enc
    global lstm_model, lstm_exercise_enc, lstm_scaler, lstm_numeric_features

    # Load Standard Model
    try:
        if os.path.exists(STD_MODEL_PATH):
            std_model = joblib.load(STD_MODEL_PATH)
            print("Standard Performance Model loaded.")
        if os.path.exists(STD_EXERCISE_ENC_PATH):
            std_exercise_enc = joblib.load(STD_EXERCISE_ENC_PATH)
            print("Standard Exercise Encoder loaded.")
        if os.path.exists(STD_PERFORMANCE_ENC_PATH):
            std_performance_enc = joblib.load(STD_PERFORMANCE_ENC_PATH)
            print("Standard Performance Encoder loaded.")
    except Exception as e:
        print(f"Error loading Standard Model: {e}")

    # Load LSTM Model
    try:
        if os.path.exists(LSTM_MODEL_PATH):
            lstm_model = tf.keras.models.load_model(LSTM_MODEL_PATH)
            print("LSTM performance Model loaded.")
        if os.path.exists(LSTM_EXERCISE_ENC_PATH):
            lstm_exercise_enc = joblib.load(LSTM_EXERCISE_ENC_PATH)
            print("LSTM Exercise Encoder loaded.")
        if os.path.exists(LSTM_SCALER_PATH):
            lstm_scaler = joblib.load(LSTM_SCALER_PATH)
            if hasattr(lstm_scaler, "feature_names_in_"):
                lstm_numeric_features = list(lstm_scaler.feature_names_in_)
            print("LSTM Scaler loaded.")
    except Exception as e:
        print(f"Error loading LSTM Model: {e}")

    # Shared Name Encoder
    try:
        if os.path.exists(LSTM_NAME_ENC_PATH):
            shared_name_enc = joblib.load(LSTM_NAME_ENC_PATH)
            print("Shared Name Encoder loaded.")
    except Exception as e:
        print(f"Error loading Name Encoder: {e}")

load_models()

@app.route('/predict', methods=['POST'])
def predict_std():
    if std_model is None:
        return jsonify({"error": "Standard model not loaded"}), 500
    try:
        data = request.get_json()
        
        # 1. Encoding
        user_name = data.get('name', 'Hasintha')
        if shared_name_enc:
            try:
                name_encoded = shared_name_enc.transform([user_name])[0]
            except ValueError:
                print(f"Standard Prediction: Unseen name '{user_name}', falling back to default.")
                name_encoded = 0
        else:
            name_encoded = 0
        
        exercise_name = data.get('exercise', 'Push Ups')
        if std_exercise_enc:
            try:
                exercise_encoded = std_exercise_enc.transform([exercise_name])[0]
            except ValueError:
                print(f"Standard Prediction: Unseen exercise '{exercise_name}', falling back to default.")
                exercise_encoded = 0
        else:
            exercise_encoded = 0

        # 2. Map features to the 12 columns expected by the model
        # Order and names must match: ['Name', 'Exercise', 'Sets', 'Total_Reps', 'Time_Mins', 
        # 'Rest_Between_Sets_Secs', 'Avg_Rest_Per_Rep_Secs', 'Day', 'Month', 'Avg_Reps', 'Max_Reps', 'Min_Reps']
        features = {
            'Name': name_encoded,
            'Exercise': exercise_encoded,
            'Sets': data.get('sets', 0),
            'Total_Reps': data.get('total_reps', 0),
            'Time_Mins': data.get('time_mins', 0.0),
            'Rest_Between_Sets_Secs': data.get('rest_between_sets_secs', 0.0),
            'Avg_Rest_Per_Rep_Secs': data.get('avg_rest_per_rep_secs', 0.0),
            'Day': data.get('day', 1),
            'Month': data.get('month', 1),
            'Avg_Reps': data.get('avg_reps', 0.0),
            'Max_Reps': data.get('max_reps', 0),
            'Min_Reps': data.get('min_reps', 0)
        }
        
        input_df = pd.DataFrame([features])
        
        # 3. Predict
        prediction_encoded = std_model.predict(input_df)[0]
        
        probability = 0.85
        if hasattr(std_model, "predict_proba"):
            proba = std_model.predict_proba(input_df)[0]
            probability = float(proba[int(prediction_encoded)]) if len(proba) > 1 else float(proba[0])

        if std_performance_enc:
            try:
                prediction_label = std_performance_enc.inverse_transform([prediction_encoded])[0]
            except:
                prediction_label = "Good" if prediction_encoded == 1 else "Average"
        else:
            prediction_label = "Good" if prediction_encoded == 1 else "Average"

        return jsonify({
            "prediction": prediction_label,
            "probability": probability
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 400

@app.route('/predict_lstm', methods=['POST'])
def predict_performance():
    try:
        data = request.get_json()
        sessions = data.get('sessions', []) # These are now actually "Sets"
        count = len(sessions)
        
        if count == 0:
            return jsonify({"error": "No data provided"}), 400

        # Rule-based Forecast Logic (Mathematical Part - 5 Sets)
        s_first = sessions[0]
        s_last = sessions[-1]
        
        first_reps = s_first.get('total_reps', 0)
        last_reps = s_last.get('total_reps', 0)
        rep_delta = last_reps - first_reps
        
        # Calculate a "Performance Score" (0.0 to 1.0)
        base_prob = 0.4 # Default Average
        
        # 1. Volume Influence
        if last_reps >= 40: base_prob += 0.2
        elif last_reps >= 20: base_prob += 0.1
        
        # 2. Trend Influence (Progression)
        if rep_delta > 5: base_prob += 0.2
        elif rep_delta > 0: base_prob += 0.1
        
        # 3. Rest Influence
        last_rest = s_last.get('rest_between_sets_secs', 100)
        if last_rest <= 45: base_prob += 0.15
        
        prob = min(0.95, base_prob)
        print(f"DEBUG: 5-Set Math Forecast ({count} points): {prob}")
        prediction_label = "Good" if prob >= 0.6 else "Average"
        
        # Historical labels for the chart
        historical_labels = []
        for s in sessions:
            r = s.get('total_reps', 0)
            rst = s.get('rest_between_sets_secs', 100)
            if r >= 35 or (r >= 20 and rst <= 60):
                historical_labels.append("Good")
            else:
                historical_labels.append("Average")

        # Basic Stats
        volume_history = [s.get('total_reps', 0) for s in sessions]
        
        return jsonify({
            "prediction": prediction_label,
            "probability": float(prob),
            "trend": "Improving" if rep_delta > 0 else "Stable",
            "volume_history": volume_history,
            "consistency_score": 90.0, # Static for now
            "coaching_tips": ["Keep up the steady pace!"],
            "historical_labels": historical_labels
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 400

# Keep the original route name for compatibility
@app.route('/predict_lstm', methods=['POST'])
def predict_lstm_compat():
    return predict_performance()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
