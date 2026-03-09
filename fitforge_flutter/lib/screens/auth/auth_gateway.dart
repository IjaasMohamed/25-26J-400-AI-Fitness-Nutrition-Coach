import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pose_detection_realtime/screens/home_screen.dart';
import 'package:pose_detection_realtime/screens/auth/login_screen.dart';

class AuthGateway extends StatefulWidget {
  const AuthGateway({super.key});

  @override
  State<AuthGateway> createState() => _AuthGatewayState();
}

class _AuthGatewayState extends State<AuthGateway> {
  @override
  void initState() {
    super.initState();
    // Listen for authentication changes automatically
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // If a session exists, return Home, else return Login
    final session = Supabase.instance.client.auth.currentSession;
    
    if (session != null) {
      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}
