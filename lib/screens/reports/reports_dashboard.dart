import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import 'overview_report.dart';
import 'lot_aging_report.dart';
import 'inward_outward_report.dart';
import 'monthly_summary_report.dart';
import 'format_reports_screen.dart';
import 'client_format_report.dart';
import 'godown_stock_report_screen.dart';
import 'quality_audit_report_screen.dart';
import 'shade_card_report_screen.dart';

class ReportsDashboard extends StatelessWidget {
  const ReportsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _ReportCard(
            title: 'Shade Card Module',
            subtitle: 'Lot & Item grouped color cards',
            icon: LucideIcons.palette,
            color: Colors.indigo,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ShadeCardReportScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ReportCard(
            title: 'Client Format Report',
            subtitle: 'Professional stock status summary',
            icon: LucideIcons.fileText,
            color: ColorPalette.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ClientFormatReportScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ReportCard(
            title: 'Quality Audit & Complaints',
            subtitle: 'Pictures and signatures of lot issues',
            icon: LucideIcons.checkCircle2,
            color: Colors.red.shade700,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const QualityAuditReportScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ReportCard(
            title: 'Godown Stock (Min/Max)',
            subtitle: 'Alerts and replenishment needs',
            icon: LucideIcons.alertTriangle,
            color: Colors.redAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GodownStockReportScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ReportCard(
            title: 'Stock Overview',
            subtitle: 'Lot name, rolls, and weights',
            icon: LucideIcons.eye,
            color: Colors.blueAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OverviewReportScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ReportCard(
            title: 'Lot Aging',
            subtitle: 'Tracking lots with days since inward',
            icon: LucideIcons.calendarClock,
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LotAgingReportScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ReportCard(
            title: 'Inward vs Outward',
            subtitle: 'Comparison of production vs dispatch',
            icon: LucideIcons.history,
            color: Colors.indigo,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InwardOutwardReportScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ReportCard(
            title: 'Monthly Summary',
            subtitle: 'Opening, closing, and movements',
            icon: LucideIcons.layers,
            color: ColorPalette.success,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MonthlySummaryReportScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ReportCard(
            title: 'Client Spreadsheet Views',
            subtitle: 'Standardized Excel format data',
            icon: LucideIcons.fileSpreadsheet,
            color: Colors.teal,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FormatReportsScreen(),
              ),
            ),
          ),
        ],
      ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: ColorPalette.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              color: ColorPalette.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
