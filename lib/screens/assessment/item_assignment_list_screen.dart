import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/responsive_wrapper.dart';
import 'cutting_master_form_screen.dart';
import 'accessories_master_form_screen.dart';
import '../../widgets/modern_data_table.dart';

class ItemAssignmentListScreen extends StatefulWidget {
  const ItemAssignmentListScreen({super.key});

  @override
  State<ItemAssignmentListScreen> createState() => _ItemAssignmentListScreenState();
}

class _ItemAssignmentListScreenState extends State<ItemAssignmentListScreen> with SingleTickerProviderStateMixin {
  final _api = MobileApiService();
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _cuttingMasters = [];
  List<Map<String, dynamic>> _accessoriesMasters = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        _cuttingMasters = (cuttingRes as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
        _accessoriesMasters = (accessoriesRes as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading item assignments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPalette.background,
      body: ResponsiveWrapper(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tab switcher + compact create button in same row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildTabSwitcher(),
                  const Spacer(),
                  InkWell(
                    onTap: () async {
                      Widget screen = _tabController.index == 0
                        ? const CuttingMasterFormScreen()
                        : const AccessoriesMasterFormScreen();
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
                      if (result == true) _loadData();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF475569),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.plus, size: 14, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'CREATE NEW ASSIGNMENT',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(100), child: CircularProgressIndicator(strokeWidth: 2)))
                : _tabController.index == 0
                  ? _buildListView(_cuttingMasters, true)
                  : _buildListView(_accessoriesMasters, false),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tabToggle('CUTTING MASTER', 0),
          _tabToggle('ACCESSORIES MASTER', 1),
        ],
      ),
    );
  }

  Widget _tabToggle(String label, int index) {
    bool active = _tabController.index == index;
    return InkWell(
      onTap: () => setState(() => _tabController.index = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12, 
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> items, bool isCutting) {
    if (items.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.clipboardList,
                size: 80,
                color: Colors.grey.withOpacity(0.3),
              ),
              const SizedBox(height: 20),
              Text(
                isCutting ? 'No cutting master entries found' : 'No accessory matrices found',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: ColorPalette.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ModernDataTable(
            columns: isCutting 
              ? const ['itemName', 'lotName', 'size', 'createdAt']
              : const ['groups', 'assignments', 'createdAt'],
            columnIcons: isCutting
              ? const {
                  'itemName': LucideIcons.scissors,
                  'lotName': LucideIcons.package,
                  'size': LucideIcons.ruler,
                  'createdAt': LucideIcons.calendar,
                }
              : const {
                  'groups': LucideIcons.package,
                  'assignments': LucideIcons.list,
                  'createdAt': LucideIcons.calendar,
                },
            rows: items.map((e) {
              if (isCutting) {
                return {
                  ...e,
                  'createdAt': e['createdAt'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(e['createdAt'].toString())) : 'N/A',
                };
              } else {
                final groups = (e['groupSetup'] as List?)?.map((ent) => ent['group']).toList().join(', ') ?? '';
                final itemsList = (e['itemAssignment'] as List?)?.map((ent) => ent['itemName']).toList().join(', ') ?? '';
                return {
                  ...e,
                  'groups': groups.isEmpty ? 'GENERAL' : groups.toUpperCase(),
                  'assignments': itemsList.isEmpty ? 'ALL ITEMS' : itemsList.toUpperCase(),
                  'createdAt': e['createdAt'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(e['createdAt'].toString())) : 'N/A',
                };
              }
            }).toList(),
            onEdit: (entry) async {
              Widget screen = isCutting 
                ? CuttingMasterFormScreen(entryId: entry['_id'])
                : AccessoriesMasterFormScreen(editEntry: entry);
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
              if (result == true) _loadData();
            },
            onDelete: (entry) => _deleteEntry(entry['_id'], isCutting),
            emptyMessage: 'No entries found in this partition.',
          ),
        ),
      );
    }

  Future<void> _deleteEntry(String id, bool isCutting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${isCutting ? 'Cutting' : 'Accessory'} Entry?'),
        content: const Text('This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: ColorPalette.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = isCutting ? await _api.deleteCuttingMaster(id) : await _api.deleteAccessoriesMaster(id);
      if (success) _loadData();
    }
  }
}
