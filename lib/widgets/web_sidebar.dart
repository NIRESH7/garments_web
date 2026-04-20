import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/color_palette.dart';
import '../core/constants/layout_constants.dart';

// Use locally-bundled Lucide font to bypass package font loading issues on Web
class _L {
  static IconData _i(int code) => IconData(code, fontFamily: 'Lucide');
  static final layoutDashboard = _i(0xf389);
  static final database        = _i(0xf26c);
  static final arrowDownCircle = _i(0xf140);
  static final arrowUpCircle   = _i(0xf15f);
  static final clipboardList   = _i(0xf21c);
  static final layoutGrid      = _i(0xf38a);
  static final layers          = _i(0xf387);
  static final calendar        = _i(0xf1d2);
  static final scissors        = _i(0xf4a8);
  static final truck           = _i(0xf54f);
  static final box             = _i(0xf1c1);
  static final barChart3       = _i(0xf187);
  static final barChart2       = _i(0xf186);
  static final fileText        = _i(0xf2d3);
  static final scale           = _i(0xf49f);
  static final palette         = _i(0xf41f);
  static final bot             = _i(0xf1c0);
  static final package         = _i(0xf414);
  static final chevronLeft     = _i(0xf1f9);
  static final chevronRight    = _i(0xf1fb);
  static final logOut          = _i(0xf3b0);
  static final shieldCheck     = _i(0xf49d);
  static final calendarDays     = _i(0xf1d4);
}

class WebSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;
  final bool isCollapsed;
  final VoidCallback onToggle;

  const WebSidebar({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      width: isCollapsed ? LayoutConstants.collapsedSidebarWidth : LayoutConstants.sidebarWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: Column(
        children: [
          // Brand Header
          _buildBrandHeader(context),
          
          const Divider(height: 1, color: ColorPalette.border),
          
          // Primary Navigation
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                if (!isCollapsed) _buildSectionHeader(context, 'CORE'),
                _buildNavItem(context, 0, _L.layoutDashboard, 'Dashboard'),
                _buildNavItem(context, 1, _L.database, 'Masters'),
                
                const SizedBox(height: 16),
                if (!isCollapsed) _buildSectionHeader(context, 'OPERATIONS'),
                _buildNavItem(context, 2, _L.arrowDownCircle, 'Inward Stock'),
                _buildNavItem(context, 3, _L.arrowUpCircle, 'Outward Stock'),
                _buildNavItem(context, 4, _L.clipboardList, 'Production Tasks'),
                _buildNavItem(context, 5, _L.layoutGrid, 'Lot Assignment'),
                _buildNavItem(context, 8, _L.layers, 'Item Assignment'),
                _buildNavItem(context, 6, _L.calendar, 'Cutting Planning'),
                _buildNavItem(context, 15, _L.calendarDays, 'Cutting Daily Plan'),
                _buildNavItem(context, 14, _L.shieldCheck, 'Complaints'),
                _buildNavItem(context, 9, _L.scissors, 'Cutting Entry'),
                _buildNavItem(context, 10, _L.truck, 'Stitching Delivery DC'),
                _buildNavItem(context, 11, _L.box, 'Iron & Packing DC'),
                
                const SizedBox(height: 16),
                if (!isCollapsed) _buildSectionHeader(context, 'ANALYTICS & REPORTS'),
                _buildNavItem(context, 7, _L.barChart3, 'Master Reports'),
                _buildNavItem(context, 12, _L.barChart2, 'Cut Stock Report'),
                _buildNavItem(context, 13, _L.fileText, 'Cutting Entry Report'),

                const SizedBox(height: 16),
                if (!isCollapsed) _buildSectionHeader(context, 'SYSTEM'),
                _buildNavItem(context, 16, _L.scale, 'Scale Settings'),
                _buildNavItem(context, 17, _L.palette, 'App Theme'),
                _buildNavItem(context, 18, _L.bot, 'AI Chatbot'),
              ],
            ),
          ),

          const Divider(height: 1, color: ColorPalette.border),
          
          // Bottom Actions Section
          _buildBottomActions(context),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 20),
      alignment: isCollapsed ? Alignment.center : Alignment.centerLeft,
      child: isCollapsed 
        ? Icon(_L.package, color: Theme.of(context).primaryColor, size: 24)
        : Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_L.package, color: Theme.of(context).primaryColor, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OM VINAYAGA',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: ColorPalette.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'GARMENTS',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: ColorPalette.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: ColorPalette.textMuted,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final primaryColor = Theme.of(context).primaryColor;
    final bool isActive = selectedIndex == index;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 12, vertical: 1),
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: InkWell(
          onTap: () => onIndexChanged(index),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isActive ? primaryColor.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive ? primaryColor : ColorPalette.textSecondary,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? primaryColor : ColorPalette.textSecondary,
                      ),
                    ),
                  ),
                  if (isActive)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildActionItem(
             context, 
             icon: isCollapsed ? _L.chevronRight : _L.chevronLeft,
             label: 'Collapse Sidebar',
             onTap: onToggle,
          ),
          const SizedBox(height: 4),
          _buildActionItem(
             context, 
             icon: _L.logOut,
             label: 'Logout Session',
             onTap: () {
               // Navigation logic handled by parent (DashboardScreen)
               onIndexChanged(99); 
             },
             color: ColorPalette.error,
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, {
    required IconData icon, 
    required String label, 
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color ?? ColorPalette.textMuted),
            if (!isCollapsed) ...[
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color ?? ColorPalette.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

