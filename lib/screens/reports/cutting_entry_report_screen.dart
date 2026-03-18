import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';

class CuttingEntryReportScreen extends StatefulWidget {
  const CuttingEntryReportScreen({super.key});
  @override
  State<CuttingEntryReportScreen> createState() => _CuttingEntryReportScreenState();
}

class _CuttingEntryReportScreenState extends State<CuttingEntryReportScreen> {
  final _api = MobileApiService();
  List<dynamic> _data = [];
  bool _loading = false;
  final _itemCtrl = TextEditingController();
  final _colourCtrl = TextEditingController();
  DateTimeRange? _range;

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final data = await _api.getCuttingEntryReport(
        itemName: _itemCtrl.text.trim().isNotEmpty ? _itemCtrl.text.trim() : null,
        colour: _colourCtrl.text.trim().isNotEmpty ? _colourCtrl.text.trim() : null,
        startDate: _range?.start.toIso8601String(),
        endDate: _range?.end.toIso8601String(),
      ).timeout(const Duration(seconds: 15));
      
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading Cutting Entry Report: $e');
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
    int totalPcs = 0;
    double totalDoz = 0;
    
    try {
      totalPcs = _data.fold<int>(0, (s, r) => s + ((r['pcs'] ?? 0) as num).toInt());
      totalDoz = _data.fold<double>(0, (s, r) => s + ((r['doz'] ?? 0) as num).toDouble());
    } catch (e) {
      debugPrint('Calculation error in Cutting Entry Report build: $e');
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
            const SizedBox(height: 8),
            Text('Apply filters and tap Search.',
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
              headingRowColor: WidgetStateProperty.all(Colors.indigo.shade700),
              headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              dataTextStyle: const TextStyle(fontSize: 12),
              columnSpacing: 14,
              columns: const [
                DataColumn(label: Text('Cut No')),
                DataColumn(label: Text('Item Name')),
                DataColumn(label: Text('Size')),
                DataColumn(label: Text('Colour')),
                DataColumn(label: Text('Lot No')),
                DataColumn(label: Text('Pcs'), numeric: true),
                DataColumn(label: Text('Doz'), numeric: true),
                DataColumn(label: Text('Date')),
              ],
              rows: [
                ..._data.map((row) {
                  String date = '-';
                  try {
                    if (row['cuttingDate'] != null) {
                      date = DateFormat('dd/MM/yy').format(DateTime.parse(row['cuttingDate']).toLocal());
                    }
                  } catch (_) {}
                  
                  return DataRow(cells: [
                    DataCell(Text(row['cutNo']?.toString() ?? '-')),
                    DataCell(Text(row['itemName']?.toString() ?? '-')),
                    DataCell(Text(row['size']?.toString() ?? '-')),
                    DataCell(Text(row['colour']?.toString() ?? '-')),
                    DataCell(Text(row['lotNo']?.toString() ?? '-')),
                    DataCell(Text((row['pcs'] ?? 0).toString())),
                    DataCell(Text(((row['doz'] ?? 0) as num).toStringAsFixed(2))),
                    DataCell(Text(date)),
                  ]);
                }),
                // Totals row
                DataRow(
                  color: WidgetStateProperty.all(Colors.indigo.shade50),
                  cells: [
                    const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    DataCell(Text('$totalPcs', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(totalDoz.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                    const DataCell(Text('')),
                  ],
                ),
              ],
            ),
          ),
        );
      } catch (e) {
        debugPrint('Rendering error in Cutting Entry Report build: $e');
        body = Center(child: Text('Error rendering data: $e'));
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Cutting Entry Report', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SizedBox.expand(
        child: Column(
          children: [
            // Filters
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _itemCtrl,
                          decoration: InputDecoration(
                            hintText: 'Item name...',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _colourCtrl,
                          decoration: InputDecoration(
                            hintText: 'Colour...',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(_range == null
                            ? 'Select Date Range'
                            : '${DateFormat('dd/MM/yy').format(_range!.start)} – ${DateFormat('dd/MM/yy').format(_range!.end)}'),
                        onPressed: () async {
                          final r = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            initialDateRange: _range,
                          );
                          if (r != null) setState(() => _range = r);
                        },
                      ),
                      if (_range != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() => _range = null),
                        ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _load,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size(0, 0), // Override global minimum size
                        ),
                        child: const Text('Search'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Summary chips
            if (_data.isNotEmpty)
              Container(
                color: Colors.indigo.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _chip('Total Rows', '${_data.length}', Colors.indigo),
                    const SizedBox(width: 16),
                    _chip('Total Pcs', '$totalPcs', Colors.indigo),
                    const SizedBox(width: 16),
                    _chip('Total Doz', totalDoz.toStringAsFixed(1), Colors.indigo),
                  ],
                ),
              ),
            // Table
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
