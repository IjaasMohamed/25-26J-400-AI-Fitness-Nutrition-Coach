import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pose_detection_realtime/DetectionScreen.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';

class Exerciselistingscreen extends StatefulWidget {
  const Exerciselistingscreen({super.key});

  @override
  State<Exerciselistingscreen> createState() => _ExerciselistingscreenState();
}

class _ExerciselistingscreenState extends State<Exerciselistingscreen> {
  List<ExerciseDataModel> exerciseList = [];

  loadData(){
    exerciseList.add(ExerciseDataModel("Push Ups", "pushup.gif", Color(0xff005F9C), ExcerciseType.PushUps));
    exerciseList.add(ExerciseDataModel("Squats", "squat.gif", Color(0xffDF5089), ExcerciseType.Squats));
    exerciseList.add(ExerciseDataModel("Plank to Downward Dog", "plank.gif", Color(0xffFD8636), ExcerciseType.PlankToDownwardDog));
    exerciseList.add(ExerciseDataModel("Jumping Jack", "jumping.gif", Color(0xff000000), ExcerciseType.JumpingJack));
    exerciseList.add(ExerciseDataModel("High Knees", "jumping.gif", Colors.deepPurple, ExcerciseType.HighKnees));
    setState(() {
      exerciseList;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("AI Exercise ")),
      body: Container(
        child: ListView.builder(
          itemBuilder: (context, index) {
            return InkWell(
              onTap: (){
                Navigator.push(context, MaterialPageRoute(builder: (context)=>Detectionscreen(exerciseDataModel: exerciseList[index])));

              },
              child: Container(
                decoration: BoxDecoration(
                  color: exerciseList[index].color,
                  borderRadius: BorderRadius.circular(20),
                ),
                height: 150,
                margin: EdgeInsets.all(10),
                padding: EdgeInsets.all(10),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        exerciseList[index].title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Align(alignment: Alignment.centerRight, child: Image.asset('assets/${exerciseList[index].image}',)),
                  ],
                ),
              ),
            );
          },
          itemCount: exerciseList.length ,
        ),
      ),
    );
  }
}
