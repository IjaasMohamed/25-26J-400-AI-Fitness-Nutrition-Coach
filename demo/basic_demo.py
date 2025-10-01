"""
Basic Demo: Real-Time Squat Form Analysis
Shows pose detection, angle calculation, and form feedback.
"""

import cv2
import sys
import os

# Add src to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.pose_detector import PoseDetector
from src.exercise_analyzer import SquatAnalyzer

def main():
    print("="*60)
    print("Real-Time Biomechanical Exercise Form Analysis - DEMO")
    print("Exercise: Squats")
    print("="*60)
    print("
Controls:")
    print("  'q' - Quit")
    print("  'r' - Reset rep count")
    print("
Starting camera...
")
    
    # Initialize components
    detector = PoseDetector(model_complexity=1)
    analyzer = SquatAnalyzer()
    
    # Open webcam
    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
    cap.set(cv2.CAP_PROP_FPS, 30)
    
    if not cap.isOpened():
        print("ERROR: Cannot open camera")
        return
    
    while True:
        ret, frame = cap.read()
        if not ret:
            print("ERROR: Failed to grab frame")
            break
        
        # Flip frame horizontally for mirror view
        frame = cv2.flip(frame, 1)
        
        # Detect pose
        frame, detected = detector.detect(frame, draw=True)
        
        if detected:
            # Get landmarks
            landmarks = detector.get_all_landmarks(frame.shape)
            
            # Analyze form
            analysis = analyzer.analyze_frame(landmarks)
            
            if analysis['status'] == 'analyzed':
                # Display angles on frame
                angles = analysis['angles']
                y_offset = 30
                
                cv2.putText(frame, f"Rep Count: {analysis['rep_count']}", 
                           (10, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                           1, (0, 255, 0), 2)
                y_offset += 40
                
                cv2.putText(frame, f"State: {analysis['current_state']}", 
                           (10, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                           0.7, (255, 255, 255), 2)
                y_offset += 35
                
                # Display key angles
                if 'right_knee' in angles:
                    cv2.putText(frame, f"Knee Angle: {angles['right_knee']:.1f}deg", 
                               (10, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                               0.6, (255, 255, 0), 2)
                    y_offset += 30
                
                if 'right_hip' in angles:
                    cv2.putText(frame, f"Hip Angle: {angles['right_hip']:.1f}deg", 
                               (10, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                               0.6, (255, 255, 0), 2)
                    y_offset += 30
                
                # Display form evaluation
                form_eval = analysis['form_evaluation']
                score_color = (0, 255, 0) if form_eval['score'] >= 80 else (0, 165, 255)
                
                cv2.putText(frame, f"Form Score: {form_eval['score']}/100", 
                           (10, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                           0.7, score_color, 2)
                y_offset += 40
                
                # Display form errors
                if form_eval['errors']:
                    cv2.putText(frame, "Form Issues:", 
                               (10, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                               0.6, (0, 0, 255), 2)
                    y_offset += 30
                    
                    for error in form_eval['errors'][:3]:  # Show max 3 errors
                        cv2.putText(frame, f"- {error}", 
                                   (10, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                                   0.5, (0, 0, 255), 1)
                        y_offset += 25
        else:
            cv2.putText(frame, "No pose detected - Stand in frame", 
                       (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 
                       0.7, (0, 0, 255), 2)
        
        # Display FPS
        cv2.putText(frame, f"Press 'q' to quit", 
                   (frame.shape[1] - 200, 30), cv2.FONT_HERSHEY_SIMPLEX, 
                   0.6, (255, 255, 255), 1)
        
        # Show frame
        cv2.imshow('Squat Form Analysis - DEMO', frame)
        
        # Handle keyboard input
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            break
        elif key == ord('r'):
            analyzer.rep_count = 0
            print("Rep count reset")
    
    # Cleanup
    cap.release()
    cv2.destroyAllWindows()
    detector.close()
    
    print("
Demo ended.")
    print(f"Total reps completed: {analyzer.rep_count}")

if __name__ == "__main__":
    main()