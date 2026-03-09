import pandas as pd
import pickle
import json
import os

# Define a dummy class so pickle can load the object even if the class is missing its methods
# Pickle just needs a class with the same name in the same module path.
# Since it was saved as __main__.FitnessRecommender, we define it here.
class FitnessRecommender:
    def __init__(self, df):
        self.df = df

model_path = r'd:\New folder\RealtimePoseDetectionStarter2025-main\RealtimePoseDetectionStarter2025-main\model\fitness_recommender (1).pkl'
output_path = r'd:\New folder\RealtimePoseDetectionStarter2025-main\RealtimePoseDetectionStarter2025-main\assets\workout_data.json'

try:
    with open(model_path, 'rb') as f:
        recommender = pickle.load(f)
    
    # Extract the dataframe
    if hasattr(recommender, 'df'):
        df = recommender.df
    else:
        # If it's just the dataframe itself or something else
        df = recommender
        
    print(f"Dataframe extracted. Shape: {df.shape}")
    
    # Save to JSON for Flutter
    # Clean up columns we need
    # Based on the notebook, these are the cleaned columns:
    required_cols = ["Name of Exercise", "Target Muscle Group_Cleaned", "Difficulty Level_Cleaned", "Calories_Burned"]
    
    # Let's check if they exist, otherwise use fallback
    existing_cols = [col for col in required_cols if col in df.columns]
    if not existing_cols:
        # Fallback to whatever looks like exercise data
        existing_cols = [col for col in ["Name of Exercise", "Target Muscle Group", "Difficulty Level", "Calories_Burned"] if col in df.columns]
        
    df_clean = df[existing_cols].copy()
    
    json_data = df_clean.to_dict(orient='records')
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    with open(output_path, 'w') as f:
        json.dump(json_data, f, indent=2)
    
    print(f"Data saved to {output_path}")

except Exception as e:
    print(f"Error: {e}")
    # Try one more time assuming it's a different structure or just the DF
    try:
        with open(model_path, 'rb') as f:
            data = pickle.load(f)
        if isinstance(data, pd.DataFrame):
            data.to_json(output_path, orient='records', indent=2)
            print(f"Data saved to {output_path} (direct DF dump)")
    except:
        pass
