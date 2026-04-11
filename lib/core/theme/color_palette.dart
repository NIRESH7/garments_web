import 'package:flutter/material.dart';

class ColorPalette {
  // SaaS Design System Colors
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;

  // Single Primary Identity
  static const Color primary = Color(0xFF0284C7); // SaaS Deep Blue
  
  // Neutral Gray Scale
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0EA5E9);
  static const Color secondary = Color(0xFF64748B); // Neutral Secondary

  // Legacy Support (Flat version)
  static const LinearGradient dashboardGradient = LinearGradient(
    colors: [primary, primary],
  );

  // Minimal Shadow (Subtle elevation)
  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
  ];
}
