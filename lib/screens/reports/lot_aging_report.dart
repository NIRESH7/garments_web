import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import '../../core/utils/format_utils.dart';
import '../../services/mobile_api_service.dart';

class LotAgingReportScreen extends StatefulWidget {
  const LotAgingReportScreen({super.key});

  @override
  State<LotAgingReportScreen> createState() => _LotAgingReportScreenState();
}

class _LotAgingReportScreenState extends State<LotAgingReportScreen> {
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
      final res = await _apiService.getLotAgingReport();
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
          const SnackBar(content: Text('Failed to load aging report')),
        );
      }
    }
  }

  int _calculateAging(String? dateStr) {
    if (dateStr == null) return 0;
    try {
      final date = DateTime.parse(dateStr);
      return DateTime.now().difference(date).inDays;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lot Aging Report')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _data.length,
              itemBuilder: (context, index) {
                final item = _data[index];
                final aging = _calculateAging(item['inward_date']);
                final isOld = aging > 30;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: ColorPalette.softShadow,
                    border: Border.all(
                      color: isOld ? Colors.red.shade100 : Colors.grey.shade100,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item['lot_number'] ?? 'N/A',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isOld
                                  ? Colors.red.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$aging Days Old',
                              style: TextStyle(
                                color: isOld ? Colors.red : Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildDataRow(
                        LucideIcons.calendar,
                        'Inward Date',
                        item['inward_date'],
                      ),
                      _buildDataRow(LucideIcons.circle, 'Dia', item['dia']),
                      _buildDataRow(
                        LucideIcons.package,
                        'Rolls / Weight',
                        '${FormatUtils.formatQuantity(item['rolls'])} Rolls / '
                            '${FormatUtils.formatWeight(item['weight'])} Kg',
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
