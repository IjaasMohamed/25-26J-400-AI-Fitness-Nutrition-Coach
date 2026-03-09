
import pickle
import pandas as pd
import os

model_path = r'd:\New folder\RealtimePoseDetectionStarter2025-main\RealtimePoseDetectionStarter2025-main\model\fitness_recommender (1).pkl'

try:
    if not os.path.exists(model_path):
        print(f"Error: Model file not found at {model_path}")
    else:
        with open(model_path, 'rb') as f:
            model = pickle.load(f)
        print(f"Model Type: {type(model)}")
        
        # Check for different model types (sklearn, tree, etc.)
        if hasattr(model, 'feature_names_in_'):
            print(f"Features: {list(model.feature_names_in_)}")
        elif hasattr(model, 'n_features_in_'):
            print(f"Number of features: {model.n_features_in_}")
        
        # If it's a LabelEncoder or similar for targets
        if hasattr(model, 'classes_'):
            print(f"Classes (Targets): {list(model.classes_)}")
            
except Exception as e:
    print(f"Error: {e}")
