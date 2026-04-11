import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/layout_constants.dart';
import '../../widgets/responsive_wrapper.dart';
import '../../services/mobile_api_service.dart';
import 'outward_detail_screen.dart';
import 'lot_outward_screen.dart';
import '../../widgets/modern_data_table.dart';

class OutwardListScreen extends StatefulWidget {
  const OutwardListScreen({super.key});

  @override
  State<OutwardListScreen> createState() => _OutwardListScreenState();
}

class _OutwardListScreenState extends State<OutwardListScreen> {
  final _api = MobileApiService();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _outwards = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOutwards();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOutwards() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getOutwards();
      setState(() {
        _outwards = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredOutwards {
    if (_searchQuery.isEmpty) return _outwards;
    return _outwards.where((item) {
      final lotName = item['lotName']?.toString().toLowerCase() ?? '';
      final dcNo = item['dcNo']?.toString().toLowerCase() ?? '';
      final party = item['partyName']?.toString().toLowerCase() ?? '';
      return lotName.contains(_searchQuery) ||
          dcNo.contains(_searchQuery) ||
          party.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = LayoutConstants.isMobile(context);

    return Scaffold(
      backgroundColor: ColorPalette.background,
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'DISPATCH LOGISTICS',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                color: ColorPalette.textPrimary,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'OUTWARD SHIPMENT REGISTRY',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: ColorPalette.textMuted,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: ColorPalette.textPrimary, size: 20),
        actions: [
          _buildSearchOverlay(isMobile),
          IconButton(
            onPressed: _fetchOutwards,
            icon: const Icon(LucideIcons.refreshCw, size: 16, color: ColorPalette.textMuted),
          ),
          Gaps.w16,
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LotOutwardScreen()),
        ).then((_) => _fetchOutwards()),
        backgroundColor: ColorPalette.textPrimary,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      body: ResponsiveWrapper(
        maxWidth: 1400,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsHeader(),
              Gaps.h24,
              _isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(64.0), child: CircularProgressIndicator()))
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ColorPalette.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ModernDataTable(
                        columns: const ['dcNo', 'lotName', 'partyName', 'process'],
                        columnIcons: const {
                          'dcNo': LucideIcons.fileText,
                          'lotName': LucideIcons.package,
                          'partyName': LucideIcons.briefcase,
                          'process': LucideIcons.activity,
                        },
                        rows: _filteredOutwards.map((item) {
                          return {
                            ...item,
                            'dcNo': item['dcNo'] ?? 'N/A',
                            'lotName': item['lotName'] ?? 'No Lot',
                            'partyName': item['partyName'] ?? 'N/A',
                            'process': item['process'] ?? 'N/A',
                          };
                        }).toList(),
                        onView: (item) => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => OutwardDetailScreen(outward: item)),
                        ),
                        onEdit: (item) => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => LotOutwardScreen(editOutward: item)),
                        ).then((_) => _fetchOutwards()),
                        onDelete: _showDeleteDialog,
                        emptyMessage: _searchQuery.isEmpty
                            ? 'No dispatch records identified'
                            : 'No matches found for "$_searchQuery"',
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Row(
      children: [
        Text(
          'SHIPMENT RECORDS',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: ColorPalette.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        Gaps.w12,
        Text(
          '(${_filteredOutwards.length} ENTRIES)',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textMuted),
        ),
      ],
    );
  }

  Widget _buildSearchOverlay(bool isMobile) {
    if (isMobile) return const SizedBox.shrink();
    return Container(
      width: 240,
      height: 36,
      margin: const EdgeInsets.only(right: 16),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search shipment...',
          hintStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted),
          prefixIcon: const Icon(LucideIcons.search, size: 14, color: ColorPalette.textMuted),
          filled: true,
          fillColor: ColorPalette.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Neutralize Record?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: const Text('This action will remove the dispatch record and restore balances. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Dismiss', style: GoogleFonts.inter(color: ColorPalette.textMuted))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _api.deleteOutward(item['_id']);
              if (success) {
                _fetchOutwards();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dispatch record neutralized'), backgroundColor: ColorPalette.error),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: ColorPalette.error),
            child: Text('Confirm', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
