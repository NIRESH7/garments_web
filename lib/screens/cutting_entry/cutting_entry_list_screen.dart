import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/responsive_wrapper.dart';
import '../../widgets/modern_data_table.dart';
import 'cutting_entry_form_screen.dart';

class CuttingEntryListScreen extends StatefulWidget {
  const CuttingEntryListScreen({super.key});

  @override
  State<CuttingEntryListScreen> createState() => _CuttingEntryListScreenState();
}

class _CuttingEntryListScreenState extends State<CuttingEntryListScreen> {
  final _api = MobileApiService();
  List<dynamic> _entries = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({String? search}) async {
    setState(() => _loading = true);
    try {
      final data = await _api.getCuttingEntries(itemName: search);
      if (mounted) setState(() { _entries = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('DELETE ENTRY', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF0F172A))),
        content: Text('This cutting entry will be permanently removed.', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('CANCEL', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), fontSize: 11))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('DELETE', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ColorPalette.error, fontSize: 11))),
        ],
      ),
    );
    if (confirm == true) {
      await _api.deleteCuttingEntry(id);
      _load();
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'Completed': return const Color(0xFF10B981);
      case 'In Progress': return const Color(0xFFF59E0B);
      default: return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchCtrl.text.isEmpty
        ? _entries
        : _entries.where((e) => (e['itemName'] ?? '').toString().toLowerCase().contains(_searchCtrl.text.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: ColorPalette.background,
      body: ResponsiveWrapper(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Controls row
              Row(
                children: [
                  // Search field
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Search by item name...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(LucideIcons.search, size: 14, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (v) => _load(search: v.isNotEmpty ? v : null),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // New Entry button
                  InkWell(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const CuttingEntryFormScreen()));
                      _load();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFF475569), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.plus, size: 14, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('NEW ENTRY', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Data table
              _loading
                ? const Center(child: Padding(padding: EdgeInsets.all(80), child: CircularProgressIndicator(strokeWidth: 2)))
                : ModernDataTable(
                    columns: const ['CUT NO', 'ITEM NAME', 'SIZE', 'DATE', 'COLOURS', 'TOTAL PCS', 'STATUS'],
                    rows: filtered.map((e) {
                      final date = e['cuttingDate'] != null
                          ? DateFormat('dd MMM yyyy').format(DateTime.parse(e['cuttingDate']).toLocal())
                          : '-';
                      final colCount = (e['colourRows'] as List?)?.length ?? 0;
                      final totalPcs = ((e['colourRows'] as List?) ?? [])
                          .fold<int>(0, (sum, row) => sum + ((row['totalPcs'] ?? 0) as num).toInt());
                      final status = e['status'] ?? 'Pending';
                      return {
                        '_id': e['_id'],
                        'CUT NO': e['cutNo']?.toString() ?? '-',
                        'ITEM NAME': e['itemName']?.toString() ?? '-',
                        'SIZE': e['size']?.toString() ?? '-',
                        'DATE': date,
                        'COLOURS': colCount.toString(),
                        'TOTAL PCS': totalPcs.toString(),
                        'STATUS': status,
                      };
                    }).toList().cast<Map<String, dynamic>>(),
                    onEdit: (row) async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => CuttingEntryFormScreen(entryId: row['_id']?.toString())));
                      _load();
                    },
                    onDelete: (row) => _delete(row['_id']?.toString() ?? ''),
                    emptyMessage: 'No cutting entries found',
                  ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
