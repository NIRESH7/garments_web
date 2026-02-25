import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';

class CutOrderPlanReportScreen extends StatefulWidget {
  const CutOrderPlanReportScreen({super.key});

  @override
  State<CutOrderPlanReportScreen> createState() =>
      _CutOrderPlanReportScreenState();
}

class _CutOrderPlanReportScreenState extends State<CutOrderPlanReportScreen> {
  final _api = MobileApiService();
  bool _isLoading = true;
  List<dynamic> _reportData = [];

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedItem;
  String? _selectedSize;

  List<String> _itemNames = [];
  final List<String> _sizes = [
    '75',
    '80',
    '85',
    '90',
    '95',
    '100',
    '105',
    '110',
    '50',
    '55',
    '60',
    '65',
    '70',
  ];

  @override
  void initState() {
    super.initState();
    _fetchReport();
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    try {
      final categories = await _api.getCategories();
      final items = _getValues(categories, ['Item Name', 'itemName', 'item']);
      setState(() {
        _itemNames = items;
      });
    } catch (e) {
      print('Error loading master data: $e');
    }
  }

  List<String> _getValues(List<dynamic> categories, List<String> matchNames) {
    final List<String> result = [];
    final matches = categories.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      return matchNames.any((m) => name == m.toLowerCase());
    });
    for (var cat in matches) {
      final values = cat['values'] as List<dynamic>?;
      if (values != null) {
        for (var v in values) {
          final val = (v is Map ? v['name'] : v).toString();
          if (val.isNotEmpty && !result.contains(val)) result.add(val);
        }
      }
    }
    return result;
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getCuttingPlanReport(
        startDate: _startDate?.toIso8601String(),
        endDate: _endDate?.toIso8601String(),
        itemName: _selectedItem,
        size: _selectedSize,
      );
      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CUT ORDER PLAN REPORT'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchReport),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reportData.isEmpty
                ? _buildEmptyState()
                : _buildReportTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDateRange: _startDate != null && _endDate != null
                          ? DateTimeRange(start: _startDate!, end: _endDate!)
                          : null,
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Theme.of(context).primaryColor,
                              onPrimary: Colors.white,
                              onSurface: Colors.black87,
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _startDate = picked.start;
                        _endDate = picked.end;
                      });
                      _fetchReport();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _startDate == null
                              ? 'Date Range'
                              : '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdown(
                  hint: 'Select Item',
                  value: _selectedItem,
                  items: _itemNames,
                  onChanged: (val) {
                    setState(() => _selectedItem = val);
                    _fetchReport();
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: _buildDropdown(
                  hint: 'Size',
                  value: _selectedSize,
                  items: _sizes,
                  onChanged: (val) {
                    setState(() => _selectedSize = val);
                    _fetchReport();
                  },
                ),
              ),
            ],
          ),
          if (_startDate != null ||
              _selectedItem != null ||
              _selectedSize != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                        _selectedItem = null;
                        _selectedSize = null;
                      });
                      _fetchReport();
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text(
                      'Clear Filters',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(fontSize: 12)),
          value: value,
          items: items
              .map(
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(i, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildReportTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 20,
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          columns: const [
            DataColumn(label: Text('PLAN NAME')),
            DataColumn(label: Text('ITEM NAME')),
            DataColumn(label: Text('SIZE')),
            DataColumn(label: Text('PLANNED DZ')),
            DataColumn(label: Text('ISSUED DZ')),
            DataColumn(label: Text('PENDING DZ')),
          ],
          rows: _reportData.map((row) {
            final pending = (row['pending'] as num? ?? 0).toDouble();
            final planned = (row['planned'] as num? ?? 0);
            final issued = (row['issued'] as num? ?? 0);
            
            return DataRow(
              cells: [
                DataCell(Text(row['planName']?.toString() ?? row['planId']?.toString() ?? '-')),
                DataCell(Text(row['itemName']?.toString() ?? '-')),
                DataCell(Text(row['size']?.toString() ?? '-')),
                DataCell(Text('$planned dz')),
                DataCell(Text('$issued dz')),
                DataCell(
                  Text(
                    '${row['pending'] ?? 0} dz',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: pending > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No matching cut order plans found.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
