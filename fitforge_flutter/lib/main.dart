import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:pose_detection_realtime/screens/auth/auth_gateway.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  
  // TODO: Replace with the actual Supabase URL and Anon Key
  await Supabase.initialize(
    url: 'https://mlhrqvnoofxxdvhlqqpy.supabase.co',
    anonKey: 'sb_publishable_ZJmwMDnenGATLhiT7EFMtg_uA427Lib',
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exercise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: AuthGateway(),
    );
  }
}
