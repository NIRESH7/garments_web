import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../../core/theme/color_palette.dart';
import '../../core/utils/format_utils.dart';
import '../../services/mobile_api_service.dart';
import '../../services/report_print_service.dart';
import '../../widgets/responsive_wrapper.dart';

class InventoryDrillDownScreen extends StatefulWidget {
  final String type; // 'opening', 'inward', 'outward', 'closing'
  final String? lotName;
  final String? lotNo;
  final String? dia;
  final String? setNo;
  final String? startDate;
  final String? endDate;

  const InventoryDrillDownScreen({
    super.key,
    required this.type,
    this.lotName,
    this.lotNo,
    this.dia,
    this.setNo,
    this.startDate,
    this.endDate,
  });

  @override
  State<InventoryDrillDownScreen> createState() => _InventoryDrillDownScreenState();
}

class _InventoryDrillDownScreenState extends State<InventoryDrillDownScreen> {
  final _api = MobileApiService();
  final _printService = ReportPrintService();
  List<dynamic> _data = [];
  bool _isLoading = true;
  int _currentPage = 0;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
    });
    try {
      final res = await _api.getInventoryDrillDown(
        type: widget.type,
        lotName: widget.lotName,
        lotNo: widget.lotNo,
        dia: widget.dia,
        setNo: widget.setNo,
        startDate: widget.startDate,
        endDate: widget.endDate,
      );
      setState(() {
        // Filter out negative values as requested by user
        _data = res.where((item) {
          final rolls = (item['totalRolls'] ?? 0) as num;
          final weight = (item['totalWeight'] ?? 0) as num;
          return rolls >= 0 && weight >= 0;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  List<dynamic> get _paginatedData {
    int start = _currentPage * _pageSize;
    int end = start + _pageSize;
    if (end > _data.length) end = _data.length;
    return _data.sublist(start, end);
  }

  int get _totalPages => (_data.length / _pageSize).ceil();

  String get _title {
    String t = widget.type.toUpperCase();
    if (widget.lotName != null) t = widget.lotName!;
    if (widget.lotNo != null) t = 'Lot No: ${widget.lotNo}';
    if (widget.dia != null) t = '${widget.dia} Dia Details';
    if (widget.setNo != null) t = '${widget.setNo} Details';
    return t;
  }

  String get _levelLabel {
    if (widget.lotName == null) return 'LOT NAME';
    if (widget.lotNo == null) return 'LOT NUMBER';
    if (widget.dia == null) return 'DIA';
    
    final bool isColorLevelFromSkip = _data.isNotEmpty && _data.any((item) => item['isColorLevel'] == true);
    if (widget.setNo == null && !isColorLevelFromSkip) return 'SET';
    
    return 'COLOR';
  }

  Color get _themeColor {
    switch (widget.type) {
      case 'inward':
        return ColorPalette.success;
      case 'outward':
        return ColorPalette.error;
      default:
        return ColorPalette.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: ColorPalette.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.printer, size: 18),
            onPressed: () => _handlePrint(share: false),
            tooltip: 'Print PDF',
          ),
          IconButton(
            icon: const Icon(LucideIcons.share2, size: 18),
            onPressed: () => _handlePrint(share: true),
            tooltip: 'Share PDF',
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: _fetchData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveWrapper(
        child: Column(
          children: [
            _buildPathBreadcrumbs(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _data.isEmpty
                      ? _buildEmptyState()
                      : _buildDataTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathBreadcrumbs() {
    List<String> parts = [widget.type.toUpperCase()];
    if (widget.lotName != null) parts.add(widget.lotName!);
    if (widget.lotNo != null) parts.add('Lot ${widget.lotNo}');
    if (widget.dia != null) parts.add('${widget.dia}Φ');
    if (widget.setNo != null) parts.add(widget.setNo!);

    return Container(
      width: double.infinity,
      color: ColorPalette.background,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: parts.asMap().entries.map((entry) {
            final isLast = entry.key == parts.length - 1;
            return Row(
              children: [
                Text(
                  entry.value,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
                    color: isLast ? _themeColor : ColorPalette.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                if (!isLast)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(LucideIcons.chevronRight, size: 12, color: ColorPalette.textMuted),
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
          Icon(LucideIcons.packageOpen, size: 48, color: ColorPalette.border),
          const SizedBox(height: 16),
          Text(
            'No inventory data available.',
            style: GoogleFonts.inter(color: ColorPalette.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorPalette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC), // Ultra-clean slate header
                border: Border(bottom: BorderSide(color: ColorPalette.border.withOpacity(0.8))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(_levelLabel,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 10, color: ColorPalette.textMuted, letterSpacing: 0.8)),
                  ),
                  Expanded(
                    flex: widget.setNo != null ? 2 : 1,
                    child: Text('ROLLS',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 10, color: ColorPalette.textMuted, letterSpacing: 0.8)),
                  ),
                  if (widget.setNo != null || (_data.isNotEmpty && _data.any((i) => i['isColorLevel'] == true)))
                    Expanded(
                      flex: 2,
                      child: Text(widget.type == 'inward' ? 'INW DATE' : 'OUT DATE',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 10, color: ColorPalette.textMuted, letterSpacing: 0.8)),
                    ),
                  Expanded(
                    flex: 2,
                    child: Text('WEIGHT',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 10, color: ColorPalette.textMuted, letterSpacing: 0.8)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('VALUE',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 10, color: ColorPalette.textMuted, letterSpacing: 0.8)),
                  ),
                  const SizedBox(width: 32),
                ],
              ),
            ),
            // Data Body
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _paginatedData.length,
                itemBuilder: (context, index) {
                  final item = _paginatedData[index];
                  final bool canDrill = !(widget.setNo != null || item['isColorLevel'] == true);
                  final bool isAlternate = index % 2 != 0;
                  
                  return InkWell(
                    onTap: canDrill ? () => _navigateToNextLevel(item) : null,
                    hoverColor: ColorPalette.primary.withOpacity(0.04),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: isAlternate ? const Color(0xFFFDFDFD) : Colors.white,
                        border: Border(bottom: BorderSide(color: ColorPalette.border.withOpacity(0.5))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] ?? 'N/A',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: ColorPalette.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (!canDrill) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rack: ${item['rack'] ?? 'N/A'} | Pallet: ${item['pallet'] ?? 'N/A'}',
                                    style: GoogleFonts.inter(fontSize: 10, color: ColorPalette.textMuted, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    'GSM: ${item['gsm'] ?? 'N/A'} | Inw: ${item['inwardNo'] ?? 'N/A'}',
                                    style: GoogleFonts.inter(fontSize: 10, color: ColorPalette.textMuted, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Expanded(
                            flex: (widget.setNo != null || item['isColorLevel'] == true) ? 2 : 1,
                            child: Text(
                              item['totalRolls'].toString(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (widget.setNo != null || item['isColorLevel'] == true)
                            Expanded(
                              flex: 2,
                              child: Text(
                                item['date'] != null ? FormatUtils.formatDate(item['date']) : 'N/A',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                            ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${item['totalWeight']} Kg',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: ColorPalette.textPrimary),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '₹${FormatUtils.formatCurrency(item['totalValue'])}',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: ColorPalette.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 24,
                            alignment: Alignment.centerRight,
                            child: canDrill 
                                ? Icon(LucideIcons.chevronRight, size: 14, color: ColorPalette.primary.withOpacity(0.3))
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            _buildSummaryFooter(),
            _buildPaginationFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationFooter() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: ColorPalette.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'SHOWING ',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5),
              ),
              Text(
                '${(_currentPage * _pageSize) + 1} - ${(_currentPage * _pageSize) + _paginatedData.length}',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: ColorPalette.textPrimary),
              ),
              Text(
                ' OF ${_data.length}',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5),
              ),
            ],
          ),
          Row(
            children: [
              _buildPaginationButton(
                LucideIcons.chevronLeft,
                _currentPage > 0 ? () => setState(() => _currentPage--) : null,
              ),
              const SizedBox(width: 12),
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: ColorPalette.textPrimary),
              ),
              const SizedBox(width: 12),
              _buildPaginationButton(
                LucideIcons.chevronRight,
                _currentPage < _totalPages - 1 ? () => setState(() => _currentPage++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton(IconData icon, VoidCallback? onTap) {
    bool isEnabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: isEnabled ? ColorPalette.border : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: isEnabled ? ColorPalette.textPrimary : Colors.grey.shade300),
      ),
    );
  }

  Widget _buildSummaryFooter() {
    double totalWeight = 0, totalValue = 0;
    int totalRolls = 0;

    for (var item in _data) {
      totalRolls += ((item['totalRolls'] ?? 0) as num).toInt();
      totalWeight += ((item['totalWeight'] ?? 0) as num).toDouble();
      totalValue += ((item['totalValue'] ?? 0) as num).toDouble();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Light slate for summary
        border: Border(top: BorderSide(color: ColorPalette.border.withOpacity(0.8))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Icon(LucideIcons.barChart3, size: 14, color: ColorPalette.primary),
                const SizedBox(width: 8),
                Text('TOTAL SUMMARY',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 10, color: ColorPalette.primary, letterSpacing: 1.0)),
              ],
            ),
          ),
          Expanded(
            flex: widget.setNo != null ? 2 : 1,
            child: Text(
              totalRolls.toString(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: ColorPalette.textPrimary),
            ),
          ),
          if (widget.setNo != null || (_data.isNotEmpty && _data.any((i) => i['isColorLevel'] == true)))
            const Expanded(flex: 2, child: SizedBox.shrink()),
          Expanded(
            flex: 2,
            child: Text(
              '${FormatUtils.formatWeight(totalWeight)} Kg',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: ColorPalette.textPrimary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '₹${FormatUtils.formatCurrency(totalValue)}',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: ColorPalette.textPrimary),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  void _navigateToNextLevel(dynamic item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryDrillDownScreen(
          type: widget.type,
          startDate: widget.startDate,
          endDate: widget.endDate,
          lotName: widget.lotName ?? item['name'],
          lotNo: widget.lotName != null ? (widget.lotNo ?? item['name']) : null,
          dia: (widget.lotName != null && widget.lotNo != null) ? (widget.dia ?? item['name']) : null,
          setNo: (widget.lotName != null && widget.lotNo != null && widget.dia != null) ? (widget.setNo ?? item['name']) : null,
        ),
      ),
    );
  }

  Future<void> _handlePrint({bool share = false}) async {
    if (_data.isEmpty) return;

    final headers = [
      _levelLabel,
      'ROLLS',
      if (widget.setNo != null) (widget.type == 'inward' ? 'INW DATE' : 'OUT DATE'),
      'WEIGHT',
      if (widget.setNo != null) 'RACK/PALLET',
      'VALUE'
    ];
    
    final rows = _data.map((item) {
      return [
        item['name']?.toString() ?? 'N/A',
        item['totalRolls']?.toString() ?? '0',
        if (widget.setNo != null) (item['date'] != null ? FormatUtils.formatDate(item['date']) : 'N/A'),
        '${item['totalWeight'] ?? 0} Kg',
        if (widget.setNo != null) '${item['rack'] ?? ''}/${item['pallet'] ?? ''}',
        'INR ${FormatUtils.formatCurrency(item['totalValue'] ?? 0)}',
      ];
    }).toList();

    // Calculate totals
    final totalRolls = _data.fold<int>(0, (sum, item) => sum + ((item['totalRolls'] ?? 0) as num).toInt());
    final totalWeight = _data.fold<double>(0.0, (sum, item) => sum + ((item['totalWeight'] ?? 0) as num).toDouble());
    final totalValue = _data.fold<double>(0.0, (sum, item) => sum + ((item['totalValue'] ?? 0) as num).toDouble());

    final footerRow = [
      'TOTAL',
      totalRolls.toString(),
      if (widget.setNo != null) '',
      '${totalWeight.toStringAsFixed(2)} Kg',
      if (widget.setNo != null) '',
      'INR ${FormatUtils.formatCurrency(totalValue)}',
    ];

    try {
      final pdfBytes = await _printService.generateReportPdf(
        title: '${widget.type.toUpperCase()} REPORT',
        subtitle: _getDrillDownBreadcrumbText(),
        headers: headers,
        rows: rows,
        footerRow: footerRow,
      );

      if (share) {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'Inventory_${widget.type}_${DateTime.now().millisecond}.pdf',
        );
      } else {
        await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  String _getDrillDownBreadcrumbText() {
    List<String> parts = [widget.type.toUpperCase()];
    if (widget.lotName != null) parts.add(widget.lotName!);
    if (widget.lotNo != null) parts.add('Lot ${widget.lotNo}');
    if (widget.dia != null) parts.add('${widget.dia} Dia');
    if (widget.setNo != null) parts.add(widget.setNo!);
    return parts.join(' > ');
  }
}
