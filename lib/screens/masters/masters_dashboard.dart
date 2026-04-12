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
import '../assessment/item_assignment_list_screen.dart';

class MastersDashboard extends StatelessWidget {
  const MastersDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final isWeb = LayoutConstants.isWeb(context);
    final isMobile = LayoutConstants.isMobile(context);
    final crossAxisCount = isMobile ? 1 : (MediaQuery.of(context).size.width > 1200 ? 3 : 2);

    final List<Map<String, dynamic>> menuItems = [
      {
        'title': 'Registry Hierarchy',
        'subtitle': 'Define core garment classification levels',
        'icon': LucideIcons.layoutTemplate,
        'screen': CategoriesMasterScreen(),
        'color': const Color(0xFF6366F1), // Indigo
      },
      {
        'title': 'Global Registry',
        'subtitle': 'Manage registry values for all dropdowns',
        'icon': LucideIcons.listPlus,
        'screen': DropdownSetupScreen(),
        'color': const Color(0xFF06B6D4), // Cyan
      },
      {
        'title': 'Entity Directory',
        'subtitle': 'Registry for suppliers, clients and vendors',
        'icon': LucideIcons.users,
        'screen': PartyMasterScreen(),
        'color': const Color(0xFF10B981), // Emerald
      },
      {
        'title': 'Product Clusters',
        'subtitle': 'Configure fabric groups and item specifications',
        'icon': LucideIcons.layoutGrid,
        'screen': ItemMasterScreen(),
        'color': const Color(0xFFF59E0B), // Amber
      },
      {
        'title': 'Dye Forecasting',
        'subtitle': 'AI-assisted garment dye color forecasting',
        'icon': LucideIcons.palette,
        'screen': ColorPredictionScreen(),
        'color': const Color(0xFFEC4899), // Pink
      },
      {
        'title': 'Guardrail Setup',
        'subtitle': 'Configure inventory guardrails and thresholds',
        'icon': LucideIcons.barChart4,
        'screen': StockLimitMasterScreen(),
        'color': const Color(0xFF8B5CF6), // Violet
      },
      {
        'title': 'Item Assignment Registry',
        'subtitle': 'Manage Cutting and Accessories Master assignments',
        'icon': LucideIcons.clipboardList,
        'screen': ItemAssignmentListScreen(),
        'color': const Color(0xFFF97316), // Orange
      },
    ];

    if (isWeb) {
      return WebLayoutWrapper(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Master Data Repository',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Synchronize and configure the fundamental system structures',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 32,
                  mainAxisSpacing: 32,
                  mainAxisExtent: 130,
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('MASTER DIRECTORY'),
        titleTextStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1E293B),
          fontSize: 16,
          letterSpacing: 1.2,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: menuItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _MenuCard(data: menuItems[index]),
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
    final themeColor = data['color'] as Color;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => data['screen']),
        ),
        hoverColor: themeColor.withOpacity(0.02),
        child: Padding(
          padding: EdgeInsets.all(isWeb ? 24 : 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  data['icon'], 
                  color: themeColor, 
                  size: isWeb ? 28 : 22
                ),
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
                        fontWeight: FontWeight.w800,
                        fontSize: isWeb ? 17 : 15,
                        color: const Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['subtitle'],
                      style: GoogleFonts.inter(
                        fontSize: isWeb ? 13 : 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.arrowRight,
                  size: isWeb ? 16 : 14,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
