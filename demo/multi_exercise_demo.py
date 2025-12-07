"""
Multi-Exercise Real-Time Form Analysis Demo
Copy this entire file to: demo/multi_exercise_demo.py

Supports: Squats, Push-ups, Sit-ups
Press 1, 2, or 3 to switch between exercises
"""

import cv2
import sys
import os
import time
from collections import deque

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.pose_detector import PoseDetector
from src.exercise_analyzer import SquatAnalyzer
from src.pushup_analyzer import PushupAnalyzer
from src.situp_analyzer import SitupAnalyzer


class MultiExerciseAnalyzer:
    """
    Real-time analysis for multiple exercises with exercise selection.
    """
    
    def __init__(self):
        print("="*60)
        print("Real-Time Biomechanical Exercise Form Analyzer")
        print("Multi-Exercise Support: Squats | Push-ups | Sit-ups")
        print("="*60)
        
        # Initialize pose detector
        self.detector = PoseDetector(
            min_detection_confidence=0.7,
            min_tracking_confidence=0.7,
            model_complexity=1
        )
        
        # Initialize all exercise analyzers
        self.analyzers = {
            'squat': SquatAnalyzer(),
            'pushup': PushupAnalyzer(),
            'situp': SitupAnalyzer()
        }
        
        # Current exercise selection
        self.current_exercise = 'squat'
        
        # Performance tracking
        self.fps_history = deque(maxlen=30)
        self.last_time = time.time()
        
        # UI Colors (BGR format for OpenCV)
        self.COLOR_GOOD = (0, 255, 0)      # Green
        self.COLOR_WARNING = (0, 165, 255)  # Orange
        self.COLOR_ERROR = (0, 0, 255)      # Red
        self.COLOR_INFO = (255, 255, 255)   # White
        self.COLOR_ACCENT = (255, 255, 0)   # Cyan
        
        print("✓ All components initialized!")
    
    def calculate_fps(self):
        """Calculate current FPS."""
        current_time = time.time()
        fps = 1.0 / (current_time - self.last_time) if (current_time - self.last_time) > 0 else 0
        self.last_time = current_time
        self.fps_history.append(fps)
        return sum(self.fps_history) / len(self.fps_history)
    
    def draw_exercise_selector(self, frame):
        """Draw exercise selection buttons at top."""
        width = frame.shape[1]
        
        # Exercise buttons
        exercises = ['squat', 'pushup', 'situp']
        button_width = 180
        button_height = 50
        start_x = (width - len(exercises) * button_width - 40) // 2
        y_pos = 90
        
        for i, exercise in enumerate(exercises):
            x_pos = start_x + i * (button_width + 20)
            
            # Button background
            if exercise == self.current_exercise:
                color = self.COLOR_ACCENT
                thickness = -1  # Filled
            else:
                color = (100, 100, 100)
                thickness = 2  # Outline only
            
            cv2.rectangle(frame, (x_pos, y_pos), 
                         (x_pos + button_width, y_pos + button_height),
                         color, thickness)
            
            # Button text
            text_color = (0, 0, 0) if exercise == self.current_exercise else self.COLOR_INFO
            text = exercise.upper()
            text_size = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, 0.7, 2)[0]
            text_x = x_pos + (button_width - text_size[0]) // 2
            text_y = y_pos + (button_height + text_size[1]) // 2
            
            cv2.putText(frame, text, (text_x, text_y),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, text_color, 2)
        
        # Instructions
        cv2.putText(frame, "Press 1=Squat | 2=Push-up | 3=Sit-up", 
                   (width//2 - 200, y_pos + button_height + 35),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, self.COLOR_INFO, 1)
    
    def draw_header(self, frame, fps):
        """Draw header with title and FPS."""
        height, width = frame.shape[:2]
        
        # Semi-transparent header bar
        overlay = frame.copy()
        cv2.rectangle(overlay, (0, 0), (width, 80), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.6, frame, 0.4, 0, frame)
        
        # Title
        cv2.putText(frame, "Multi-Exercise Form Analyzer", 
                   (10, 35), cv2.FONT_HERSHEY_DUPLEX, 
                   1.0, self.COLOR_ACCENT, 2)
        
        # Subtitle with current exercise
        exercise_name = self.current_exercise.upper()
        cv2.putText(frame, f"Current: {exercise_name}", 
                   (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 
                   0.6, self.COLOR_GOOD, 1)
        
        # FPS counter
        fps_text = f"FPS: {fps:.1f}"
        fps_color = self.COLOR_GOOD if fps >= 25 else self.COLOR_WARNING
        cv2.putText(frame, fps_text, 
                   (width - 120, 35), cv2.FONT_HERSHEY_SIMPLEX, 
                   0.8, fps_color, 2)
    
    def draw_metrics_panel(self, frame, analysis):
        """Draw side panel with metrics."""
        height, width = frame.shape[:2]
        panel_width = 350
        
        # Semi-transparent panel
        overlay = frame.copy()
        cv2.rectangle(overlay, (width - panel_width, 160), (width, height), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.7, frame, 0.3, 0, frame)
        
        x_offset = width - panel_width + 15
        y_offset = 180
        line_height = 35
        
        # Rep Counter
        rep_text = f"REPS: {analysis['rep_count']}"
        cv2.putText(frame, rep_text, (x_offset, y_offset),
                   cv2.FONT_HERSHEY_DUPLEX, 1.2, self.COLOR_ACCENT, 3)
        y_offset += 50
        
        # Partial reps (if any)
        if 'partial_reps' in analysis and analysis['partial_reps'] > 0:
            partial_text = f"Partial: {analysis['partial_reps']}"
            cv2.putText(frame, partial_text, (x_offset, y_offset),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, self.COLOR_WARNING, 1)
            y_offset += 30
        
        # Current State
        state_text = f"State: {analysis['current_state'].upper()}"
        cv2.putText(frame, state_text, (x_offset, y_offset),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.8, self.COLOR_INFO, 2)
        y_offset += line_height + 10
        
        # Divider
        cv2.line(frame, (x_offset, y_offset), (width - 15, y_offset),
                self.COLOR_INFO, 1)
        y_offset += 20
        
        # Form Score
        form_eval = analysis['form_evaluation']
        score = form_eval['score']
        score_color = self.COLOR_GOOD if score >= 80 else (
            self.COLOR_WARNING if score >= 60 else self.COLOR_ERROR)
        
        cv2.putText(frame, "FORM SCORE:", (x_offset, y_offset),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, self.COLOR_INFO, 1)
        y_offset += 30
        
        # Score bar
        bar_width = 280
        bar_height = 25
        cv2.rectangle(frame, (x_offset, y_offset),
                     (x_offset + bar_width, y_offset + bar_height),
                     (50, 50, 50), -1)
        
        fill_width = int((score / 100) * bar_width)
        cv2.rectangle(frame, (x_offset, y_offset),
                     (x_offset + fill_width, y_offset + bar_height),
                     score_color, -1)
        
        score_text = f"{score}/100"
        cv2.putText(frame, score_text,
                   (x_offset + bar_width//2 - 35, y_offset + 18),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, self.COLOR_INFO, 2)
        y_offset += bar_height + 25
        
        # Divider
        cv2.line(frame, (x_offset, y_offset), (width - 15, y_offset),
                self.COLOR_INFO, 1)
        y_offset += 20
        
        # Key Angles
        cv2.putText(frame, "KEY ANGLES:", (x_offset, y_offset),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, self.COLOR_INFO, 1)
        y_offset += 30
        
        angles = analysis.get('angles', {})
        # Show different angles based on exercise
        if self.current_exercise == 'squat':
            angle_keys = ['right_knee', 'right_hip', 'torso']
            labels = ['Knee', 'Hip', 'Torso']
        elif self.current_exercise == 'pushup':
            angle_keys = ['right_elbow', 'body_alignment', 'elbow_flare']
            labels = ['Elbow', 'Body Align', 'Elbow Flare']
        else:  # situp
            angle_keys = ['torso', 'right_hip', 'right_knee']
            labels = ['Torso Lift', 'Hip', 'Knee']
        
        for key, label in zip(angle_keys, labels):
            if key in angles:
                cv2.putText(frame, f"{label}: {angles[key]:.1f}°",
                           (x_offset + 10, y_offset),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.6, self.COLOR_INFO, 1)
                y_offset += 25
        
        y_offset += 10
        
        # Form Errors
        if form_eval['errors']:
            cv2.line(frame, (x_offset, y_offset), (width - 15, y_offset),
                    self.COLOR_ERROR, 2)
            y_offset += 20
            
            cv2.putText(frame, "FORM CORRECTIONS:",
                       (x_offset, y_offset),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, self.COLOR_ERROR, 2)
            y_offset += 30
            
            for error in form_eval['errors'][:3]:
                # Wrap long text
                if len(error) > 35:
                    words = error.split()
                    line1, line2 = "", ""
                    for word in words:
                        if len(line1 + word) < 35:
                            line1 += word + " "
                        else:
                            line2 += word + " "
                    
                    cv2.putText(frame, f"• {line1.strip()}",
                               (x_offset, y_offset),
                               cv2.FONT_HERSHEY_SIMPLEX, 0.5, self.COLOR_WARNING, 1)
                    y_offset += 20
                    if line2:
                        cv2.putText(frame, f"  {line2.strip()}",
                                   (x_offset, y_offset),
                                   cv2.FONT_HERSHEY_SIMPLEX, 0.5, self.COLOR_WARNING, 1)
                        y_offset += 20
                else:
                    cv2.putText(frame, f"• {error}",
                               (x_offset, y_offset),
                               cv2.FONT_HERSHEY_SIMPLEX, 0.5, self.COLOR_WARNING, 1)
                    y_offset += 22
        else:
            cv2.putText(frame, "✓ EXCELLENT FORM!",
                       (x_offset, y_offset),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, self.COLOR_GOOD, 2)
    
    def draw_instructions(self, frame):
        """Draw control instructions."""
        height, width = frame.shape[:2]
        instructions = [
            "Controls: 1/2/3 - Switch Exercise | R - Reset | Q - Quit | S - Screenshot"
        ]
        
        y_offset = height - 20
        for instruction in instructions:
            cv2.putText(frame, instruction, (10, y_offset),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, self.COLOR_INFO, 1)
            y_offset += 20
    
    def run(self):
        """Main application loop."""
        cap = cv2.VideoCapture(0)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
        
        print("\n📋 Instructions:")
        print("  • Position yourself for the selected exercise")
        print("  • Press 1/2/3 to switch between exercises")
        print("  • Press 'R' to reset rep count")
        print("  • Press 'Q' to quit")
        print("✓ Starting camera...\n")
        
        if not cap.isOpened():
            print("❌ Error: Could not open webcam!")
            return
        
        screenshot_counter = 0
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            frame = cv2.flip(frame, 1)
            fps = self.calculate_fps()
            
            # Detect pose
            frame, detected = self.detector.detect(frame, draw=True)
            
            # Draw header
            self.draw_header(frame, fps)
            
            # Draw exercise selector
            self.draw_exercise_selector(frame)
            
            if detected:
                landmarks = self.detector.get_all_landmarks(frame.shape)
                
                # Get current analyzer
                analyzer = self.analyzers[self.current_exercise]
                analysis = analyzer.analyze_frame(landmarks)
                
                if analysis['status'] == 'analyzed':
                    self.draw_metrics_panel(frame, analysis)
            else:
                height, width = frame.shape[:2]
                cv2.putText(frame, "Position yourself in camera view",
                           (width//2 - 250, height//2),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.8, self.COLOR_WARNING, 2)
            
            self.draw_instructions(frame)
            cv2.imshow('Multi-Exercise Form Analyzer', frame)
            
            # Handle keyboard
            key = cv2.waitKey(1) & 0xFF
            
            if key == ord('q') or key == ord('Q'):
                print("\n👋 Shutting down...")
                break
            elif key == ord('1'):
                self.current_exercise = 'squat'
                print("Switched to: SQUAT")
            elif key == ord('2'):
                self.current_exercise = 'pushup'
                print("Switched to: PUSH-UP")
            elif key == ord('3'):
                self.current_exercise = 'situp'
                print("Switched to: SIT-UP")
            elif key == ord('r') or key == ord('R'):
                self.analyzers[self.current_exercise].reset()
                print("🔄 Rep count reset")
            elif key == ord('s') or key == ord('S'):
                screenshot_counter += 1
                filename = f"screenshot_{screenshot_counter}.png"
                cv2.imwrite(filename, frame)
                print(f"📸 Screenshot saved: {filename}")
        
        # Cleanup
        print("\n📊 Session Summary:")
        for exercise, analyzer in self.analyzers.items():
            print(f"  {exercise.upper()}: {analyzer.rep_count} reps")
        print("✓ Application closed successfully")
        
        cap.release()
        cv2.destroyAllWindows()
        self.detector.close()


def main():
    """Entry point."""
    try:
        app = MultiExerciseAnalyzer()
        app.run()
    except KeyboardInterrupt:
        print("\n⚠️  Application interrupted by user")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()