import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  
  String _selectedGender = 'Male';
  final List<String> _genders = ['Male', 'Female', 'Other'];
  bool _isLoading = false;

  Future<void> _signUp() async {
    if (_emailController.text.isEmpty || 
        _passwordController.text.isEmpty ||
        _ageController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _heightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final int? age = int.tryParse(_ageController.text);
    final double? weightKg = double.tryParse(_weightController.text);
    final double? heightCm = double.tryParse(_heightController.text);

    if (age == null || weightKg == null || heightCm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numbers for Age, Weight, and Height')),
      );
      return;
    }

    // Calculate BMI = kg / m^2
    final double heightM = heightCm / 100;
    final double bmi = weightKg / (heightM * heightM);

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'gender': _selectedGender,
          'age': age,
          'weight_kg': weightKg,
          'height_cm': heightCm,
          'bmi': double.parse(bmi.toStringAsFixed(1)), // Keep it to 1 decimal place
        }
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Success! You can now log in.'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context); // Go back to login screen
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.person_add, size: 80, color: AppTheme.secondary),
              const SizedBox(height: 24),
              const Text(
                'Create Account',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign up to track your exercise history',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: AppTheme.bgDarkSecondary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email, color: Colors.white70),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: AppTheme.bgDarkSecondary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              
              // Gender Dropdown
              DropdownButtonFormField<String>(
                value: _selectedGender,
                dropdownColor: AppTheme.bgDarkSecondary,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Gender',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: AppTheme.bgDarkSecondary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.people, color: Colors.white70),
                ),
                items: _genders.map((String gender) {
                  return DropdownMenuItem<String>(
                    value: gender,
                    child: Text(gender),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedGender = newValue!;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Age Field
              TextField(
                controller: _ageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Age',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: AppTheme.bgDarkSecondary,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.cake, color: Colors.white70),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              
              // Weight & Height Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weightController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Weight (kg)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: AppTheme.bgDarkSecondary,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.monitor_weight, color: Colors.white70),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _heightController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Height (cm)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: AppTheme.bgDarkSecondary,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.height, color: Colors.white70),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Sign Up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
