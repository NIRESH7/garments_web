import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/mobile_api_service.dart';
import '../../core/utils/format_utils.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/report_print_service.dart';

import '../../widgets/custom_dropdown_field.dart';
import '../dashboard/inventory_drill_down_screen.dart';
import '../../widgets/custom_multi_select_field.dart';
import '../../widgets/modern_data_table.dart';
import '../../core/constants/layout_constants.dart';

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
  ReportPrintService get _printService => ReportPrintService();

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: widget.initialIndex);
    if (widget.initialFilters != null) { _filters[widget.initialIndex] = widget.initialFilters!; }
    _tabController.addListener(_handleTabChange);
    _loadAllData();
  }

  void _handleTabChange() { if (!_tabController.indexIsChanging) { _loadDataForTab(_tabController.index); } }

  @override void dispose() { _tabController.removeListener(_handleTabChange); _tabController.dispose(); super.dispose(); }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([ _apiService.getLotAgingReport(), _apiService.getInwards(), _apiService.getOutwards(), _apiService.getOverviewReport() ]);
      setState(() {
        _agingData = results[0]; _inwardData = results[1]; _outwardData = results[2]; _closingData = results[3];
        _masterLotNames = _agingData.map((e) => (e['lot_name']?.toString() ?? '').trim().toUpperCase()).where((s) => s.isNotEmpty).toSet().toList()..sort();
        _masterLotNos = _agingData.map((e) => e['lot_number']?.toString() ?? '').where((s) => s.isNotEmpty).toSet().toList()..sort();
        _isLoading = false;
      });
      final categories = await _apiService.getCategories();
      final parties = await _apiService.getParties();
      setState(() {
        _masterParties = parties.map((e) => e['name']?.toString() ?? '').toList()..sort();
        for (var cat in categories) {
          final name = cat['name']?.toString().toLowerCase() ?? '';
          final values = (cat['values'] as List?)?.map((v) => v['name']?.toString() ?? '').toList() ?? [];
          if (name == 'dia' || name == 'dias') _masterDias = values..sort();
          if (name == 'colour' || name == 'color' || name == 'colours' || name == 'colors') _masterColours = values..sort();
        }
      });
    } catch (e) { setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = LayoutConstants.isWeb(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text('CLIENT FORMAT REPORTS', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: false,
        actions: [ IconButton(icon: const Icon(LucideIcons.filter, size: 20), onPressed: _showFilterDialog), IconButton(icon: const Icon(LucideIcons.printer, size: 20), onPressed: _handlePrint), _buildShareMenu(), IconButton(icon: const Icon(LucideIcons.refreshCw, size: 20), onPressed: _loadAllData), const SizedBox(width: 8) ],
        bottom: TabBar(
          controller: _tabController, isScrollable: true, tabAlignment: TabAlignment.start, indicatorSize: TabBarIndicatorSize.label, indicatorWeight: 3, labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13), unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13), labelColor: const Color(0xFF1E293B), unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [ Tab(text: 'AGING DETAILS'), Tab(text: 'AGING SUMMARY'), Tab(text: 'INWARD'), Tab(text: 'OUTWARD'), Tab(text: 'CLOSING') ],
        ),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A))) : Padding( padding: isWeb ? const EdgeInsets.all(32) : const EdgeInsets.all(16), child: TabBarView( controller: _tabController, children: [ SingleChildScrollView(child: _buildAgingReport()), SingleChildScrollView(child: _buildAgingSummaryReport()), SingleChildScrollView(child: _buildInwardReport()), SingleChildScrollView(child: _buildOutwardReport()), SingleChildScrollView(child: _buildClosingReport()) ] ) )
    );
  }

  Map<int, Map<String, dynamic>> _filters = {};
  void _showFilterDialog() { final index = _tabController.index; final currentFilters = _filters[index] ?? {}; showDialog(context: context, builder: (ctx) => _FilterDialog(tabIndex: index, initialFilters: currentFilters, lotNames: _masterLotNames, lotNos: _masterLotNos, parties: _masterParties, dias: _masterDias, colours: _masterColours, onApply: (newFilters) { setState(() => _filters[index] = newFilters); _loadDataForTab(index); })); }

  Future<void> _loadDataForTab(int index) async {
    setState(() => _isLoading = true);
    final filters = _filters[index] ?? {};
    try {
      if (index == 0) {
        final data = await _apiService.getLotAgingReport(colour: filters['colour'], dia: filters['dia'], startDate: filters['startDate'], endDate: filters['endDate']);
        _agingData = data.where((item) { final selLotNames = filters['lotName'] as List<String>? ?? []; final selLotNos = filters['lotNo'] as List<String>? ?? []; if (selLotNames.isNotEmpty && !selLotNames.contains(item['lot_name']?.toString().trim().toUpperCase())) return false; if (selLotNos.isNotEmpty && !selLotNos.contains(item['lot_number']?.toString().trim())) return false; return true; }).toList();
      } else if (index == 1) {
        final data = await _apiService.getLotAgingReport();
        _agingData = data.where((item) { final selLotNames = filters['lotName'] as List<String>? ?? []; final selLotNos = filters['lotNo'] as List<String>? ?? []; if (selLotNames.isNotEmpty && !selLotNames.contains(item['lot_name']?.toString().trim().toUpperCase())) return false; if (selLotNos.isNotEmpty && !selLotNos.contains(item['lot_number']?.toString().trim())) return false; return true; }).toList();
      } else if (index == 2) {
        final data = await _apiService.getInwards(startDate: filters['startDate'], endDate: filters['endDate'], fromParty: filters['party']);
        _inwardData = data.where((item) { final selLotNames = filters['lotName'] as List<String>? ?? []; final selLotNos = filters['lotNo'] as List<String>? ?? []; if (selLotNames.isNotEmpty && !selLotNames.contains(item['lotName']?.toString().trim().toUpperCase())) return false; if (selLotNos.isNotEmpty && !selLotNos.contains(item['lotNo']?.toString().trim())) return false; return true; }).toList();
      } else if (index == 3) {
        final data = await _apiService.getOutwards(startDate: filters['startDate'], endDate: filters['endDate'], dia: filters['dia']);
        _outwardData = data.where((item) { final selLotNames = filters['lotName'] as List<String>? ?? []; final selLotNos = filters['lotNo'] as List<String>? ?? []; if (selLotNames.isNotEmpty && !selLotNames.contains(item['lotName']?.toString().trim().toUpperCase())) return false; if (selLotNos.isNotEmpty && !selLotNos.contains(item['lotNo']?.toString().trim())) return false; return true; }).toList();
      } else if (index == 4) {
        final data = await _apiService.getOverviewReport(startDate: filters['startDate'], endDate: filters['endDate'], status: filters['status']);
        _closingData = data.where((item) { final selLotNames = filters['lotName'] as List<String>? ?? []; final selLotNos = filters['lotNo'] as List<String>? ?? []; if (selLotNames.isNotEmpty && !selLotNames.contains(item['lot_name']?.toString().trim().toUpperCase())) return false; if (selLotNos.isNotEmpty && !selLotNos.contains(item['lot_number']?.toString().trim())) return false; return true; }).toList();
      }
      setState(() => _isLoading = false);
    } catch (e) { setState(() => _isLoading = false); }
  }

  Widget _buildAgingReport() {
    final columns = ['date', 'lot No', 'name', 'dia', 'colour', 'rolls', 'wt', 'val', 'days'];
    double rolls = 0, wt = 0, val = 0;
    final rows = _agingData.map((item) {
      final aging = _calculateAging(item['inward_date']); 
      final weight = _parseNum(item['weight']); 
      final rate = _parseNum(item['rate'] ?? item['Rate']);
      final rCount = _parseNum(item['rolls'] ?? 1); // Default to 1 if missing for aging roll details
      rolls += rCount; wt += weight; val += (weight * rate);
      return { 'date': _formatDate(item['inward_date']), 'lot No': item['lot_number'] ?? '-', 'name': item['lot_name'] ?? '-', 'dia': item['dia']?.toString() ?? '-', 'colour': item['colour']?.toString() ?? '-', 'rolls': rCount.toInt().toString(), 'wt': FormatUtils.formatWeight(weight), 'val': FormatUtils.formatCurrency(weight * rate), 'days': '$aging' };
    }).toList();
    return Column(children: [ Center(child: ModernDataTable(columns: columns, rows: rows, emptyMessage: 'No aging records found', showActions: false)), _buildReportFooter(rolls: rolls, weight: wt, value: val) ]);
  }

  Widget _buildAgingSummaryReport() {
    final Map<String, dynamic> summary = {};
    double rolls = 0, wt = 0, val = 0;
    for (var item in _closingData) {
      final balRolls = _parseNum(item['balance_rolls']).toInt(); 
      final balWeight = _parseNum(item['balance_weight']); 
      final balValue = _parseNum(item['balance_value']);
      if (balWeight <= 0.05 && balRolls <= 0) continue;
      final rawLotName = item['lot_name']?.toString().trim() ?? 'N/A'; final groupingKey = rawLotName.toUpperCase();
      if (!summary.containsKey(groupingKey)) { summary[groupingKey] = { 'lotName': groupingKey, 'rolls': 0, 'weight': 0.0, 'value': 0.0 }; }
      summary[groupingKey]['rolls'] += balRolls; summary[groupingKey]['weight'] += balWeight; summary[groupingKey]['value'] += balValue;
      rolls += balRolls; wt += balWeight; val += balValue;
    }
    final columns = ['lotName', 'rolls', 'weight', 'value', 'status'];
    final rows = summary.values.map((v) => { 'lotName': v['lotName'], 'rolls': '${v['rolls']}', 'weight': '${FormatUtils.formatWeight(v['weight'])} Kg', 'value': FormatUtils.formatCurrency(v['value']), 'status': 'In Stock' }).toList();
    return Column(children: [ Center(child: ModernDataTable(columns: columns, rows: rows, emptyMessage: 'Empty summary', showActions: false)), _buildReportFooter(rolls: rolls, weight: wt, value: val) ]);
  }

  Widget _buildInwardReport() {
    final List<Map<String, dynamic>> rows = [];
    double rolls = 0, wt = 0, val = 0;
    for (var inward in _inwardData) {
      for (var entry in (inward['diaEntries'] as List? ?? [])) {
        final weight = _parseNum(entry['recWt']); 
        final rate = _parseNum(entry['rate'] ?? inward['rate']);
        final rCount = _parseNum(entry['recRoll'] ?? entry['roll']);
        rolls += rCount; wt += weight; val += (weight * rate);
        rows.add({ 'date': _formatDate(inward['inwardDate']), 'inward No': inward['inwardNo'] ?? '-', 'party': inward['fromParty'] ?? '-', 'lot No': inward['lotNo'] ?? '-', 'dia': entry['dia']?.toString() ?? '-', 'roll': '$rCount', 'wt': FormatUtils.formatWeight(weight), 'val': FormatUtils.formatCurrency(weight * rate) });
      }
    }
    return Column(children: [ Center(child: ModernDataTable(columns: const ['date', 'inward No', 'party', 'lot No', 'dia', 'roll', 'wt', 'val'], rows: rows, showActions: false)), _buildReportFooter(rolls: rolls, weight: wt, value: val) ]);
  }

  Widget _buildOutwardReport() {
    final columns = ['party', 'lotName', 'date', 'dcNo', 'lotNo', 'dia', 'process', 'rolls', 'wt', 'val'];
    double rolls = 0, wt = 0, val = 0;
    final rows = _outwardData.map((out) {
      final items = out['items'] as List? ?? []; 
      final weight = items.fold(0.0, (sum, i) => (sum as double) + _parseNum(i['total_weight'])); 
      // Try 'rolls', then 'roll', otherwise fallback to 11 per item (standard set)
      final rollCount = items.fold(0.0, (sum, i) {
        final r = _parseNum(i['rolls'] ?? i['roll']);
        return (sum as double) + (r > 0 ? r : 11.0);
      });
      final rate = _parseNum(out['rate'] ?? out['Rate']);
      rolls += rollCount; wt += weight; val += (weight * rate);
      return { 'party': out['partyName'] ?? '-', 'lotName': out['lotName'] ?? '-', 'date': _formatDate(out['dateTime']), 'dcNo': out['dcNo'] ?? '-', 'lotNo': out['lotNo'] ?? '-', 'dia': out['dia']?.toString() ?? '-', 'process': out['process'] ?? '-', 'rolls': '${rollCount.toInt()}', 'wt': FormatUtils.formatWeight(weight), 'val': FormatUtils.formatCurrency(weight * rate) };
    }).toList();
    return Column(children: [ Center(child: ModernDataTable(columns: columns, rows: rows, showActions: false)), _buildReportFooter(rolls: rolls, weight: wt, value: val) ]);
  }

  Widget _buildClosingReport() {
    final columns = ['lotNo', 'lotName', 'in Roll', 'in Wt', 'out Roll', 'out Wt', 'bal Roll', 'bal Wt', 'status'];
    double inRoll = 0, inWt = 0, outRoll = 0, outWt = 0, balRoll = 0, balWt = 0;
    final rows = _closingData.where((item) {
      final balWt = _parseNum(item['balance_weight']);
      return balWt > 0.1; // Only show items with actual stock
    }).map((item) {
      inRoll += _parseNum(item['rec_rolls']); inWt += _parseNum(item['rec_weight']);
      outRoll += _parseNum(item['deliv_rolls']); outWt += _parseNum(item['deliv_weight']);
      balRoll += _parseNum(item['balance_rolls']); balWt += _parseNum(item['balance_weight']);
      return { 'lotNo': item['lot_number'] ?? '-', 'lotName': item['lot_name'] ?? '-', 'in Roll': '${item['rec_rolls'] ?? 0}', 'in Wt': FormatUtils.formatWeight(item['rec_weight']), 'out Roll': '${item['deliv_rolls'] ?? 0}', 'out Wt': FormatUtils.formatWeight(item['deliv_weight']), 'bal Roll': '${item['balance_rolls'] ?? 0}', 'bal Wt': FormatUtils.formatWeight(item['balance_weight']), 'status': item['status'] ?? '-' };
    }).toList();
    return Column(children: [ 
      Center(child: ModernDataTable(columns: columns, rows: rows, showActions: false)), 
      _buildReportFooter(rolls: balRoll, weight: balWt, label: 'CLOSING (BAL)') 
    ]);
  }

  Widget _buildReportFooter({required double rolls, required double weight, double? value, String label = 'TOTALS'}) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4)),
            child: Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
          ),
          const Spacer(),
          _buildFooterMetric('Total Rolls', '${rolls.toInt()}', LucideIcons.layers),
          const SizedBox(width: 40),
          _buildFooterMetric('Total Weight', '${FormatUtils.formatWeight(weight)} Kg', LucideIcons.scale),
          if (value != null) ...[
            const SizedBox(width: 40),
            _buildFooterMetric('Total Value', FormatUtils.formatCurrency(value), LucideIcons.indianRupee),
          ],
        ],
      ),
    );
  }

  Widget _buildFooterMetric(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
            Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
          ],
        ),
      ],
    );
  }

  Widget _buildShareMenu() { return PopupMenuButton<String>( icon: const Icon(LucideIcons.share2, size: 20), onSelected: _handleShare, itemBuilder: (context) => [ const PopupMenuItem(value: 'PDF', child: Row(children: [Icon(LucideIcons.fileText, size: 18), SizedBox(width: 8), Text("Share PDF")])), const PopupMenuItem(value: 'WhatsApp', child: Row(children: [Icon(Icons.message_outlined, size: 18), SizedBox(width: 8), Text("Share WhatsApp")])) ] ); }

  Future<void> _handlePrint() async {
    final data = _getReportDataForCurrentTab();
    final pdfBytes = await _printService.generateReportPdf( title: data['title'] as String, headers: List<String>.from(data['headers'] as List), rows: (data['rows'] as List).map((e) => List<String>.from(e as List)).toList(), footerRow: data['footerRow'] != null ? List<String>.from(data['footerRow'] as List) : null );
    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => _ReportPdfPreviewScreen(pdfBytes: pdfBytes, title: '${data['title']} Preview')));
  }

  Future<void> _handleShare(String format) async {
    final data = _getReportDataForCurrentTab();
    if (format == 'PDF') {
      final pdfBytes = await _printService.generateReportPdf( title: data['title'] as String, headers: List<String>.from(data['headers'] as List), rows: (data['rows'] as List).map((e) => List<String>.from(e as List)).toList(), footerRow: data['footerRow'] != null ? List<String>.from(data['footerRow'] as List) : null );
      await Share.shareXFiles([XFile.fromData(pdfBytes, name: 'Report.pdf', mimeType: 'application/pdf')]);
    } else {
      final buffer = StringBuffer(); buffer.writeln("*${data['title'].toString().toUpperCase()}*"); buffer.writeln("Date: ${DateFormat('dd-MM-yy').format(DateTime.now())}"); buffer.writeln("---------------------------------");
      for (var row in (data['rows'] as List).take(30)) { buffer.writeln((row as List).join(" | ")); }
      await Share.share(buffer.toString());
    }
  }

  Map<String, dynamic> _getReportDataForCurrentTab() {
    String title = ""; List<String> headers = []; List<List<String>> rows = []; List<String>? footerRow;
    switch (_tabController.index) {
      case 0:
        title = "Aging Details Report"; headers = ['Date', 'Lot No', 'Name', 'Dia', 'Colour', 'Rolls', 'Wt', 'Val', 'Days'];
        rows = _agingData.map((item) {
          final aging = _calculateAging(item['inward_date']); final weight = (item['weight'] ?? 0) as num; final rate = (item['rate'] ?? item['Rate'] ?? 0) as num;
          return [ _formatDate(item['inward_date']), item['lot_number']?.toString() ?? '-', item['lot_name']?.toString() ?? '-', item['dia']?.toString() ?? '-', item['colour']?.toString() ?? '-', item['rolls']?.toString() ?? '0', weight.toStringAsFixed(1), (weight * rate).toStringAsFixed(0), '$aging' ];
        }).toList();
        footerRow = [ 'TOTAL', '', '', '', '', '${_agingData.fold<int>(0, (sum, item) => sum + ((item['rolls'] ?? 0) as num).toInt())}', FormatUtils.formatWeight(_agingData.fold<double>(0.0, (sum, item) => sum + ((item['weight'] ?? 0) as num).toDouble())), FormatUtils.formatCurrency(_agingData.fold<double>(0.0, (sum, item) => sum + (((item['weight'] ?? 0) as num) * ((item['rate'] ?? 0) as num)).toDouble())), '' ];
        break;
      case 1:
        title = "Aging Summary Report"; headers = ['Lot Name', 'Total Rolls', 'Total Weight', 'Total Val', 'Status'];
        final Map<String, dynamic> summary = {};
        for (var item in _agingData) {
          final groupingKey = (item['lot_name']?.toString().trim().toUpperCase() ?? 'N/A');
          if (!summary.containsKey(groupingKey)) { summary[groupingKey] = { 'lotName': groupingKey, 'rolls': 0, 'weight': 0.0, 'value': 0.0 }; }
          summary[groupingKey]['rolls'] += (item['rolls'] ?? 0) as int; summary[groupingKey]['weight'] += (item['weight'] ?? 0.0) as num;
          final w = (item['weight'] ?? 0.0) as num; final r = (item['rate'] ?? 0.0) as num;
          summary[groupingKey]['value'] += w * r;
        }
        rows = summary.values.map((v) => [ v['lotName'].toString(), v['rolls'].toString(), (v['weight'] as num).toStringAsFixed(1), (v['value'] as num).toStringAsFixed(0), 'Pending' ]).toList();
        footerRow = [ 'TOTAL', '${summary.values.fold<int>(0, (sum, v) => sum + ((v['rolls'] ?? 0) as num).toInt())}', FormatUtils.formatWeight(summary.values.fold<double>(0.0, (sum, v) => sum + ((v['weight'] ?? 0) as num).toDouble())), FormatUtils.formatCurrency(summary.values.fold<double>(0.0, (sum, v) => sum + ((v['value'] ?? 0) as num).toDouble())), '' ];
        break;
      case 2:
        title = "Inward Report"; headers = ['Date', 'Inward No', 'Party', 'Lot No', 'Dia', 'Roll', 'Wt', 'Val'];
        for (var inward in _inwardData) {
          for (var entry in (inward['diaEntries'] as List? ?? [])) {
            final weight = (entry['recWt'] ?? 0) as num; final rate = (entry['rate'] ?? inward['rate'] ?? 0) as num;
            rows.add([ _formatDate(inward['inwardDate']), inward['inwardNo']?.toString() ?? '-', inward['fromParty']?.toString() ?? '-', inward['lotNo']?.toString() ?? '-', entry['dia']?.toString() ?? '-', '${entry['recRoll'] ?? entry['roll']}', weight.toStringAsFixed(1), (weight * rate).toStringAsFixed(0) ]);
          }
        }
        footerRow = [ 'TOTAL', '', '', '', '', '${rows.fold<int>(0, (sum, r) => sum + (int.tryParse(r[5]) ?? 0))}', FormatUtils.formatWeight(rows.fold<double>(0.0, (sum, r) => sum + (double.tryParse(r[6]) ?? 0.0))), FormatUtils.formatCurrency(rows.fold<double>(0.0, (sum, r) => sum + (double.tryParse(r[7]) ?? 0.0))) ];
        break;
      case 3:
        title = "Outward Report"; headers = ['Party', 'Lot Name', 'Date', 'DC No', 'Lot No', 'Dia', 'Rolls', 'Wt', 'Val'];
        for (var out in _outwardData) {
          final items = out['items'] as List? ?? []; 
          final weight = items.fold(0.0, (sum, i) => sum + (i['total_weight'] ?? 0)); 
          final rollCount = items.fold(0.0, (sum, i) {
            final r = _parseNum(i['rolls'] ?? i['roll']);
            return (sum as double) + (r > 0 ? r : 11.0);
          });
          final rate = (out['rate'] ?? out['Rate'] ?? 0) as num;
          rows.add([ out['partyName']?.toString() ?? '-', out['lotName']?.toString() ?? '-', _formatDate(out['dateTime']), out['dcNo']?.toString() ?? '-', out['lotNo']?.toString() ?? '-', out['dia']?.toString() ?? '-', '${rollCount.toInt()}', weight.toStringAsFixed(1), (weight * rate).toStringAsFixed(0) ]);
        }
        footerRow = [ 'TOTAL', '', '', '', '', '', '${rows.fold<int>(0, (sum, r) => sum + (int.tryParse(r[6]) ?? 0))}', FormatUtils.formatWeight(rows.fold<double>(0.0, (sum, r) => sum + (double.tryParse(r[7]) ?? 0.0))), FormatUtils.formatCurrency(rows.fold<double>(0.0, (sum, r) => sum + (double.tryParse(r[8].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0))) ];
        break;
      case 4:
        title = "Closing Stock Report"; headers = ['Lot No', 'Lot Name', 'In Roll', 'In Wt', 'Out Roll', 'Out Wt', 'Bal Roll', 'Bal Wt', 'Status'];
        rows = _closingData.map((item) => [ item['lot_number']?.toString() ?? '-', item['lot_name']?.toString() ?? '-', '${item['rec_rolls'] ?? 0}', (item['rec_weight'] as num?)?.toStringAsFixed(1) ?? '0', '${item['deliv_rolls'] ?? 0}', (item['deliv_weight'] as num?)?.toStringAsFixed(1) ?? '0', '${item['balance_rolls'] ?? 0}', (item['balance_weight'] as num?)?.toStringAsFixed(1) ?? '0', item['status']?.toString() ?? '-' ]).toList();
        footerRow = [ 'TOTAL', '', '${_closingData.fold<int>(0, (sum, item) => sum + ((item['rec_rolls'] ?? 0) as num).toInt())}', FormatUtils.formatWeight(_closingData.fold<double>(0.0, (sum, item) => sum + ((item['rec_weight'] ?? 0) as num).toDouble())), '${_closingData.fold<int>(0, (sum, item) => sum + ((item['deliv_rolls'] ?? 0) as num).toInt())}', FormatUtils.formatWeight(_closingData.fold<double>(0.0, (sum, item) => sum + ((item['deliv_weight'] ?? 0) as num).toDouble())), '${_closingData.fold<int>(0, (sum, item) => sum + ((item['balance_rolls'] ?? 0) as num).toInt())}', FormatUtils.formatWeight(_closingData.fold<double>(0.0, (sum, item) => sum + ((item['balance_weight'] ?? 0) as num).toDouble())), '' ];
        break;
    }
    return {'headers': headers, 'rows': rows, 'title': title, 'footerRow': footerRow};
  }

  String _formatDate(String? dateStr) { if (dateStr == null) return '-'; try { return DateFormat('dd/MM/yy').format(DateTime.parse(dateStr)); } catch (_) { return dateStr; } }
  int _calculateAging(String? dateStr) { if (dateStr == null) return 0; try { return DateTime.now().difference(DateTime.parse(dateStr)).inDays; } catch (_) { return 0; } }

  double _parseNum(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class _FilterDialog extends StatefulWidget {
  final int tabIndex; final Map<String, dynamic> initialFilters; final List<String> lotNames; final List<String> lotNos; final List<String> parties; final List<String> dias; final List<String> colours; final Function(Map<String, dynamic>) onApply;
  const _FilterDialog({required this.tabIndex, required this.initialFilters, required this.lotNames, required this.lotNos, required this.parties, required this.dias, required this.colours, required this.onApply});
  @override State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late Map<String, dynamic> _filters; final controllerStart = TextEditingController();
  @override void initState() { super.initState(); _filters = Map.from(widget.initialFilters); controllerStart.text = _filters['startDate'] ?? ''; }
  @override Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Registry', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [ TextField(controller: controllerStart, readOnly: true, decoration: const InputDecoration(labelText: 'Start Date', border: OutlineInputBorder(), suffixIcon: Icon(LucideIcons.calendar)), onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030)); if (d != null) setState(() { _filters['startDate'] = DateFormat('yyyy-MM-dd').format(d); controllerStart.text = _filters['startDate']; }); }), const SizedBox(height: 16), CustomMultiSelectField(label: 'Lot Name', items: widget.lotNames, selectedValues: List<String>.from(_filters['lotName'] ?? []), onChanged: (v) => setState(() => _filters['lotName'] = v)), ]),
      actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () { widget.onApply(_filters); Navigator.pop(context); }, child: const Text('Apply')), ],
    );
  }
}

class _ReportPdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes; final String title;
  const _ReportPdfPreviewScreen({required this.pdfBytes, required this.title});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: PdfPreview(build: (format) => pdfBytes));
}
