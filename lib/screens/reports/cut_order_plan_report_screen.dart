import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../services/mobile_api_service.dart';
import '../../utils/print_utils.dart';

class CutOrderPlanReportScreen extends StatelessWidget {
  const CutOrderPlanReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CutOrderPlanReportView();
  }
}

class CutOrderPlanReportView extends StatefulWidget {
  const CutOrderPlanReportView({super.key});

  @override
  State<CutOrderPlanReportView> createState() => _CutOrderPlanReportViewState();
}

class _CutOrderPlanReportViewState extends State<CutOrderPlanReportView> {
  final _api = MobileApiService();
  bool _isLoading = true;
  List<dynamic> _reportData = [];
  
  // Pagination
  int _currentPage = 1;
  final int _pageSize = 10;

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedItem = 'ALL ITEMS';
  String _selectedSize = 'ALL';

  List<String> _itemNames = ['ALL ITEMS'];
  final List<String> _sizes = [
    'ALL', '75', '80', '85', '90', '95', '100', '105', '110', '50', '55', '60', '65', '70'
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
        _itemNames = ['ALL ITEMS', ...items];
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
        itemName: _selectedItem == 'ALL ITEMS' ? null : _selectedItem,
        size: _selectedSize == 'ALL' ? null : _selectedSize,
      );
      setState(() {
        _reportData = data;
        _isLoading = false;
        _currentPage = 1;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          // Header
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
                  'CUTTING VARIANCES',
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
                              Expanded(child: _buildReportTable()),
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

  Widget _buildCompactFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        height: 64, // Fixed height for a compact look
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Date Range
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDateRange: _startDate != null && _endDate != null
                        ? DateTimeRange(start: _startDate!, end: _endDate!)
                        : null,
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate = picked.start;
                      _endDate = picked.end;
                    });
                    _fetchReport();
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DATE RANGE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(LucideIcons.calendar, size: 12, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Text(
                          _startDate == null ? 'ALL TIME' : '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(height: 32, width: 1, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 16)),
            // Select Item
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SELECT ITEM', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedItem,
                      isDense: true,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                      items: _itemNames.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
                      onChanged: (val) {
                        setState(() => _selectedItem = val!);
                        _fetchReport();
                      },
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 32, width: 1, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 16)),
            // Size
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SIZE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSize,
                      isDense: true,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                      items: _sizes.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
                      onChanged: (val) {
                        setState(() => _selectedSize = val!);
                        _fetchReport();
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedItem != 'ALL ITEMS' || _startDate != null || _selectedSize != 'ALL') 
              IconButton(
                onPressed: () {
                  setState(() {
                    _startDate = null; _endDate = null; _selectedItem = 'ALL ITEMS'; _selectedSize = 'ALL';
                  });
                  _fetchReport();
                }, 
                icon: const Icon(LucideIcons.xCircle, size: 16, color: Color(0xFFEF4444)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTable() {
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
                DataColumn(label: Text('PLAN NAME')),
                DataColumn(label: Text('ITEM NAME')),
                DataColumn(label: Text('SIZE')),
                DataColumn(label: Text('PLANNED DZ')),
                DataColumn(label: Text('ISSUED DZ')),
                DataColumn(label: Text('PENDING DZ')),
              ],
              rows: paginatedData.map((row) {
                final pending = (row['pending'] as num? ?? 0).toDouble();
                final planned = (row['planned'] as num? ?? 0);
                final issued = (row['issued'] as num? ?? 0);
                return DataRow(
                  cells: [
                    DataCell(Text(row['planName']?.toString().toUpperCase() ?? row['planId']?.toString().toUpperCase() ?? '-')),
                    DataCell(Text(row['itemName']?.toString().toUpperCase() ?? '-')),
                    DataCell(Text(row['size']?.toString() ?? '-')),
                    DataCell(Text('$planned DZ')),
                    DataCell(Text('$issued DZ')),
                    DataCell(
                      Text(
                        '${row['pending'] ?? 0} DZ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: pending > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
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
            'SHOWING $startItem-$endItem OF $totalItems VARIANCES',
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
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isDisabled ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  Widget _buildActionIcons() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(LucideIcons.printer, size: 18, color: Color(0xFF64748B)),
          onPressed: () async => Printing.layoutPdf(
            onLayout: (format) async => (await _generatePDF()).save(),
          ),
        ),
        IconButton(
          icon: const Icon(LucideIcons.refreshCw, size: 18, color: Color(0xFF64748B)),
          onPressed: _fetchReport,
        ),
      ],
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
            pw.Text('PRODUCTION CUTTING VARIANCES REPORT', style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColors.blueGrey800)),
            pw.Text('Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}', style: pw.TextStyle(font: normal, fontSize: 8)),
          ],
        ),
        pw.SizedBox(height: 15),
        pw.TableHelper.fromTextArray(
          headers: ['PLAN NAME', 'ITEM NAME', 'SIZE', 'PLANNED', 'ISSUED', 'PENDING'],
          headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellStyle: pw.TextStyle(font: normal, fontSize: 7),
          data: dataSubset.map((i) => [
             (i['planName']?.toString() ?? i['planId']?.toString() ?? '-').toUpperCase(),
             (i['itemName']?.toString().toUpperCase() ?? '-'),
             (i['size']?.toString() ?? '-'),
             '${i['planned'] ?? 0} DZ',
             '${i['issued'] ?? 0} DZ',
             '${i['pending'] ?? 0} DZ',
          ]).toList(),
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
          Icon(LucideIcons.fileSearch, size: 40, color: const Color(0xFF94A3B8).withOpacity(0.3)),
          const SizedBox(height: 12),
          Text('No cutting variances identified', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}
