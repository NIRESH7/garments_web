import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  void _login() {
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPalette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),

              // Logo
              Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: ColorPalette.dashboardGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: ColorPalette.primary.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.factory,
                      color: Colors.white,
                      size: 32,
                    ),
                  )
                  .animate()
                  .scale(
                    delay: 200.ms,
                    duration: 600.ms,
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(),

              const SizedBox(height: 32),

              Text(
                'Textile Lot\nManagement',
                style: Theme.of(context).textTheme.displayLarge,
              ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2),

              const SizedBox(height: 8),

              Text(
                'Welcome back! Please enter your details.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: ColorPalette.textSecondary,
                ),
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 48),

              // Form
              Column(
                children: [
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(LucideIcons.user, size: 20),
                    ),
                  ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1),

                  const SizedBox(height: 20),

                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(LucideIcons.lock, size: 20),
                      suffixIcon: Icon(LucideIcons.eyeOff, size: 20),
                    ),
                  ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.1),
                ],
              ),

              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ).animate().fadeIn(delay: 1100.ms),

              const SizedBox(height: 40),

              ElevatedButton(onPressed: _login, child: const Text('Sign In'))
                  .animate()
                  .fadeIn(delay: 1200.ms)
                  .scale(begin: const Offset(0.95, 0.95)),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: TextStyle(color: ColorPalette.textSecondary),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Contact Admin',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 1400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
