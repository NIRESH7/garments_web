import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';

import '../../widgets/custom_dropdown_field.dart';

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
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load summary')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Summary')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
          ? const Center(child: Text('No report data available'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildMonthSelector(),
                  const SizedBox(height: 32),
                  _buildSummarySection(
                    'Opening Stock',
                    _reports[_selectedIndex]['opening_balance_rolls'] ?? 0,
                    _reports[_selectedIndex]['opening_balance'] ?? 0,
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildSummarySection(
                    'Total Inward',
                    _reports[_selectedIndex]['inward_rolls'] ?? 0,
                    _reports[_selectedIndex]['inward_weight'] ?? 0,
                    ColorPalette.success,
                  ),
                  const SizedBox(height: 16),
                  _buildSummarySection(
                    'Total Outward',
                    _reports[_selectedIndex]['outward_rolls'] ?? 0,
                    _reports[_selectedIndex]['outward_weight'] ?? 0,
                    ColorPalette.error,
                  ),
                  const Divider(height: 48),
                  _buildSummarySection(
                    'Closing Stock',
                    (_reports[_selectedIndex]['opening_balance_rolls'] ?? 0) +
                        (_reports[_selectedIndex]['inward_rolls'] ?? 0) -
                        (_reports[_selectedIndex]['outward_rolls'] ?? 0),
                    (_reports[_selectedIndex]['opening_balance'] ?? 0.0) +
                        (_reports[_selectedIndex]['inward_weight'] ?? 0.0) -
                        (_reports[_selectedIndex]['outward_weight'] ?? 0.0),
                    ColorPalette.primary,
                    isBold: true,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthSelector() {
    return CustomDropdownField(
      label: 'Select Month',
      value: _reports.isNotEmpty ? _reports[_selectedIndex]['month'] : null,
      items: _reports.map((r) => r['month'] as String).toList(),
      onChanged: (val) {
        if (val != null) {
          final index = _reports.indexWhere((r) => r['month'] == val);
          if (index != -1) {
            setState(() => _selectedIndex = index);
          }
        }
      },
      prefixIcon: LucideIcons.calendar,
    );
  }

  Widget _buildSummarySection(
    String title,
    dynamic rolls,
    dynamic weight,
    Color color, {
    bool isBold = false,
  }) {
    final numRolls = (rolls ?? 0) as num;
    final numWeight = (weight ?? 0.0) as num;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isBold ? color.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ColorPalette.softShadow,
        border: isBold ? Border.all(color: color.withOpacity(0.1)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                '${numRolls.toInt()} Rolls',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            '${numWeight.toDouble().toStringAsFixed(2)} Kg',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
