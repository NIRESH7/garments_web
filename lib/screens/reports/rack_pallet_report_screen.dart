import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // Filters
  String _selectedLot = 'ALL LOTS';
  String _selectedRack = 'ALL RACKS';
  String _selectedPallet = 'ALL PALLETS';
  String _selectedDia = 'ALL DIAS';

  List<String> _lotNames = ['ALL LOTS'];
  List<String> _racks = ['ALL RACKS'];
  List<String> _pallets = ['ALL PALLETS'];
  List<String> _dias = ['ALL DIAS'];

  // Set-wise grouping
  List<Map<String, dynamic>> _setGroups = [];

  // Expanded sets for colour detail
  final Set<String> _expandedSets = {};

  // Pagination on Set groups
  int _currentPage = 1;
  final int _pageSize = 15;

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
          _dias = ['ALL DIAS', ..._getValues(categories, 'Dia')];
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

      // Client-side filter for DIA if selected
      var filteredData = data;
      if (_selectedDia != 'ALL DIAS') {
        filteredData = data.where((item) => 
          (item['dia']?.toString().toLowerCase() ?? '') == _selectedDia.toLowerCase()
        ).toList();
      }

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

          _buildSetGroups(filteredData);
          _currentPage = 1;
          _expandedSets.clear();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _buildSetGroups(List<dynamic> data) {
    // Group by setNo + lotNo (each set belongs to a specific lot)
    final Map<String, Map<String, dynamic>> groups = {};

    for (final item in data) {
      final setNo = item['setNo']?.toString() ?? 'N/A';
      final lotNo = item['lotNo']?.toString() ?? 'N/A';
      final key = '$lotNo||$setNo';

      if (!groups.containsKey(key)) {
        final rack = item['rackName']?.toString() ?? '-';
        final pallet = item['palletNo']?.toString() ?? '-';
        groups[key] = {
          'setNo': setNo,
          'lotNo': lotNo,
          'lotName': item['lotName']?.toString() ?? 'N/A',
          'dia': item['dia']?.toString() ?? '-',
          'rack': rack,
          'pallet': pallet,
          'inwardDate': item['inwardDate'],
          'totalWeight': 0.0,
          'colours': <Map<String, dynamic>>[],
        };
      }

      groups[key]!['totalWeight'] = (groups[key]!['totalWeight'] as double) +
          ((item['weight'] as num?) ?? 0).toDouble();
      (groups[key]!['colours'] as List).add({
        'colour': item['colour']?.toString() ?? 'N/A',
        'weight': ((item['weight'] as num?) ?? 0).toDouble(),
      });
    }

    _setGroups = groups.values.toList();
    // Sort by rack → pallet → setNo
    _setGroups.sort((a, b) {
      final r = (a['rack'] as String).compareTo(b['rack'] as String);
      if (r != 0) return r;
      final p = (a['pallet'] as String).compareTo(b['pallet'] as String);
      if (p != 0) return p;
      return (a['setNo'] as String).compareTo(b['setNo'] as String);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(toolbarHeight: 0, backgroundColor: Colors.white, elevation: 0),
      body: Column(
        children: [
          // Top bar
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
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF1E293B), letterSpacing: 0.5),
                ),
                const Spacer(),
                _buildActionIcons(),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          _buildFilterBar(),
          _buildAnalyticsBar(),

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
                    : _setGroups.isEmpty
                        ? _buildEmptyState()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _buildSetWiseTable()),
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
              setState(() => _isPrinting = true);
              try {
                await Printing.layoutPdf(onLayout: (f) async => (await _generatePDF()).save());
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

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            _buildFilter('LOT NAME', _selectedLot, _lotNames, (v) => setState(() => _selectedLot = v!)),
            _buildVDiv(),
            _buildFilter('LOCATION RACK', _selectedRack, _racks, (v) => setState(() => _selectedRack = v!)),
            _buildVDiv(),
            _buildFilter('PALLET UNIT', _selectedPallet, _pallets, (v) => setState(() => _selectedPallet = v!)),
            _buildVDiv(),
            _buildFilter('DIA', _selectedDia, _dias, (v) => setState(() => _selectedDia = v!)),
            if (_selectedLot != 'ALL LOTS' || _selectedRack != 'ALL RACKS' || _selectedPallet != 'ALL PALLETS' || _selectedDia != 'ALL DIAS')
              IconButton(
                onPressed: () {
                  setState(() { 
                    _selectedLot = 'ALL LOTS'; 
                    _selectedRack = 'ALL RACKS'; 
                    _selectedPallet = 'ALL PALLETS'; 
                    _selectedDia = 'ALL DIAS';
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

  Widget _buildFilter(String label, String value, List<String> items, Function(String?) onChanged) {
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
              onChanged: (v) { onChanged(v); _fetchReport(); },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVDiv() => Container(height: 32, width: 1, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 16));

  Widget _buildAnalyticsBar() {
    double totalWeight = _reportData.fold(0.0, (s, i) => s + ((i['weight'] as num?) ?? 0).toDouble());
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: [
          _chip(LucideIcons.layers, '${_setGroups.length}', 'TOTAL SETS'),
          const SizedBox(width: 12),
          _chip(LucideIcons.package, '${_reportData.length}', 'TOTAL COLOURS'),
          const SizedBox(width: 12),
          _chip(LucideIcons.scale, '${totalWeight.toStringAsFixed(2)} KG', 'TOTAL WEIGHT'),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(children: [
        Icon(icon, size: 12, color: const Color(0xFF2563EB)),
        const SizedBox(width: 8),
        Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
      ]),
    );
  }

  Widget _buildSetWiseTable() {
    final start = (_currentPage - 1) * _pageSize;
    final paginated = _setGroups.skip(start).take(_pageSize).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const SizedBox(width: 28), // expand icon space
                _hdr('LOCATION (R/P)', 2),
                _hdr('LOT NAME', 2),
                _hdr('DIA', 1),
                _hdr('SET NO', 1),
                _hdr('COLOURS', 1),
                _hdr('TOTAL WEIGHT', 1),
                _hdr('INWARD DATE', 1),
              ],
            ),
          ),

          // Data rows
          ...paginated.map((group) {
            final key = '${group['lotNo']}||${group['setNo']}';
            final isExpanded = _expandedSets.contains(key);
            final rack = group['rack'] as String;
            final pallet = group['pallet'] as String;
            final isUnassigned = rack == '-' || rack == 'N/A' || pallet == '-' || pallet == 'N/A';
            final colours = group['colours'] as List<Map<String, dynamic>>;
            final date = group['inwardDate'] != null
                ? DateFormat('dd MMM yy').format(DateTime.parse(group['inwardDate']))
                : 'N/A';

            return Column(
              children: [
                // Set summary row
                InkWell(
                  onTap: () => setState(() {
                    if (isExpanded) _expandedSets.remove(key);
                    else _expandedSets.add(key);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: isExpanded ? const Color(0xFFF0F9FF) : Colors.white,
                      border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        // Expand icon
                        Icon(
                          isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                          size: 14,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        // Location
                        Expanded(
                          flex: 2,
                          child: isUnassigned
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(2)),
                                  child: Text('NOT ASSIGNED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFFEF4444))),
                                )
                              : Text('R:$rack - P:$pallet', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                        ),
                        // Lot Name
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(group['lotName'].toString().toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                              Text(group['lotNo'].toString(), style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        // DIA
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              group['dia'].toString(),
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                            ),
                          ),
                        ),
                        // Set No
                        Expanded(
                          flex: 1,
                          child: Text(group['setNo'].toString(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                        ),
                        // Colours count
                        Expanded(
                          flex: 1,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  '${colours.length} colours',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF166534)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Total weight
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${(group['totalWeight'] as double).toStringAsFixed(2)} kg',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB)),
                          ),
                        ),
                        // Date
                        Expanded(
                          flex: 1,
                          child: Text(date, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        ),
                      ],
                    ),
                  ),
                ),

                // Expanded colour detail rows
                if (isExpanded)
                  Container(
                    color: const Color(0xFFF8FAFF),
                    child: Column(
                      children: [
                        // Colour sub-header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE0E7FF)))),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text('COLOUR', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF6366F1), letterSpacing: 0.5))),
                              Expanded(flex: 1, child: Text('WEIGHT (KG)', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF6366F1), letterSpacing: 0.5))),
                            ],
                          ),
                        ),
                        ...colours.map((c) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 9),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF2FF)))),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle)),
                                    const SizedBox(width: 10),
                                    Text(c['colour'].toString().toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${(c['weight'] as double).toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _hdr(String label, int flex) => Expanded(
    flex: flex,
    child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
  );

  Widget _buildPaginationBar() {
    final total = _setGroups.length;
    final totalPages = (total / _pageSize).ceil().clamp(1, 9999);
    final start = total == 0 ? 0 : (_currentPage - 1) * _pageSize + 1;
    final end = (_currentPage * _pageSize).clamp(0, total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(color: Color(0xFFF8FAFC), border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          Text('SHOWING $start–$end OF $total SETS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
          const Spacer(),
          _pageBtn('PREV', _currentPage > 1 ? () => setState(() => _currentPage--) : null),
          const SizedBox(width: 8),
          _pageBtn('NEXT', _currentPage < totalPages ? () => setState(() => _currentPage++) : null),
        ],
      ),
    );
  }

  Widget _pageBtn(String label, VoidCallback? onTap) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: disabled ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: disabled ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: disabled ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B))),
      ),
    );
  }

  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();
    final bold = pw.Font.helveticaBold();
    final normal = pw.Font.helvetica();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      header: (context) => PrintUtils.buildCompanyHeader(bold, normal),
      build: (context) => [
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('RACK & PALLET INVENTORY (SET-WISE)', style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColors.blueGrey800)),
            pw.Text('Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}', style: pw.TextStyle(font: normal, fontSize: 8)),
          ],
        ),
        pw.SizedBox(height: 12),
        ..._setGroups.map((group) {
          final rack = group['rack'], pallet = group['pallet'];
          final loc = (rack == '-' || rack == 'N/A') ? 'NOT ASSIGNED' : 'R:$rack - P:$pallet';
          final colours = group['colours'] as List<Map<String, dynamic>>;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 2, child: pw.Text('$loc', style: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white))),
                    pw.Expanded(flex: 3, child: pw.Text('${group['lotName'].toString().toUpperCase()}  (${group['lotNo']})', style: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white))),
                    pw.Expanded(flex: 1, child: pw.Text('DIA: ${group['dia']}', style: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white))),
                    pw.Expanded(flex: 1, child: pw.Text('Set: ${group['setNo']}', style: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white))),
                    pw.Expanded(flex: 1, child: pw.Text('${(group['totalWeight'] as double).toStringAsFixed(2)} kg', style: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.yellow))),
                  ],
                ),
              ),
              pw.TableHelper.fromTextArray(
                headers: ['COLOUR', 'WEIGHT (KG)'],
                headerStyle: pw.TextStyle(font: bold, fontSize: 7, color: PdfColors.blueGrey700),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
                cellStyle: pw.TextStyle(font: normal, fontSize: 7),
                data: colours.map((c) => [c['colour'].toString().toUpperCase(), (c['weight'] as double).toStringAsFixed(2)]).toList(),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        }),
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
          Text('No inventory found', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}
