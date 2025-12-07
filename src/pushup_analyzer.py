"""
Push-up Analyzer - Biomechanical Analysis Module
Copy this entire file to: src/pushup_analyzer.py
"""

from typing import Dict, List, Tuple, Optional
from src.angle_calculator import AngleCalculator
import numpy as np


class PushupAnalyzer:
    """
    Biomechanical analysis for push-up exercise.
    Tracks form quality, counts reps, provides real-time feedback.
    """
    
    # Biomechanical standards for proper push-up form
    STANDARDS = {
        'elbow_angle': {
            'min_bottom': 70,   # Minimum angle at bottom (degrees)
            'max_bottom': 100,  # Maximum angle at bottom
            'min_top': 160,     # Minimum angle at top (nearly straight)
            'optimal_bottom': 90
        },
        'body_alignment': {
            'max_hip_sag': 15,      # Maximum hip drop (degrees from straight)
            'max_hip_pike': 15,     # Maximum hip pike
            'optimal_straight': 180  # Perfect straight line
        },
        'shoulder_angle': {
            'min': 60,   # Minimum shoulder flexion
            'max': 120,  # Maximum shoulder flexion
            'optimal': 90
        },
        'elbow_flare': {
            'max_safe': 45,  # Maximum safe elbow flare from body
            'optimal': 30    # Optimal elbow position
        }
    }
    
    def __init__(self):
        self.angle_calc = AngleCalculator()
        self.current_state = 'up'  # up, descending, bottom, ascending
        self.rep_count = 0
        self.partial_rep_count = 0
        self.form_errors = []
        
        # For velocity adaptation
        self.last_elbow_angle = None
        self.last_timestamp = None
        
    def analyze_frame(self, landmarks: Dict[str, Tuple]) -> Dict:
        """
        Analyze a single frame for push-up form.
        
        Args:
            landmarks: Dictionary of landmark coordinates
            
        Returns:
            Analysis results including angles, form errors, and rep count
        """
        if not landmarks:
            return {'status': 'no_pose_detected'}
        
        # Calculate key angles
        angles = self._calculate_angles(landmarks)
        
        if not angles:
            return {'status': 'incomplete_pose'}
        
        # Evaluate form
        form_evaluation = self._evaluate_form(angles, landmarks)
        
        # Update state and count reps
        self._update_state(angles)
        
        return {
            'status': 'analyzed',
            'angles': angles,
            'form_evaluation': form_evaluation,
            'rep_count': self.rep_count,
            'partial_reps': self.partial_rep_count,
            'current_state': self.current_state,
            'form_errors': self.form_errors
        }
    
    def _calculate_angles(self, landmarks: Dict[str, Tuple]) -> Dict[str, float]:
        """Calculate all relevant angles for push-up analysis."""
        angles = {}
        
        try:
            # Elbow angles (most critical for push-ups)
            angles['right_elbow'] = self.angle_calc.calculate_elbow_angle(
                landmarks['right_shoulder'],
                landmarks['right_elbow'],
                landmarks['right_wrist']
            )
            
            # Shoulder angles
            angles['right_shoulder'] = self.angle_calc.calculate_shoulder_angle(
                landmarks['right_hip'],
                landmarks['right_shoulder'],
                landmarks['right_elbow']
            )
            
            # Body alignment (shoulder-hip-ankle line)
            angles['body_alignment'] = self._calculate_body_alignment(
                landmarks['right_shoulder'],
                landmarks['right_hip'],
                landmarks['right_ankle']
            )
            
            # Elbow flare (distance from body midline)
            angles['elbow_flare'] = self._calculate_elbow_flare(landmarks)
            
            # Calculate left side if visible
            if all(k in landmarks for k in ['left_shoulder', 'left_elbow', 'left_wrist']):
                left_elbow = self.angle_calc.calculate_elbow_angle(
                    landmarks['left_shoulder'],
                    landmarks['left_elbow'],
                    landmarks['left_wrist']
                )
                angles['left_elbow'] = left_elbow
                angles['elbow_avg'] = (angles['right_elbow'] + left_elbow) / 2
            
        except KeyError as e:
            print(f"Missing landmark for push-up analysis: {e}")
            return {}
        
        return angles
    
    def _calculate_body_alignment(self, shoulder: Tuple, hip: Tuple, ankle: Tuple) -> float:
        """
        Calculate body straightness.
        Returns angle deviation from straight line (180° = perfect).
        """
        return self.angle_calc.calculate_angle(shoulder, hip, ankle)
    
    def _calculate_elbow_flare(self, landmarks: Dict[str, Tuple]) -> float:
        """
        Calculate elbow flare angle from body midline.
        Higher values = elbows too wide.
        """
        # Vector from shoulder to elbow
        shoulder = np.array(landmarks['right_shoulder'][:2])
        elbow = np.array(landmarks['right_elbow'][:2])
        hip = np.array(landmarks['right_hip'][:2])
        
        # Vector along body (shoulder to hip)
        body_vector = hip - shoulder
        elbow_vector = elbow - shoulder
        
        # Calculate angle between vectors
        cos_angle = np.dot(body_vector, elbow_vector) / (
            np.linalg.norm(body_vector) * np.linalg.norm(elbow_vector) + 1e-6
        )
        cos_angle = np.clip(cos_angle, -1.0, 1.0)
        angle = np.degrees(np.arccos(cos_angle))
        
        return angle
    
    def _evaluate_form(self, angles: Dict[str, float], landmarks: Dict) -> Dict:
        """
        Evaluate form quality based on biomechanical standards.
        
        Returns:
            Dictionary with form score and specific errors
        """
        self.form_errors = []
        form_score = 100
        
        # Get primary elbow angle
        elbow_angle = angles.get('elbow_avg', angles.get('right_elbow', 180))
        
        # Check if in bottom position for depth evaluation
        if self.current_state in ['bottom', 'descending'] and elbow_angle < 120:
            # Evaluate bottom position depth
            if elbow_angle < self.STANDARDS['elbow_angle']['min_bottom']:
                self.form_errors.append('Going too low - risk of shoulder strain')
                form_score -= 20
            elif elbow_angle > self.STANDARDS['elbow_angle']['max_bottom']:
                self.form_errors.append('Not going low enough - increase range of motion')
                form_score -= 25
        
        # Check body alignment
        body_alignment = angles.get('body_alignment', 180)
        alignment_deviation = abs(180 - body_alignment)
        
        if alignment_deviation > self.STANDARDS['body_alignment']['max_hip_sag']:
            if body_alignment < 180:
                self.form_errors.append('Hips sagging - engage your core!')
                form_score -= 30  # High penalty - injury risk
            else:
                self.form_errors.append('Hips too high - lower them to body level')
                form_score -= 20
        
        # Check elbow flare
        elbow_flare = angles.get('elbow_flare', 30)
        if elbow_flare > self.STANDARDS['elbow_flare']['max_safe']:
            self.form_errors.append('Elbows flaring out - keep them closer to body')
            form_score -= 20
        
        # Check shoulder angle for safety
        shoulder_angle = angles.get('right_shoulder', 90)
        if shoulder_angle < self.STANDARDS['shoulder_angle']['min']:
            self.form_errors.append('Excessive shoulder flexion - reduce range')
            form_score -= 15
        
        return {
            'score': max(0, form_score),
            'errors': self.form_errors,
            'status': 'good' if form_score >= 80 else 'needs_correction'
        }
    
    def _update_state(self, angles: Dict[str, float]):
        """
        Update exercise state and count reps using state machine.
        Distinguishes between complete and partial reps.
        """
        if not angles:
            return
        
        elbow_angle = angles.get('elbow_avg', angles.get('right_elbow', 180))
        
        # State machine for rep counting
        if self.current_state == 'up' and elbow_angle < 150:
            self.current_state = 'descending'
            
        elif self.current_state == 'descending' and elbow_angle < 100:
            self.current_state = 'bottom'
            
        elif self.current_state == 'bottom' and elbow_angle > 110:
            self.current_state = 'ascending'
            
        elif self.current_state == 'ascending' and elbow_angle > 160:
            # Check if it was a complete rep
            if angles.get('body_alignment', 180) > 165:  # Good alignment throughout
                self.current_state = 'up'
                self.rep_count += 1  # Complete rep
            else:
                self.current_state = 'up'
                self.partial_rep_count += 1  # Partial rep (poor form)
    
    def reset(self):
        """Reset counter and state."""
        self.rep_count = 0
        self.partial_rep_count = 0
        self.current_state = 'up'
        self.form_errors = []