# Wrong Pose Detection System (Proposed)

## Overview
While the current tracking logic accurately counts repetitions when form thresholds are crossed, an advanced "Wrong Pose Detection" module is essential for a comprehensive digital coaching experience. This proposed system will actively identify biomechanical failures and dangerous postures *during* the exercise movement.

## 1. The Need for Error Detection
Relying solely on successful repetition counting ignores bad repetitions. Users may inadvertently perform exercises with improper alignment, which limits muscular engagement and drastically increases the risk of injury. The application must know not just when an exercise is done, but when it is done *incorrectly*.

## 2. Proposed Technical Implementation
The system will build upon the existing `google_mlkit_pose_detection` continuous stream. Alongside the `ExerciseClassifier`, a dedicated `FormAnalyzer` will evaluate frame-by-frame geometries against a dictionary of known postural faults.

### Common Fault Detections:
1. **Push-Ups - Sagging Hips:**
   - **Logic:** Calculate the angle between Shoulder, Hip, and Knee. If the angle dips below $150^\circ$ toward the floor, the torso is not rigid.
2. **Squats - Knee Valgus (Caving In):**
   - **Logic:** Track the horizontal ($X$) distance between the left and right knees compared to the ankles. If the knees move inward significantly past the ankle alignment during the downward phase, it indicates valgus collapse.
3. **Squats - Inadequate Depth:**
   - **Logic:** The hip joint fails to drop below the parallel line of the knee joint before the user returns to a standing position.
4. **General - Asymmetry:**
   - **Logic:** Comparing the extension angle of the left limb versus the right limb. Differences exceeding $15^\circ$ indicate muscle imbalance or overcompensation.

## 3. Data Logging & Impact
When a wrong pose is detected, it will not count toward the target repetitions. Instead, the specific error type and the exact degree of deviation will be logged locally and synced to the `exercise_reps` database. This granular fault data will significantly enrich the Injury Risk Prediction models by providing concrete evidence of form degradation over time.
