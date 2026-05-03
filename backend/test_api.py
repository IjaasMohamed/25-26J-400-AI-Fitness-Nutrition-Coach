import requests
import json

def test_prediction():
    url = "http://localhost:5000/predict"
    data = {
        "name": "Hasintha",
        "exercise": "Push Ups",
        "sets": 3,
        "total_reps": 54,
        "time_mins": 5.2,
        "rest_between_sets_secs": 60,
        "avg_rest_per_rep_secs": 1.11,
        "day": 10,
        "month": 3,
        "avg_reps": 18.0,
        "max_reps": 20,
        "min_reps": 16
    }
    
    try:
        response = requests.post(url, json=data)
        if response.statusCode == 200:
            print("Success!")
            print(json.dumps(response.json(), indent=4))
        else:
            print(f"Error {response.status_code}: {response.text}")
    except Exception as e:
        print(f"Failed to connect: {e}")

if __name__ == "__main__":
    print("Ensure the Flask API is running before executing this test.")
    # test_prediction() # Uncomment to run if needed
