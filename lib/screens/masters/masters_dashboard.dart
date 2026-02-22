import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import 'categories_master_screen.dart';
import 'dropdown_setup_screen.dart';
import 'item_master_screen.dart';
import 'party_master_screen.dart';
import 'color_prediction_screen.dart';
import 'stock_limit_master_screen.dart';

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
            title: 'Categories Master',
            subtitle: 'Create and manage master categories',
            icon: LucideIcons.layoutTemplate,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CategoriesMasterScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _MenuTile(
            title: 'Dropdown Setup',
            subtitle: 'Add values to categories',
            icon: LucideIcons.listPlus,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DropdownSetupScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _MenuTile(
            title: 'Party Master',
            subtitle: 'Manage parties and details',
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
            title: 'Item Group Master',
            subtitle: 'Manage items and groups',
            icon: LucideIcons.layoutGrid,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ItemMasterScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _MenuTile(
            title: 'Color Prediction',
            subtitle: 'Predict garment dye color from recipe',
            icon: LucideIcons.palette,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ColorPredictionScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _MenuTile(
            title: 'Stock Limit Setup',
            subtitle: 'Set Min/Max stock for Lot/DIA',
            icon: LucideIcons.barChart4,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StockLimitMasterScreen(),
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
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor),
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
