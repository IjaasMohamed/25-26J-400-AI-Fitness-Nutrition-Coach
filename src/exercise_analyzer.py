from typing import Dict, List, Tuple, Optional
from src.angle_calculator import AngleCalculator
import numpy as np

class SquatAnalyzer:
    """
    Biomechanical analysis for squat exercise.
    Based on kinesiology standards from research literature.
    """
    
    # Biomechanical standards for proper squat form
    STANDARDS = {
        'knee_angle': {
            'min': 70,   # degrees
            'max': 110,  # degrees
            'optimal_bottom': 90
        },
        'hip_angle': {
            'min': 60,
            'max': 120,
            'optimal_bottom': 90
        },
        'torso_angle': {
            'min': 45,   # from vertical
            'max': 85,
            'optimal': 65
        }
    }
    
    def __init__(self):
        self.angle_calc = AngleCalculator()
        self.current_state = 'standing'  # standing, descending, bottom, ascending
        self.rep_count = 0
        self.form_errors = []
        
    def analyze_frame(self, landmarks: Dict[str, Tuple]) -> Dict:
        """
        Analyze a single frame for squat form.
        
        Args:
            landmarks: Dictionary of landmark coordinates
            
        Returns:
            Analysis results including angles, form errors, and rep count
        """
        if not landmarks:
            return {'status': 'no_pose_detected'}
        
        # Calculate key angles
        angles = self._calculate_angles(landmarks)
        
        # Evaluate form
        form_evaluation = self._evaluate_form(angles)
        
        # Update state and count reps
        self._update_state(angles)
        
        return {
            'status': 'analyzed',
            'angles': angles,
            'form_evaluation': form_evaluation,
            'rep_count': self.rep_count,
            'current_state': self.current_state,
            'form_errors': self.form_errors
        }
    
    def _calculate_angles(self, landmarks: Dict[str, Tuple]) -> Dict[str, float]:
        """Calculate all relevant angles for squat."""
        angles = {}
        
        try:
            # Right side angles (use left if right not visible)
            angles['right_knee'] = self.angle_calc.calculate_knee_angle(
                landmarks['right_hip'],
                landmarks['right_knee'],
                landmarks['right_ankle']
            )
            
            angles['right_hip'] = self.angle_calc.calculate_hip_angle(
                landmarks['right_shoulder'],
                landmarks['right_hip'],
                landmarks['right_knee']
            )
            
            # Torso angle
            angles['torso'] = self.angle_calc.calculate_torso_angle(
                landmarks['right_shoulder'],
                landmarks['right_hip']
            )
            
            # Average left and right if both visible
            if 'left_knee' in landmarks and 'left_hip' in landmarks:
                left_knee_angle = self.angle_calc.calculate_knee_angle(
                    landmarks['left_hip'],
                    landmarks['left_knee'],
                    landmarks['left_ankle']
                )
                left_hip_angle = self.angle_calc.calculate_hip_angle(
                    landmarks['left_shoulder'],
                    landmarks['left_hip'],
                    landmarks['left_knee']
                )
                
                angles['left_knee'] = left_knee_angle
                angles['left_hip'] = left_hip_angle
                angles['knee_avg'] = (angles['right_knee'] + left_knee_angle) / 2
                angles['hip_avg'] = (angles['right_hip'] + left_hip_angle) / 2
            
        except KeyError as e:
            print(f"Missing landmark: {e}")
            return {}
        
        return angles
    
    def _evaluate_form(self, angles: Dict[str, float]) -> Dict:
        """
        Evaluate form quality based on biomechanical standards.
        
        Returns:
            Dictionary with form score and specific errors
        """
        self.form_errors = []
        form_score = 100
        
        if not angles:
            return {'score': 0, 'errors': ['Pose not fully visible']}
        
        # Check knee angle
        knee_angle = angles.get('knee_avg', angles.get('right_knee', 180))
        if knee_angle < self.STANDARDS['knee_angle']['min']:
            self.form_errors.append('Knees bent too much - risk of strain')
            form_score -= 20
        elif knee_angle > self.STANDARDS['knee_angle']['max']:
            self.form_errors.append('Squat not deep enough')
            form_score -= 15
        
        # Check hip angle
        hip_angle = angles.get('hip_avg', angles.get('right_hip', 180))
        if hip_angle < self.STANDARDS['hip_angle']['min']:
            self.form_errors.append('Excessive hip flexion')
            form_score -= 15
        
        # Check torso angle
        torso_angle = angles.get('torso', 90)
        if torso_angle < self.STANDARDS['torso_angle']['min']:
            self.form_errors.append('Leaning too far forward - back strain risk')
            form_score -= 25
        elif torso_angle > self.STANDARDS['torso_angle']['max']:
            self.form_errors.append('Too upright - not engaging glutes properly')
            form_score -= 10
        
        return {
            'score': max(0, form_score),
            'errors': self.form_errors,
            'status': 'good' if form_score >= 80 else 'needs_correction'
        }
    
    def _update_state(self, angles: Dict[str, float]):
        """Update exercise state and count reps."""
        if not angles:
            return
        
        knee_angle = angles.get('knee_avg', angles.get('right_knee', 180))
        
        # Simple state machine for rep counting
        if self.current_state == 'standing' and knee_angle < 130:
            self.current_state = 'descending'
        elif self.current_state == 'descending' and knee_angle < 100:
            self.current_state = 'bottom'
        elif self.current_state == 'bottom' and knee_angle > 110:
            self.current_state = 'ascending'
        elif self.current_state == 'ascending' and knee_angle > 150:
            self.current_state = 'standing'
            self.rep_count += 1  # Complete rep