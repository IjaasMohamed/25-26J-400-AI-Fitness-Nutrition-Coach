import 'dart:ui';
import 'package:flutter/material.dart';

enum ExcerciseType {
  PushUps,
  Squats,
  PlankToDownwardDog,
  JumpingJack,
  HighKnees
}

class ExerciseDataModel {
  String title;
  String image;
  Color color;
  ExcerciseType type;
  String difficulty;
  int caloriesPerRep;
  String description;

  ExerciseDataModel(
    this.title,
    this.image,
    this.color,
    this.type, {
    this.difficulty = "Medium",
    this.caloriesPerRep = 3,
    this.description = "",
  });

  static List<ExerciseDataModel> allExercises() {
    return [
      ExerciseDataModel("Push Ups", "pushup.gif", const Color(0xFF6C63FF), ExcerciseType.PushUps, difficulty: "Medium", caloriesPerRep: 5, description: "Build upper body strength"),
      ExerciseDataModel("Squats", "squat.gif", const Color(0xFFDF5089), ExcerciseType.Squats, difficulty: "Easy", caloriesPerRep: 3, description: "Strengthen your legs & glutes"),
      ExerciseDataModel("Plank to Downward Dog", "plank.gif", const Color(0xFFFD8636), ExcerciseType.PlankToDownwardDog, difficulty: "Hard", caloriesPerRep: 8, description: "Full body core workout"),
      ExerciseDataModel("Jumping Jack", "jumping.gif", const Color(0xFF00D9FF), ExcerciseType.JumpingJack, difficulty: "Easy", caloriesPerRep: 2, description: "Cardio & coordination"),
      ExerciseDataModel("High Knees", "jumping.gif", const Color(0xFF8B5CF6), ExcerciseType.HighKnees, difficulty: "Medium", caloriesPerRep: 4, description: "Boost your heart rate"),
    ];
  }
}
