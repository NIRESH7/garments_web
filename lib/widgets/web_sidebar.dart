import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/color_palette.dart';
import '../core/constants/layout_constants.dart';

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
      width: LayoutConstants.sidebarWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                if (!isCollapsed) _buildSectionHeader(context, 'CORE'),
                _buildNavItem(context, 0, LucideIcons.layoutDashboard, 'Dashboard'),
                _buildNavItem(context, 1, LucideIcons.database, 'Masters'),
                
                const SizedBox(height: 24),
                if (!isCollapsed) _buildSectionHeader(context, 'OPERATIONS'),
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
                if (!isCollapsed) _buildSectionHeader(context, 'ANALYTICS & REPORTS'),
                _buildNavItem(context, 7, LucideIcons.barChart3, 'Master Reports'),
                _buildNavItem(context, 12, LucideIcons.barChart2, 'Cut Stock Report'),
                _buildNavItem(context, 13, LucideIcons.fileText, 'Cutting Entry Report'),

                const SizedBox(height: 24),
                if (!isCollapsed) _buildSectionHeader(context, 'SYSTEM'),
                _buildNavItem(context, 14, LucideIcons.scale, 'Scale Settings'),
                _buildNavItem(context, 15, LucideIcons.palette, 'App Theme'),
                _buildNavItem(context, 16, LucideIcons.bot, 'AI Chatbot'),
              ],
            ),
          ),
          _buildCollapseToggle(context),
          _buildUserFooter(context),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 10 : 12,
        vertical: 12, // Reduced from 24
      ),
      margin: EdgeInsets.all(isCollapsed ? 6 : 8), // Reduced from 8/12
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(12), // Slightly more compact radius
        boxShadow: ColorPalette.softShadow,
      ),
      child: isCollapsed
          ? Center(
              child: Icon(LucideIcons.userCircle, color: Colors.white, size: 24),
            )
          : Row(
              children: [
                CircleAvatar(
                  radius: 16, // Reduced from 20
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(LucideIcons.user, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Garments Admin',
                        style: GoogleFonts.outfit(
                          fontSize: 13, // Reduced from 14
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'admin@garments.com',
                        style: GoogleFonts.inter(
                          fontSize: 9, // Reduced from 10
                          color: Colors.white.withOpacity(0.7),
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
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 12,
        vertical: 2,
      ),
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: InkWell(
          onTap: () => onIndexChanged(index),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isActive ? primaryColor.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
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
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? primaryColor : ColorPalette.textSecondary,
                      ),
                    ),
                  ),
                  if (isActive)
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
      ),
    );
  }

  Widget _buildCollapseToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                isCollapsed ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
                size: 16,
                color: ColorPalette.textMuted,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                Text(
                  'Collapse Sidebar',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ColorPalette.textMuted,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 0 : 20,
        vertical: isCollapsed ? 12 : 20,
      ),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorPalette.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(LucideIcons.logOut, size: 16, color: ColorPalette.textMuted),
          if (!isCollapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Logout Session',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ColorPalette.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
