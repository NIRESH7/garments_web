import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/layout/web_layout_wrapper.dart';
import '../../services/lot_allocation_print_service.dart';
import 'cutting_master_form_screen.dart';
import 'accessories_master_form_screen.dart';


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
    final isWeb = LayoutConstants.isWeb(context);
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isWeb ? ColorPalette.background : ColorPalette.background,
        appBar: AppBar(
          title: Text('LOGISTICS ASSIGNMENT', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: isWeb ? 0 : 24, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: ColorPalette.primary.withOpacity(0.1),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: ColorPalette.primary,
                unselectedLabelColor: ColorPalette.textSecondary,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(text: 'CUTTING MASTER'),
                  Tab(text: 'ACCESSORIES'),
                ],
              ),
            ),
          ),
        ),
        body: isWeb ? _buildWebLayout() : _buildMobileLayout(),
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
            backgroundColor: ColorPalette.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            label: Text(isWeb ? 'NEW ASSIGNMENT' : 'NEW', style: const TextStyle(fontWeight: FontWeight.w700)),
            icon: Icon(LucideIcons.plus, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildWebLayout() {
    return WebLayoutWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Item Assignment Management',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: ColorPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage cutting protocols and accessory assignments',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: ColorPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: TabBarView(
              children: [
                _buildCuttingMasterList(),
                _buildAccessoriesMasterList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return TabBarView(
      children: [
        _buildCuttingMasterList(),
        _buildAccessoriesMasterList(),
      ],
    );
  }

  Widget _buildCuttingMasterList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_cuttingMasters.isEmpty) return _buildEmptyState(LucideIcons.scissors, 'No cutting protocols defined');

    final isWeb = LayoutConstants.isWeb(context);
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: isWeb
          ? GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                mainAxisExtent: 200,
              ),
              itemCount: _cuttingMasters.length,
              itemBuilder: (context, index) {
                final entry = _cuttingMasters[index];
                return _buildAssignmentCard(
                  title: entry['itemName'] ?? 'Unnamed Item',
                  subtitle: 'Lot: ${entry['lotName']} • Size: ${entry['size']}',
                  date: entry['createdAt'],
                  imageUrl: entry['itemImage'],
                  icon: LucideIcons.scissors,
                  color: Colors.blue,
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CuttingMasterFormScreen(entryId: entry['_id'])),
                    );
                    if (result == true) _loadData();
                  },
                  onDelete: () => _deleteCutting(entry['_id']),
                  onShare: () => _shareCutting(entry),
                  onPrint: () => _print(entry, true),
                ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05);
              },
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _cuttingMasters.length,
              itemBuilder: (context, index) {
                final entry = _cuttingMasters[index];
                return _buildAssignmentCard(
                  title: entry['itemName'] ?? 'Unnamed Item',
                  subtitle: 'Lot: ${entry['lotName']} • Size: ${entry['size']}',
                  date: entry['createdAt'],
                  imageUrl: entry['itemImage'],
                  icon: LucideIcons.scissors,
                  color: Colors.blue,
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CuttingMasterFormScreen(entryId: entry['_id'])),
                    );
                    if (result == true) _loadData();
                  },
                  onDelete: () => _deleteCutting(entry['_id']),
                  onShare: () => _shareCutting(entry),
                  onPrint: () => _print(entry, true),
                ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05);
              },
            ),
    );
  }

  Widget _buildAccessoriesMasterList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_accessoriesMasters.isEmpty) return _buildEmptyState(LucideIcons.package, 'No accessory matrix found');

    final isWeb = LayoutConstants.isWeb(context);
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: isWeb
          ? GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                mainAxisExtent: 200,
              ),
              itemCount: _accessoriesMasters.length,
              itemBuilder: (context, index) {
                final entry = _accessoriesMasters[index];
                final groups = (entry['groupSetup'] as List?)?.map((e) => e['group']).toList().join(', ') ?? '';
                final items = (entry['itemAssignment'] as List?)?.map((e) => e['itemName']).toList().join(', ') ?? '';

                return _buildAssignmentCard(
                  title: groups.isEmpty ? 'Accessories Protocol' : groups,
                  subtitle: 'Items: ${items.isEmpty ? "All" : items}',
                  date: entry['createdAt'],
                  icon: LucideIcons.package,
                  color: ColorPalette.success,
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AccessoriesMasterFormScreen(editEntry: entry)),
                    );
                    if (result == true) _loadData();
                  },
                  onDelete: () => _deleteAccessory(entry['_id']),
                  onShare: () => _shareAccessory(entry),
                  onPrint: () => _print(entry, false),
                ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05);
              },
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _accessoriesMasters.length,
              itemBuilder: (context, index) {
                final entry = _accessoriesMasters[index];
                final groups = (entry['groupSetup'] as List?)?.map((e) => e['group']).toList().join(', ') ?? '';
                final items = (entry['itemAssignment'] as List?)?.map((e) => e['itemName']).toList().join(', ') ?? '';

                return _buildAssignmentCard(
                  title: groups.isEmpty ? 'Accessories Protocol' : groups,
                  subtitle: 'Items: ${items.isEmpty ? "All" : items}',
                  date: entry['createdAt'],
                  icon: LucideIcons.package,
                  color: ColorPalette.success,
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AccessoriesMasterFormScreen(editEntry: entry)),
                    );
                    if (result == true) _loadData();
                  },
                  onDelete: () => _deleteAccessory(entry['_id']),
                  onShare: () => _shareAccessory(entry),
                  onPrint: () => _print(entry, false),
                ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05);
              },
            ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: ColorPalette.textMuted.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(message, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard({
    required String title,
    required String subtitle,
    required dynamic date,
    String? imageUrl,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required VoidCallback onDelete,
    required VoidCallback onShare,
    required VoidCallback onPrint,
  }) {
    final formattedDate = date != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(date.toString())) : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: ColorPalette.softShadow,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  _buildCardImage(imageUrl, icon, color),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: ColorPalette.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: ColorPalette.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(LucideIcons.calendar, size: 12, color: ColorPalette.textMuted),
                            const SizedBox(width: 6),
                            Text(formattedDate, style: const TextStyle(fontSize: 11, color: ColorPalette.textMuted, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _actionIcon(LucideIcons.share2, Colors.green, onShare),
                  const SizedBox(width: 8),
                  _actionIcon(LucideIcons.printer, Colors.purple, onPrint),
                  const Spacer(),
                  _actionIcon(LucideIcons.pencil, Colors.blue, onTap),
                  const SizedBox(width: 8),
                  _actionIcon(LucideIcons.trash2, ColorPalette.error, onDelete),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardImage(String? imageUrl, IconData fallbackIcon, Color color) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: (imageUrl != null && imageUrl.isNotEmpty)
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                ApiConstants.getImageUrl(imageUrl),
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Icon(fallbackIcon, color: color, size: 24),
              ),
            )
          : Icon(fallbackIcon, color: color, size: 24),
    );
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
