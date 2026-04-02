import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/mobile_api_service.dart';
import '../../core/utils/format_utils.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/report_print_service.dart';

import '../../widgets/custom_dropdown_field.dart';

class FormatReportsScreen extends StatefulWidget {
  final int initialIndex;
  final Map<String, dynamic>? initialFilters;
  const FormatReportsScreen({
    super.key,
    this.initialIndex = 0,
    this.initialFilters,
  });

  @override
  State<FormatReportsScreen> createState() => _FormatReportsScreenState();
}

class _FormatReportsScreenState extends State<FormatReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _apiService = MobileApiService();
  // Use a getter to ensure we always have an instance
  ReportPrintService get _printService => ReportPrintService();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  List<dynamic> _agingData = [];
  List<dynamic> _inwardData = [];
  List<dynamic> _outwardData = [];
  List<dynamic> _closingData = [];
  List<String> _masterLotNames = [];
  List<String> _masterLotNos = [];
  List<String> _masterParties = [];
  List<String> _masterDias = [];
  List<String> _masterColours = [];

  String _statusFilter = 'All'; // All, Complete, Incomplete

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    if (widget.initialFilters != null) {
      _filters[widget.initialIndex] = widget.initialFilters!;
    }
    _tabController.addListener(_handleTabChange);
    _loadAllData();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      // Only trigger when the transition is finished
      setState(() {
        _filters.clear();
      });
      _loadDataForTab(_tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
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

        // Extract master lists
        _masterLotNames =
            _agingData
                .map((e) => (e['lot_name']?.toString() ?? '').trim().toUpperCase())
                .where((s) => s.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        _masterLotNos =
            _agingData
                .map((e) => e['lot_number']?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        _isLoading = false;
      });

      // Fetch categories for Dia and Colour
      final categories = await _apiService.getCategories();
      final parties = await _apiService.getParties();

      setState(() {
        _masterParties =
            parties.map((e) => e['name']?.toString() ?? '').toList()..sort();

        for (var cat in categories) {
          final name = cat['name']?.toString().toLowerCase() ?? '';
          final values =
              (cat['values'] as List?)
                  ?.map((v) => v['name']?.toString() ?? '')
                  .toList() ??
              [];
          if (name == 'dia' || name == 'dias') _masterDias = values..sort();
          if (name == 'colour' ||
              name == 'color' ||
              name == 'colours' ||
              name == 'colors') {
            _masterColours = values..sort();
          }
        }
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
            icon: const Icon(LucideIcons.printer, size: 20),
            onPressed: _handlePrint,
            tooltip: 'Print Report',
          ),
          _buildShareMenu(),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: _loadAllData,
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _scrollToBottom,
        mini: true,
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
        child: const Icon(LucideIcons.arrowDown, color: Colors.white),
      ),
    );
  }

  Widget _buildActiveFilterInfo() {
    if (_statusFilter == 'All') return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Text(
        'Filtered by Status: $_statusFilter',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).primaryColor,
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
        lotNames: _masterLotNames,
        lotNos: _masterLotNos,
        parties: _masterParties,
        dias: _masterDias,
        colours: _masterColours,
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
        final data = await _apiService.getLotAgingReport(
          lotNo: filters['lotNo'],
          lotName: filters['lotName'],
          colour: filters['colour'],
          dia: filters['dia'],
          startDate: filters['startDate'],
          endDate: filters['endDate'],
        );
        // Local Exact Match Filter
        _agingData = data.where((item) {
          if (filters['lotName'] != null &&
              item['lot_name']?.toString().trim().toUpperCase() != filters['lotName'])
            return false;
          if (filters['lotNo'] != null &&
              item['lot_number'] != filters['lotNo'])
            return false;
          if (filters['colour'] != null && item['colour'] != filters['colour'])
            return false;
          if (filters['dia'] != null &&
              item['dia']?.toString() != filters['dia'].toString())
            return false;
          return true;
        }).toList();
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
        final data = await _apiService.getLotAgingReport(
          lotName: filters['lotName'],
        );
        // Local Exact Match Filter
        _agingData = data.where((item) {
          if (filters['lotName'] != null &&
              item['lot_name']?.toString().trim().toUpperCase() != filters['lotName'])
            return false;
          if (filters['lotNo'] != null &&
              item['lot_number']?.toString().trim() != filters['lotNo'])
            return false;
          return true;
        }).toList();
      } else if (index == 2) {
        // Inward
        final data = await _apiService.getInwards(
          startDate: filters['startDate'],
          endDate: filters['endDate'],
          fromParty: filters['party'],
          lotName: filters['lotName'],
          lotNo: filters['lotNo'],
        );
        // Local Exact Match Filter
        _inwardData = data.where((item) {
          if (filters['lotName'] != null &&
              item['lotName']?.toString().trim().toUpperCase() != filters['lotName'])
            return false;
          if (filters['lotNo'] != null && item['lotNo'] != filters['lotNo'])
            return false;
          if (filters['party'] != null && item['fromParty'] != filters['party'])
            return false;
          return true;
        }).toList();
      } else if (index == 3) {
        // Outward
        final data = await _apiService.getOutwards(
          startDate: filters['startDate'],
          endDate: filters['endDate'],
          lotName: filters['lotName'],
          lotNo: filters['lotNo'],
          dia: filters['dia'],
        );
        // Local Exact Match Filter
        _outwardData = data.where((item) {
          if (filters['lotName'] != null &&
              item['lotName']?.toString().trim().toUpperCase() != filters['lotName'])
            return false;
          if (filters['lotNo'] != null && item['lotNo'] != filters['lotNo'])
            return false;
          if (filters['dia'] != null &&
              item['dia']?.toString() != filters['dia'].toString())
            return false;
          return true;
        }).toList();
      } else if (index == 4) {
        // Closing - Stock Overview
        final data = await _apiService.getOverviewReport(
          startDate: filters['startDate'],
          endDate: filters['endDate'],
          lotNo: filters['lotNo'],
          lotName: filters['lotName'],
          status: filters['status'],
        );
        // Local Exact Match Filter
        _closingData = data.where((item) {
          if (filters['lotName'] != null &&
              item['lot_name']?.toString().trim().toUpperCase() != filters['lotName'])
            return false;
          if (filters['lotNo'] != null &&
              item['lot_number'] != filters['lotNo'])
            return false;
          return true;
        }).toList();
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
        'Val', // ADDED
        'Days',
      ],
      rows: _agingData.map((item) {
        final aging = _calculateAging(item['inward_date']);
        final weight = (item['weight'] ?? 0) as num;
        final rate = (item['rate'] ?? item['Rate'] ?? 0) as num;
        return <String>[
          _formatDate(item['inward_date']),
          item['lot_number'] ?? 'N/A',
          item['lot_name'] ?? 'N/A',
          item['dia']?.toString() ?? '-',
          item['colour']?.toString() ?? '-', 
          item['rolls']?.toString() ?? '0',
          '${FormatUtils.formatWeight(item['weight'])}',
          '${FormatUtils.formatCurrency(weight * rate)}', // ADDED
          '$aging',
        ];
      }).toList(),
      footerRow: [
        'TOTAL',
        '',
        '',
        '',
        '',
        '${_agingData.fold<int>(0, (sum, item) => sum + ((item['rolls'] ?? 0) as num).toInt())}',
        FormatUtils.formatWeight(
          _agingData.fold<double>(0.0, (sum, item) => sum + ((item['weight'] ?? 0) as num).toDouble()),
        ),
        FormatUtils.formatCurrency(
          _agingData.fold<double>(0.0, (sum, item) => sum + (((item['weight'] ?? 0) as num) * ((item['rate'] ?? 0) as num)).toDouble()),
        ), // ADDED
        '',
      ],
    );
  }

  Widget _buildAgingSummaryReport() {
    // Apply local date filter if needed for Summary
    final filters = _filters[1] ?? {};
    final dateFilter =
        filters['date']; // Assuming single date or we can do range

    // Group by Lot Name
    final Map<String, dynamic> summary = {};
    for (var item in _agingData) {
      // Local Date Filter
      if (dateFilter != null && dateFilter.isNotEmpty) {
        // Simple string match or compare
        if (!_formatDate(item['inward_date']).contains(dateFilter)) continue;
      }

      final lotNo = item['lot_number']?.toString().trim() ?? 'N/A';
      final rawLotName = item['lot_name']?.toString().trim() ?? 'N/A';
      final groupingKey = rawLotName.toUpperCase();

      if (!summary.containsKey(groupingKey)) {
        summary[groupingKey] = {
          'lotNos': <String>{},
          'lotName': rawLotName.toUpperCase(),
          'rolls': 0,
          'weight': 0.0,
          'value': 0.0, // ADDED
        };
      }
      if (lotNo != 'N/A' && lotNo.isNotEmpty) {
        summary[groupingKey]['lotNos'].add(lotNo);
      }
      summary[groupingKey]['rolls'] += (item['rolls'] ?? 0) as int;
      final weight = (item['weight'] ?? 0.0) as num;
      final rate = (item['rate'] ?? item['Rate'] ?? 0.0) as num;
      summary[groupingKey]['weight'] += weight;
      summary[groupingKey]['value'] += (weight * rate); // ADDED
    }

    return _buildReportTable(
      headers: [
        'Lot Number',
        'Lot Name',
        'Total Rolls',
        'Total Weight',
        'Total Value', // ADDED
        'Status',
      ],
      rows: summary.values.map((v) {
        final lotNosSet = v['lotNos'] as Set;
        String lotNoDisplay = 'N/A';
        if (lotNosSet.isNotEmpty) {
          final lotNosList = lotNosSet.toList();
          List<String> chunks = [];
          for (int i = 0; i < lotNosList.length; i += 2) {
            chunks.add(lotNosList.sublist(i, (i + 2 > lotNosList.length) ? lotNosList.length : i + 2).join(', '));
          }
          lotNoDisplay = chunks.join('\n');
        }

        return <String>[
          lotNoDisplay,
          v['lotName'],
          '${v['rolls']}',
          '${FormatUtils.formatWeight(v['weight'])} Kg',
          '${FormatUtils.formatCurrency(v['value'] ?? 0)}', // ADDED
          'Pending',
        ];
      }).toList(),
      footerRow: [
        'TOTAL',
        '',
        '${summary.values.fold<int>(0, (sum, v) => sum + ((v['rolls'] ?? 0) as num).toInt())}',
        '${FormatUtils.formatWeight(summary.values.fold<double>(0.0, (sum, v) => sum + ((v['weight'] ?? 0) as num).toDouble()))} Kg',
        '${FormatUtils.formatCurrency(summary.values.fold<double>(0.0, (sum, v) => sum + ((v['value'] ?? 0) as num).toDouble()))}', // ADDED
        '',
      ],
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
          entry['dia']?.toString() ?? '-',
          '${entry['recRoll'] ?? entry['roll']}',
          '${FormatUtils.formatWeight(weight)}',
          '${FormatUtils.formatCurrency(weight * rate)}',
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
        'Dia',
        'Roll',
        'Wt',
        'Val',
      ],
      rows: rows,
      footerRow: [
        'TOTAL',
        '',
        '',
        '',
        '',
        '',
        '',
        '${rows.fold<int>(0, (sum, r) => sum + (double.tryParse(r[7]) ?? 0).toInt())}',
        FormatUtils.formatWeight(
          rows.fold<double>(0.0, (sum, r) => sum + (double.tryParse(r[8]) ?? 0.0)),
        ),
        FormatUtils.formatCurrency(
          rows.fold<double>(
            0.0,
            (sum, r) => sum + (double.tryParse(r[9].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0),
          ),
        ),
      ],
    );
  }

  // --- 4. OUTWARD REPORT --- (Headers: Party, Lot Name, Date, DC No, Lot No, Dia, Process, Rolls, Wt)
  Widget _buildOutwardReport() {
    final filters = _filters[3] ?? {};
    final diaFilter = filters['dia'];

    if (diaFilter != null && diaFilter.toString().isNotEmpty) {
      // Summary View when filtered by DIA
      final Map<String, Map<String, dynamic>> summary = {};
      for (var out in _outwardData) {
        final dia = out['dia']?.toString() ?? '-';
        if (!summary.containsKey(dia)) {
          summary[dia] = {'lots': <String>{}, 'rolls': 0, 'weight': 0.0};
        }
        if (out['lotNo'] != null) {
          summary[dia]!['lots'].add(out['lotNo'].toString());
        }
        final items = out['items'] as List? ?? [];
        summary[dia]!['rolls'] += items.length;
        summary[dia]!['weight'] += items.fold(
          0.0,
          (sum, i) => sum + (i['total_weight'] ?? 0),
        );
      }

      return _buildReportTable(
        headers: ['I.no', 'dia', 'roll', 'weight'],
        rows: summary.entries.map((e) {
          return <String>[
            (e.value['lots'] as Set).join(', '),
            e.key,
            '${e.value['rolls']}',
            '${FormatUtils.formatWeight(e.value['weight'])}',
          ];
        }).toList(),
        footerRow: [
          'TOTAL',
          '',
          '${summary.values.fold<int>(0, (sum, v) => sum + ((v['rolls'] ?? 0) as num).toInt())}',
          FormatUtils.formatWeight(
            summary.values.fold<double>(0.0, (sum, v) => sum + ((v['weight'] ?? 0) as num)),
          ),
        ],
      );
    }

    return _buildReportTable(
      headers: [
        'Party',
        'Lot Name',
        'Date',
        'DC No',
        'Lot No',
        'Dia',
        'Process',
        'Rolls',
        'Wt',
        'Val', // ADDED
      ],
      rows: _outwardData.map((out) {
        final items = out['items'] as List? ?? [];
        final weight = items.fold(
          0.0,
          (sum, i) => sum + (i['total_weight'] ?? 0),
        );
        final rate = (out['rate'] ?? out['Rate'] ?? 0) as num; // ADDED
        return <String>[
          out['partyName'] ?? '-',
          out['lotName'] ?? '-',
          _formatDate(out['dateTime']),
          out['dcNo'] ?? '-',
          out['lotNo'] ?? '-',
          out['dia']?.toString() ?? '-',
          out['process'] ?? '-',
          '${items.length}',
          FormatUtils.formatWeight(weight),
          FormatUtils.formatCurrency(weight * rate), // ADDED
        ];
      }).toList(),
      footerRow: [
        'TOTAL',
        '',
        '',
        '',
        '',
        '',
        '',
        '${_outwardData.fold<int>(0, (sum, out) => sum + (out['items'] as List).length)}',
        FormatUtils.formatWeight(
          _outwardData.fold<double>(
            0.0,
            (sum, out) =>
                sum +
                (out['items'] as List).fold<double>(0.0, (s, i) => s + ((i['total_weight'] ?? 0) as num).toDouble()),
          ),
        ),
        FormatUtils.formatCurrency(
          _outwardData.fold<double>(
            0.0,
            (sum, out) =>
                sum +
                ((out['items'] as List).fold<double>(0.0, (s, i) => s + ((i['total_weight'] ?? 0) as num).toDouble()) * ((out['rate'] ?? 0) as num).toDouble()),
          ),
        ), // ADDED
      ],
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
        'In Val', // ADDED
        'Out Roll',
        'Out Wt',
        'Out Val', // ADDED
        'Bal Roll',
        'Bal Wt',
        'Bal Val', // ADDED
        'Status',
      ],
      rows: _closingData.map((item) {
        return <String>[
          item['lot_number'] ?? '-',
          item['lot_name'] ?? '-',
          '${item['rec_rolls'] ?? 0}',
          '${FormatUtils.formatWeight(item['rec_weight'])}',
          '${FormatUtils.formatCurrency(item['rec_value'] ?? 0)}', // ADDED
          '${item['deliv_rolls'] ?? 0}',
          '${FormatUtils.formatWeight(item['deliv_weight'])}',
          '${FormatUtils.formatCurrency(item['deliv_value'] ?? 0)}', // ADDED
          '${item['balance_rolls'] ?? 0}',
          '${FormatUtils.formatWeight(item['balance_weight'])}',
          '${FormatUtils.formatCurrency(item['balance_value'] ?? 0)}', // ADDED
          item['status'] ?? '-',
        ];
      }).toList(),
      footerRow: [
        'TOTAL',
        '',
        '${_closingData.fold<int>(0, (sum, item) => sum + ((item['rec_rolls'] ?? 0) as num).toInt())}',
        FormatUtils.formatWeight(
          _closingData.fold<double>(0.0, (sum, item) => sum + ((item['rec_weight'] ?? 0) as num).toDouble()),
        ),
        FormatUtils.formatCurrency(
          _closingData.fold<double>(0.0, (sum, item) => sum + ((item['rec_value'] ?? 0) as num).toDouble()),
        ), // ADDED
        '${_closingData.fold<int>(0, (sum, item) => sum + ((item['deliv_rolls'] ?? 0) as num).toInt())}',
        FormatUtils.formatWeight(
          _closingData.fold<double>(0.0, (sum, item) => sum + ((item['deliv_weight'] ?? 0) as num).toDouble()),
        ),
        FormatUtils.formatCurrency(
          _closingData.fold<double>(0.0, (sum, item) => sum + ((item['deliv_value'] ?? 0) as num).toDouble()),
        ), // ADDED
        '${_closingData.fold<int>(0, (sum, item) => sum + ((item['balance_rolls'] ?? 0) as num).toInt())}',
        FormatUtils.formatWeight(
          _closingData.fold<double>(0.0, (sum, item) => sum + ((item['balance_weight'] ?? 0) as num).toDouble()),
        ),
        FormatUtils.formatCurrency(
          _closingData.fold<double>(0.0, (sum, item) => sum + ((item['balance_value'] ?? 0) as num).toDouble()),
        ), // ADDED
        '',
      ],
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildReportTable({
    required List<String> headers,
    required List<List<String>> rows,
    List<String>? footerRow,
  }) {
    if (rows.isEmpty) return const Center(child: Text('No data found'));

    return Scrollbar(
      thickness: 8,
      radius: const Radius.circular(4),
      child: SingleChildScrollView(
        controller: _scrollController,
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
              dataRowMaxHeight: double.infinity,
              columnSpacing: 20,
              horizontalMargin: 12,
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
              columns: headers
                  .map(
                    (h) => DataColumn(
                      label: Text(
                        h,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              rows: [
                ...rows.map((row) {
                  return DataRow(
                    cells: row.asMap().entries.map((entry) {
                      final index = entry.key;
                      final cell = entry.value;
                      final columnHeader = headers[index];

                      Color? textColor;
                      if (columnHeader == 'Status') {
                        if (cell == 'Completed') textColor = Colors.green;
                        if (cell == 'Pending') textColor = Colors.red;
                      }

                      return DataCell(
                        Text(
                          cell,
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor,
                            fontWeight:
                                textColor != null ? FontWeight.bold : null,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),
                if (footerRow != null)
                  DataRow(
                    color: WidgetStateProperty.all(Colors.grey.shade100),
                    cells: footerRow.map((cell) {
                      return DataCell(
                        Text(
                          cell,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- EXPORT LOGIC ---

  Widget _buildShareMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(LucideIcons.share2, size: 20),
      tooltip: 'Share Report',
      onSelected: (val) => _handleShare(val),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'PDF',
          child: Row(
            children: [
              Icon(LucideIcons.fileText, size: 18),
              SizedBox(width: 8),
              Text("Share as PDF"),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'WhatsApp',
          child: Row(
            children: [
              Icon(Icons.message_outlined, size: 18),
              SizedBox(width: 8),
              Text("Share via WhatsApp"),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handlePrint() async {
    if (_isLoading) return;
    final data = _getReportDataForCurrentTab();
    if (data['rows'].isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No data to print')));
      return;
    }

    try {
      final service = _printService;
      // ignore: unnecessary_null_comparison

      print('Generating PDF for ${data['title']}');
      final pdfBytes = await service.generateReportPdf(
        title: data['title'] as String,
        headers: List<String>.from(data['headers'] as List),
        rows: List<List<String>>.from((data['rows'] as List).map((e) => List<String>.from(e as List))),
        footerRow: data['footerRow'] != null ? List<String>.from(data['footerRow'] as List) : null,
      );

      print('Navigating to Print Preview');
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _ReportPdfPreviewScreen(
            pdfBytes: pdfBytes,
            title: '${data['title']} Preview',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }

  Future<void> _handleShare(String format) async {
    if (_isLoading) return;
    final data = _getReportDataForCurrentTab();
    if (data['rows'].isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No data to share')));
      return;
    }

    if (format == 'PDF') {
      try {
        final service = _printService;
        // ignore: unnecessary_null_comparison

        final pdfBytes = await service.generateReportPdf(
          title: data['title'] as String,
          headers: List<String>.from(data['headers'] as List),
          rows: List<List<String>>.from((data['rows'] as List).map((e) => List<String>.from(e as List))),
          footerRow: data['footerRow'] != null ? List<String>.from(data['footerRow'] as List) : null,
        );

        final fileName =
            '${data['title'].replaceAll(' ', '_')}_${DateFormat('ddMMyy').format(DateTime.now())}.pdf';

        // Use Share.shareXFiles for better native sharing support
        await Share.shareXFiles(
          [
            XFile.fromData(
              pdfBytes,
              name: fileName,
              mimeType: 'application/pdf',
            ),
          ],
          text:
              '${data['title']} - ${DateFormat('dd/MM/yy').format(DateTime.now())}',
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error sharing PDF: $e')));
        }
      }
    } else if (format == 'WhatsApp') {
      final buffer = StringBuffer();
      buffer.writeln("*${data['title'].toUpperCase()}*");
      buffer.writeln(
        "Generated: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}",
      );
      buffer.writeln("---------------------------------");

      // Add Headers (Joined by |)
      buffer.writeln(data['headers'].join(" | "));
      buffer.writeln("---------------------------------");

      // Add Rows (First 30 rows to avoid WhatsApp char limit issues)
      final List<List<String>> rows = data['rows'];
      for (var row in rows.take(30)) {
        buffer.writeln(row.join(" | "));
      }

      if (rows.length > 30) {
        buffer.writeln("... and ${rows.length - 30} more items.");
      }
      buffer.writeln("---------------------------------");

      await Share.share(buffer.toString());
    }
  }

  Map<String, dynamic> _getReportDataForCurrentTab() {
    String title = "";
    List<String> headers = [];
    List<List<String>> rows = [];
    List<String>? footerRow;

    switch (_tabController.index) {
      case 0:
        title = "Aging Details Report";
        headers = [
          'Date',
          'Lot No',
          'Name',
          'Dia',
          'Colour',
          'Rolls',
          'Wt',
          'Val',
          'Days',
        ];
        rows = _agingData.map((item) {
          final aging = _calculateAging(item['inward_date']);
          final weight = (item['weight'] ?? 0) as num;
          final rate = (item['rate'] ?? item['Rate'] ?? 0) as num;
          return <String>[
            _formatDate(item['inward_date']),
            item['lot_number'] ?? '-',
            item['lot_name'] ?? '-',
            item['dia']?.toString() ?? '-',
            item['colour']?.toString() ?? '-',
            item['rolls']?.toString() ?? '0',
            weight.toStringAsFixed(1),
            (weight * rate).toStringAsFixed(0),
            '$aging',
          ];
        }).toList();
        footerRow = [
          'TOTAL',
          '',
          '',
          '',
          '',
          '${_agingData.fold<int>(0, (sum, item) => sum + ((item['rolls'] ?? 0) as num).toInt())}',
          FormatUtils.formatWeight(_agingData.fold<double>(0.0, (sum, item) => sum + ((item['weight'] ?? 0) as num).toDouble())),
          FormatUtils.formatCurrency(_agingData.fold<double>(0.0, (sum, item) => sum + (((item['weight'] ?? 0) as num) * ((item['rate'] ?? 0) as num)).toDouble())),
          '',
        ];
        break;
      case 1:
        title = "Aging Summary Report";
        headers = [
          'Lot Number',
          'Lot Name',
          'Total Rolls',
          'Total Weight',
          'Status',
        ];

        final filters = _filters[1] ?? {};
        final dateFilter = filters['date'];

        final Map<String, dynamic> summary = {};
        for (var item in _agingData) {
          // Local Date Filter
          if (dateFilter != null && dateFilter.isNotEmpty) {
            if (!_formatDate(item['inward_date']).contains(dateFilter))
              continue;
          }

          final lotNo = item['lot_number']?.toString().trim() ?? 'N/A';
          final rawLotName = item['lot_name']?.toString().trim() ?? 'N/A';
          final groupingKey = rawLotName.toUpperCase();

          if (!summary.containsKey(groupingKey)) {
            summary[groupingKey] = {
              'lotNos': <String>{},
              'lotName': rawLotName.toUpperCase(),
              'rolls': 0,
              'weight': 0.0,
              'value': 0.0, // ADDED
            };
          }
          if (lotNo != 'N/A' && lotNo.isNotEmpty) {
            summary[groupingKey]['lotNos'].add(lotNo);
          }
          summary[groupingKey]['rolls'] += (item['rolls'] ?? 0) as int;
          final weight = (item['weight'] ?? 0.0) as num;
          final rate = (item['rate'] ?? item['Rate'] ?? 0.0) as num;
          summary[groupingKey]['weight'] += weight;
          summary[groupingKey]['value'] += (weight * rate);
        }

        headers = [
          'Lot Number',
          'Lot Name',
          'Total Rolls',
          'Total Weight',
          'Total Val', // ADDED
          'Status',
        ];

        rows = summary.values.map((v) {
          final lotNosSet = v['lotNos'] as Set;
          String lotNoDisplay = 'N/A';
          if (lotNosSet.isNotEmpty) {
            final lotNosList = lotNosSet.toList();
            List<String> chunks = [];
            for (int i = 0; i < lotNosList.length; i += 2) {
              chunks.add(lotNosList.sublist(i, (i + 2 > lotNosList.length) ? lotNosList.length : i + 2).join(', '));
            }
            lotNoDisplay = chunks.join('\n');
          }

          return <String>[
            lotNoDisplay,
            v['lotName'],
            '${v['rolls']}',
            '${(v['weight'] as num).toStringAsFixed(1)} Kg',
            '${(v['value'] as num).toStringAsFixed(0)}', // ADDED
            'Pending',
          ];
        }).toList();
        footerRow = [
          'TOTAL',
          '',
          '${summary.values.fold<int>(0, (sum, v) => sum + ((v['rolls'] ?? 0) as num).toInt())}',
          '${FormatUtils.formatWeight(summary.values.fold<double>(0.0, (sum, v) => sum + ((v['weight'] ?? 0) as num).toDouble()))} Kg',
          '${FormatUtils.formatCurrency(summary.values.fold<double>(0.0, (sum, v) => sum + ((v['value'] ?? 0) as num).toDouble()))}',
          '',
        ];
        break;
      case 2:
        title = "Inward Report";
        headers = [
          'Date',
          'Inward No',
          'Party',
          'Party DC',
          'Lot No',
          'Lot Name',
          'Dia',
          'Roll',
          'Wt',
          'Val',
        ];
        for (var inward in _inwardData) {
          final entries = inward['diaEntries'] as List? ?? [];
          for (var entry in entries) {
            final weight = (entry['recWt'] ?? 0) as num;
            final rate = (entry['rate'] ?? inward['rate'] ?? 0) as num;
            rows.add([
              _formatDate(inward['inwardDate']),
              inward['inwardNo'] ?? '-',
              inward['fromParty'] ?? '-',
              inward['partyDcNo'] ?? '-',
              inward['lotNo'] ?? '-',
              inward['lotName'] ?? '-',
              entry['dia']?.toString() ?? '-',
              '${entry['recRoll'] ?? entry['roll']}',
              '${weight.toStringAsFixed(1)}',
              '${(weight * rate).toStringAsFixed(0)}',
            ]);
          }
        }
        footerRow = [
          'TOTAL',
          '',
          '',
          '',
          '',
          '',
          '',
          '${rows.fold<int>(0, (sum, r) => sum + (double.tryParse(r[7]) ?? 0).toInt())}',
          FormatUtils.formatWeight(rows.fold<double>(0.0, (sum, r) => sum + (double.tryParse(r[8]) ?? 0.0))),
          FormatUtils.formatCurrency(rows.fold<double>(0.0, (sum, r) => sum + (double.tryParse(r[9].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0))),
        ];
        break;

        title = "Outward Report";
        final filters = _filters[3] ?? {};
        final diaFilter = filters['dia'];

        if (diaFilter != null && diaFilter.toString().isNotEmpty) {
          title = "Outward Report (DIA Summary)";
          headers = ['I.no', 'dia', 'roll', 'weight'];
          final Map<String, Map<String, dynamic>> summary = {};
          for (var out in _outwardData) {
            final dia = out['dia']?.toString() ?? '-';
            if (!summary.containsKey(dia)) {
              summary[dia] = {'lots': <String>{}, 'rolls': 0, 'weight': 0.0};
            }
            if (out['lotNo'] != null) {
              summary[dia]!['lots'].add(out['lotNo'].toString());
            }
            final items = out['items'] as List? ?? [];
            summary[dia]!['rolls'] += items.length;
            summary[dia]!['weight'] += items.fold(
              0.0,
              (sum, i) => sum + (i['total_weight'] ?? 0),
            );
          }
          rows = summary.entries.map((e) {
            return <String>[
              (e.value['lots'] as Set).join(', '),
              e.key,
              '${e.value['rolls']}',
              '${(e.value['weight'] as num).toStringAsFixed(1)}',
            ];
          }).toList();
          footerRow = [
            'TOTAL',
            '',
            '${summary.values.fold<int>(0, (sum, v) => sum + ((v['rolls'] ?? 0) as num).toInt())}',
            FormatUtils.formatWeight(summary.values.fold<double>(0.0, (sum, v) => sum + ((v['weight'] ?? 0) as num))),
          ];
        } else {
          headers = [
            'Party',
            'Lot Name',
            'Date',
            'DC No',
            'Lot No',
            'Dia',
            'Process',
            'Rolls',
            'Wt',
            'Val', // ADDED
          ];
          rows = _outwardData.map((out) {
            final items = out['items'] as List? ?? [];
            final weight = items.fold(
              0.0,
              (sum, i) => sum + (i['total_weight'] ?? 0),
            );
            final rate = (out['rate'] as num?) ?? 0; // ADDED
            return <String>[
              out['partyName'] ?? '-',
              out['lotName'] ?? '-',
              _formatDate(out['dateTime']),
              out['dcNo'] ?? '-',
              out['lotNo'] ?? '-',
              out['dia']?.toString() ?? '-',
              out['process'] ?? '-',
              '${items.length}',
              weight.toStringAsFixed(1),
              (weight * ((out['rate'] ?? out['Rate'] ?? 0) as num)).toStringAsFixed(0),
            ];
          }).toList();
          footerRow = [
            'TOTAL',
            '',
            '',
            '',
            '',
            '',
            '',
            '${_outwardData.fold<int>(0, (sum, out) => sum + (out['items'] as List).length)}',
            FormatUtils.formatWeight(_outwardData.fold<double>(0.0, (sum, out) => sum + (out['items'] as List).fold<double>(0.0, (s, i) => s + ((i['total_weight'] ?? 0) as num).toDouble()))),
            FormatUtils.formatCurrency(_outwardData.fold<double>(0.0, (sum, out) => sum + ((out['items'] as List).fold<double>(0.0, (s, i) => s + ((i['total_weight'] ?? 0) as num).toDouble()) * ((out['rate'] ?? 0) as num).toDouble()))),
          ];
        }
        break;
      case 4:
        title = "Closing Stock Report";
        headers = [
          'Lot No',
          'Lot Name',
          'In Roll',
          'In Wt',
          'In Val', // ADDED
          'Out Roll',
          'Out Wt',
          'Out Val', // ADDED
          'Bal Roll',
          'Bal Wt',
          'Bal Val', // ADDED
          'Status',
        ];
        rows = _closingData.map((item) {
          return <String>[
            item['lot_number'] ?? '-',
            item['lot_name'] ?? '-',
            '${item['rec_rolls'] ?? 0}',
            '${(item['rec_weight'] as num?)?.toStringAsFixed(1) ?? "0"}',
            '${(item['rec_value'] as num?)?.toStringAsFixed(0) ?? "0"}', // ADDED
            '${item['deliv_rolls'] ?? 0}',
            '${(item['deliv_weight'] as num?)?.toStringAsFixed(1) ?? "0"}',
            '${(item['deliv_value'] as num?)?.toStringAsFixed(0) ?? "0"}', // ADDED
            '${item['balance_rolls'] ?? 0}',
            '${(item['balance_weight'] as num?)?.toStringAsFixed(1) ?? "0"}',
            '${(item['balance_value'] as num?)?.toStringAsFixed(0) ?? "0"}', // ADDED
            item['status'] ?? '-',
          ];
        }).toList();
        footerRow = [
          'TOTAL',
          '',
          '${_closingData.fold<int>(0, (sum, item) => sum + ((item['rec_rolls'] ?? 0) as num).toInt())}',
          FormatUtils.formatWeight(_closingData.fold<double>(0.0, (sum, item) => sum + ((item['rec_weight'] ?? 0) as num).toDouble())),
          FormatUtils.formatCurrency(_closingData.fold<double>(0.0, (sum, item) => sum + ((item['rec_value'] ?? 0) as num).toDouble())),
          '${_closingData.fold<int>(0, (sum, item) => sum + ((item['deliv_rolls'] ?? 0) as num).toInt())}',
          FormatUtils.formatWeight(_closingData.fold<double>(0.0, (sum, item) => sum + ((item['deliv_weight'] ?? 0) as num).toDouble())),
          FormatUtils.formatCurrency(_closingData.fold<double>(0.0, (sum, item) => sum + ((item['deliv_value'] ?? 0) as num).toDouble())),
          '${_closingData.fold<int>(0, (sum, item) => sum + ((item['balance_rolls'] ?? 0) as num).toInt())}',
          FormatUtils.formatWeight(_closingData.fold<double>(0.0, (sum, item) => sum + ((item['balance_weight'] ?? 0) as num).toDouble())),
          FormatUtils.formatCurrency(_closingData.fold<double>(0.0, (sum, item) => sum + ((item['balance_value'] ?? 0) as num).toDouble())),
          '',
        ];
        break;
    }

    return {'headers': headers, 'rows': rows, 'title': title, 'footerRow': footerRow};
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
  final List<String> lotNames;
  final List<String> lotNos;
  final List<String> parties;
  final List<String> dias;
  final List<String> colours;
  final Function(Map<String, dynamic>) onApply;

  const _FilterDialog({
    required this.tabIndex,
    required this.initialFilters,
    required this.lotNames,
    required this.lotNos,
    required this.parties,
    required this.dias,
    required this.colours,
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
              if ([0, 2, 3, 4].contains(widget.tabIndex)) ...[
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
                _buildDropdown('lotName', 'Lot Name', widget.lotNames),
              if ([0, 1, 2, 3, 4].contains(
                widget.tabIndex,
              )) // Lot No (Aging, Inward, Outward, Closing)
                _buildDropdown('lotNo', 'Lot No', widget.lotNos),
              if (widget.tabIndex == 2) // Party (Inward)
                _buildDropdown('party', 'Party Name', widget.parties),
              if ([0, 3].contains(widget.tabIndex)) // Dia (Aging, Outward)
                _buildDropdown('dia', 'Dia', widget.dias),
              if (widget.tabIndex == 0) // Colour (Aging)
                _buildDropdown('colour', 'Colour', widget.colours),
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
    final options = ['All', ...items.where((i) => i.toUpperCase() != 'ALL')];
    return CustomDropdownField(
      label: label,
      value: _filters[key] ?? 'All',
      items: options,
      onChanged: (val) {
        if (val != null) {
          setState(() {
            if (val == 'All') {
              _filters.remove(key);
            } else {
              _filters[key] = val;
            }
          });
        }
      },
    );
  }
}

class _ReportPdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;

  const _ReportPdfPreviewScreen({
    required this.pdfBytes,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: PdfPreview(
        build: (format) => pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: title.replaceAll(' ', '_') + '.pdf',
      ),
    );
  }
}
