import 'dart:ui';

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
}