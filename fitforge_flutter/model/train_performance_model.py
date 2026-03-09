import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, accuracy_score
import joblib

# 1. Load the data
df = pd.read_csv('model/colected_dataset.csv')

# 2. Preprocessing
# Encode categorical variables
le_exercise = LabelEncoder()
df['Exercise_Encoded'] = le_exercise.fit_transform(df['Exercise'])

le_performance = LabelEncoder()
df['Performance_Encoded'] = le_performance.fit_transform(df['Performance'])

# Handle Reps_Per_Set (extract max, min, and variance to capture fatigue)
def process_reps(rep_str):
    try:
        reps = [int(r.strip()) for r in str(rep_str).replace('"', '').split(',')]
        return pd.Series([max(reps), min(reps), np.std(reps)])
    except:
        return pd.Series([0, 0, 0])

df[['Max_Reps', 'Min_Reps', 'Rep_Variance']] = df['Reps_Per_Set'].apply(process_reps)

# Features: Sets, Total_Reps, Time_Mins, Rest_Between_Sets_Secs, Avg_Rest_Per_Rep_Secs, Exercise_Encoded, Max_Reps, Min_Reps, Rep_Variance
features = ['Sets', 'Total_Reps', 'Time_Mins', 'Rest_Between_Sets_Secs', 'Avg_Rest_Per_Rep_Secs', 'Exercise_Encoded', 'Max_Reps', 'Min_Reps', 'Rep_Variance']
X = df[features]
y = df['Performance_Encoded']

# 3. Split data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# 4. Train Model
model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# 5. Evaluate
y_pred = model.predict(X_test)
print(f"Accuracy: {accuracy_score(y_test, y_pred)}")
print(classification_report(y_test, y_pred, target_names=le_performance.classes_))

# 6. Export for Mobile/Logic
# We can export as .pkl, but for a Flutter app, we'll extract the core logic or export as TFLite if needed.
# For now, let's save the encoders and model.
joblib.dump(model, 'performance_model.pkl')
joblib.dump(le_exercise, 'exercise_encoder.pkl')
joblib.dump(le_performance, 'performance_encoder.pkl')

print("Model training complete. Files saved: performance_model.pkl, exercise_encoder.pkl, performance_encoder.pkl")
