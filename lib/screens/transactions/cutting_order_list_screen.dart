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

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await _api.getCuttingOrders();
      setState(() => _plans = plans);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load plans: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredPlans {
    if (_searchQuery.isEmpty) return _plans;
    return _plans.where((p) {
      final name = p['planName']?.toString().toLowerCase() ?? '';
      final id = p['planId']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase()) || id.contains(_searchQuery.toLowerCase());
    }).toList();
  }

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

  void _shareEntry(Map<String, dynamic> entry) {
    final name = entry['planName'] ?? 'No Name';
    final type = entry['planType'] ?? '-';
    final period = entry['planPeriod'] ?? '-';
    final entries = entry['cuttingEntries'] as List? ?? [];

    String summary = "Cutting Order Plan: $name\nType: $type\nPeriod: $period\n\nItems:\n";
    for (var e in entries) {
      summary += "• ${e['itemName']}: ${e['totalDozens']} doz\n";
    }

    Share.share(summary);
  }

  void _printEntry(Map<String, dynamic> entry) {
    // Standard sizes for reference
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
      backgroundColor: ColorPalette.background,
      appBar: AppBar(
        title: Text('PRODUCTION BLUEPRINTS', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1)),
        actions: [
          IconButton(
            onPressed: _fetchPlans,
            icon: Icon(LucideIcons.refreshCw, size: 20, color: ColorPalette.textMuted),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton.filledTonal(
              icon: const Icon(LucideIcons.plus, size: 18),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CuttingOrderPlanningScreen()),
                ).then((_) => _fetchPlans());
              },
            ),
          ),
        ],
      ),
      body: ResponsiveWrapper(
        child: Column(
          children: [
            _buildSearchHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredPlans.isEmpty
                      ? _buildEmptyState()
                      : _buildPlanList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search blueprints by name or identifier...',
          prefixIcon: const Icon(LucideIcons.search, size: 18),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade100),
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
          Icon(LucideIcons.fileX2, size: 64, color: ColorPalette.textMuted.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('No production plans identified', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPlanList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _filteredPlans.length,
      itemBuilder: (context, index) {
        final plan = _filteredPlans[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: ColorPalette.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: ColorPalette.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(LucideIcons.fileText, color: ColorPalette.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PLAN #${plan['planId']}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan['planName'] ?? 'Unnamed Blueprint',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: ColorPalette.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${plan['planType']} • ${plan['planPeriod']}',
                        style: TextStyle(fontSize: 12, color: ColorPalette.textSecondary),
                      ),
                    ],
                  ),
                ),
                _buildActionButtons(plan),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05);
      },
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> plan) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(LucideIcons.eye, Colors.blue, () => _previewEntry(plan)),
        const SizedBox(width: 8),
        _buildActionButton(LucideIcons.pencil, Colors.orange, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CuttingOrderPlanningScreen(initialData: plan)),
          ).then((_) => _fetchPlans());
        }),
        const SizedBox(width: 8),
        _buildActionButton(LucideIcons.printer, Colors.purple, () => _printEntry(plan)),
        const SizedBox(width: 8),
        _buildActionButton(LucideIcons.trash2, ColorPalette.error, () => _showDeleteDialog(plan)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive Blueprint?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: const Text('This action will permanently neutralize this production blueprint from the active repository.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _api.deleteCuttingOrder(plan['_id']);
              if (success) {
                _fetchPlans();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Blueprint neutralizing confirmed'), backgroundColor: ColorPalette.error));
              }
            },
            style: TextButton.styleFrom(foregroundColor: ColorPalette.error),
            child: const Text('CONFIRM ARCHIVE'),
          ),
        ],
      ),
    );
  }
}
