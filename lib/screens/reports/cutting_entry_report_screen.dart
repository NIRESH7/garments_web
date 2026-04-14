import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';

class CuttingEntryReportScreen extends StatefulWidget {
  const CuttingEntryReportScreen({super.key});
  @override
  State<CuttingEntryReportScreen> createState() => _CuttingEntryReportScreenState();
}

class _CuttingEntryReportScreenState extends State<CuttingEntryReportScreen> {
  final _api = MobileApiService();
  List<dynamic> _data = [];
  bool _loading = false;
  DateTimeRange? _range;
  List<String> _items = [];
  List<String> _colours = [];
  String? _selectedItem;
  String? _selectedColour;
  int _currentPage = 0;
  static const int _pageSize = 10;

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
            final values = (c['values'] as List? ?? []).map((v) => (v['name'] ?? '').toString()).toList();
            if (name.contains('ITEM')) {
              _items = values;
            } else if (name.contains('COLOUR') || name.contains('COLOR')) {
              _colours = values;
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      setState(() { _loading = true; _currentPage = 0; });
      final data = await _api.getCuttingEntryReport(
        itemName: _selectedItem,
        colour: _selectedColour,
        startDate: _range?.start.toIso8601String(),
        endDate: _range?.end.toIso8601String(),
      ).timeout(const Duration(seconds: 15));
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int totalPcs = 0;
    double totalDoz = 0;
    try {
      totalPcs = _data.fold<int>(0, (s, r) => s + ((r['pcs'] ?? 0) as num).toInt());
      totalDoz = _data.fold<double>(0, (s, r) => s + ((r['doz'] ?? 0) as num).toDouble());
    } catch (_) {}

    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize > _data.length) ? _data.length : startIndex + _pageSize;
    final visibleData = _data.isEmpty ? [] : _data.sublist(startIndex, endIndex);

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
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(6)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _selectedItem,
                        hint: Text('Item name...', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                        icon: const Icon(LucideIcons.scissors, size: 14, color: Color(0xFF94A3B8)),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All Items', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                          ..._items.map((i) => DropdownMenuItem<String?>(value: i, child: Text(i, style: GoogleFonts.inter(fontSize: 13)))),
                        ],
                        onChanged: (v) => setState(() => _selectedItem = v),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(6)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _selectedColour,
                        hint: Text('Colour...', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                        icon: const Icon(LucideIcons.palette, size: 14, color: Color(0xFF94A3B8)),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All Colours', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                          ..._colours.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c, style: GoogleFonts.inter(fontSize: 13)))),
                        ],
                        onChanged: (v) => setState(() => _selectedColour = v),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () async {
                    final r = await showDateRangePicker(
                      context: context, 
                      firstDate: DateTime(2020), 
                      lastDate: DateTime(2030), 
                      initialDateRange: _range,
                      builder: (context, child) {
                        return Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
                            child: child,
                          ),
                        );
                      }
                    );
                    if (r != null) setState(() => _range = r);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _range != null ? const Color(0xFF475569) : const Color(0xFFF8FAFC),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.calendarRange, size: 14, color: _range != null ? Colors.white : const Color(0xFF475569)),
                      const SizedBox(width: 6),
                      Text(
                        _range != null
                          ? '${DateFormat('dd/MM/yy').format(_range!.start)} – ${DateFormat('dd/MM/yy').format(_range!.end)}'
                          : 'DATE RANGE',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _range != null ? Colors.white : const Color(0xFF475569)),
                      ),
                      if (_range != null) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => setState(() => _range = null),
                          child: const Icon(LucideIcons.x, size: 12, color: Colors.white),
                        ),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
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
          // Summary bar & Pagination Info
          if (_data.isNotEmpty)
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
              child: Row(children: [
                _chip('GRAND TOTAL PCS', '$totalPcs'),
                const SizedBox(width: 24),
                _chip('GRAND TOTAL DOZ', totalDoz.toStringAsFixed(2)),
                const Spacer(),
                Text('Showing ${startIndex + 1}–$endIndex of ${_data.length}', 
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft, size: 16),
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                  style: IconButton.styleFrom(backgroundColor: Colors.white, padding: EdgeInsets.zero, minimumSize: const Size(28, 28), side: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight, size: 16),
                  onPressed: endIndex < _data.length ? () => setState(() => _currentPage++) : null,
                  style: IconButton.styleFrom(backgroundColor: Colors.white, padding: EdgeInsets.zero, minimumSize: const Size(28, 28), side: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ]),
            ),
          if (_data.isNotEmpty) const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _data.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.fileText, size: 48, color: Color(0xFFCBD5E1)),
                        const SizedBox(height: 12),
                        Text('Apply filters to view records', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13)),
                      ],
                    ),
                  )
                : LayoutBuilder(builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                      child: Container(
                        width: constraints.maxWidth,
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                              headingTextStyle: GoogleFonts.outfit(color: const Color(0xFF475569), fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5),
                              dataTextStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A)),
                              dividerThickness: 0,
                              columnSpacing: 20,
                              headingRowHeight: 40,
                              dataRowMinHeight: 36,
                              dataRowMaxHeight: 36,
                              horizontalMargin: 12,
                              border: TableBorder.all(color: const Color(0xFFE2E8F0)),
                              columns: const [
                                DataColumn(label: Text('CUT NO')),
                                DataColumn(label: Text('ITEM NAME')),
                                DataColumn(label: Text('SIZE')),
                                DataColumn(label: Text('COLOUR')),
                                DataColumn(label: Text('LOT NO')),
                                DataColumn(label: Text('PCS'), numeric: true),
                                DataColumn(label: Text('DOZ'), numeric: true),
                                DataColumn(label: Text('DATE')),
                              ],
                              rows: visibleData.map((row) {
                                String date = '-';
                                try {
                                  if (row['cuttingDate'] != null) {
                                    date = DateFormat('dd/MM/yy').format(DateTime.parse(row['cuttingDate']).toLocal());
                                  }
                                } catch (_) {}
                                return DataRow(cells: [
                                  DataCell(Text(row['cutNo']?.toString() ?? '-')),
                                  DataCell(Text(row['itemName']?.toString() ?? '-', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                                  DataCell(Text(row['size']?.toString() ?? '-')),
                                  DataCell(Text(row['colour']?.toString() ?? '-')),
                                  DataCell(Text(row['lotNo']?.toString() ?? '-')),
                                  DataCell(Text((row['pcs'] ?? 0).toString())),
                                  DataCell(Text(((row['doz'] ?? 0) as num).toStringAsFixed(2))),
                                  DataCell(Text(date)),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
      Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
    ]);
  }
}
