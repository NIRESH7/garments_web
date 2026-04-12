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
    return Container(
      width: LayoutConstants.sidebarWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: Column(
        children: [
          _buildBrandHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                _buildSectionHeader('CORE'),
                _buildNavItem(0, LucideIcons.layoutDashboard, 'Dashboard'),
                _buildNavItem(1, LucideIcons.database, 'Masters'),
                
                const SizedBox(height: 24),
                _buildSectionHeader('OPERATIONS'),
                _buildNavItem(2, LucideIcons.arrowDownCircle, 'Inward Stock'),
                _buildNavItem(3, LucideIcons.arrowUpCircle, 'Outward Stock'),
                _buildNavItem(4, LucideIcons.clipboardList, 'Production Tasks'),
                _buildNavItem(5, LucideIcons.layoutGrid, 'Lot Assignment'),
                _buildNavItem(6, LucideIcons.calendar, 'Cutting Planning'),
                
                const SizedBox(height: 24),
                _buildSectionHeader('ANALYTICS'),
                _buildNavItem(7, LucideIcons.barChart3, 'Reports'),

                const SizedBox(height: 24),
                _buildSectionHeader('SYSTEM'),
                _buildNavItem(10, LucideIcons.palette, 'App Theme'),
                _buildNavItem(11, LucideIcons.bot, 'AI Chatbot'),
              ],
            ),
          ),
          _buildUserFooter(context),
        ],
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: ColorPalette.dashboardGradient,
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

  Widget _buildSectionHeader(String title) {
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

  Widget _buildNavItem(int index, IconData icon, String label) {
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
            color: isActive ? ColorPalette.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? ColorPalette.primary : ColorPalette.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? ColorPalette.primary : ColorPalette.textSecondary,
                ),
              ),
              if (isActive) ...[
                const Spacer(),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: ColorPalette.primary,
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
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorPalette.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: ColorPalette.primary,
            child: Icon(LucideIcons.user, size: 14, color: Colors.white),
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
