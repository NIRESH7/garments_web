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
  final _itemCtrl = TextEditingController();
  final _colourCtrl = TextEditingController();
  DateTimeRange? _range;

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final data = await _api.getCuttingEntryReport(
        itemName: _itemCtrl.text.trim().isNotEmpty ? _itemCtrl.text.trim() : null,
        colour: _colourCtrl.text.trim().isNotEmpty ? _colourCtrl.text.trim() : null,
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
    _itemCtrl.dispose();
    _colourCtrl.dispose();
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

    return Scaffold(
      backgroundColor: ColorPalette.background,
      appBar: AppBar(
        toolbarHeight: 60,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 18, color: Color(0xFF475569)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('CUTTING ENTRY REPORT', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: 16, letterSpacing: 0.5)),
        iconTheme: const IconThemeData(color: Color(0xFF475569)),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: Color(0xFFE2E8F0))),
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            child: Row(
              children: [
                // Item name
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(6)),
                    child: TextField(
                      controller: _itemCtrl,
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Item name...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(LucideIcons.scissors, size: 13, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Colour
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(6)),
                    child: TextField(
                      controller: _colourCtrl,
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Colour...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(LucideIcons.palette, size: 13, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Date range
                InkWell(
                  onTap: () async {
                    final r = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2030), initialDateRange: _range);
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
                        InkWell(onTap: () => setState(() => _range = null), child: const Icon(LucideIcons.x, size: 12, color: Colors.white)),
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
          // Summary strip
          if (_data.isNotEmpty)
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
              child: Row(children: [
                _chip('ROWS', '${_data.length}'),
                const SizedBox(width: 16),
                _chip('TOTAL PCS', '$totalPcs'),
                const SizedBox(width: 16),
                _chip('TOTAL DOZ', totalDoz.toStringAsFixed(2)),
              ]),
            ),
          if (_data.isNotEmpty) const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // Table
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
                    padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF475569)),
                            headingTextStyle: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5),
                            dataTextStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A)),
                            columnSpacing: 16,
                            headingRowHeight: 44,
                            dataRowMinHeight: 40,
                            dataRowMaxHeight: 40,
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
                            rows: [
                              ..._data.map((row) {
                                String date = '-';
                                try {
                                  if (row['cuttingDate'] != null) {
                                    date = DateFormat('dd/MM/yy').format(DateTime.parse(row['cuttingDate']).toLocal());
                                  }
                                } catch (_) {}
                                return DataRow(cells: [
                                  DataCell(Text(row['cutNo']?.toString() ?? '-')),
                                  DataCell(Text(row['itemName']?.toString() ?? '-')),
                                  DataCell(Text(row['size']?.toString() ?? '-')),
                                  DataCell(Text(row['colour']?.toString() ?? '-')),
                                  DataCell(Text(row['lotNo']?.toString() ?? '-')),
                                  DataCell(Text((row['pcs'] ?? 0).toString())),
                                  DataCell(Text(((row['doz'] ?? 0) as num).toStringAsFixed(2))),
                                  DataCell(Text(date)),
                                ]);
                              }),
                              // Totals row
                              DataRow(
                                color: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                                cells: [
                                  DataCell(Text('TOTAL', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11))),
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                  DataCell(Text('$totalPcs', style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
                                  DataCell(Text(totalDoz.toStringAsFixed(2), style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
                                  const DataCell(Text('')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
      Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
    ]);
  }
}
