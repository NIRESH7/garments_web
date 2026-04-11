import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/layout_constants.dart';
import '../../widgets/responsive_wrapper.dart';
import 'item_master_screen.dart';

class ItemGroupHistoryScreen extends StatefulWidget {
  const ItemGroupHistoryScreen({super.key});

  @override
  State<ItemGroupHistoryScreen> createState() => _ItemGroupHistoryScreenState();
}

class _ItemGroupHistoryScreenState extends State<ItemGroupHistoryScreen> {
  final _api = MobileApiService();
  List<dynamic> _itemGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchItemGroups();
  }

  Future<void> _fetchItemGroups() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getItemGroups();
      setState(() {
        _itemGroups = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Registry fetch failure: Connection unstable');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: ColorPalette.error));
  }

  Future<void> _deleteGroup(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Confirm Deletion', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to permanently remove this specification group? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: ColorPalette.error, foregroundColor: Colors.white), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _api.deleteItemGroup(id);
      if (success) {
        _fetchItemGroups();
      } else {
        _showError('Registry Deletion Failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = LayoutConstants.isMobile(context);

    return Scaffold(
      backgroundColor: ColorPalette.background,
      appBar: AppBar(
        title: Text('Group Specification Logs', style: TextStyle(fontWeight: FontWeight.w800, color: ColorPalette.textPrimary, fontSize: isMobile ? 18 : 22)),
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: ColorPalette.textPrimary),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton.filledTonal(
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              onPressed: _fetchItemGroups,
              style: IconButton.styleFrom(backgroundColor: ColorPalette.primary.withOpacity(0.05), foregroundColor: ColorPalette.primary),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveWrapper(
              child: _itemGroups.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(LucideIcons.packageX, size: 48, color: ColorPalette.textMuted.withOpacity(0.3)), const SizedBox(height: 16), Text('No registered groups found', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary))]))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      itemCount: _itemGroups.length,
                      itemBuilder: (context, index) {
                        final group = _itemGroups[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: ColorPalette.softShadow, border: Border.all(color: Colors.grey.shade200)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: ColorPalette.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: const Icon(LucideIcons.package2, color: ColorPalette.primary, size: 24)),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(group['groupName'] ?? 'Unnamed Group', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: ColorPalette.textPrimary)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _HistoryBadge(label: 'GSM: ${group['gsm']}', color: ColorPalette.secondary),
                                          const SizedBox(width: 8),
                                          _HistoryBadge(label: '₹ ${group['rate']}/Kg', color: ColorPalette.success),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      _buildInfoRow(LucideIcons.tag, 'Items: ', (group['itemNames'] as List).join(", ")),
                                      const SizedBox(height: 4),
                                      _buildInfoRow(LucideIcons.palette, 'Colours: ', (group['colours'] as List).join(", ")),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton.filledTonal(
                                      icon: const Icon(LucideIcons.edit2, size: 16),
                                      onPressed: () async {
                                        final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => ItemMasterScreen(editGroup: group)));
                                        if (result == true) _fetchItemGroups();
                                      },
                                      style: IconButton.styleFrom(backgroundColor: ColorPalette.primary.withOpacity(0.05), foregroundColor: ColorPalette.primary),
                                    ),
                                    const SizedBox(height: 8),
                                    IconButton.filledTonal(
                                      icon: const Icon(LucideIcons.trash2, size: 16),
                                      onPressed: () => _deleteGroup(group['_id']),
                                      style: IconButton.styleFrom(backgroundColor: ColorPalette.error.withOpacity(0.05), foregroundColor: ColorPalette.error),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 12, color: ColorPalette.textMuted),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ColorPalette.textSecondary)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: ColorPalette.textMuted), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _HistoryBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _HistoryBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
    );
  }
}
