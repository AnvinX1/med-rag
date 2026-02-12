import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simulate loading process
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // EKG heartbeat animation
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.monitor_heart,
                size: 64,
                color: Color(0xFF0D9488),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .scale(
                duration: 1200.ms,
                curve: Curves.easeInOut,
                begin: const Offset(1, 1),
                end: const Offset(1.1, 1.1),
              )
              .then()
              .scale(
                duration: 600.ms,
                curve: Curves.easeInOut,
                end: const Offset(1, 1),
              ),
            ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms),
            
            const SizedBox(height: 32),
            
            Text(
              'Medical GenAI',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: Colors.blueGrey[900],
              ),
            ).animate().fadeIn(delay: 400.ms).moveY(begin: 10, end: 0),
            
            const SizedBox(height: 8),
            
            Text(
              'AI-Powered Clinical Assistant',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blueGrey[500],
                letterSpacing: 0.5,
              ),
            ).animate().fadeIn(delay: 600.ms).moveY(begin: 10, end: 0),
            
            const SizedBox(height: 50),
            
            // Loading indicator
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
              ),
            ).animate().fadeIn(delay: 1000.ms),
          ],
        ),
      ),
    );
  }
}
