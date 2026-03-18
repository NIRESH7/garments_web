import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';

class CutStockReportScreen extends StatefulWidget {
  const CutStockReportScreen({super.key});
  @override
  State<CutStockReportScreen> createState() => _CutStockReportScreenState();
}

class _CutStockReportScreenState extends State<CutStockReportScreen> {
  final _api = MobileApiService();
  List<dynamic> _data = [];
  bool _loading = false;
  final _itemNameCtrl = TextEditingController();
  DateTimeRange? _dateRange;

  final List<String> _sizes = ['75', '80', '85', '90', '95', '100', '105', '110'];

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      // Add timeout to prevent infinite loading if backend hangs
      final data = await _api.getCutStockReport(
        itemName: _itemNameCtrl.text.trim().isNotEmpty ? _itemNameCtrl.text.trim() : null,
        startDate: _dateRange?.start.toIso8601String(),
        endDate: _dateRange?.end.toIso8601String(),
      ).timeout(const Duration(seconds: 15));
      
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading Cut Stock Report: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load report: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap calculations in try-catch to prevent white screen on data errors
    final totals = <String, double>{};
    double grandTotal = 0;
    
    try {
      for (final s in _sizes) {
        totals[s] = _data.fold(0.0, (sum, row) => sum + ((row[s] ?? 0) as num).toDouble());
        grandTotal += totals[s]!;
      }
    } catch (e) {
      debugPrint('Calculation error in build: $e');
      // Fallback if data is malformed
      for (final s in _sizes) totals[s] = 0;
      grandTotal = 0;
    }

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_data.isEmpty) {
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No data. Apply filters and tap Search.',
                style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Refresh')),
          ],
        ),
      );
    } else {
      try {
        body = SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.blue.shade700),
              headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              dataTextStyle: const TextStyle(fontSize: 12),
              columnSpacing: 12,
              columns: [
                const DataColumn(label: Text('Item Name')),
                ..._sizes.map((s) => DataColumn(label: Text(s), numeric: true)),
                const DataColumn(label: Text('Total'), numeric: true),
              ],
              rows: [
                ..._data.map((row) {
                  final rowTotal = _sizes.fold<double>(0, (sum, s) => sum + ((row[s] ?? 0) as num).toDouble());
                  return DataRow(cells: [
                    DataCell(Text(row['itemName'] ?? '-')),
                    ..._sizes.map((s) => DataCell(Text((row[s] ?? 0).toString()))),
                    DataCell(Text(rowTotal.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                  ]);
                }),
                // Totals row
                DataRow(
                  color: WidgetStateProperty.all(Colors.blue.shade50),
                  cells: [
                    const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                    ..._sizes.map((s) => DataCell(Text(totals[s]!.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold)))),
                    DataCell(Text(grandTotal.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                  ],
                ),
              ],
            ),
          ),
        );
      } catch (e) {
        debugPrint('Rendering error in DataTable: $e');
        body = Center(
          child: Text('Rendering error: $e', 
            style: const TextStyle(color: Colors.red, fontSize: 12)),
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Cut Stock Report', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SizedBox.expand(
        child: Column(
          children: [
            // Filter bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _itemNameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Item name...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.date_range, color: Colors.blue),
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        initialDateRange: _dateRange,
                      );
                      if (range != null) setState(() => _dateRange = range);
                    },
                  ),
                  ElevatedButton(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(0, 0), // Override global minimum size
                    ),
                    child: const Text('Search'),
                  ),
                ],
              ),
            ),
            if (_dateRange != null)
              Container(
                color: Colors.blue.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      '${DateFormat('dd/MM/yy').format(_dateRange!.start)} – ${DateFormat('dd/MM/yy').format(_dateRange!.end)}',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => setState(() => _dateRange = null),
                      child: const Icon(Icons.clear, size: 16, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
