# Real-Time Form Feedback (Proposed)

## Overview
To effectively function as a digital personal trainer, the system must close the loop between detecting an error (Wrong Pose Detection) and correcting the user. The proposed Real-Time Form Feedback system aims to deliver immediate, actionable corrections without requiring the user to break their concentration or look closely at the device screen.

## 1. The Coaching Feedback Loop
The goal is to correct biomechanical faults *while* the user is performing the set, preventing the cementing of bad habits and protecting against acute injury. Feedback must be instantaneous and cognitively lightweight.

## 2. Proposed Mechanisms of Feedback

### A. Dynamic Audio Cues (Primary)
Because users often cannot look at their phone while exercising (e.g., facing the floor during push-ups), audio is the most effective feedback channel.
- **Technology:** Integration with `flutter_tts` (Text-to-Speech).
- **Trigger Logic:** When the `FormAnalyzer` detects a fault spanning across multiple consecutive frames (to prevent jitter/false positives), an interruptive audio cue is played.
- **Examples:** 
  - *"Keep your back straight."* (If hip sag is detected).
  - *"Push your knees outward."* (If knee valgus is detected).
  - *"Go lower."* (If squat depth is insufficient).

### B. Visual Skeletal Augmentation
For exercises where the screen is visible, visual overlays provide immediate spatial correction.
- **Technology:** Enhancing the custom `PosePainter` canvas in Flutter.
- **Trigger Logic:** 
  - Standard landmarks and connecting lines are drawn in a neutral color (e.g., white or green).
  - If a specific joint alignment violates safety thresholds, the specific limb segments involved will turn **red** on the screen.
  - Directional arrows could be dynamically rendered to show the user how to adjust their posture (e.g., an upward arrow on the hips during a sagging push-up).

## 3. Phased Implementation Strategy
1. **Rule Definition:** Hardcoding the mathematical thresholds for acceptable vs. unacceptable form for core exercises.
2. **Debouncing Logic:** Ensuring that a single bad frame does not trigger a cascade of annoying voice prompts. The error must persist for $N$ milliseconds.
3. **Priority Queuing:** If multiple faults occur simultaneously (e.g., bad depth AND caving knees), the system must prioritize the cue that addresses the highest risk of acute injury.
