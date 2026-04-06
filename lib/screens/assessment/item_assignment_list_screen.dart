import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/api_constants.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'cutting_master_form_screen.dart';
import 'accessories_master_form_screen.dart';
import '../../services/lot_allocation_print_service.dart';

class ItemAssignmentListScreen extends StatefulWidget {
  const ItemAssignmentListScreen({super.key});

  @override
  State<ItemAssignmentListScreen> createState() => _ItemAssignmentListScreenState();
}

class _ItemAssignmentListScreenState extends State<ItemAssignmentListScreen> {
  final _api = MobileApiService();
  bool _isLoading = true;
  List<dynamic> _cuttingMasters = [];
  List<dynamic> _accessoriesMasters = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final cuttingRes = await _api.getCuttingMasters();
      final accessoriesRes = await _api.getAccessoriesMasters();
      if (!mounted) return;
      setState(() {
        _cuttingMasters = cuttingRes ?? [];
        _accessoriesMasters = accessoriesRes ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCutting(String id) async {
    final ok = await _showDeleteConfirm('cutting master');
    if (ok == true) {
      final success = await _api.deleteCuttingMaster(id);
      if (success) _loadData();
    }
  }

  Future<void> _deleteAccessory(String id) async {
    final ok = await _showDeleteConfirm('accessories master');
    if (ok == true) {
      final success = await _api.deleteAccessoriesMaster(id);
      if (success) _loadData();
    }
  }

  Future<bool?> _showDeleteConfirm(String type) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to remove this $type entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _shareCutting(Map<String, dynamic> entry) {
    final summary = "Cutting Master: ${entry['itemName']}\nLot: ${entry['lotName']}\nSize: ${entry['size']}\nInstructions: ${entry['instructionText'] ?? 'N/A'}";
    Share.share(summary);
  }

  void _shareAccessory(Map<String, dynamic> entry) {
    final groups = (entry['groupSetup'] as List?)?.map((e) => e['group']).toList().join(', ') ?? '';
    final items = (entry['itemAssignment'] as List?)?.map((e) => e['itemName']).toList().join(', ') ?? '';
    final summary = "Accessories Master\nGroups: $groups\nAssignments for: $items";
    Share.share(summary);
  }

  void _print(Map<String, dynamic> entry, bool isCutting) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Printing initialized...')));
    // In real app: isCutting ? printCutting : printAccessory
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Item Assignments'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Cutting Master'),
              Tab(text: 'Accessories Master'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCuttingMasterList(),
            _buildAccessoriesMasterList(),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: () async {
              final tabController = DefaultTabController.of(context);
              Widget screen = tabController.index == 0
                  ? const CuttingMasterFormScreen()
                  : const AccessoriesMasterFormScreen();
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => screen),
              );
              if (result == true) _loadData();
            },
            label: const Text('Add Assignment'),
            icon: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  Widget _buildCuttingMasterList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_cuttingMasters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No cutting master entries found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final cutting = _cuttingMasters ?? [];
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: cutting.length,
        itemBuilder: (context, index) {
          final entry = cutting[index];
          final String itemName = entry['itemName'] ?? 'Unknown Item';
          final String size = entry['size'] ?? 'N/A';
          final String lotName = entry['lotName'] ?? 'N/A';
          final String date = entry['createdAt'] != null
              ? DateFormat('dd MMM yyyy').format(DateTime.parse(entry['createdAt']))
              : 'N/A';
          final String? imageUrl = entry['itemImage'];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CuttingMasterFormScreen(entryId: entry['_id'])),
                );
                if (result == true) _loadData();
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: const Color(0xFF3B82F6).withOpacity(0.08),
                          ),
                          child: (imageUrl != null && imageUrl.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.network(
                                    ApiConstants.getImageUrl(imageUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(Icons.style_outlined, color: Color(0xFF3B82F6)),
                                  ),
                                )
                              : const Icon(Icons.style_outlined, color: Color(0xFF3B82F6), size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _infoChip(Icons.straighten_outlined, size, Colors.orange),
                                  _infoChip(Icons.label_outline, lotName, Colors.blue),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade400),
                                  const SizedBox(width: 6),
                                  Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _actionIcon(Icons.share_outlined, Colors.green, () => _shareCutting(entry)),
                            const SizedBox(width: 8),
                            _actionIcon(Icons.print_outlined, Colors.purple, () => _print(entry, true)),
                          ],
                        ),
                        Row(
                          children: [
                            _actionIcon(Icons.edit_outlined, Colors.blue, () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => CuttingMasterFormScreen(entryId: entry['_id'])),
                              );
                              if (result == true) _loadData();
                            }),
                            const SizedBox(width: 8),
                            _actionIcon(Icons.delete_outline, Colors.red, () => _deleteCutting(entry['_id'])),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccessoriesMasterList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final accessories = _accessoriesMasters ?? [];
    if (accessories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No accessories master entries found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }


    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: accessories.length,
        itemBuilder: (context, index) {
          final entry = accessories[index];
          final groups = (entry['groupSetup'] as List?)?.map((e) => e['group']).toList().join(', ') ?? '';
          final items = (entry['itemAssignment'] as List?)?.map((e) => e['itemName']).toList().join(', ') ?? '';
          final String date = entry['createdAt'] != null
              ? DateFormat('dd MMM yyyy').format(DateTime.parse(entry['createdAt']))
              : 'N/A';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AccessoriesMasterFormScreen(editEntry: entry)),
                );
                if (result == true) _loadData();
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: const Color(0xFF10B981).withOpacity(0.08),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF10B981), size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                groups.isEmpty ? 'Accessories Master' : groups,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Items: ${items.isEmpty ? "None" : items}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade400),
                                  const SizedBox(width: 6),
                                  Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _actionIcon(Icons.share_outlined, Colors.green, () => _shareAccessory(entry)),
                            const SizedBox(width: 8),
                            _actionIcon(Icons.print_outlined, Colors.purple, () => _print(entry, false)),
                          ],
                        ),
                        Row(
                          children: [
                            _actionIcon(Icons.edit_outlined, Colors.blue, () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => AccessoriesMasterFormScreen(editEntry: entry)),
                              );
                              if (result == true) _loadData();
                            }),
                            const SizedBox(width: 8),
                            _actionIcon(Icons.delete_outline, Colors.red, () => _deleteAccessory(entry['_id'])),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.image_outlined, color: Colors.grey),
    );
  }
}
