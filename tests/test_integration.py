"""
Integration test for the complete pipeline
"""
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.pose_detector import PoseDetector
from src.angle_calculator import AngleCalculator
from src.exercise_analyzer import SquatAnalyzer

def test_pipeline():
    """Test if all components work together"""
    
    print("Testing Pose Detection...")
    detector = PoseDetector()
    assert detector is not None, "Pose detector failed to initialize"
    print("✓ Pose detector initialized")
    
    print("Testing Angle Calculator...")
    calc = AngleCalculator()
    
    # Test with known angles
    p1 = (0, 0)
    p2 = (0, 100)
    p3 = (100, 100)
    
    angle = calc.calculate_angle(p1, p2, p3)
    assert 89 <= angle <= 91, f"Expected 90°, got {angle}°"
    print(f"✓ Angle calculation accurate: {angle:.2f}°")
    
    print("Testing Squat Analyzer...")
    analyzer = SquatAnalyzer()
    assert analyzer.rep_count == 0, "Initial rep count should be 0"
    print("✓ Squat analyzer initialized")
    
    print("" + "="*50)
    print("ALL TESTS PASSED ✓")
    print("="*50)
    
    detector.close()

if __name__ == "__main__":
    test_pipeline()