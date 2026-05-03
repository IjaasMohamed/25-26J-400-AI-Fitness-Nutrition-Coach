# Injury Risk Prediction API

This is a FastAPI backend to run the machine learning models predicting injury risk.

## Installation

1. Make sure you have Python 3.9+ installed.
2. Navigate to the `backend` folder via your terminal.
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Folder Structure

- `main.py` - Contains the FastAPI application and endpoints.
- `requirements.txt` - Python dependencies needed.
- `models/` - Sub-directory to place your `.pkl` model files.
  - `injury_risk_model.pkl` must be inside this folder.
  - `injury_risk_feature_order.pkl` must be inside this folder.
  - *(Note: We automatically copied these earlier if they existed in the `model` folder.)*

## Running the API

You can run the FastAPI app via `uvicorn`:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8080
```
*(If `uvicorn` is not recognized on Windows, use `python -m uvicorn main:app --reload --host 0.0.0.0 --port 8080` instead)*

- The API will be available at `http://127.0.0.1:8080`.
- The interactive Swagger UI documentation will be available at `http://127.0.0.1:8080/docs`.

## Flutter Integration Notes

If you are running your Flutter app on an Android Emulator, make sure that `InjuryRiskApiService` uses `http://10.0.2.2:8000` to connect to your local machine.

If you are running the app on a physical device, find your PC's IP address (e.g., `192.168.1.100`) and use `http://192.168.1.100:8000`. 
