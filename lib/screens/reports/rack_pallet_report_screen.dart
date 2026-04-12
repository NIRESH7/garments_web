import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../services/mobile_api_service.dart';
import '../../utils/print_utils.dart';

class RackPalletReportScreen extends StatefulWidget {
  const RackPalletReportScreen({super.key});

  @override
  State<RackPalletReportScreen> createState() => _RackPalletReportScreenState();
}

class _RackPalletReportScreenState extends State<RackPalletReportScreen> {
  final _api = MobileApiService();
  bool _isLoading = true;
  bool _isPrinting = false;
  List<dynamic> _reportData = [];
  
  // Pagination
  int _currentPage = 1;
  final int _pageSize = 10;

  // Filters
  String _selectedLot = 'ALL LOTS';
  String _selectedRack = 'ALL RACKS';
  String _selectedPallet = 'ALL PALLETS';

  List<String> _lotNames = ['ALL LOTS'];
  List<String> _racks = ['ALL RACKS'];
  List<String> _pallets = ['ALL PALLETS'];

  @override
  void initState() {
    super.initState();
    _loadInitialConfig();
  }

  Future<void> _loadInitialConfig() async {
    try {
      final categories = await _api.getCategories();
      if (mounted) {
        setState(() {
          _lotNames = ['ALL LOTS', ..._getValues(categories, 'Lot Name')];
        });
      }
      _fetchReport();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _getValues(List<dynamic> categories, String name) {
    try {
      final match = categories.firstWhere(
        (c) => (c['name'] ?? '').toString().toLowerCase() == name.toLowerCase(),
        orElse: () => null,
      );
      if (match == null) return [];
      final vals = match['values'] as List;
      return vals.map((v) => v is Map ? v['name'].toString() : v.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _fetchReport() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _api.getRackPalletStockReport(
        lotName: _selectedLot == 'ALL LOTS' ? null : _selectedLot,
        rackName: _selectedRack == 'ALL RACKS' ? null : _selectedRack,
        palletNo: _selectedPallet == 'ALL PALLETS' ? null : _selectedPallet,
      );
      
      if (mounted) {
        setState(() {
          _reportData = data;
          
          if (_racks.length <= 1) {
            final uniqueRacks = data.map((e) => (e['rackName'] ?? 'N/A').toString()).toSet().toList();
            uniqueRacks.sort();
            _racks = ['ALL RACKS', ...uniqueRacks.where((r) => r != 'N/A' && r != 'null' && r != '-')];
          }
          
          if (_pallets.length <= 1) {
            final uniquePallets = data.map((e) => (e['palletNo'] ?? 'N/A').toString()).toSet().toList();
            uniquePallets.sort();
            _pallets = ['ALL PALLETS', ...uniquePallets.where((p) => p != 'N/A' && p != 'null' && p != '-')];
          }

          _currentPage = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Operational Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.arrowLeft, size: 20, color: Color(0xFF1E293B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                Text(
                  'RACK & PALLET INVENTORY',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: const Color(0xFF1E293B),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                _buildActionIcons(),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          
          _buildCompactFilterBar(),
          _buildInventoryAnalytics(),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _reportData.isEmpty
                        ? _buildEmptyState()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _buildMasterGrid()),
                              _buildPaginationBar(),
                            ],
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcons() {
    return Row(
      children: [
        if (_isPrinting)
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        else
          IconButton(
            icon: const Icon(LucideIcons.printer, size: 18, color: Color(0xFF64748B)),
            onPressed: () async {
              if (_reportData.length > 500) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dataset too large for instant print. Try filtering below 500 items.'))
                );
                return;
              }
              setState(() => _isPrinting = true);
              try {
                await Printing.layoutPdf(
                  onLayout: (format) async => (await _generatePDF()).save(),
                );
              } finally {
                setState(() => _isPrinting = false);
              }
            },
          ),
        IconButton(
          icon: const Icon(LucideIcons.refreshCw, size: 18, color: Color(0xFF64748B)),
          onPressed: _fetchReport,
        ),
      ],
    );
  }

  Widget _buildCompactFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            _buildDropdownFilter('LOT NAME', _selectedLot, _lotNames, (v) => setState(() => _selectedLot = v!)),
            _buildVerticalDivider(),
            _buildDropdownFilter('LOCATION RACK', _selectedRack, _racks, (v) => setState(() => _selectedRack = v!)),
            _buildVerticalDivider(),
            _buildDropdownFilter('PALLET UNIT', _selectedPallet, _pallets, (v) => setState(() => _selectedPallet = v!)),
            if (_selectedLot != 'ALL LOTS' || _selectedRack != 'ALL RACKS' || _selectedPallet != 'ALL PALLETS')
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedLot = 'ALL LOTS'; _selectedRack = 'ALL RACKS'; _selectedPallet = 'ALL PALLETS';
                  });
                  _fetchReport();
                },
                icon: const Icon(LucideIcons.xCircle, size: 16, color: Color(0xFFEF4444)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter(String label, String value, List<String> items, Function(String?) onChanged) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
          const SizedBox(height: 2),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: items.contains(value) ? value : items.first,
              isDense: true,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
              onChanged: (v) {
                onChanged(v);
                _fetchReport();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() => Container(height: 32, width: 1, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 16));

  Widget _buildInventoryAnalytics() {
    double totalWeight = _reportData.fold(0.0, (sum, item) => sum + (item['weight'] ?? 0));
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        children: [
          _analyticsChip(LucideIcons.layers, '${_reportData.length}', 'TOTAL UNITS'),
          const SizedBox(width: 12),
          _analyticsChip(LucideIcons.scale, '${totalWeight.toStringAsFixed(2)} KG', 'TOTAL WEIGHT'),
        ],
      ),
    );
  }

  Widget _analyticsChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: const Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildMasterGrid() {
    final startIndex = (_currentPage - 1) * _pageSize;
    final paginatedData = _reportData.skip(startIndex).take(_pageSize).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowHeight: 45,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 48,
              columnSpacing: 30,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFF64748B), letterSpacing: 0.5),
              dataTextStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)),
              columns: const [
                DataColumn(label: Text('LOCATION (R/P)')),
                DataColumn(label: Text('LOT NAME')),
                DataColumn(label: Text('LOT NO')),
                DataColumn(label: Text('COLOUR')),
                DataColumn(label: Text('WEIGHT (KG)')),
                DataColumn(label: Text('SET NO')),
                DataColumn(label: Text('INWARD DATE')),
              ],
              rows: paginatedData.map((item) {
                final rack = (item['rackName']?.toString() ?? '-');
                final pallet = (item['palletNo']?.toString() ?? '-');
                final isUnassigned = rack == '-' || rack == 'N/A' || pallet == '-' || pallet == 'N/A';
                
                return DataRow(
                  cells: [
                    DataCell(
                      isUnassigned 
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(2)),
                            child: Text('NOT ASSIGNED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFFEF4444))),
                          )
                        : Text('R:$rack - P:$pallet', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    DataCell(Text(item['lotName']?.toString().toUpperCase() ?? 'N/A')),
                    DataCell(Text(item['lotNo']?.toString() ?? 'N/A')),
                    DataCell(Text(item['colour']?.toString().toUpperCase() ?? 'N/A')),
                    DataCell(Text('${(item['weight'] ?? 0).toStringAsFixed(2)}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF2563EB)))),
                    DataCell(Text(item['setNo']?.toString() ?? 'N/A')),
                    DataCell(Text(item['inwardDate'] != null ? DateFormat('dd MMM yy').format(DateTime.parse(item['inwardDate'])) : 'N/A')),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      }
    );
  }

  Widget _buildPaginationBar() {
    final int totalItems = _reportData.length;
    final int totalPages = (totalItems / _pageSize).ceil();
    final int startItem = (totalItems == 0) ? 0 : ((_currentPage - 1) * _pageSize) + 1;
    final int endItem = (_currentPage * _pageSize).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Text(
            'SHOWING $startItem-$endItem OF $totalItems STOCK ITEMS',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5),
          ),
          const Spacer(),
          _buildPageBtn('PREV', _currentPage > 1 ? () => setState(() => _currentPage--) : null),
          const SizedBox(width: 8),
          _buildPageBtn('NEXT', _currentPage < totalPages ? () => setState(() => _currentPage++) : null),
        ],
      ),
    );
  }

  Widget _buildPageBtn(String label, VoidCallback? onTap) {
    bool isDisabled = onTap == null;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isDisabled ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: isDisabled ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B)),
        ),
      ),
    );
  }

  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();
    final dataSubset = _reportData.take(500).toList();
    final bold = pw.Font.helveticaBold();
    final normal = pw.Font.helvetica();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => PrintUtils.buildCompanyHeader(bold, normal),
      build: (pw.Context context) => [
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('RACK & PALLET INVENTORY REPORT', style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColors.blueGrey800)),
            pw.Text('Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}', style: pw.TextStyle(font: normal, fontSize: 8)),
          ],
        ),
        pw.SizedBox(height: 15),
        pw.TableHelper.fromTextArray(
          headers: ['RACK', 'PALLET', 'LOT NAME', 'LOT NO', 'COLOUR', 'WEIGHT', 'SET NO'],
          headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellStyle: pw.TextStyle(font: normal, fontSize: 7),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(2),
            5: const pw.FlexColumnWidth(1.5),
            6: const pw.FlexColumnWidth(1.5),
          },
          data: dataSubset.map((i) => [
             (i['rackName'] ?? '-').toString(),
             (i['palletNo'] ?? '-').toString(),
             (i['lotName'] ?? 'N/A').toString(),
             (i['lotNo'] ?? 'N/A').toString(),
             (i['colour'] ?? 'N/A').toString(),
             '${(i['weight'] ?? 0).toStringAsFixed(2)}',
             (i['setNo'] ?? 'N/A').toString()
          ]).toList(),
        ),
        if (_reportData.length > 500)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Text('Note: Report truncated to first 500 items for stability. Please use filters for specific data.', style: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.red)),
          ),
      ],
    ));
    return pdf;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.package2, size: 40, color: const Color(0xFF94A3B8).withOpacity(0.3)),
          const SizedBox(height: 12),
          Text('No stock identification found', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}
