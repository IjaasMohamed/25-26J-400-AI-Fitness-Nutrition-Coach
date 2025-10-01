import numpy as np
from typing import Tuple, Optional

class AngleCalculator:
    """
    Calculate joint angles for biomechanical analysis.
    Accuracy target: ±5 degrees as per project objectives.
    """
    
    @staticmethod
    def calculate_angle(point1: Tuple, point2: Tuple, point3: Tuple) -> float:
        """
        Calculate angle between three points.
        
        Args:
            point1: First point (x, y, [z])
            point2: Vertex point (x, y, [z])
            point3: Third point (x, y, [z])
            
        Returns:
            Angle in degrees (0-180)
        """
        # Convert to numpy arrays
        p1 = np.array(point1[:2])  # Use only x, y
        p2 = np.array(point2[:2])
        p3 = np.array(point3[:2])
        
        # Calculate vectors
        vector1 = p1 - p2
        vector2 = p3 - p2
        
        # Calculate angle using dot product
        cos_angle = np.dot(vector1, vector2) / (
            np.linalg.norm(vector1) * np.linalg.norm(vector2) + 1e-6
        )
        
        # Clip to handle numerical errors
        cos_angle = np.clip(cos_angle, -1.0, 1.0)
        
        angle = np.degrees(np.arccos(cos_angle))
        
        return angle
    
    @staticmethod
    def calculate_knee_angle(hip: Tuple, knee: Tuple, ankle: Tuple) -> float:
        """Calculate knee flexion angle."""
        return AngleCalculator.calculate_angle(hip, knee, ankle)
    
    @staticmethod
    def calculate_hip_angle(shoulder: Tuple, hip: Tuple, knee: Tuple) -> float:
        """Calculate hip flexion angle."""
        return AngleCalculator.calculate_angle(shoulder, hip, knee)
    
    @staticmethod
    def calculate_elbow_angle(shoulder: Tuple, elbow: Tuple, wrist: Tuple) -> float:
        """Calculate elbow flexion angle."""
        return AngleCalculator.calculate_angle(shoulder, elbow, wrist)
    
    @staticmethod
    def calculate_shoulder_angle(hip: Tuple, shoulder: Tuple, elbow: Tuple) -> float:
        """Calculate shoulder flexion angle."""
        return AngleCalculator.calculate_angle(hip, shoulder, elbow)
    
    @staticmethod
    def calculate_torso_angle(shoulder: Tuple, hip: Tuple, vertical_ref: Optional[Tuple] = None) -> float:
        """
        Calculate torso inclination from vertical.
        
        Args:
            shoulder: Shoulder position
            hip: Hip position
            vertical_ref: Reference point for vertical (if None, uses vertical line)
            
        Returns:
            Angle from vertical in degrees
        """
        if vertical_ref is None:
            # Create vertical reference point
            vertical_ref = (hip[0], hip[1] - 100)  # Point directly above hip
        
        return AngleCalculator.calculate_angle(shoulder, hip, vertical_ref)