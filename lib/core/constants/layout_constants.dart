import 'package:flutter/material.dart';

class LayoutConstants {
  // 8px Base Spacing Grid
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  static const double s48 = 48.0;
  static const double s64 = 64.0;

  // Border Radii
  static const double r8 = 8.0;
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r24 = 24.0;

  // Responsive Breakpoints
  static const double mobile = 600.0;
  static const double tablet = 800.0;
  
  // Content Constraints
  static const double maxContentWidth = 1200.0;
  static const double sidebarWidth = 240.0;
  static const double collapsedSidebarWidth = 72.0;

  // Helpers
  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < mobile;
  static bool isTablet(BuildContext context) => 
      MediaQuery.of(context).size.width >= mobile && MediaQuery.of(context).size.width < tablet;
  static bool isWeb(BuildContext context) => MediaQuery.of(context).size.width >= tablet;
}

class Gaps {
  static const h4 = SizedBox(height: 4.0);
  static const h8 = SizedBox(height: LayoutConstants.s8);
  static const h12 = SizedBox(height: LayoutConstants.s12);
  static const h16 = SizedBox(height: LayoutConstants.s16);
  static const h20 = SizedBox(height: LayoutConstants.s20);
  static const h24 = SizedBox(height: LayoutConstants.s24);
  static const h32 = SizedBox(height: LayoutConstants.s32);
  static const h40 = SizedBox(height: LayoutConstants.s40);
  static const h48 = SizedBox(height: LayoutConstants.s48);
  static const h64 = SizedBox(height: LayoutConstants.s64);

  static const w4 = SizedBox(width: 4.0);
  static const w8 = SizedBox(width: LayoutConstants.s8);
  static const w12 = SizedBox(width: LayoutConstants.s12);
  static const w16 = SizedBox(width: LayoutConstants.s16);
  static const w20 = SizedBox(width: LayoutConstants.s20);
  static const w24 = SizedBox(width: LayoutConstants.s24);
  static const w32 = SizedBox(width: LayoutConstants.s32);
  static const w40 = SizedBox(width: LayoutConstants.s40);
  static const w48 = SizedBox(width: LayoutConstants.s48);
  static const w64 = SizedBox(width: LayoutConstants.s64);
}
