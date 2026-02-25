import 'package:flutter/material.dart';
import '../../core/theme/color_palette.dart';
import '../../core/utils/format_utils.dart';
import '../../services/mobile_api_service.dart';

class InwardOutwardReportScreen extends StatefulWidget {
  const InwardOutwardReportScreen({super.key});

  @override
  State<InwardOutwardReportScreen> createState() =>
      _InwardOutwardReportScreenState();
}

class _InwardOutwardReportScreenState extends State<InwardOutwardReportScreen> {
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
      final res = await _apiService.getInwardOutwardReport();
      setState(() {
        _data = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load report')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inward vs Outward')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _data.length,
              itemBuilder: (context, index) {
                final item = _data[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: ColorPalette.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['lot_number'] ?? 'N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        item['party_name'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ColorPalette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMovementBlock(
                              'INWARD',
                              item['in_rolls'],
                              item['in_weight'],
                              ColorPalette.primary,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey.shade100,
                          ),
                          Expanded(
                            child: _buildMovementBlock(
                              'OUTWARD',
                              item['out_rolls'],
                              item['out_weight'],
                              ColorPalette.error,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      _buildDifferenceRow(item),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMovementBlock(
    String label,
    dynamic rolls,
    dynamic weight,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${FormatUtils.formatQuantity(rolls)} Rolls',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          '${FormatUtils.formatWeight(weight)} Kg',
          style: const TextStyle(
            fontSize: 12,
            color: ColorPalette.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDifferenceRow(dynamic item) {
    final diffWeight = (item['in_weight'] as num) - (item['out_weight'] as num);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Remaining Weight',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        Text(
          '${FormatUtils.formatWeight(diffWeight)} Kg',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: ColorPalette.success,
          ),
        ),
      ],
    );
  }
}
