import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';
import 'package:intl/intl.dart';

class FormatReportsScreen extends StatefulWidget {
  const FormatReportsScreen({super.key});

  @override
  State<FormatReportsScreen> createState() => _FormatReportsScreenState();
}

class _FormatReportsScreenState extends State<FormatReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _apiService = MobileApiService();

  bool _isLoading = true;
  List<dynamic> _agingData = [];
  List<dynamic> _inwardData = [];
  List<dynamic> _outwardData = [];
  List<dynamic> _closingData = [];

  String _statusFilter = 'All'; // All, Complete, Incomplete

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getLotAgingReport(),
        _apiService.getInwards(),
        _apiService.getOutwards(),
        _apiService.getMonthlyReport(),
      ]);

      setState(() {
        _agingData = results[0];
        _inwardData = results[1];
        _outwardData = results[2];
        _closingData = results[3];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load format reports')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Format Reports'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.filter),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Aging Details'),
            Tab(text: 'Aging Summary'),
            Tab(text: 'Inward'),
            Tab(text: 'Outward'),
            Tab(text: 'Closing'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildActiveFilterInfo(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAgingReport(),
                      _buildAgingSummaryReport(),
                      _buildInwardReport(),
                      _buildOutwardReport(),
                      _buildClosingReport(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildActiveFilterInfo() {
    if (_statusFilter == 'All') return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: Text(
        'Filtered by Status: $_statusFilter',
        style: TextStyle(
          fontSize: 12,
          color: Colors.blue.shade800,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter Reports'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: const InputDecoration(labelText: 'Lot Status'),
              items: [
                'All',
                'Complete',
                'Incomplete',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _statusFilter = v!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadAllData();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // --- 1. AGING REPORT --- (Headers: Date, Lot No, Name, Dia, Colour, Rolls, Weight, Days)
  Widget _buildAgingReport() {
    return _buildReportTable(
      headers: ['Date', 'Lot No', 'Name', 'Dia', 'Rolls', 'Wt', 'Days'],
      rows: _agingData.map((item) {
        final aging = _calculateAging(item['inward_date']);
        return <String>[
          _formatDate(item['inward_date']),
          item['lot_number'] ?? 'N/A',
          item['lot_name'] ?? 'N/A',
          item['dia']?.toString() ?? '-',
          item['rolls']?.toString() ?? '0',
          '${(item['weight'] as num?)?.toStringAsFixed(1) ?? "0"}',
          '$aging',
        ];
      }).toList(),
    );
  }

  // --- 2. AGING SUMMARY --- (Headers: Lot No, Rolls, Weight, Total)
  Widget _buildAgingSummaryReport() {
    // Group by Lot No
    final Map<String, dynamic> summary = {};
    for (var item in _agingData) {
      final lot = item['lot_number'] ?? 'N/A';
      if (!summary.containsKey(lot)) {
        summary[lot] = {'rolls': 0, 'weight': 0.0};
      }
      summary[lot]['rolls'] += (item['rolls'] ?? 0) as int;
      summary[lot]['weight'] += (item['weight'] ?? 0.0) as num;
    }

    return _buildReportTable(
      headers: ['Lot Number', 'Total Rolls', 'Total Weight', 'Status'],
      rows: summary.entries.map((e) {
        return <String>[
          e.key,
          '${e.value['rolls']}',
          '${e.value['weight'].toStringAsFixed(1)} Kg',
          'Pending', // Placeholder for status
        ];
      }).toList(),
    );
  }

  // --- 3. INWARD REPORT --- (Headers: Date, Lot No, Party, Roll, Weight, Rate, Value)
  Widget _buildInwardReport() {
    List<List<String>> rows = [];
    for (var inward in _inwardData) {
      final entries = inward['diaEntries'] as List? ?? [];
      for (var entry in entries) {
        final weight = (entry['recWt'] ?? 0) as num;
        final rate = (inward['rate'] ?? 0) as num;
        rows.add([
          _formatDate(inward['inwardDate']),
          inward['lotNo'] ?? '-',
          inward['fromParty'] ?? '-',
          '${entry['roll']}',
          '${weight.toStringAsFixed(1)}',
          '${inward['rate']}',
          '${(weight * rate).toStringAsFixed(0)}',
        ]);
      }
    }

    return _buildReportTable(
      headers: ['Date', 'Lot No', 'Party', 'Roll', 'Wt', 'Rate', 'Val'],
      rows: rows,
    );
  }

  // --- 4. OUTWARD REPORT --- (Headers: Lot No, DC No, Date, Process, Roll, Weight)
  Widget _buildOutwardReport() {
    return _buildReportTable(
      headers: ['Lot No', 'DC No', 'Date', 'Process', 'Roll', 'Wt'],
      rows: _outwardData.map((out) {
        final items = out['items'] as List? ?? [];
        final weight = items.fold(
          0.0,
          (sum, i) => sum + (i['selected_weight'] ?? 0),
        );
        return <String>[
          out['lotNo'] ?? '-',
          out['dcNo'] ?? '-',
          _formatDate(out['dateTime']),
          out['process'] ?? '-',
          '${items.length}',
          weight.toStringAsFixed(1),
        ];
      }).toList(),
    );
  }

  // --- 5. CLOSING STOCK --- (Headers: MONTH, OPENING, INWARD, OUTWARD, CLOSING)
  Widget _buildClosingReport() {
    return _buildReportTable(
      headers: ['Month', 'Opening', 'Inward', 'Outward', 'Closing'],
      rows: _closingData.map((item) {
        return <String>[
          item['month'] ?? '-',
          '${(item['opening_balance'] as num?)?.toStringAsFixed(0) ?? "0"}',
          '${(item['inward_weight'] as num?)?.toStringAsFixed(0) ?? "0"}',
          '${(item['outward_weight'] as num?)?.toStringAsFixed(0) ?? "0"}',
          '${(item['closing_balance'] as num?)?.toStringAsFixed(0) ?? "0"}',
        ];
      }).toList(),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildReportTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    if (rows.isEmpty) return const Center(child: Text('No data found'));

    return Scrollbar(
      thickness: 8,
      radius: const Radius.circular(4),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DataTable(
              headingRowHeight: 45,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 60,
              columnSpacing: 20,
              horizontalMargin: 12,
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
              columns: headers
                  .map(
                    (h) => DataColumn(
                      label: Text(
                        h,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: ColorPalette.primary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              rows: rows
                  .map(
                    (row) => DataRow(
                      cells: row
                          .map(
                            (cell) => DataCell(
                              Text(cell, style: const TextStyle(fontSize: 12)),
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yy').format(date);
    } catch (_) {
      return dateStr;
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
}
