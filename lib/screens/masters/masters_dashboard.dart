import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import 'lot_master_screen.dart';
import 'item_master_screen.dart';
import 'party_master_screen.dart';
import 'dropdown_setup_screen.dart';

class MastersDashboard extends StatelessWidget {
  const MastersDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Masters'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _MenuTile(
            title: 'Lot Master',
            subtitle: 'Create and manage production lots',
            icon: LucideIcons.package,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LotMasterScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _MenuTile(
            title: 'Item Master',
            subtitle: 'Manage fabric items and parameters',
            icon: LucideIcons.layers,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ItemMasterScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _MenuTile(
            title: 'Party Master',
            subtitle: 'Customer and supplier directory',
            icon: LucideIcons.users,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PartyMasterScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _MenuTile(
            title: 'Dropdown Setup',
            subtitle: 'Configure reusable dropdown values',
            icon: LucideIcons.settings2,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DropdownSetupScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ColorPalette.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: ColorPalette.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: ColorPalette.textSecondary,
          ),
        ),
        trailing: const Icon(LucideIcons.chevronRight, size: 18),
        onTap: onTap,
      ),
    );
  }
}
