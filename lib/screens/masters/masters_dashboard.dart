import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/layout/web_layout_wrapper.dart';
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
    final isWeb = LayoutConstants.isWeb(context);
    final isMobile = LayoutConstants.isMobile(context);
    final crossAxisCount = isMobile ? 1 : (MediaQuery.of(context).size.width > 1200 ? 3 : 2);

    final List<Map<String, dynamic>> menuItems = [
      {
        'title': 'Categories Master',
        'subtitle': 'Define core garment classification levels',
        'icon': LucideIcons.layoutTemplate,
        'screen': const CategoriesMasterScreen(),
      },
      {
        'title': 'Dropdown Setup',
        'subtitle': 'Manage registry values for all dropdowns',
        'icon': LucideIcons.listPlus,
        'screen': const DropdownSetupScreen(),
      },
      {
        'title': 'Party Master',
        'subtitle': 'Registry for suppliers, clients and vendors',
        'icon': LucideIcons.users,
        'screen': const PartyMasterScreen(),
      },
      {
        'title': 'Item Group Master',
        'subtitle': 'Configure fabric groups and item specifications',
        'icon': LucideIcons.layoutGrid,
        'screen': const ItemMasterScreen(),
      },
      {
        'title': 'Color Prediction',
        'subtitle': 'AI-assisted garment dye color forecasting',
        'icon': LucideIcons.palette,
        'screen': const ColorPredictionScreen(),
      },
      {
        'title': 'Stock Limit Setup',
        'subtitle': 'Configure inventory guardrails and thresholds',
        'icon': LucideIcons.barChart4,
        'screen': const StockLimitMasterScreen(),
      },
    ];

    if (isWeb) {
      return WebLayoutWrapper(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Master Data Management',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: ColorPalette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure and manage core system data',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: ColorPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  mainAxisExtent: 140,
                ),
                itemCount: menuItems.length,
                itemBuilder: (context, index) => _MenuCard(data: menuItems[index]),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: isMobile ? null : const SizedBox.shrink(),
        toolbarHeight: isMobile ? null : 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile) const SizedBox(height: 32),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: menuItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _MenuCard(data: menuItems[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _MenuCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isWeb = LayoutConstants.isWeb(context);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorPalette.border),
        boxShadow: isWeb ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => data['screen']),
        ),
        hoverColor: ColorPalette.primary.withOpacity(0.04),
        child: Padding(
          padding: EdgeInsets.all(isWeb ? 28 : 24),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isWeb ? 14 : 12),
                decoration: BoxDecoration(
                  color: ColorPalette.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data['icon'], color: ColorPalette.primary, size: isWeb ? 24 : 22),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'],
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: isWeb ? 16 : 15,
                        color: ColorPalette.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data['subtitle'],
                      style: GoogleFonts.inter(
                        fontSize: isWeb ? 13 : 11,
                        color: ColorPalette.textMuted,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: isWeb ? 18 : 16,
                color: ColorPalette.primary.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
