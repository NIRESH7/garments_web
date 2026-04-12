import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/color_palette.dart';
import '../../core/utils/format_utils.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/layout/web_layout_wrapper.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/custom_dropdown_field.dart';
import 'format_reports_screen.dart';

class MonthlySummaryReportScreen extends StatefulWidget {
  const MonthlySummaryReportScreen({super.key});

  @override
  State<MonthlySummaryReportScreen> createState() =>
      _MonthlySummaryReportScreenState();
}

class _MonthlySummaryReportScreenState
    extends State<MonthlySummaryReportScreen> {
  final _apiService = MobileApiService();
  List<dynamic> _reports = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    try {
      final res = await _apiService.getMonthlyReport();
      setState(() {
        _reports = res;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load summary')));
      }
    }
  }

  void _navigateToDetails(int tabIndex) {
    if (_reports.isEmpty) return;
    final monthStr = _reports[_selectedIndex]['month'] as String;
    final parts = monthStr.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormatReportsScreen(
          initialIndex: tabIndex,
          initialFilters: {
            'startDate': DateFormat('yyyy-MM-dd').format(startDate),
            'endDate': DateFormat('yyyy-MM-dd').format(endDate),
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = LayoutConstants.isWeb(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Even lighter, cleaner background
      appBar: AppBar(
        title: Text(
          'SUMMARY REPORT', 
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900, 
            fontSize: 12, 
            letterSpacing: 2,
            color: const Color(0xFF111827),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E7EB), height: 1),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111827)))
        : _reports.isEmpty 
          ? const Center(child: Text('NO DATA AVAILABLE'))
          : isWeb ? _buildNetWebLayout() : _buildNetMobileLayout(),
    );
  }

  Widget _buildNetWebLayout() {
    final data = _reports[_selectedIndex];
    final closingRolls = (data['opening_balance_rolls'] ?? 0) + (data['inward_rolls'] ?? 0) - (data['outward_rolls'] ?? 0);
    final closingWeight = (data['opening_balance'] ?? 0.0) + (data['inward_weight'] ?? 0.0) - (data['outward_weight'] ?? 0.0);

    return WebLayoutWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Repository Summary',
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF111827), letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Consolidated view of operational stock flows',
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              _buildNetPicker(),
            ],
          ),
          const SizedBox(height: 40),
          
          _buildNetRow('Opening Statement', data['opening_balance_rolls'], data['opening_balance'], () => _navigateToDetails(0)),
          const SizedBox(height: 8),
          _buildNetRow('Total Inflow', data['inward_rolls'], data['inward_weight'], () => _navigateToDetails(2)),
          const SizedBox(height: 8),
          _buildNetRow('Total Outflow', data['outward_rolls'], data['outward_weight'], () => _navigateToDetails(3)),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(color: Color(0xFFE5E7EB)),
          ),
          
          _buildNetRow('Closing Net Balance', closingRolls, closingWeight, () => _navigateToDetails(4), isResult: true),
        ],
      ),
    );
  }

  Widget _buildNetRow(String label, dynamic rolls, dynamic weight, VoidCallback onTap, {bool isResult = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), // Tightened
        decoration: BoxDecoration(
          color: isResult ? const Color(0xFFF3F4F6) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(6)
              ),
              child: Icon(
                isResult ? LucideIcons.shieldCheck : LucideIcons.boxSelect, 
                size: 16, 
                color: const Color(0xFF374151) 
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFF374151), letterSpacing: 1),
              ),
            ),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${FormatUtils.formatQuantity(rolls as num)}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15, color: const Color(0xFF111827)),
                    ),
                    Text('ROLLS', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFF9CA3AF))),
                  ],
                ),
                const SizedBox(width: 48),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      FormatUtils.formatWeight(weight as num),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF111827)),
                    ),
                    Text('KG', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFF9CA3AF))),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 32),
            const Icon(LucideIcons.chevronRight, size: 14, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }

  Widget _buildNetPicker() {
    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(6), 
        border: Border.all(color: const Color(0xFFE5E7EB))
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _reports[_selectedIndex]['month'],
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, size: 12, color: Color(0xFF9CA3AF)),
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF111827)),
          items: _reports.map((r) => DropdownMenuItem(value: r['month'] as String, child: Text(r['month'] as String))).toList(),
          onChanged: (val) {
            if (val != null) {
              final index = _reports.indexWhere((r) => r['month'] == val);
              if (index != -1) setState(() => _selectedIndex = index);
            }
          },
        ),
      ),
    );
  }

  Widget _buildNetMobileLayout() {
    final data = _reports[_selectedIndex];
    final closingRolls = (data['opening_balance_rolls'] ?? 0) + (data['inward_rolls'] ?? 0) - (data['outward_rolls'] ?? 0);
    final closingWeight = (data['opening_balance'] ?? 0.0) + (data['inward_weight'] ?? 0.0) - (data['outward_weight'] ?? 0.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildNetPicker(),
          const SizedBox(height: 24),
          _buildNetRow('Opening', data['opening_balance_rolls'], data['opening_balance'], () => _navigateToDetails(0)),
          const SizedBox(height: 8),
          _buildNetRow('Inward', data['inward_rolls'], data['inward_weight'], () => _navigateToDetails(2)),
          const SizedBox(height: 8),
          _buildNetRow('Outward', data['outward_rolls'], data['outward_weight'], () => _navigateToDetails(3)),
          const SizedBox(height: 24),
          _buildNetRow('Closing', closingRolls, closingWeight, () => _navigateToDetails(4), isResult: true),
        ],
      ),
    );
  }
}
