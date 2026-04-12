import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:garments/services/mobile_api_service.dart';
import 'package:garments/services/lot_allocation_print_service.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/layout_constants.dart';
import '../../widgets/responsive_wrapper.dart';
import 'cutting_order_planning_screen.dart';

class CuttingOrderListScreen extends StatefulWidget {
  const CuttingOrderListScreen({super.key});

  @override
  State<CuttingOrderListScreen> createState() => _CuttingOrderListScreenState();
}

class _LotAllocationPrintServiceWrapper extends LotAllocationPrintService {}

class _CuttingOrderListScreenState extends State<CuttingOrderListScreen> {
  final _api = MobileApiService();
  final _printService = _LotAllocationPrintServiceWrapper();
  bool _isLoading = false;
  List<dynamic> _plans = [];
  String _searchQuery = '';
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await _api.getCuttingOrders();
      setState(() {
        _plans = plans;
        _currentPage = 1;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load plans: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredListAll {
    if (_searchQuery.isEmpty) return _plans;
    return _plans.where((p) {
      final name = p['planName']?.toString().toLowerCase() ?? '';
      final id = p['planId']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase()) || id.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<dynamic> get _filteredPlans {
    final list = _filteredListAll;
    int start = (_currentPage - 1) * _pageSize;
    int end = start + _pageSize;
    if (start >= list.length) return [];
    return list.sublist(start, end.clamp(0, list.length));
  }

  int get _totalFilteredCount => _filteredListAll.length;
  int get _totalPages => (_totalFilteredCount / _pageSize).ceil();

  void _previewEntry(Map<String, dynamic> entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry['planName'] ?? 'Plan Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Plan ID', entry['planId']),
                _detailRow('Type', entry['planType']),
                _detailRow('Period', entry['planPeriod']),
                _detailRow('Size Type', entry['sizeType']),
                const Divider(),
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...(entry['cuttingEntries'] as List? ?? []).map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• ${e['itemName']}: ${e['totalDozens']} doz'),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(value?.toString() ?? '-', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  void _printEntry(Map<String, dynamic> entry) {
    final List<int> sizes = [75, 80, 85, 90, 95, 100, 105, 110];
    final allocations = entry['lotAllocations'] as List? ?? [];
    final entries = (entry['cuttingEntries'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    for (final e in entries) {
      final raw = e['sizeQuantities'];
      if (raw is Map) {
        e['sizeQuantities'] = raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
      }
      final itemName = e['itemName'];
      final cuttingQty = {for (var s in sizes) s.toString(): 0};
      for (final alloc in allocations) {
        if (alloc['itemName'] == itemName) {
          final sz = alloc['size']?.toString();
          if (sz != null && cuttingQty.containsKey(sz)) {
            cuttingQty[sz] = (cuttingQty[sz] ?? 0) + ((alloc['dozen'] as num?)?.toInt() ?? 0);
          }
        }
      }
      e['cuttingQuantities'] = cuttingQty;
    }

    _printService.printCuttingOrderPlanning(
      entry['planType']?.toString() ?? '',
      entry['planPeriod']?.toString() ?? '',
      entry['startDate'] != null ? DateTime.tryParse(entry['startDate'].toString()) : null,
      entry['endDate'] != null ? DateTime.tryParse(entry['endDate'].toString()) : null,
      entry['sizeType']?.toString() ?? '',
      entries,
      sizes,
    );
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
                  'PRODUCTION BLUEPRINTS',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: const Color(0xFF1E293B),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _fetchPlans,
                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                  label: Text('REFRESH', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CuttingOrderPlanningScreen()),
                    ).then((_) => _fetchPlans());
                  },
                  icon: const Icon(LucideIcons.plus, size: 14, color: Colors.white),
                  label: Text('NEW BLUEPRINT', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white)),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Column(
                  children: [
                    _buildSearchHeader(),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                          : _filteredPlans.isEmpty
                              ? _buildEmptyState()
                              : _buildPlanList(),
                    ),
                    if (!_isLoading && _plans.isNotEmpty) _buildPaginationBar(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildPaginationBar() {
    final total = _totalFilteredCount;
    final totalPages = _totalPages;
    int from = (_currentPage - 1) * _pageSize + 1;
    int to = (_currentPage * _pageSize).clamp(0, total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Text(
            'Showing $from to $to of $total records',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          _buildPageBtn(LucideIcons.chevronLeft, 'PREV', _currentPage > 1 ? () => setState(() => _currentPage--) : null),
          const SizedBox(width: 8),
          _buildPageBtn(LucideIcons.chevronRight, 'NEXT', _currentPage < totalPages ? () => setState(() => _currentPage++) : null),
        ],
      ),
    );
  }

  Widget _buildPageBtn(IconData icon, String label, VoidCallback? onTap) {
    bool isEnabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.transparent,
          border: Border.all(color: isEnabled ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            if (label == 'PREV') Icon(icon, size: 14, color: isEnabled ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
            if (label == 'PREV') const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 10, color: isEnabled ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1))),
            if (label == 'NEXT') const SizedBox(width: 4),
            if (label == 'NEXT') Icon(icon, size: 14, color: isEnabled ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: TextField(
          onChanged: (v) => setState(() {
            _searchQuery = v;
            _currentPage = 1;
          }),
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Search blueprints by identifier...',
            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
            prefixIcon: const Icon(LucideIcons.search, size: 14, color: Color(0xFF64748B)),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.fileX2, size: 48, color: const Color(0xFF94A3B8).withOpacity(0.3)),
          const SizedBox(height: 12),
          Text('No production plans identified', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildPlanList() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _filteredPlans.length,
      itemBuilder: (context, index) {
        final plan = _filteredPlans[index];
        return Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(LucideIcons.fileText, color: Color(0xFF64748B), size: 18),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan['planId']?.toString().toUpperCase() ?? 'NO-ID',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2563EB),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              plan['planType']?.toString().toUpperCase() ?? '-',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan['planName']?.toString().toUpperCase() ?? 'UNNAMED PLAN',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: const Color(0xFF1E293B),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan['planPeriod'] ?? '-',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    _buildActionButtons(plan),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (index * 30).ms);
      },
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> plan) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(LucideIcons.eye, const Color(0xFF64748B), () => _previewEntry(plan)),
        const SizedBox(width: 8),
        _buildActionButton(LucideIcons.pencil, const Color(0xFF2563EB), () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CuttingOrderPlanningScreen(initialData: plan)),
          ).then((_) => _fetchPlans());
        }),
        const SizedBox(width: 8),
        _buildActionButton(LucideIcons.printer, const Color(0xFF2563EB), () => _printEntry(plan)),
        const SizedBox(width: 8),
        _buildActionButton(LucideIcons.trash2, const Color(0xFFEF4444), () => _showDeleteDialog(plan)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('ARCHIVE BLUEPRINT?', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5)),
        content: Text(
          'This action will permanently neutralize this production blueprint from the active repository. This cannot be undone.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _api.deleteCuttingOrder(plan['_id']);
              if (success) {
                _fetchPlans();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Blueprint neutralizing confirmed'), backgroundColor: Color(0xFFEF4444)),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: Text('CONFIRM ARCHIVE', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
