# Zero-Interaction Fitness Tracking Using Computer Vision and Pose Detection

This document provides a comprehensive technical overview of the "Zero-Interaction Fitness Tracking" component. It explains how device cameras and machine learning (specifically Google ML Kit Pose Detection) are combined with biomechanical body angle calculations to automatically detect exercises, count repetitions, and record workout metrics without requiring manual user intervention.

This document focuses exclusively on the frontend (Flutter/Dart) implementation and the on-device computer vision logic, ignoring backend processing (.py files).

---

## 1. Introduction & The Problem Solved

Traditional fitness applications often interrupt the user's flow, requiring them to constantly interact with their mobile device to start sets, log repetitions, or switch exercises. This constant context-switching degrades the workout experience. 

**The Problem Solved:** Our zero-interaction fitness tracking module eliminates this friction. By allowing users to freely do their workout without thinking about how the mobile app is functioning, we build inherent **trust** between the user and the application. The system acts as an invisible, reliable digital personal trainer.

By leveraging the device's native camera and on-device machine learning, the system analyzes the user's skeletal movements in real time. It autonomously identifies exercise states, counts repetitions based on strict biomechanical rules, estimates calories burned, and logs completed sets and rest times.

### Key Benefits of Zero-Interaction
The primary advantage of this component is its completely **hands-free** operation, which fundamentally shifts how users interact with fitness technology:
- **No Manual Start/Stop for Exercises:** The system automatically detects when an exercise motion begins and ends.
- **No Manual Set Tracking:** It seamlessly transitions between active sets and rest periods without requiring the user to press a "finish set" or "start rest" button.
- **No Manual Exercise Selection:** The AI identifies the specific exercise being performed based on posture and movement patterns.
- **Cognitive Offloading:** Users no longer need to keep a mental count of their repetitions.
- **Unbroken Focus & Trust:** Because the user doesn't need to babysit the application, they can trust the app to do the heavy lifting of tracking. They can focus entirely on their physical form, breathing, and momentum.

## 2. Real-Time Camera Feed and Image Processing

The foundation of the tracking component is a continuous, high-performance camera stream.

### Camera Initialization
The system utilizes the Flutter `camera` package to access the device's camera. The feed is configured with a medium resolution preset to balance processing speed and image clarity.
To optimize for real-time analysis, the image stream is processed frame-by-frame. A boolean flag (`isBusy`) ensures that frames are not queued up if the machine learning model is still processing the previous frame, preventing memory leaks and UI lag.

### Format Translation
Machine learning models require specific image formats depending on the underlying operating system. The camera stream dynamically captures frames in:
- **Android:** `NV21` format
- **iOS:** `BGRA8888` format

The raw bytes from the camera's image planes are converted into an `InputImage` object. This process also accounts for the device's physical orientation and sensor rotation, ensuring the machine learning model always receives an upright image for accurate detection.

## 3. Pose Detection Integration (Google ML Kit)

Once the frame is pre-processed, it is passed to the **Google ML Kit Pose Detection** API. 

### Landmark Extraction
The `PoseDetector` operates in a `stream` mode, optimized for continuous video input. It analyzes the `InputImage` and returns a `Pose` object.
Each `Pose` consists of 33 distinct skeletal landmarks (e.g., left shoulder, right elbow, left hip, right ankle). Each landmark provides an $(X, Y)$ coordinate corresponding to its position on the screen.

### Real-Time Visualization
For immediate user feedback, a custom `PosePainter` renders these landmarks directly over the camera preview. It draws interconnected lines between joints (e.g., connecting the shoulder, elbow, and wrist) dynamically mapping the user's skeletal structure in real-time.

## 4. Biomechanical Analysis and Angle Logic

The core logic for zero-interaction tracking relies on calculating the geometric angles between body joints. This ensures that a repetition is only counted when the user achieves the correct form.

### The Angle Calculation Algorithm
The angle between three landmarks (e.g., Shoulder, Elbow, and Wrist to calculate the elbow angle) is determined using Euclidean distance and the **Law of Cosines**:

1. Calculate the distances between the three joints:
   - $a = \text{distance(Elbow, Wrist)}$
   - $b = \text{distance(Shoulder, Elbow)}$
   - $c = \text{distance(Shoulder, Wrist)}$
2. Apply the mathematical formula to find the angle in degrees:
   $$ \text{Angle} = \arccos\left(\frac{b^2 + a^2 - c^2}{2 \cdot b \cdot a}\right) \times \left(\frac{180}{\pi}\right) $$

## 5. Exercise Recognition and Repetition Counting

By continuously monitoring specific joint angles and their vertical $(Y)$ coordinates on the screen, the system acts as a digital personal trainer. Below is the exact biomechanical logic used to track specific exercises.

### 5.1. Push-Ups
To ensure a valid push-up, the system tracks the elbows and the torso.
- **Torso Alignment:** Calculates the angle between the Shoulder, Hip, and Knee. The body must maintain a straight plank position (angle between $160^\circ$ and $180^\circ$).
- **Downward Phase:** The user is considered "lowered" when the average angle of both elbows drops below $90^\circ$.
- **Upward Phase (Rep Count):** A repetition is counted when the user pushes back up, extending the elbow angle past $160^\circ$ while still maintaining the straight torso alignment.

### 5.2. Squats
Squat detection focuses on the depth of the hips relative to the knees and the bending of the legs.
- **Joints Tracked:** Hips, Knees, Ankles.
- **Downward Phase (Deep Squat):** The user enters the squatting state when the average knee angle (Hip-Knee-Ankle) drops below $90^\circ$ **AND** the $Y$-coordinate of the hips is greater than the knees (hips drop below knee level visually).
- **Upward Phase (Rep Count):** A repetition is logged when the user stands back up, and the knee angle opens up above $90^\circ$.

### 5.3. Plank to Downward Dog
This complex movement involves tracking the entire body posture in relation to the ground.
- **Plank Detection:** The shoulders and hips must be roughly on the same vertical level ($Y$-difference $< 30$), and the ankles must be significantly lower than the hips.
- **Downward Dog Detection:** The user shifts their weight back; the hips move significantly higher than the shoulders ($Y$-coordinate of hip $<$ shoulder - $50$), and ankles stay lower than hips.
- **Rep Count:** The system waits for the user to reach the Downward Dog pose and counts the repetition when they transition back to the flat Plank pose.

### 5.4. Jumping Jacks
Unlike exercises dependent purely on angles, Jumping Jacks are tracked using dynamic spatial thresholds based on the user's specific body proportions.
- **Proportional Thresholds:** The system calculates the user's shoulder width dynamically to define how far the legs and arms must spread.
- **Outward Phase:** The legs must spread wider than $1.2\times$ the shoulder width, and the wrists must rise above the shoulders (Wrist $Y <$ Hip $Y$ - $0.5\times$ Shoulder Width).
- **Inward Phase (Rep Count):** A repetition is recorded when the arms and legs return to the neutral standing position.

### 5.5. High Knees
High knees require independent tracking for the left and right legs.
- **Elevation Check:** The knee must be physically lifted higher than the hip (Knee $Y <$ Hip $Y$).
- **Angle Check:** The knee angle (Hip-Knee-Ankle) must be less than $120^\circ$.
- **Rep Count:** Lifting and lowering the left knee counts as one motion; the right knee is tracked independently in the exact same manner.

## 6. Workout Metrics, Rest Time, and Persistence

The zero-interaction component goes beyond rep counting by automatically tracking the flow of the entire workout session.

### Rest Time and Session Logging
Once a set is completed, the system utilizes a `WorkoutService` to persist the data seamlessly to a backend database (e.g., Supabase). The system records:
- **Exercise Name & Set Number**
- **Total Reps** completed
- **Date and Timestamp**
- **Actual Rest Time (`actual_rest_time_seconds`)**: This tracks the temporal gap between the end of one set and the beginning of the next, analyzing the user's recovery periods without them having to manually press a stopwatch.

### Workout Intensity Calculation
The system calculates a "Workout Intensity" score (from 1.0 to 10.0) based on biomechanical pacing:
1. **Pace Score:** Calculates the Reps Per Minute (RPM) based on the total reps and the duration of the set.
2. **Heart Rate Integration:** If a heart rate monitor is used or data is inputted post-workout, a heart rate intensity score is generated.
3. **Blended Metric:** The final intensity is an algorithmic blend of the mechanical pacing ($40\%$) and the cardiovascular heart rate load ($60\%$).
