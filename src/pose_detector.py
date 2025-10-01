import cv2
import mediapipe as mp
import numpy as np
from typing import Optional, Dict, Tuple

class PoseDetector:
    """
    Real-time pose detection using MediaPipe Pose.
    Optimized for mobile devices with 30 FPS target.
    """
    
    def __init__(self, 
                 static_mode=False,
                 model_complexity=1,  # 0=Lite, 1=Full, 2=Heavy
                 smooth_landmarks=True,
                 min_detection_confidence=0.5,
                 min_tracking_confidence=0.5):
        """
        Initialize MediaPipe Pose detector.
        
        Args:
            model_complexity: 0 for fastest (mobile), 1 for balanced, 2 for accuracy
            smooth_landmarks: Enable temporal smoothing for stability
        """
        self.mp_pose = mp.solutions.pose
        self.mp_draw = mp.solutions.drawing_utils
        
        self.pose = self.mp_pose.Pose(
            static_image_mode=static_mode,
            model_complexity=model_complexity,
            smooth_landmarks=smooth_landmarks,
            min_detection_confidence=min_detection_confidence,
            min_tracking_confidence=min_tracking_confidence
        )
        
        self.results = None
        self.landmarks = None
        
    def detect(self, frame: np.ndarray, draw=True) -> Tuple[np.ndarray, bool]:
        """
        Detect pose in a single frame.
        
        Args:
            frame: Input BGR image from camera
            draw: Whether to draw skeleton on frame
            
        Returns:
            Tuple of (processed_frame, detection_success)
        """
        # Convert BGR to RGB (MediaPipe requirement)
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # Process frame
        self.results = self.pose.process(frame_rgb)
        
        # Extract landmarks if detected
        if self.results.pose_landmarks:
            self.landmarks = self.results.pose_landmarks.landmark
            
            if draw:
                self.mp_draw.draw_landmarks(
                    frame, 
                    self.results.pose_landmarks,
                    self.mp_pose.POSE_CONNECTIONS,
                    self.mp_draw.DrawingSpec(color=(0, 255, 0), thickness=2, circle_radius=2),
                    self.mp_draw.DrawingSpec(color=(0, 0, 255), thickness=2)
                )
            
            return frame, True
        
        return frame, False
    
    def get_landmark_coordinates(self, landmark_id: int, 
                                 frame_shape: Tuple[int, int]) -> Optional[Tuple[int, int]]:
        """
        Get pixel coordinates of a specific landmark.
        
        Args:
            landmark_id: MediaPipe landmark ID (0-32)
            frame_shape: (height, width) of the frame
            
        Returns:
            (x, y) pixel coordinates or None if not detected
        """
        if not self.landmarks:
            return None
        
        if landmark_id >= len(self.landmarks):
            return None
        
        landmark = self.landmarks[landmark_id]
        h, w = frame_shape[:2]
        
        # Convert normalized coordinates to pixels
        x = int(landmark.x * w)
        y = int(landmark.y * h)
        
        return (x, y)
    
    def get_all_landmarks(self, frame_shape: Tuple[int, int]) -> Optional[Dict[str, Tuple[int, int]]]:
        """
        Get all 33 landmark coordinates as a dictionary.
        
        Returns:
            Dictionary mapping landmark names to (x, y) coordinates
        """
        if not self.landmarks:
            return None
        
        h, w = frame_shape[:2]
        landmarks_dict = {}
        
        # Key landmarks for exercise analysis
        landmark_names = {
            0: 'nose',
            11: 'left_shoulder', 12: 'right_shoulder',
            13: 'left_elbow', 14: 'right_elbow',
            15: 'left_wrist', 16: 'right_wrist',
            23: 'left_hip', 24: 'right_hip',
            25: 'left_knee', 26: 'right_knee',
            27: 'left_ankle', 28: 'right_ankle',
        }
        
        for idx, name in landmark_names.items():
            landmark = self.landmarks[idx]
            landmarks_dict[name] = (
                int(landmark.x * w),
                int(landmark.y * h),
                landmark.z  # depth information
            )
        
        return landmarks_dict
    
    def close(self):
        """Release resources."""
        self.pose.close()