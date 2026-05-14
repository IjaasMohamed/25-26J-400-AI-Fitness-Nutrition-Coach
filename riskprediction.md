# Injury Risk Prediction & AI Safety Advisor

This document details the advanced predictive analytics and AI-driven safety features integrated into the FitForge AI system. The goal of this component is to move beyond simple tracking and provide proactive health insights using machine learning and Large Language Models (LLMs).

---

## 1. Component Overview: Injury Risk Dashboard

The **Injury Risk Dashboard** is a centralized hub where users can monitor their physiological and biomechanical safety. It automatically aggregates data from several sources to generate a holistic risk profile.

### Key Data Inputs
The system analyzes 12 critical biometric and training metrics:
1.  **Demographics:** Age, Gender.
2.  **Physiology:** Height, Weight, BMI (Body Mass Index).
3.  **Training Load:** Frequency (sessions per week), Duration (average minutes per session), Intensity (mechanical & cardiovascular load).
4.  **Biomechanics:** Muscle Asymmetry (calculated from left/right joint angle imbalances).
5.  **History:** Previous injury count and recovery history.
6.  **Preparation:** Warmup time and flexibility scores.

---

## 2. Machine Learning Prediction Model

The backend utilizes an **XGBoost (Extreme Gradient Boosting)** model to process the 12 input metrics and predict the likelihood of an injury occurring in the next 30 days.

-   **Risk Categorization:** Predictions are categorized into High, Moderate, and Low risk levels.
-   **Probability Scoring:** Users receive a percentage-based confidence score for the prediction.
-   **Feature Importance:** The system identifies which specific factors (e.g., high training intensity or significant muscle asymmetry) are contributing most to the risk level.

---

## 3. AI Safety Advisor (Powered by Grok)

Once a risk is detected, the system integrates **Grok AI** to provide immediate, actionable feedback. This shifts the application from a "data logger" to an "intelligent coach."

### 3.1. Automatic Feedback Suggestions
When a user opens their dashboard, the system automatically sends their unique risk profile to Grok. The AI then generates:
-   **Personalized Warnings:** Context-aware explanations of why their current training load might be dangerous.
-   **Immediate Actions:** Specific steps to take (e.g., "Reduce squat intensity by 20% for the next 3 sessions").
-   **Exercise Modifications:** Suggestions for safer alternatives based on detected biomechanical imbalances.

### 3.2. Interactive AI Chatbot
The dashboard includes an integrated **Ask AI** feature. This allows users to engage in a natural language conversation about their safety:
-   **Context-Aware:** The chatbot "knows" the user's recent workout history and predicted risk level.
-   **Follow-up Questions:** Users can ask specific questions like "How can I fix my left-side muscle asymmetry?" or "Is it safe for me to do high-intensity sprints today?"
-   **Real-Time Guidance:** Provides immediate biomechanical advice and safety tips.

---

## 4. Technical Architecture

The system follows a proxy-based architecture for security and performance:
1.  **Flutter App:** Collects biometric data and displays the Dashboard.
2.  **Backend (Python):** Proxies requests to the ML models (XGBoost/LSTM) and the Grok API.
3.  **Supabase:** Stores historical exercise sets and user profiles for trend analysis.
4.  **Inference Engine:** The `InjuryRiskApiService` and `GrokSuggestionService` handle all external communication.

---

## 5. User Interface Features

-   **Risk Meter:** A visual gauge (Green to Red) indicating the current safety status.
-   **Insights Cards:** Detailed breakdown of training frequency, duration, and heart rate trends.
-   **AI Suggestion Modal:** A dedicated space for the AI coach's latest safety protocol.
-   **Floating AI Button:** Quick access to the chatbot from anywhere on the dashboard.
