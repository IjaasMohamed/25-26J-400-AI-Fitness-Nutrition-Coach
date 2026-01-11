# FitForge AI: AI-Powered Personalized Gym Assistant

Repository Link : https://github.com/IjaasMohamed/25-26J-400-AI-Fitness-Nutrition-Coach/tree/main

## Project Overview

**FitForge AI** is a smart fitness coaching system designed to turn any smartphone into a personal trainer. It addresses the limitations of traditional fitness apps by providing a fully automated, hands-free, and adaptive workout experience.

Unlike standard apps that rely on manual input and generic templates, FitForge AI uses computer vision and predictive analytics to autonomously track exercises, analyze form in real-time, and generate dynamic workout schedules based on user performance and recovery needs.

---

## Problem Statement

Current fitness solutions often fail because they rely on manual input (which is impractical during exercise), provide "one-size-fits-all" schedules that don't adapt to the user, and lack real-time feedback on exercise technique. This leads to ineffective workouts and increased injury risk.

* **Manual Distractions:** Traditional apps require users to manually input data (reps/sets) or use touch controls, which breaks focus and is impractical during intense exercise.
* **Lack of Guidance:** Novice users often suffer from injuries due to incorrect form, with no real-time feedback available outside of expensive personal trainers.
* **Generic Planning:** Most apps provide static schedules that fail to adapt to individual recovery rates and performance fluctuations.
* **Device Dependency:** Advanced tracking often requires expensive specialized hardware or wearables.

---

## Key Features

### 1. Zero-Interaction Fitness Tracking
A truly hands-free experience that allows users to focus solely on their workout.
* **Automated Recognition:** Uses computer vision (YOLOv11) to autonomously detect exercise start and end times.
* **Smart Counting:** Automatically tracks sets and repetitions without manual input.
* **Flow Management:** Automatically calculates and manages rest periods between sets.

### 2. Real-Time Biomechanical Form Analysis
Functions as a vigilant spotter to ensure safety and effectiveness.
* **Skeletal Tracking:** Tracks 33 body keypoints at over 30 FPS using on-device processing.
* **Angle Calculation:** Measures critical joint angles (knees, elbows, spine) with high accuracy (±5 degrees) to detect deviations.
* **Instant Feedback:** Provides visual and audio corrective cues within 100ms of detecting an error to prevent injury.

### 3. Intelligent Workout Forecasting
Replaces static templates with dynamic, AI-driven planning.
* **Adaptive Scheduling:** Generates personalized workout plans that evolve based on historical performance and body data.
* **Image-Based Analysis:** Analyzes body composition via smartphone images to tailor fitness plans.
* **Progressive Overload:** Forecasts future workout needs to ensure consistent progress.

### 4. Predictive Health Analytics
Proactive insights to manage long-term health and performance.
* **Recovery Estimation:** Predicts recovery duration based on heart rate, calorie expenditure, and workload.
* **Risk Detection:** Identifies patterns indicating overtraining or potential injury risks before they occur.
* **Performance Forecasting:** Models future strength and endurance trends to set realistic goals.

---

## System Architecture

The system operates using a hybrid architecture balancing on-device processing for low latency with cloud computing for heavy data analysis.

![alt text](image-3.png)

* **Client Layer:** Native Android App handling User Interface, Sensor Data, and Camera Input.
* **AI Engine Layer:** Contains modules for Form Analysis, Zero-Interaction Tracking, and Predictive Analytics.
* **Cloud Data Layer:** Manages User Profiles, Exercise Databases, and Historical Logs.

---

## 🛠 Technology Stack

### Mobile & Frontend
* **Platform:** Android (Native)
* **IDE:** Android Studio

### AI & Machine Learning
* **Languages:** Python
* **Frameworks:** TensorFlow, PyTorch
* **Vision Engine:** YOLOv11 (Pose Estimation)
* **Algorithms:**
    * Convolutional Neural Networks (CNNs)
    * RNN / LSTM (Time-Series Forecasting)
    * Random Forest / Decision Trees

### Backend & Database
* **Database:** MongoDB
* **Cloud Services:** Google Cloud / AWS
* **Version Control:** GitHub

---

##  Getting Started

1.  **Clone the repository**
    ```bash
    git clone [https://github.com/your-username/fitforge-ai.git](https://github.com/your-username/fitforge-ai.git)
    ```
2.  **Open in Android Studio**
    * File -> Open -> Select project folder.
3.  **Sync Gradle**
    * Ensure all dependencies are installed.
4.  **Run on Device**
    * Connect an Android device with Camera permissions enabled.

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
*Developed by the FitForge AI Research Team - SLIIT Faculty of Computing*