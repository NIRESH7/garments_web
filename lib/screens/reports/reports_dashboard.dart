import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
        'subtitle': 'Live status monitoring',
        'icon': LucideIcons.listChecks,
        'color': const Color(0xFF6366F1),
        'screen': const TaskProgressReportScreen(),
      },
      {
        'title': 'Cut Order Planning',
        'subtitle': 'Yield vs Variance',
        'icon': LucideIcons.scissors,
        'color': const Color(0xFFF59E0B),
        'screen': const CutOrderPlanReportScreen(),
      },
      {
        'title': 'Rack & Pallet Assets',
        'subtitle': 'Inventory distribution',
        'icon': LucideIcons.box,
        'color': const Color(0xFF8B5CF6),
        'screen': const RackPalletReportScreen(),
      },
      {
        'title': 'Shade Card Analytics',
        'subtitle': 'Color group mapping',
        'icon': LucideIcons.palette,
        'color': const Color(0xFF10B981),
        'screen': const ShadeCardReportScreen(),
      },
      {
        'title': 'Quality & Complaints',
        'subtitle': 'Performance audits',
        'icon': LucideIcons.checkCircle2,
        'color': const Color(0xFFEF4444),
        'screen': const QualityAuditReportScreen(),
      },
      {
        'title': 'Stock Alert (Min/Max)',
        'subtitle': 'Replenishment forecast',
        'icon': LucideIcons.alertTriangle,
        'color': const Color(0xFFF43F5E),
        'screen': const GodownStockReportScreen(),
      },
      {
        'title': 'Monthly Summary',
        'subtitle': 'Inventory flow audit',
        'icon': LucideIcons.layers,
        'color': const Color(0xFF2563EB),
        'screen': const MonthlySummaryReportScreen(),
      },
      {
        'title': 'Standard Spreadsheet',
        'subtitle': 'Excel record exports',
        'icon': LucideIcons.fileSpreadsheet,
        'color': const Color(0xFF0D9488),
        'screen': const FormatReportsScreen(),
      },
    ];

    if (isWeb) {
      return WebLayoutWrapper(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 1 : 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 140,
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
                  ).animate().fadeIn(delay: (index * 40).ms).scale(begin: const Offset(0.98, 0.98));
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                mainAxisSpacing: 12,
                mainAxisExtent: 80,
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
                ).animate().fadeIn(delay: (index * 40).ms);
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
          'INTELLIGENCE ENGINE',
          style: GoogleFonts.inter(
            fontSize: 14, 
            fontWeight: FontWeight.w900, 
            color: const Color(0xFF1E293B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatefulWidget {
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
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isWeb = LayoutConstants.isWeb(context);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _isHovered ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: _isHovered ? [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: isWeb ? _buildWebCard() : _buildMobileCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildWebCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(widget.icon, color: widget.color, size: 18),
            ),
            const Icon(LucideIcons.arrowUpRight, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title.toUpperCase(),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: const Color(0xFF1E293B),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileCard() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(widget.icon, color: widget.color, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFFCBD5E1)),
      ],
    );
  }
}
