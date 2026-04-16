import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../core/theme/color_palette.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/layout/web_layout_wrapper.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/custom_dropdown_field.dart';
import '../../utils/print_utils.dart';

class GodownStockReportScreen extends StatefulWidget {
  const GodownStockReportScreen({super.key});

  @override
  State<GodownStockReportScreen> createState() =>
      _GodownStockReportScreenState();
}

class _GodownStockReportScreenState extends State<GodownStockReportScreen> {
  final _api = MobileApiService();

  List<String> _selectedLotNames = [];
  String? _selectedDia;
  String? _statusFilter;
  String _displayUnit = 'Weight'; // 'Weight' or 'Roll'

  List<String> _lotNames = [];
  List<String> _dias = ['All'];
  final List<String> _units = ['Weight', 'Roll'];
  List<dynamic> _reportData = [];
  bool _isLoading = true;

  // Pagination State
  int _currentPage = 0;
  final int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadFiltersAndData();
  }

  Future<void> _loadFiltersAndData() async {
    try {
      final categories = await _api.getCategories();
      setState(() {
        _lotNames = _getValues(categories, 'Lot Name');
        _dias = ['All', ..._getValues(categories, 'dia')];
      });
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
      return vals.map((v) => v['name'].toString()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getGodownStockReport(
        lotName: _selectedLotNames.isEmpty ? null : _selectedLotNames,
        dia: _selectedDia == 'All' ? null : _selectedDia,
      );
      setState(() {
        _reportData = data;
        _isLoading = false;
        _currentPage = 0; 
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy HH:mm').format(now);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) => pw.Column(
          children: [
            PrintUtils.buildCompanyHeader(pw.Font.helveticaBold(), pw.Font.helvetica()),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'STOCK STATUS REPORT',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  'Generated on: $dateStr',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (pw.Context context) {
          return [
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: [
                'LOT',
                'DIA',
                'STOCK (Kg)',
                'MIN',
                'MAX',
                'NEED WT',
                'NEED ROLL',
                'STATUS',
              ],
              data: _reportData.map((item) {
                return [
                  item['lotName'],
                  item['dia'],
                  '${item['currentWeight'].toStringAsFixed(1)}${item['outsideInput'] != 0 ? ' (+${item['outsideInput']})' : ''}',
                  '${item['minWeight']}',
                  '${item['maxWeight']}',
                  '${item['needWeight'].toStringAsFixed(1)}',
                  '${(item['needWeight'] / 20).toStringAsFixed(1)}',
                  item['status'],
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );
    return pdf;
  }

  Future<void> _shareReport() async {
    if (_reportData.isEmpty) return;
    final pdf = await _generatePDF();
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'Godown_Stock_Report_${DateFormat('ddMMyy').format(DateTime.now())}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = LayoutConstants.isWeb(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'STOCK FORECASTING', 
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800, 
            fontSize: 18, 
            letterSpacing: 1,
            color: const Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        actions: [
          _buildAppBarAction(LucideIcons.printer, () async => Printing.layoutPdf(
            onLayout: (format) async => (await _generatePDF()).save(),
          )),
          _buildAppBarAction(LucideIcons.share2, _shareReport),
          _buildAppBarAction(LucideIcons.refreshCw, _fetchReport),
          const SizedBox(width: 12),
        ],
      ),
      body: isWeb ? _buildWebLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildAppBarAction(IconData icon, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: const Color(0xFF475569)),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildWebLayout() {
    return WebLayoutWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stock Forecasting Report',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Monitor inventory levels and replenishment requirements',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              _buildFiltersRow(),
            ],
          ),
          const SizedBox(height: 32),
          _buildSummaryHeader(),
          const SizedBox(height: 32),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _buildWebReportTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow() {
    return Container(
      height: 45,
      child: Row(
        children: [
          _buildCircularFilter(
            label: 'Lot Name',
            value: _selectedLotNames.isEmpty 
                ? 'All' 
                : (_selectedLotNames.length == 1 ? _selectedLotNames[0] : '${_selectedLotNames.length} Selected'),
            items: _lotNames,
            onChanged: (v) => _showLotNameMultiSelect(),
            isMulti: true,
          ),
          const SizedBox(width: 12),
          _buildCircularFilter(
            label: 'DIA',
            value: _selectedDia ?? 'All',
            items: _dias,
            onChanged: (v) {
              setState(() => _selectedDia = v);
              _fetchReport();
            },
          ),
          const SizedBox(width: 12),
          _buildCircularFilter(
            label: 'Unit',
            value: _displayUnit,
            items: _units,
            onChanged: (v) {
              if (v != null) setState(() => _displayUnit = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCircularFilter({
    required String label, 
    required String value, 
    required List<String> items,
    required Function(String?) onChanged,
    bool isMulti = false,
  }) {
    if (isMulti) {
      return InkWell(
        onTap: () => onChanged(null),
        child: Container(
          width: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value, 
                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(LucideIcons.chevronDown, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          hint: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          icon: const Icon(LucideIcons.chevronDown, size: 14, color: Color(0xFF94A3B8)),
          style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _showLotNameMultiSelect() {
    showDialog(
      context: context,
      builder: (context) => _LotNameMultiSelectDialog(
        allLots: _lotNames,
        initialSelected: _selectedLotNames,
        onApply: (selected) {
          setState(() => _selectedLotNames = selected);
          _fetchReport();
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildFilters(),
        _buildSummaryHeader(),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildReportTable(),
        ),
      ],
    );
  }

  Widget _buildWebReportTable() {
    // Apply local filters (Status)
    final filteredByStatus = _statusFilter == null 
        ? _reportData 
        : _reportData.where((d) => d['status'] == _statusFilter).toList();

    if (filteredByStatus.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              Icon(LucideIcons.filterX, size: 48, color: Colors.blueGrey.shade100),
              const SizedBox(height: 16),
              Text('No items with $_statusFilter status', style: GoogleFonts.inter(color: Colors.grey)),
            ],
          ),
        );
    }

    // Logic for Pagination
    final int startIndex = _currentPage * _rowsPerPage;
    final int endIndex = (startIndex + _rowsPerPage) > filteredByStatus.length 
        ? filteredByStatus.length 
        : (startIndex + _rowsPerPage);
    final List<dynamic> paginatedData = filteredByStatus.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                _buildHeaderText('LOT / DIA', 2),
                _buildHeaderText('IN STOCK', 1),
                _buildHeaderText('OUT STOCK', 1),
                _buildHeaderText('TOTAL STOCK', 1),
                _buildHeaderText('MIN', 1),
                _buildHeaderText('MAX', 1),
                _buildHeaderText('NEED WEIGHT', 1),
                _buildHeaderText('EST. ROLLS', 1),
                _buildHeaderText('STATUS', 1),
              ],
            ),
          ),
          // Table Rows
          Expanded(
            child: ListView.separated(
              itemCount: paginatedData.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) => _buildWebReportRow(paginatedData[index]),
            ),
          ),
          
          // Pagination Footer
          _buildPaginationFooter(),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter() {
    final int totalPages = (_reportData.length / _rowsPerPage).ceil();
    final int start = _currentPage * _rowsPerPage + 1;
    final int end = (_currentPage + 1) * _rowsPerPage > _reportData.length 
        ? _reportData.length 
        : (_currentPage + 1) * _rowsPerPage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $start to $end of ${_reportData.length} entries',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              _buildPaginationButton(
                icon: LucideIcons.chevronLeft,
                onPressed: _currentPage > 0 
                  ? () => setState(() => _currentPage--) 
                  : null,
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page ${_currentPage + 1} of $totalPages',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildPaginationButton(
                icon: LucideIcons.chevronRight,
                onPressed: (_currentPage + 1) < totalPages 
                  ? () => setState(() => _currentPage++) 
                  : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton({required IconData icon, VoidCallback? onPressed}) {
    final bool isDisabled = onPressed == null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.transparent : const Color(0xFFF8FAFC),
          border: Border.all(color: isDisabled ? const Color(0xFFF1F5F9) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon, 
          size: 16, 
          color: isDisabled ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildHeaderText(String label, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700, 
          fontSize: 11, 
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildWebReportRow(Map<String, dynamic> item) {
    final status = item['status'];
    final bool isRoll = _displayUnit == 'Roll';
    final String unitLabel = isRoll ? 'rolls' : 'kg';
    
    double convert(dynamic val) {
      final num v = (val as num?) ?? 0;
      return isRoll ? v / 20.0 : v.toDouble();
    }

    final inStock = convert(item['currentWeight']);
    final outStock = convert(item['outsideInput']);
    final totalStock = inStock + outStock;
    final minStock = convert(item['minWeight']);
    final maxStock = convert(item['maxWeight']);
    final needWeight = convert(item['needWeight']);
    final estRolls = (item['needWeight'] as num? ?? 0) / 20.0; // Estimate always based on weight logic

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['lotName'],
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                ),
                Text(
                  'DIA ${item['dia']}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          _buildCellText('${inStock.toStringAsFixed(1)} $unitLabel', 1),
          _buildCellText('${outStock.toStringAsFixed(1)} $unitLabel', 1, color: const Color(0xFF2563EB)),
          _buildCellText('${totalStock.toStringAsFixed(1)} $unitLabel', 1, fontWeight: FontWeight.w800),
          _buildCellText('${minStock.toStringAsFixed(1)}', 1),
          _buildCellText('${maxStock.toStringAsFixed(1)}', 1),
          Expanded(
            flex: 1,
            child: Text(
              needWeight.toStringAsFixed(1),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF2563EB),
                fontSize: 13,
              ),
            ),
          ),
          _buildCellText(estRolls.toStringAsFixed(1), 1, color: const Color(0xFF94A3B8)),
          Expanded(
            flex: 1,
            child: _buildStatusBadge(status),
          ),
        ],
      ),
    );
  }

  Widget _buildCellText(String text, int flex, {Color color = const Color(0xFF1E293B), FontWeight fontWeight = FontWeight.w600}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: fontWeight, color: color),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    IconData icon;

    if (status == 'LOW STOCK') {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFF991B1B);
      icon = LucideIcons.trendingDown;
    } else if (status == 'HIGH STOCK') {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFF92400E);
      icon = LucideIcons.trendingUp;
    } else {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF166534);
      icon = LucideIcons.checkCircle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(color: text, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    int lowCount = _reportData.where((d) => d['status'] == 'LOW STOCK').length;
    int highCount = _reportData.where((d) => d['status'] == 'HIGH STOCK').length;
    int normalCount = _reportData.length - lowCount - highCount;

    return Row(
      children: [
        _SummaryBox(
          label: 'LOW STOCK', 
          count: lowCount, 
          color: const Color(0xFFEF4444), 
          bgColor: const Color(0xFFFEF2F2),
          isSelected: _statusFilter == 'LOW STOCK',
          onTap: () => setState(() => _statusFilter = (_statusFilter == 'LOW STOCK' ? null : 'LOW STOCK')),
        ),
        const SizedBox(width: 20),
        _SummaryBox(
          label: 'HIGH STOCK', 
          count: highCount, 
          color: const Color(0xFFF59E0B), 
          bgColor: const Color(0xFFFFFBEB),
          isSelected: _statusFilter == 'HIGH STOCK',
          onTap: () => setState(() => _statusFilter = (_statusFilter == 'HIGH STOCK' ? null : 'HIGH STOCK')),
        ),
        const SizedBox(width: 20),
        _SummaryBox(
          label: 'NORMAL RANGE', 
          count: normalCount, 
          color: const Color(0xFF10B981), 
          bgColor: const Color(0xFFF0FDF4),
          isSelected: _statusFilter == 'NORMAL',
          onTap: () => setState(() => _statusFilter = (_statusFilter == 'NORMAL' ? null : 'NORMAL')),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: CustomDropdownField(
                label: 'Lot Name',
                value: _selectedLotNames.isEmpty 
                    ? 'All' 
                    : (_selectedLotNames.length == 1 ? _selectedLotNames[0] : '${_selectedLotNames.length} Selected'),
                items: _lotNames,
                onChanged: (v) => _showLotNameMultiSelect(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomDropdownField(
                label: 'DIA',
                value: _selectedDia ?? 'All',
                items: _dias,
                onChanged: (v) {
                  setState(() => _selectedDia = v);
                  _fetchReport();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTable() {
    if (_reportData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.package2, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No stock movements captured yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            horizontalMargin: 12,
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('LOT/DIA', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('STOCK', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('MIN', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('MAX', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('NEED WT', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('NEED ROLL', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _reportData.map((item) {
              final status = item['status'];
              Color statusColor = Colors.green;
              if (status == 'LOW STOCK') statusColor = Colors.red;
              if (status == 'HIGH STOCK') statusColor = Colors.orange;

              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(item['lotName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('DIA ${item['dia']}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${item['currentWeight'].toStringAsFixed(1)}kg', style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (item['outsideInput'] != 0)
                          Text('Adj: ${item['outsideInput']}kg', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                      ],
                    ),
                  ),
                  DataCell(Text('${item['minWeight']}', style: const TextStyle(fontSize: 11))),
                  DataCell(Text('${item['maxWeight']}', style: const TextStyle(fontSize: 11))),
                  DataCell(Text('${item['needWeight'].toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold, color: ColorPalette.primary))),
                  DataCell(Text('${(item['needWeight'] / 20).toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, color: Colors.grey))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bgColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _SummaryBox({
    Key? key,
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? bgColor : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color.withOpacity(0.5) : const Color(0xFFF1F5F9),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(color: color.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                    child: Icon(
                      label.contains('LOW') ? LucideIcons.trendingDown : 
                      (label.contains('HIGH') ? LucideIcons.trendingUp : LucideIcons.checkCircle),
                      size: 16, 
                      color: color,
                    ),
                  ),
                  if (isSelected)
                    Icon(LucideIcons.filter, size: 14, color: color),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                count.toString(),
                style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B), letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LotNameMultiSelectDialog extends StatefulWidget {
  final List<String> allLots;
  final List<String> initialSelected;
  final Function(List<String>) onApply;

  const _LotNameMultiSelectDialog({
    required this.allLots,
    required this.initialSelected,
    required this.onApply,
  });

  @override
  State<_LotNameMultiSelectDialog> createState() => _LotNameMultiSelectDialogState();
}

class _LotNameMultiSelectDialogState extends State<_LotNameMultiSelectDialog> {
  late List<String> _selected;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.allLots
        .where((l) => l.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return AlertDialog(
      title: Text('Select Lot Names', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search lots...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _selected = List.from(widget.allLots)),
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: () => setState(() => _selected = []),
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const Divider(),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final lot = filtered[index];
                    final isSel = _selected.contains(lot);
                    return CheckboxListTile(
                      value: isSel,
                      title: Text(lot, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selected.add(lot);
                          } else {
                            _selected.remove(lot);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_selected);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }
}
