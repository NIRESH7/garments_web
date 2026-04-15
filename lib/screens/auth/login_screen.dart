import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/layout_constants.dart';
import '../../services/mobile_api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: "admin1@example.com");
  final _passwordController = TextEditingController(text: "password123");
  final _api = MobileApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await _api.login(
      _emailController.text,
      _passwordController.text,
    );
    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Email or Password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPalette.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeader(),
                Gaps.h32,
                _buildLoginCard(),
                Gaps.h32,
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(LayoutConstants.s16),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Icon(LucideIcons.factory, color: ColorPalette.primary, size: 32),
        ),
        Gaps.h20,
        Text(
          'Om Vinayaka Garments',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: ColorPalette.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        Gaps.h8,
        Text(
          'Enterprise Resource Planning',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: ColorPalette.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(LayoutConstants.s40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(LayoutConstants.r24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: Colors.white), // Subtle border for high DPI screens
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sign In',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: ColorPalette.textPrimary,
            ),
          ),
          Gaps.h4,
          Text(
            'Enter your credentials to access your account',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: ColorPalette.textSecondary,
            ),
          ),
          Gaps.h32,
          _buildLoginForm(),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('OFFICIAL EMAIL'),
        Gaps.h8,
        _buildCleanInput(
          controller: _emailController,
          hint: 'admin@garments.erp',
          icon: LucideIcons.mail,
        ),
        Gaps.h24,
        _buildFieldLabel('SECURITY PASSWORD'),
        Gaps.h8,
        _buildCleanInput(
          controller: _passwordController,
          hint: '••••••••',
          icon: LucideIcons.lock,
          isPassword: true,
        ),
        Gaps.h32,
        _buildSignInButton(),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: ColorPalette.textSecondary,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildCleanInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      style: GoogleFonts.inter(
        fontSize: 14, 
        fontWeight: FontWeight.w500,
        color: ColorPalette.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: ColorPalette.textMuted),
        prefixIcon: Icon(icon, size: 18, color: ColorPalette.secondary),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(_obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye, size: 18, color: ColorPalette.secondary),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            )
          : null,
        filled: true,
        fillColor: ColorPalette.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LayoutConstants.r12), 
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LayoutConstants.r12), 
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LayoutConstants.r12), 
          borderSide: const BorderSide(color: ColorPalette.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LayoutConstants.r12),
        gradient: const LinearGradient(
          colors: [ColorPalette.primary, Color(0xFF0EA5E9)],
        ),
        boxShadow: [
          BoxShadow(
            color: ColorPalette.primary.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LayoutConstants.r12)),
        ),
        child: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(
                'Sign In',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
              ),
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'FOR ASSISTANCE CONTACT SYSTEM ADMIN',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: ColorPalette.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }
}
