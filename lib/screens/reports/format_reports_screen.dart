import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';
import 'package:intl/intl.dart';

import '../../widgets/custom_dropdown_field.dart';

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
        _apiService.getOverviewReport(), // Changed from getMonthlyReport
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

  // Filters
  Map<int, Map<String, dynamic>> _filters = {};

  void _showFilterDialog() {
    final index = _tabController.index;
    final currentFilters = _filters[index] ?? {};

    showDialog(
      context: context,
      builder: (ctx) => _FilterDialog(
        tabIndex: index,
        initialFilters: currentFilters,
        onApply: (newFilters) {
          setState(() {
            _filters[index] = newFilters;
          });
          _loadDataForTab(index);
        },
      ),
    );
  }

  Future<void> _loadDataForTab(int index) async {
    setState(() => _isLoading = true);
    final filters = _filters[index] ?? {};

    try {
      if (index == 0) {
        // Aging
        _agingData = await _apiService.getLotAgingReport(
          lotNo: filters['lotNo'],
          lotName: filters['lotName'],
          colour: filters['colour'],
          dia: filters['dia'],
        );
      } else if (index == 1) {
        // Aging Summary
        // Note: Summary is usually derived from Details.
        // User asked for Date, LotName filters.
        // Backend `getLotAgingReport` supports lotName already.
        // If "Date" means "Inward Date" filter, we might need to add that to backend if strictly required for *summary*.
        // But usually "Aging" implies "Current Stock". Filtering by inward date might be weird for "Current Stock".
        // Let's assume filtering the *source* list (which we already do via Aging Report API) is enough,
        // unless we want to filter the *summary view* locally.
        // Let's reload Aging Data with filters and then re-summarize.
        _agingData = await _apiService.getLotAgingReport(
          lotName: filters['lotName'],
          // Date filter is not standard for "Current Stock" usually, but let's see.
          // If user wants to see "Stock that came in on Date X", we can add date filter to aging API if needed.
          // Current API supports: lotNo, lotName, colour, dia.
          // I will use client-side filtering for Date if needed or just stick to what API supports for now
          // based on the valid filters request: "date,lotname".
          // I'll filter locally by date if provided, as API update for date in aging wasn't explicitly added yet (my bad, I missed adding date to getLotAgingReport in backend).
          // Actually, let's filter the _agingData list locally for date if 'date' filter is present.
        );
      } else if (index == 2) {
        // Inward
        _inwardData = await _apiService.getInwards(
          startDate: filters['startDate'],
          endDate: filters['endDate'],
          fromParty: filters['party'],
          lotName: filters['lotName'],
        );
      } else if (index == 3) {
        // Outward
        _outwardData = await _apiService.getOutwards(
          startDate: filters['startDate'],
          endDate: filters['endDate'],
          lotName: filters['lotName'],
          lotNo: filters['lotNo'],
          dia: filters['dia'],
        );
      } else if (index == 4) {
        // Closing - Stock Overview
        _closingData = await _apiService.getOverviewReport(
          startDate: filters['startDate'],
          endDate: filters['endDate'],
          lotNo: filters['lotNo'],
          lotName: filters['lotName'],
          status: filters['status'],
        );
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // --- 1. AGING REPORT --- (Headers: Date, Lot No, Name, Dia, Colour, Rolls, Weight, Days)
  Widget _buildAgingReport() {
    return _buildReportTable(
      headers: [
        'Date',
        'Lot No',
        'Name',
        'Dia',
        'Colour',
        'Rolls',
        'Wt',
        'Days',
      ],
      rows: _agingData.map((item) {
        final aging = _calculateAging(item['inward_date']);
        return <String>[
          _formatDate(item['inward_date']),
          item['lot_number'] ?? 'N/A',
          item['lot_name'] ?? 'N/A',
          item['dia']?.toString() ?? '-',
          item['colour']?.toString() ?? '-', // New Column
          item['rolls']?.toString() ?? '0',
          '${(item['weight'] as num?)?.toStringAsFixed(1) ?? "0"}',
          '$aging',
        ];
      }).toList(),
    );
  }

  // --- 2. AGING SUMMARY --- (Headers: Lot No, Rolls, Weight, Total)
  Widget _buildAgingSummaryReport() {
    // Apply local date filter if needed for Summary
    final filters = _filters[1] ?? {};
    final dateFilter =
        filters['date']; // Assuming single date or we can do range

    // Group by Lot No
    final Map<String, dynamic> summary = {};
    for (var item in _agingData) {
      // Local Date Filter
      if (dateFilter != null && dateFilter.isNotEmpty) {
        // Simple string match or compare
        if (!_formatDate(item['inward_date']).contains(dateFilter)) continue;
      }

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
          'Pending',
        ];
      }).toList(),
    );
  }

  // --- 3. INWARD REPORT --- (Headers: Date, Inward No, Party, Party DC, Lot No, Lot Name, Roll, Wt, Val)
  Widget _buildInwardReport() {
    List<List<String>> rows = [];
    for (var inward in _inwardData) {
      final entries = inward['diaEntries'] as List? ?? [];
      for (var entry in entries) {
        final weight = (entry['recWt'] ?? 0) as num;
        // Use entry rate if available, else inward rate
        final rate = (entry['rate'] ?? inward['rate'] ?? 0) as num;
        rows.add([
          _formatDate(inward['inwardDate']),
          inward['inwardNo'] ?? '-',
          inward['fromParty'] ?? '-',
          inward['partyDcNo'] ?? '-',
          inward['lotNo'] ?? '-',
          inward['lotName'] ?? '-',
          '${entry['recRoll'] ?? entry['roll']}',
          '${weight.toStringAsFixed(1)}',
          '${(weight * rate).toStringAsFixed(0)}',
        ]);
      }
    }

    return _buildReportTable(
      headers: [
        'Date',
        'Inward No',
        'Party',
        'Party DC',
        'Lot No',
        'Lot Name',
        'Roll',
        'Wt',
        'Val',
      ],
      rows: rows,
    );
  }

  // --- 4. OUTWARD REPORT --- (Headers: Party, Lot Name, Date, DC No, Lot No, Process, Rolls, Wt)
  Widget _buildOutwardReport() {
    return _buildReportTable(
      headers: [
        'Party',
        'Lot Name',
        'Date',
        'DC No',
        'Lot No',
        'Process',
        'Rolls',
        'Wt',
      ],
      rows: _outwardData.map((out) {
        final items = out['items'] as List? ?? [];
        final weight = items.fold(
          0.0,
          (sum, i) => sum + (i['selected_weight'] ?? 0),
        );
        return <String>[
          out['partyName'] ?? '-',
          out['lotName'] ?? '-',
          _formatDate(out['dateTime']),
          out['dcNo'] ?? '-',
          out['lotNo'] ?? '-',
          out['process'] ?? '-',
          '${items.length}',
          weight.toStringAsFixed(1),
        ];
      }).toList(),
    );
  }

  // --- 5. CLOSING STOCK --- (Headers: Lot No, Lot Name, In Roll, In Wt, Out Roll, Out Wt, Bal Roll, Bal Wt, Status)
  Widget _buildClosingReport() {
    return _buildReportTable(
      headers: [
        'Lot No',
        'Lot Name',
        'In Roll',
        'In Wt',
        'Out Roll',
        'Out Wt',
        'Bal Roll',
        'Bal Wt',
        'Status',
      ],
      rows: _closingData.map((item) {
        return <String>[
          item['lot_number'] ?? '-',
          item['lot_name'] ?? '-',
          '${item['rec_rolls'] ?? 0}',
          '${(item['rec_weight'] as num?)?.toStringAsFixed(1) ?? "0"}',
          '${item['deliv_rolls'] ?? 0}',
          '${(item['deliv_weight'] as num?)?.toStringAsFixed(1) ?? "0"}',
          '${item['balance_rolls'] ?? 0}',
          '${(item['balance_weight'] as num?)?.toStringAsFixed(1) ?? "0"}',
          item['status'] ?? '-',
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

class _FilterDialog extends StatefulWidget {
  final int tabIndex;
  final Map<String, dynamic> initialFilters;
  final Function(Map<String, dynamic>) onApply;

  const _FilterDialog({
    required this.tabIndex,
    required this.initialFilters,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _filters;

  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filters = Map.from(widget.initialFilters);
    _startDateController.text = _filters['startDate'] ?? '';
    _endDateController.text = _filters['endDate'] ?? '';
    _dateController.text = _filters['date'] ?? '';
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Reports'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if ([2, 3, 4].contains(widget.tabIndex)) ...[
                _buildDateRangePicker(
                  'startDate',
                  'Start Date',
                  _startDateController,
                ),
                const SizedBox(height: 8),
                _buildDateRangePicker(
                  'endDate',
                  'End Date',
                  _endDateController,
                ),
                const SizedBox(height: 8),
              ],
              if (widget.tabIndex == 1) // Aging Summary
                _buildDatePicker('date', 'Date (Inward)', _dateController),
              if ([
                0,
                1,
                2,
                3,
                4,
              ].contains(widget.tabIndex)) // Lot Name (All Reports)
                _buildTextField('lotName', 'Lot Name'),
              if ([
                0,
                3,
                4,
              ].contains(widget.tabIndex)) // Lot No (Aging, Outward, Closing)
                _buildTextField('lotNo', 'Lot No'),
              if (widget.tabIndex == 2) // Party (Inward)
                _buildTextField('party', 'Party Name'),
              if ([0, 3].contains(widget.tabIndex)) // Dia (Aging, Outward)
                _buildTextField('dia', 'Dia'),
              if (widget.tabIndex == 0) // Colour (Aging)
                _buildTextField('colour', 'Colour'),
              if (widget.tabIndex == 4) // Status (Closing)
                _buildDropdown('status', 'Status', [
                  'All',
                  'Pending',
                  'Completed',
                ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_filters);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildTextField(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextFormField(
        initialValue: _filters[key],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        onChanged: (val) => _filters[key] = val,
      ),
    );
  }

  Widget _buildDateRangePicker(
    String key,
    String label,
    TextEditingController controller,
  ) {
    return TextFormField(
      controller:
          controller, // Use controller instead of initialValue for date pickers
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(LucideIcons.calendar),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) {
          final formatted = DateFormat('yyyy-MM-dd').format(date);
          setState(() {
            _filters[key] = formatted;
            controller.text = formatted;
          });
        }
      },
    );
  }

  Widget _buildDatePicker(
    String key,
    String label,
    TextEditingController controller,
  ) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(LucideIcons.calendar),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) {
          final formatted = DateFormat('dd/MM/yy').format(date);
          setState(() {
            _filters[key] = formatted;
            controller.text = formatted;
          });
        }
      },
    );
  }

  Widget _buildDropdown(String key, String label, List<String> items) {
    return CustomDropdownField(
      label: label,
      value: _filters[key],
      items: items,
      onChanged: (val) {
        if (val != null) setState(() => _filters[key] = val);
      },
    );
  }
}
