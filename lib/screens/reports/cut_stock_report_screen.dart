import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/responsive_wrapper.dart';

class CutStockReportScreen extends StatefulWidget {
  const CutStockReportScreen({super.key});
  @override
  State<CutStockReportScreen> createState() => _CutStockReportScreenState();
}

class _CutStockReportScreenState extends State<CutStockReportScreen> {
  final _api = MobileApiService();
  List<dynamic> _data = [];
  bool _loading = false;
  List<String> _items = [];
  String? _selectedItem;
  DateTimeRange? _dateRange;
  final List<String> _sizes = ['75', '80', '85', '90', '95', '100', '105', '110'];

  @override
  void initState() {
    super.initState();
    _loadMasters();
  }

  Future<void> _loadMasters() async {
    try {
      final cats = await _api.getCategories();
      if (mounted) {
        setState(() {
          for (var c in cats) {
            final name = (c['name'] ?? '').toString().toUpperCase();
            if (name.contains('ITEM')) {
              _items = (c['values'] as List? ?? []).map((v) => (v['name'] ?? '').toString()).toList();
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final data = await _api.getCutStockReport(
        itemName: _selectedItem,
        startDate: _dateRange?.start.toIso8601String(),
        endDate: _dateRange?.end.toIso8601String(),
      ).timeout(const Duration(seconds: 15));
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    double grandTotal = 0;
    try {
      for (final s in _sizes) {
        totals[s] = _data.fold(0.0, (sum, row) => sum + ((row[s] ?? 0) as num).toDouble());
        grandTotal += totals[s]!;
      }
    } catch (_) {
      for (final s in _sizes) totals[s] = 0;
    }

    return Scaffold(
      backgroundColor: ColorPalette.background,
      body: Column(
        children: [
          // Filter bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            child: Row(
              children: [
                // Item dropdown
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(6)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _selectedItem,
                        hint: Text('Item name...', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                        icon: const Icon(LucideIcons.search, size: 14, color: Color(0xFF94A3B8)),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All Items', style: TextStyle(fontSize: 12))),
                          ..._items.map((i) => DropdownMenuItem<String?>(value: i, child: Text(i, style: GoogleFonts.inter(fontSize: 13)))),
                        ],
                        onChanged: (v) => setState(() => _selectedItem = v),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Date range picker
                InkWell(
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      initialDateRange: _dateRange,
                      builder: (context, child) {
                        return Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
                            child: child,
                          ),
                        );
                      }
                    );
                    if (range != null) setState(() => _dateRange = range);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _dateRange != null ? const Color(0xFF475569) : const Color(0xFFF8FAFC),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.calendarRange, size: 14, color: _dateRange != null ? Colors.white : const Color(0xFF475569)),
                      const SizedBox(width: 6),
                      Text(
                        _dateRange != null
                          ? '${DateFormat('dd/MM/yy').format(_dateRange!.start)} – ${DateFormat('dd/MM/yy').format(_dateRange!.end)}'
                          : 'DATE RANGE',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _dateRange != null ? Colors.white : const Color(0xFF475569)),
                      ),
                      if (_dateRange != null) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => setState(() => _dateRange = null),
                          child: const Icon(LucideIcons.x, size: 12, color: Colors.white),
                        ),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                // Search button
                InkWell(
                  onTap: _load,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                    decoration: BoxDecoration(color: const Color(0xFF475569), borderRadius: BorderRadius.circular(6)),
                    child: Text('SEARCH', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // Content area
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _data.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.barChart2, size: 48, color: Color(0xFFCBD5E1)),
                        const SizedBox(height: 12),
                        Text('Apply filters and tap Search', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13)),
                        const SizedBox(height: 20),
                        InkWell(
                          onTap: _load,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(6)),
                            child: Text('LOAD ALL', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 11, color: const Color(0xFF475569))),
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary chips
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              _summaryChip('TOTAL ROWS', _data.length.toString()),
                              const SizedBox(width: 12),
                              _summaryChip('GRAND TOTAL', grandTotal.toStringAsFixed(1)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Table
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Container(
                              width: constraints.maxWidth,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                    headingTextStyle: GoogleFonts.outfit(color: const Color(0xFF475569), fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5),
                                    dataTextStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A)),
                                    dividerThickness: 0,
                                    columnSpacing: (constraints.maxWidth - 200) / 10, // Dynamic spacing
                                    headingRowHeight: 40,
                                    dataRowMinHeight: 36,
                                    dataRowMaxHeight: 36,
                                    horizontalMargin: 12,
                                    border: TableBorder.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 1,
                                    ),
                                    columns: [
                                      const DataColumn(label: Text('ITEM NAME')),
                                      ..._sizes.map((s) => DataColumn(label: Text(s), numeric: true)),
                                      const DataColumn(label: Text('TOTAL'), numeric: true),
                                    ],
                                    rows: [
                                      ..._data.map((row) {
                                        final rowTotal = _sizes.fold<double>(0, (sum, s) => sum + ((row[s] ?? 0) as num).toDouble());
                                        return DataRow(cells: [
                                          DataCell(Text(row['itemName'] ?? '-', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12))),
                                          ..._sizes.map((s) => DataCell(Text((row[s] ?? 0).toString(), style: GoogleFonts.inter(fontSize: 12)))),
                                          DataCell(Text(rowTotal.toStringAsFixed(1), style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF475569)))),
                                        ]);
                                      }),
                                      // Totals row
                                      DataRow(
                                        color: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                                        cells: [
                                          DataCell(Text('TOTALS', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFF64748B)))),
                                          ..._sizes.map((s) => DataCell(Text(totals[s]!.toStringAsFixed(1), style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF475569))))),
                                          DataCell(Text(grandTotal.toStringAsFixed(1), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF0F172A)))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
      ]),
    );
  }
}
