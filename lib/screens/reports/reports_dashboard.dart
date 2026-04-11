import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/layout/web_layout_wrapper.dart';
import 'monthly_summary_report.dart';
import 'format_reports_screen.dart';
import 'godown_stock_report_screen.dart';
import 'quality_audit_report_screen.dart';
import 'shade_card_report_screen.dart';
import 'rack_pallet_report_screen.dart';
import 'task_progress_report.dart';
import 'cut_order_plan_report_screen.dart';

class ReportsDashboard extends StatelessWidget {
  const ReportsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isWeb = LayoutConstants.isWeb(context);
    final bool isMobile = LayoutConstants.isMobile(context);

    // List of active reports only
    final List<Map<String, dynamic>> activeReports = [
      {
        'title': 'Departmental Tasks',
        'subtitle': 'Cutting/Packing/Tailoring status',
        'icon': LucideIcons.listChecks,
        'color': Colors.purple,
        'screen': const TaskProgressReportScreen(),
      },
      {
        'title': 'Cut Order Planning',
        'subtitle': 'Planned vs Issued (Pending Dozen)',
        'icon': LucideIcons.scissors,
        'color': Colors.orange.shade800,
        'screen': const CutOrderPlanReportScreen(),
      },
      {
        'title': 'Rack & Pallet Assets',
        'subtitle': 'Inventory grouping by storage zone',
        'icon': LucideIcons.box,
        'color': Colors.brown,
        'screen': const RackPalletReportScreen(),
      },
      {
        'title': 'Shade Card Analytics',
        'subtitle': 'Lot & Item grouped color mapping',
        'icon': LucideIcons.palette,
        'color': Colors.indigo,
        'screen': const ShadeCardReportScreen(),
      },
      {
        'title': 'Quality & Complaints',
        'subtitle': 'Signatures and pictorial audits',
        'icon': LucideIcons.checkCircle2,
        'color': Colors.red.shade700,
        'screen': const QualityAuditReportScreen(),
      },
      {
        'title': 'Stock Alert (Min/Max)',
        'subtitle': 'Godown replenishment forecasting',
        'icon': LucideIcons.alertTriangle,
        'color': Colors.redAccent,
        'screen': const GodownStockReportScreen(),
      },
      {
        'title': 'Monthly Summary',
        'subtitle': 'Opening/Closing inventory flows',
        'icon': LucideIcons.layers,
        'color': ColorPalette.success,
        'screen': const MonthlySummaryReportScreen(),
      },
      {
        'title': 'Standard Spreadsheet',
        'subtitle': 'Professional Excel data exporting',
        'icon': LucideIcons.fileSpreadsheet,
        'color': Colors.teal,
        'screen': const FormatReportsScreen(),
      },
    ];

    if (isWeb) {
      return WebLayoutWrapper(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 1 : 2,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  mainAxisExtent: 120,
                ),
                itemCount: activeReports.length,
                itemBuilder: (context, index) {
                  final report = activeReports[index];
                  return _ReportCard(
                    title: report['title'],
                    subtitle: report['subtitle'],
                    icon: report['icon'],
                    color: report['color'],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => report['screen']),
                    ),
                  ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.1);
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: ColorPalette.background,
      appBar: AppBar(
        title: Text('ANALYTICS ENGINE', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.helpCircle, size: 18),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 32),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                mainAxisExtent: 100,
              ),
              itemCount: activeReports.length,
              itemBuilder: (context, index) {
                final report = activeReports[index];
                return _ReportCard(
                  title: report['title'],
                  subtitle: report['subtitle'],
                  icon: report['icon'],
                  color: report['color'],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => report['screen']),
                  ),
                ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.1);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Intelligence Reports',
          style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Synthesized data and operational insights for production scaling.',
          style: GoogleFonts.inter(fontSize: 14, color: ColorPalette.textSecondary),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWeb = LayoutConstants.isWeb(context);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWeb ? 16 : 24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: isWeb ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : ColorPalette.softShadow,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isWeb ? 16 : 24),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isWeb ? 24 : 20,
            vertical: isWeb ? 20 : 16,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isWeb ? 14 : 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.1)),
                ),
                child: Icon(icon, color: color, size: isWeb ? 24 : 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: isWeb ? 14 : 13,
                        color: ColorPalette.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: isWeb ? 12 : 11,
                        color: ColorPalette.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.arrowRight,
                color: ColorPalette.textMuted,
                size: isWeb ? 18 : 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
