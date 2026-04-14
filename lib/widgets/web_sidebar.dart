import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/color_palette.dart';
import '../core/constants/layout_constants.dart';

class WebSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;

  const WebSidebar({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      width: LayoutConstants.sidebarWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: Column(
        children: [
          _buildBrandHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                _buildSectionHeader(context, 'CORE'),
                _buildNavItem(context, 0, LucideIcons.layoutDashboard, 'Dashboard'),
                _buildNavItem(context, 1, LucideIcons.database, 'Masters'),
                
                const SizedBox(height: 24),
                _buildSectionHeader(context, 'OPERATIONS'),
                _buildNavItem(context, 2, LucideIcons.arrowDownCircle, 'Inward Stock'),
                _buildNavItem(context, 3, LucideIcons.arrowUpCircle, 'Outward Stock'),
                _buildNavItem(context, 4, LucideIcons.clipboardList, 'Production Tasks'),
                _buildNavItem(context, 5, LucideIcons.layoutGrid, 'Lot Assignment'),
                _buildNavItem(context, 8, LucideIcons.layers, 'Item Assignment'),
                _buildNavItem(context, 6, LucideIcons.calendar, 'Cutting Planning'),
                _buildNavItem(context, 9, LucideIcons.scissors, 'Cutting Entry'),
                _buildNavItem(context, 10, LucideIcons.truck, 'Stitching Delivery DC'),
                _buildNavItem(context, 11, LucideIcons.box, 'Iron & Packing DC'),
                
                const SizedBox(height: 24),
                _buildSectionHeader(context, 'ANALYTICS & REPORTS'),
                _buildNavItem(context, 7, LucideIcons.barChart3, 'Master Reports'),
                _buildNavItem(context, 12, LucideIcons.barChart2, 'Cut Stock Report'),
                _buildNavItem(context, 13, LucideIcons.fileText, 'Cutting Entry Report'),

                const SizedBox(height: 24),
                _buildSectionHeader(context, 'SYSTEM'),
                _buildNavItem(context, 14, LucideIcons.scale, 'Scale Settings'),
                _buildNavItem(context, 15, LucideIcons.palette, 'App Theme'),
                _buildNavItem(context, 16, LucideIcons.bot, 'AI Chatbot'),
              ],
            ),
          ),
          _buildUserFooter(context),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, primaryColor]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.factory, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'OM VINAYAGA',
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: ColorPalette.textPrimary,
                    letterSpacing: 0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'GARMENTS ERP',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: ColorPalette.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: ColorPalette.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final primaryColor = Theme.of(context).primaryColor;
    final bool isActive = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: () => onIndexChanged(index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? primaryColor.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? primaryColor : ColorPalette.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? primaryColor : ColorPalette.textSecondary,
                ),
              ),
              if (isActive) ...[
                const Spacer(),
                Container(
                  width: 4,
                  height: 4,
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
    );
  }

  Widget _buildUserFooter(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorPalette.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: primaryColor,
            child: const Icon(LucideIcons.user, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Admin User',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColorPalette.textPrimary,
                  ),
                ),
                Text(
                  'Main Branch',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: ColorPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.logOut, size: 14, color: ColorPalette.textMuted),
        ],
      ),
    );
  }
}
