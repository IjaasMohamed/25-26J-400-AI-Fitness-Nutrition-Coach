import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pose_detection_realtime/theme/app_theme.dart';

class RestTimerScreen extends StatefulWidget {
  final int restSeconds;
  final String message;
  final VoidCallback onRestComplete;

  const RestTimerScreen({
    super.key,
    required this.restSeconds,
    required this.message,
    required this.onRestComplete,
  });

  @override
  State<RestTimerScreen> createState() => _RestTimerScreenState();
}

class _RestTimerScreenState extends State<RestTimerScreen> with SingleTickerProviderStateMixin {
  late int _remaining;
  Timer? _timer;
  late FlutterTts _tts;
  late AnimationController _animController;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _remaining = widget.restSeconds;
    _tts = FlutterTts();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.restSeconds),
    );
    _progressAnim = Tween<double>(begin: 1.0, end: 0.0).animate(_animController);

    // Speak the rest message
    _speak(widget.message);

    // Start countdown + animation
    _animController.forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _remaining--);
      if (_remaining <= 3 && _remaining > 0) {
        _speak(_remaining.toString());
      }
      if (_remaining <= 0) {
        t.cancel();
        _onDone();
      }
    });
  }

  Future<void> _speak(String text) async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.speak(text);
  }

  void _onDone() async {
    await _speak('Go!');
    // Give 1.5 second buffer so camera doesn't open immediately after "1"
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) widget.onRestComplete();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.self_improvement, size: 64, color: AppTheme.secondary),
            const SizedBox(height: 24),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            // Circular countdown
            SizedBox(
              width: 180,
              height: 180,
              child: AnimatedBuilder(
                animation: _progressAnim,
                builder: (context, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: _progressAnim.value,
                          strokeWidth: 10,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondary),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$_remaining',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'SEC REST',
                            style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 2),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: _onDone,
              child: const Text('Skip Rest →', style: TextStyle(color: AppTheme.secondary, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
