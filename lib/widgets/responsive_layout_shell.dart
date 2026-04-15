import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/layout_constants.dart';
import '../core/theme/color_palette.dart';
import '../core/theme/theme_provider.dart';
import '../screens/auth/login_screen.dart';
import 'web_sidebar.dart';
import 'app_drawer.dart';

class ResponsiveLayoutShell extends ConsumerStatefulWidget {
  final Widget child;
  final int selectedIndex;
  final Function(int) onIndexChanged;
  final String title;
  final List<Widget>? headerActions;

  const ResponsiveLayoutShell({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.title,
    this.headerActions,
  });

  @override
  ConsumerState<ResponsiveLayoutShell> createState() => _ResponsiveLayoutShellState();
}

class _ResponsiveLayoutShellState extends ConsumerState<ResponsiveLayoutShell> {
  bool _isSidebarCollapsed = false;

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }


  @override
  Widget build(BuildContext context) {
    final bool isWeb = LayoutConstants.isWeb(context);

    if (isWeb) {
      return Scaffold(
        backgroundColor: ColorPalette.background,
        body: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: _isSidebarCollapsed 
                ? LayoutConstants.collapsedSidebarWidth 
                : LayoutConstants.sidebarWidth,
              child: WebSidebar(
                selectedIndex: widget.selectedIndex,
                onIndexChanged: widget.onIndexChanged,
                isCollapsed: _isSidebarCollapsed,
                onToggle: _toggleSidebar,
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _buildWebHeader(),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: ColorPalette.background,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.bell, size: 20),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AppDrawer(),
      body: widget.child,
    );
  }

  Widget _buildWebHeader() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: ColorPalette.border, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            widget.title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: ColorPalette.textPrimary,
            ),
          ),
          const Spacer(),
          if (widget.headerActions != null) ...[
            ...widget.headerActions!,
            const SizedBox(width: 8),
            Container(width: 1, height: 24, color: ColorPalette.border),
            const SizedBox(width: 16),
          ],
          _buildHeaderAction(LucideIcons.search),
          const SizedBox(width: 8),
          _buildNotificationBadge(),
          const SizedBox(width: 16),
          _buildUserActionTrigger(),
          const SizedBox(width: 8),
          _buildHeaderAction(LucideIcons.logOut, color: ColorPalette.error, onTap: _showLogoutDialog),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, {Color? color, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: color ?? ColorPalette.textSecondary),
      ),
    );
  }

  Widget _buildNotificationBadge() {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            const Icon(LucideIcons.bell, size: 18, color: ColorPalette.textSecondary),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: ColorPalette.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserActionTrigger() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: ColorPalette.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: ColorPalette.primary.withOpacity(0.1),
            child: Text(
              'A',
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: ColorPalette.primary),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Admin User',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ColorPalette.textPrimary),
          ),
          const SizedBox(width: 4),
          const Icon(LucideIcons.chevronDown, size: 14, color: ColorPalette.textMuted),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to terminate your session?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(themeProvider.notifier).resetTheme();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(foregroundColor: ColorPalette.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
