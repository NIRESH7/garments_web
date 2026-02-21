import 'package:flutter/material.dart';
import '../../core/theme/color_palette.dart';

import 'package:flutter_animate/flutter_animate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
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
            Image.asset('assets/images/app_logo.png', width: 150, height: 150)
                .animate()
                .scale(duration: 800.ms, curve: Curves.easeOutBack)
                .fadeIn(duration: 800.ms),
            const SizedBox(height: 30),
            const Text(
                  'Om Vinayaka',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: ColorPalette.primary,
                    letterSpacing: 1.2,
                  ),
                )
                .animate()
                .fade(delay: 500.ms, duration: 600.ms)
                .slideY(begin: 0.5, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 10),
            const Text(
              'Crafting Quality, Weaving Trust',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ).animate().fade(delay: 1000.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
