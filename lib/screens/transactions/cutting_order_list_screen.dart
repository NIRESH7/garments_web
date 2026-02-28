import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:garments/services/mobile_api_service.dart';
import 'package:garments/services/lot_allocation_print_service.dart';
import 'package:share_plus/share_plus.dart';
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
      appBar: AppBar(
        title: const Text('View Plans'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by plan name or ID...',
                prefixIcon: const Icon(LucideIcons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPlans.isEmpty
                    ? const Center(child: Text('No plans found.'))
                    : ListView.builder(
                        itemCount: _filteredPlans.length,
                        itemBuilder: (context, index) {
                          final plan = _filteredPlans[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              title: Text(plan['planName'] ?? 'Unnamed Plan', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${plan['planId']} • ${plan['planType']} • ${plan['planPeriod']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(LucideIcons.eye, color: Colors.blue, size: 20),
                                    onPressed: () => _previewEntry(plan),
                                    tooltip: 'Preview',
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.edit, color: Colors.orange, size: 20),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CuttingOrderPlanningScreen(initialData: plan),
                                        ),
                                      ).then((_) => _fetchPlans());
                                    },
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.share2, color: Colors.green, size: 20),
                                    onPressed: () => _shareEntry(plan),
                                    tooltip: 'Share',
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.printer, color: Colors.purple, size: 20),
                                    onPressed: () => _printEntry(plan),
                                    tooltip: 'Print',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
