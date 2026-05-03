import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:pose_detection_realtime/screens/auth/auth_gateway.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  
  await Supabase.initialize(
    url: 'https://qqvwvuwwcfihzoiwjesa.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFxdnd2dXd3Y2ZpaHpvaXdqZXNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3MDI1NDksImV4cCI6MjA5MzI3ODU0OX0.lw_y_bciXyk4VyCX4uuM8FSWUnmMbup1C_t_SsK2WKI',
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
