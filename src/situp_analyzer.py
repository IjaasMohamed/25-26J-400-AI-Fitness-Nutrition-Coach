"""
Sit-up Analyzer - Biomechanical Analysis Module
Copy this entire file to: src/situp_analyzer.py
"""

from typing import Dict, List, Tuple, Optional
from src.angle_calculator import AngleCalculator
import numpy as np


class SitupAnalyzer:
    """
    Biomechanical analysis for sit-up exercise.
    Tracks torso lift, hip flexion, and neck safety.
    """
    
    # Biomechanical standards for proper sit-up form
    STANDARDS = {
        'torso_angle': {
            'min_bottom': 5,      # Nearly flat (degrees from horizontal)
            'max_bottom': 20,     # Slight lift acceptable at rest
            'min_top': 50,        # Minimum lift to count as sit-up
            'optimal_top': 70,    # Optimal full sit-up
            'max_top': 90         # Beyond this is using momentum
        },
        'hip_angle': {
            'min': 60,   # Minimum hip flexion
            'max': 120,  # Maximum hip flexion
            'optimal': 90
        },
        'neck_safety': {
            'max_forward_tilt': 30,  # Neck shouldn't bend too far forward
            'optimal': 15
        }
    }
    
    def __init__(self):
        self.angle_calc = AngleCalculator()
        self.current_state = 'down'  # down, rising, up, lowering
        self.rep_count = 0
        self.partial_rep_count = 0
        self.form_errors = []
        
    def analyze_frame(self, landmarks: Dict[str, Tuple]) -> Dict:
        """
        Analyze a single frame for sit-up form.
        
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
        """Calculate all relevant angles for sit-up analysis."""
        angles = {}
        
        try:
            # Torso angle from horizontal (key metric for sit-ups)
            angles['torso'] = self._calculate_torso_from_horizontal(
                landmarks['right_shoulder'],
                landmarks['right_hip']
            )
            
            # Hip flexion angle
            angles['right_hip'] = self.angle_calc.calculate_hip_angle(
                landmarks['right_shoulder'],
                landmarks['right_hip'],
                landmarks['right_knee']
            )
            
            # Knee angle (should stay relatively stable)
            angles['right_knee'] = self.angle_calc.calculate_knee_angle(
                landmarks['right_hip'],
                landmarks['right_knee'],
                landmarks['right_ankle']
            )
            
            # Neck safety check
            if 'nose' in landmarks:
                angles['neck_angle'] = self._calculate_neck_angle(
                    landmarks['nose'],
                    landmarks['right_shoulder'],
                    landmarks['right_hip']
                )
            
            # Calculate left side if visible for averaging
            if 'left_hip' in landmarks and 'left_knee' in landmarks:
                left_hip = self.angle_calc.calculate_hip_angle(
                    landmarks['left_shoulder'],
                    landmarks['left_hip'],
                    landmarks['left_knee']
                )
                angles['left_hip'] = left_hip
                angles['hip_avg'] = (angles['right_hip'] + left_hip) / 2
            
        except KeyError as e:
            print(f"Missing landmark for sit-up analysis: {e}")
            return {}
        
        return angles
    
    def _calculate_torso_from_horizontal(self, shoulder: Tuple, hip: Tuple) -> float:
        """
        Calculate torso angle from horizontal plane.
        0° = lying flat, 90° = sitting upright.
        """
        # Create horizontal reference point
        horizontal_ref = (hip[0] + 100, hip[1])  # Point to the right of hip
        
        # Calculate angle
        angle = self.angle_calc.calculate_angle(shoulder, hip, horizontal_ref)
        
        # Convert to angle from horizontal (0-90 range)
        # If shoulder is above hip, angle is positive
        if shoulder[1] < hip[1]:  # Y-axis is inverted in image coordinates
            torso_angle = 90 - angle
        else:
            torso_angle = angle - 90
        
        return abs(torso_angle)
    
    def _calculate_neck_angle(self, nose: Tuple, shoulder: Tuple, hip: Tuple) -> float:
        """
        Calculate neck forward tilt to check for strain.
        """
        # Vector from shoulder to nose (head position)
        # Vector from hip to shoulder (torso direction)
        return self.angle_calc.calculate_angle(hip, shoulder, nose)
    
    def _evaluate_form(self, angles: Dict[str, float], landmarks: Dict) -> Dict:
        """
        Evaluate form quality based on biomechanical standards.
        
        Returns:
            Dictionary with form score and specific errors
        """
        self.form_errors = []
        form_score = 100
        
        torso_angle = angles.get('torso', 0)
        
        # Check if in top position for depth evaluation
        if self.current_state in ['up', 'rising'] and torso_angle > 30:
            # Evaluate top position
            if torso_angle < self.STANDARDS['torso_angle']['min_top']:
                self.form_errors.append('Not lifting high enough - engage your core more')
                form_score -= 30
            elif torso_angle > self.STANDARDS['torso_angle']['max_top']:
                self.form_errors.append('Using too much momentum - control the movement')
                form_score -= 15
        
        # Check hip angle
        hip_angle = angles.get('hip_avg', angles.get('right_hip', 90))
        if hip_angle < self.STANDARDS['hip_angle']['min']:
            self.form_errors.append('Excessive hip flexion - may strain lower back')
            form_score -= 20
        elif hip_angle > self.STANDARDS['hip_angle']['max']:
            self.form_errors.append('Keep knees bent at 90 degrees')
            form_score -= 15
        
        # Check knee angle (should stay around 90 degrees)
        knee_angle = angles.get('right_knee', 90)
        if knee_angle < 70 or knee_angle > 110:
            self.form_errors.append('Maintain bent knees throughout movement')
            form_score -= 10
        
        # Check neck safety
        if 'neck_angle' in angles:
            neck_angle = angles['neck_angle']
            # Neck should be relatively neutral, not excessively forward
            if neck_angle > 180:  # Excessive forward bend
                self.form_errors.append('NECK STRAIN RISK - Keep neck neutral!')
                form_score -= 25  # High penalty for injury risk
        
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
        
        torso_angle = angles.get('torso', 0)
        
        # State machine for rep counting
        if self.current_state == 'down' and torso_angle > 20:
            self.current_state = 'rising'
            
        elif self.current_state == 'rising' and torso_angle > 60:
            self.current_state = 'up'
            
        elif self.current_state == 'up' and torso_angle < 55:
            self.current_state = 'lowering'
            
        elif self.current_state == 'lowering' and torso_angle < 15:
            # Check if it was a complete rep (reached sufficient height)
            if torso_angle < 10:  # Properly returned to start
                self.current_state = 'down'
                # Check if the rep reached the target height
                # (This would need tracking of max angle during rep)
                self.rep_count += 1  # Complete rep
            else:
                self.current_state = 'down'
                self.partial_rep_count += 1  # Partial rep
    
    def reset(self):
        """Reset counter and state."""
        self.rep_count = 0
        self.partial_rep_count = 0
        self.current_state = 'down'
        self.form_errors = []