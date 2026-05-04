# Injury Risk Prediction & AI Chatbot Integration - Task List

## Component 1: Data Collection & Biomechanical Feature Engineering (Tasks 1–10)

1. Research on sports-injury risk factors and identification of 12 key predictive features (Age, Gender, Height, Weight, BMI, Training Frequency, Training Duration, Warmup Time, Flexibility Score, Muscle Asymmetry, Injury History, Training Intensity).
2. Design of the Supabase `users` table schema to store persistent biometric fields (age, height_cm, weight_kg, bmi, gender, injury_count).
3. Design of the `exercise_sets` table schema to capture per-set metrics (created_at, exercise_date, intensity, heart_rate) for training metric derivation.
4. Development of RiskAssessmentEngine to track real-time left/right joint imbalance using elbow, knee, and shoulder angle differentials.
5. Implementation of max_depth_angle tracking in RiskAssessmentEngine using running-minimum of average knee angles per rep.
6. Implementation of maxImbalanceDegrees tracking by computing the composite mean of bilateral joint angle differences.
7. Development of fetchAndResetMetrics() to atomically return accumulated risk metrics and reset state between repetitions.
8. Integration of RiskAssessmentEngine.updateMetrics() into the real-time pose detection loop for continuous biomechanical sampling.
9. Development of FormAnalyzer for on-device, rule-based form quality scoring using per-exercise biomechanical rules (push-up hip sag, squat knee cave, etc.).
10. Design of FormAnalysisResult data structure to carry per-frame form issues, form score (0–100), and joint angle maps for downstream analysis.

## Component 2: Injury Risk ML Model & Backend API (Tasks 11–20)

11. Dataset acquisition and exploratory data analysis of injury risk training data with 12 feature columns and binary injury outcome label.
12. Training a scikit-learn classification model (Random Forest / Logistic Regression) for binary injury risk prediction (0 = Low Risk, 1 = High Risk).
13. Model evaluation using precision, recall, F1-score, and ROC-AUC on held-out test data to validate prediction reliability.
14. Serialization of the trained injury risk model to `injury_risk_model.pkl` using joblib for deployment portability.
15. Development of the Flask `/predict-injury-risk` endpoint in unified_backend.py with strict 12-feature input schema validation.
16. Implementation of predict_proba() extraction to return calibrated probability scores alongside binary predictions.
17. Construction of the JSON response schema (`prediction`, `risk_label`, `probability`) for standardized frontend consumption.
18. Configuration of Flask-CORS to enable cross-origin requests from the Flutter mobile client to the Python backend.
19. Error handling implementation in the `/predict-injury-risk` endpoint for missing features, invalid types, and model loading failures.
20. End-to-end testing of the injury risk prediction pipeline using test_api.py with synthetic user profiles.

## Component 3: Flutter Data Models & API Service Layer (Tasks 21–30)

21. Development of InjuryRiskRequest data model with 12 typed fields and toJson() serialization matching backend feature naming conventions (Age, Gender, Height_cm, etc.).
22. Development of InjuryRiskResponse data model with fromJson() factory constructor parsing prediction (int), risk_label (String), and probability (double).
23. Development of RiskSuggestion data model with title, description, and priority fields for AI-generated suggestion cards.
24. Development of RiskSuggestionResponse data model with summary, warning, and suggestions list for structured AI advisor output.
25. Implementation of InjuryRiskApiService with HTTP POST to `/predict-injury-risk` including JSON encoding, Content-Type headers, and 10-second timeout.
26. Implementation of response status code handling (200 OK parsing, 400/500 error extraction from `detail` field) in the API service.
27. Development of ApiConfig utility class centralizing server IP, port, and all API endpoint URLs for single-point configuration.
28. Configuration of physical device networking (serverIp constant) to enable mobile-to-desktop Flask communication over local WiFi.
29. Implementation of the request timeout strategy (Duration(seconds: 10)) to prevent UI thread blocking on network failures.
30. Exception wrapping in InjuryRiskApiService to transform network errors, JSON parse failures, and HTTP errors into user-readable messages.

## Component 4: Injury Risk Prediction Screen — Manual Input (Tasks 31–38)

31. Design of InjuryRiskScreen StatefulWidget with Form validation and 10 TextEditingController instances for editable numeric inputs.
32. Implementation of _fetchUserData() to auto-populate form fields from Supabase user profile (age, height, weight, BMI, gender, injury_count).
33. Development of training metric derivation from `exercise_sets` history: computing weekly frequency from unique exercise dates over 30 days.
34. Development of average session duration calculation by grouping sets by exercise_date and computing max-min created_at time spans.
35. Development of average training intensity calculation from historical set intensity values with fallback defaults.
36. Implementation of _submitPrediction() to construct InjuryRiskRequest from form data, call the API, and display results with color-coded risk cards.
37. Implementation of injury_count auto-increment logic: automatically updating Supabase `users.injury_count` when High Risk (prediction == 1) is detected.
38. Design of the prediction result Card widget with conditional red/green coloring, risk label display, and probability percentage bar.

## Component 5: Risk Dashboard Screen — Auto-Calculated (Tasks 39–46)

39. Design of RiskDashboardScreen as a fully automated risk assessment that fetches, computes, and predicts on screen initialization without manual input.
40. Implementation of _fetchAndPredict() orchestrating the complete pipeline: profile fetch → training stats calculation → API prediction → AI suggestions.
41. Development of the dual-fallback Supabase query strategy: primary query with intensity/heart_rate columns, fallback query with basic columns on schema mismatch.
42. Implementation of the glassmorphism-styled risk card widget with dynamic icon (warning/check), gradient borders, and animated probability progress bar.
43. Development of the 2x2 stats grid displaying training frequency (days/wk), average duration (mins), last heart rate (bpm), and average intensity.
44. Implementation of the error state UI with retry button, error icon, and descriptive error message display for failed predictions.
45. Integration of auto-refresh capability via _fetchAndPredict() allowing users to retry the entire prediction pipeline on demand.
46. Design of the informational card explaining risk calculation methodology to build user trust and transparency.

## Component 6: Gemini AI Chatbot Integration — Backend Proxy (Tasks 47–53)

47. Configuration of Google Gemini API credentials (API key, model selection: gemini-2.5-flash-lite) and REST API URL construction in unified_backend.py.
48. Design of the `/risk-suggestions` endpoint prompt engineering: crafting the FitForge AI Safety Advisor system prompt with user metrics context injection.
49. Implementation of structured JSON output enforcement using Gemini's `responseMimeType: "application/json"` generation config parameter.
50. Development of the risk profile context builder transforming raw API features into human-readable metric descriptions for LLM comprehension.
51. Implementation of JSON response parsing with markdown fence stripping, missing-field defaults, and graceful fallback suggestions on parse failure.
52. Design of the `/risk-chat` follow-up endpoint for conversational AI interaction with injected risk profile context and concise response constraints.
53. Implementation of rate-limiting strategy through model tier selection (gemini-2.5-flash-lite) and 30-second backend timeout configuration.

## Component 7: Gemini AI Chatbot Integration — Flutter Frontend (Tasks 54–60)

54. Development of GrokSuggestionService.fetchSuggestions() combining 12 risk metrics + prediction result into a single POST request to `/risk-suggestions`.
55. Development of GrokSuggestionService.sendChatMessage() for follow-up conversations with optional risk_context injection for personalized AI responses.
56. Implementation of the AI Safety Advisor section in RiskDashboardScreen with gradient header, loading spinner, error retry, and suggestion card rendering.
57. Development of priority-based suggestion cards with color-coded indicators (🔴 High / 🟡 Medium / 🟢 Low), priority badges, and detailed descriptions.
58. Implementation of the interactive chat section with scrollable message list, user/AI message bubble styling, and real-time loading state management.
59. Integration of auto-triggered AI suggestions on RiskDashboardScreen: automatically calling _fetchGrokSuggestions() after successful risk prediction completion.
60. Implementation of the AI suggestion card in InjuryRiskScreen (manual input flow) with warning banner, priority-colored suggestion items, and icon-labeled header.
