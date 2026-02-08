import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';

class OverviewReportScreen extends StatefulWidget {
  const OverviewReportScreen({super.key});

  @override
  State<OverviewReportScreen> createState() => _OverviewReportScreenState();
}

class _OverviewReportScreenState extends State<OverviewReportScreen> {
  final _apiService = MobileApiService();
  List<dynamic> _data = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final res = await _apiService.getOverviewReport();
      setState(() {
        _data = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load overview report')),
        );
      }
    }
  }

  double get _grandTotalWeight => _data.fold(
    0.0,
    (sum, item) => sum + ((item['weight'] ?? 0) as num).toDouble(),
  );
  int get _grandTotalRolls =>
      _data.fold(0, (sum, item) => sum + ((item['rolls'] ?? 0) as num).toInt());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Overview')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryHeader(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _data.length,
                    itemBuilder: (context, index) {
                      final item = _data[index];
                      return _buildLotCard(item);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: ColorPalette.dashboardGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ColorPalette.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SummaryStat(label: 'GRAND TOTAL ROLLS', value: '$_grandTotalRolls'),
          _SummaryStat(
            label: 'GRAND TOTAL WEIGHT',
            value: '${_grandTotalWeight.toStringAsFixed(2)} Kg',
          ),
        ],
      ),
    );
  }

  Widget _buildLotCard(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ColorPalette.softShadow,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColorPalette.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              LucideIcons.package,
              color: ColorPalette.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['lot_number'] ?? 'N/A',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  item['lot_name'] ?? 'No Party',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ColorPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item['rolls'] ?? 0} Rolls',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${((item['weight'] ?? 0) as num).toStringAsFixed(2)} Kg',
                style: const TextStyle(
                  color: ColorPalette.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
