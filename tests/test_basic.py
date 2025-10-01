"""
Real-Time Biomechanical Exercise Form Analysis - Demo Application
Exercise: Squats
Author: [Your Name]
Date: October 2025

This demo showcases real-time pose detection and biomechanical analysis
for squat exercise form evaluation.
"""

import cv2
import sys
import os
import time
from collections import deque

# Add parent directory to path to import our modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.pose_detector import PoseDetector
from src.angle_calculator import AngleCalculator
from src.exercise_analyzer import SquatAnalyzer


class SquatFormAnalyzer:
    """
    Real-time squat form analysis application with visual feedback.
    """
    
    def __init__(self):
        """Initialize all components."""
        print("Initializing Real-Time Biomechanical Exercise Form Analyzer...")
        
        # Initialize detector with optimal settings for real-time
        self.detector = PoseDetector(
            min_detection_confidence=0.7,
            min_tracking_confidence=0.7,
            model_complexity=1  # 0=fast, 1=balanced, 2=accurate
        )
        
        self.analyzer = SquatAnalyzer()
        self.angle_calc = AngleCalculator()
        
        # Performance tracking
        self.fps_history = deque(maxlen=30)
        self.last_time = time.time()
        
        # UI Colors (BGR format)
        self.COLOR_GOOD = (0, 255, 0)      # Green
        self.COLOR_WARNING = (0, 165, 255)  # Orange
        self.COLOR_ERROR = (0, 0, 255)      # Red
        self.COLOR_INFO = (255, 255, 255)   # White
        self.COLOR_ACCENT = (255, 255, 0)   # Cyan
        
        print("✓ Initialization complete!")
    
    def calculate_fps(self):
        """Calculate current FPS."""
        current_time = time.time()
        fps = 1.0 / (current_time - self.last_time) if (current_time - self.last_time) > 0 else 0
        self.last_time = current_time
        self.fps_history.append(fps)
        return sum(self.fps_history) / len(self.fps_history)
    
    def draw_header(self, frame, fps):
        """Draw header with app title and FPS."""
        height = frame.shape[0]
        width = frame.shape[1]
        
        # Semi-transparent header bar
        overlay = frame.copy()
        cv2.rectangle(overlay, (0, 0), (width, 80), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.6, frame, 0.4, 0, frame)
        
        # Title
        cv2.putText(frame, "Real-Time Squat Form Analysis", 
                   (10, 35), cv2.FONT_HERSHEY_DUPLEX, 
                   1.0, self.COLOR_ACCENT, 2)
        
        # Subtitle
        cv2.putText(frame, "Biomechanical Exercise Evaluation System", 
                   (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 
                   0.6, self.COLOR_INFO, 1)
        
        # FPS counter (top right)
        fps_text = f"FPS: {fps:.1f}"
        fps_color = self.COLOR_GOOD if fps >= 25 else self.COLOR_WARNING
        cv2.putText(frame, fps_text, 
                   (width - 120, 35), cv2.FONT_HERSHEY_SIMPLEX, 
                   0.8, fps_color, 2)
    
    def draw_metrics_panel(self, frame, analysis):
        """Draw side panel with metrics and feedback."""
        height = frame.shape[0]
        width = frame.shape[1]
        
        # Semi-transparent side panel
        panel_width = 350
        overlay = frame.copy()
        cv2.rectangle(overlay, (width - panel_width, 80), (width, height), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.7, frame, 0.3, 0, frame)
        
        x_offset = width - panel_width + 15
        y_offset = 110
        line_height = 35
        
        # Rep Counter (large and prominent)
        rep_text = f"REPS: {analysis['rep_count']}"
        cv2.putText(frame, rep_text, 
                   (x_offset, y_offset), cv2.FONT_HERSHEY_DUPLEX, 
                   1.2, self.COLOR_ACCENT, 3)
        y_offset += 50
        
        # Current State
        state_text = f"State: {analysis['current_state'].upper()}"
        state_color = {
            'standing': self.COLOR_INFO,
            'descending': self.COLOR_WARNING,
            'bottom': self.COLOR_ACCENT,
            'ascending': self.COLOR_WARNING
        }.get(analysis['current_state'], self.COLOR_INFO)
        
        cv2.putText(frame, state_text, 
                   (x_offset, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                   0.8, state_color, 2)
        y_offset += line_height + 10
        
        # Divider line
        cv2.line(frame, (x_offset, y_offset), (width - 15, y_offset), 
                self.COLOR_INFO, 1)
        y_offset += 20
        
        # Form Score
        form_eval = analysis['form_evaluation']
        score = form_eval['score']
        score_color = self.COLOR_GOOD if score >= 80 else (self.COLOR_WARNING if score >= 60 else self.COLOR_ERROR)
        
        cv2.putText(frame, "FORM SCORE:", 
                   (x_offset, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                   0.7, self.COLOR_INFO, 1)
        y_offset += 30
        
        # Score bar
        bar_width = 280
        bar_height = 25
        bar_x = x_offset
        bar_y = y_offset
        
        # Background bar
        cv2.rectangle(frame, (bar_x, bar_y), (bar_x + bar_width, bar_y + bar_height), 
                     (50, 50, 50), -1)
        
        # Score bar (filled portion)
        fill_width = int((score / 100) * bar_width)
        cv2.rectangle(frame, (bar_x, bar_y), (bar_x + fill_width, bar_y + bar_height), 
                     score_color, -1)
        
        # Score text on bar
        score_text = f"{score}/100"
        cv2.putText(frame, score_text, 
                   (bar_x + bar_width//2 - 35, bar_y + 18), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, self.COLOR_INFO, 2)
        
        y_offset += bar_height + 25
        
        # Divider line
        cv2.line(frame, (x_offset, y_offset), (width - 15, y_offset), 
                self.COLOR_INFO, 1)
        y_offset += 20
        
        # Angles section
        cv2.putText(frame, "JOINT ANGLES:", 
                   (x_offset, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                   0.7, self.COLOR_INFO, 1)
        y_offset += 30
        
        angles = analysis.get('angles', {})
        angle_labels = {
            'right_knee': 'Knee',
            'right_hip': 'Hip',
            'torso': 'Torso'
        }
        
        for key, label in angle_labels.items():
            if key in angles:
                angle_value = angles[key]
                cv2.putText(frame, f"{label}: {angle_value:.1f}°", 
                           (x_offset + 10, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                           0.6, self.COLOR_INFO, 1)
                y_offset += 25
        
        y_offset += 10
        
        # Form Errors section
        if form_eval['errors']:
            # Divider line
            cv2.line(frame, (x_offset, y_offset), (width - 15, y_offset), 
                    self.COLOR_ERROR, 2)
            y_offset += 20
            
            cv2.putText(frame, "FORM CORRECTIONS:", 
                       (x_offset, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                       0.7, self.COLOR_ERROR, 2)
            y_offset += 30
            
            # Display up to 3 errors
            for i, error in enumerate(form_eval['errors'][:3]):
                # Wrap text if too long
                if len(error) > 35:
                    words = error.split()
                    line1 = ""
                    line2 = ""
                    for word in words:
                        if len(line1 + word) < 35:
                            line1 += word + " "
                        else:
                            line2 += word + " "
                    
                    cv2.putText(frame, f"• {line1.strip()}", 
                               (x_offset, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                               0.5, self.COLOR_WARNING, 1)
                    y_offset += 20
                    if line2:
                        cv2.putText(frame, f"  {line2.strip()}", 
                                   (x_offset, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                                   0.5, self.COLOR_WARNING, 1)
                        y_offset += 20
                else:
                    cv2.putText(frame, f"• {error}", 
                               (x_offset, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                               0.5, self.COLOR_WARNING, 1)
                    y_offset += 22
        else:
            # Good form message
            y_offset += 10
            cv2.putText(frame, "✓ EXCELLENT FORM!", 
                       (x_offset, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                       0.7, self.COLOR_GOOD, 2)
    
    def draw_angle_visualization(self, frame, landmarks, angles):
        """Draw angle arcs on joints."""
        if not landmarks or not angles:
            return
        
        height, width = frame.shape[:2]
        
        # Draw knee angle arc
        if 'right_knee' in angles:
            knee = landmarks.get('right_knee')
            if knee:
                x, y = int(knee[0] * width), int(knee[1] * height)
                angle_text = f"{angles['right_knee']:.0f}°"
                
                # Draw small circle at joint
                cv2.circle(frame, (x, y), 8, self.COLOR_ACCENT, -1)
                cv2.circle(frame, (x, y), 12, self.COLOR_ACCENT, 2)
                
                # Draw angle text near joint
                cv2.putText(frame, angle_text, 
                           (x + 20, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 
                           0.6, self.COLOR_ACCENT, 2)
    
    def draw_instructions(self, frame):
        """Draw control instructions at bottom."""
        height = frame.shape[0]
        width = frame.shape[1]
        
        instructions = [
            "Controls: 'R' - Reset Count | 'Q' - Quit | 'S' - Screenshot"
        ]
        
        y_offset = height - 20
        for instruction in instructions:
            cv2.putText(frame, instruction, 
                       (10, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 
                       0.5, self.COLOR_INFO, 1)
            y_offset += 20
    
    def run(self):
        """Main application loop."""
        # Initialize webcam
        cap = cv2.VideoCapture(0)
        
        # Try to set optimal resolution
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
        
        # Get actual resolution
        actual_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        actual_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        
        print("" + "="*60)
        print("REAL-TIME BIOMECHANICAL SQUAT ANALYSIS")
        print("="*60)
        print(f"Camera Resolution: {actual_width}x{actual_height}")
        print("📋 Instructions:")
        print("  • Stand in front of camera (full body visible)")
        print("  • Perform squats with proper form")
        print("  • Watch the form score and corrections")
        print("⌨️  Controls:")
        print("  • 'R' key - Reset rep count")
        print("  • 'S' key - Save screenshot")
        print("  • 'Q' key - Quit application")
        print("✓ Application ready! Starting camera...")
        
        if not cap.isOpened():
            print("❌ Error: Could not open webcam!")
            return
        
        screenshot_counter = 0
        
        while True:
            ret, frame = cap.read()
            if not ret:
                print("❌ Error: Failed to grab frame")
                break
            
            # Flip frame horizontally for mirror effect
            frame = cv2.flip(frame, 1)
            
            # Calculate FPS
            fps = self.calculate_fps()
            
            # Detect pose
            frame, detected = self.detector.detect(frame, draw=True)
            
            # Draw header
            self.draw_header(frame, fps)
            
            if detected:
                # Get all landmarks
                landmarks = self.detector.get_all_landmarks(frame.shape)
                
                # Analyze squat form
                analysis = self.analyzer.analyze_frame(landmarks)
                
                if analysis['status'] == 'analyzed':
                    # Draw angle visualizations
                    self.draw_angle_visualization(frame, landmarks, analysis.get('angles', {}))
                    
                    # Draw metrics panel
                    self.draw_metrics_panel(frame, analysis)
            else:
                # No pose detected message
                height = frame.shape[0]
                width = frame.shape[1]
                
                message = "Stand in camera view (full body visible)"
                cv2.putText(frame, message, 
                           (width//2 - 250, height//2), 
                           cv2.FONT_HERSHEY_SIMPLEX, 
                           0.8, self.COLOR_WARNING, 2)
            
            # Draw instructions
            self.draw_instructions(frame)
            
            # Display frame
            cv2.imshow('Squat Form Analyzer - Real-Time Biomechanics', frame)
            
            # Handle keyboard input
            key = cv2.waitKey(1) & 0xFF
            
            if key == ord('q') or key == ord('Q'):
                print("👋 Shutting down application...")
                break
            elif key == ord('r') or key == ord('R'):
                self.analyzer.rep_count = 0
                print("🔄 Rep count reset to 0")
            elif key == ord('s') or key == ord('S'):
                screenshot_counter += 1
                filename = f"screenshot_{screenshot_counter}.png"
                cv2.imwrite(filename, frame)
                print(f"📸 Screenshot saved: {filename}")
        
        # Cleanup
        print("📊 Session Summary:")
        print(f"  • Total Reps: {self.analyzer.rep_count}")
        print(f"  • Average FPS: {sum(self.fps_history) / len(self.fps_history):.1f}")
        print("✓ Application closed successfully")
        
        cap.release()
        cv2.destroyAllWindows()
        self.detector.close()


def main():
    """Entry point for the application."""
    try:
        app = SquatFormAnalyzer()
        app.run()
    except KeyboardInterrupt:
        print("⚠️  Application interrupted by user")
    except Exception as e:
        print(f"❌ Error occurred: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()