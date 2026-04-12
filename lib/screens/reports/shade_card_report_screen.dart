import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/mobile_api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../services/shade_card_print_service.dart';

class ShadeCardReportScreen extends StatefulWidget {
  const ShadeCardReportScreen({super.key});

  @override
  State<ShadeCardReportScreen> createState() => _ShadeCardReportScreenState();
}

class _ShadeCardReportScreenState extends State<ShadeCardReportScreen> {
  final _api = MobileApiService();
  List<dynamic> _reportData = [];
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  String _selectedLot = 'ALL LOT GROUPS';

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getShadeCardReport();
      setState(() => _reportData = res);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<String> get _availableLots {
    final Set<String> names = {'ALL LOT GROUPS'};
    for (var g in _reportData) {
      if (g['groupName'] != null) names.add(g['groupName'].toString());
    }
    return names.toList()..sort();
  }

  List<dynamic> get _filteredData {
    if (_selectedLot == 'ALL LOT GROUPS') return _reportData;
    return _reportData.where((g) => g['groupName'] == _selectedLot).toList();
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
          // Clinical Header
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
                  'SHADE CARD INTELLIGENCE',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: const Color(0xFF1E293B),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                _buildActionIcons(),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          
          _buildCompactFilterBar(),
          _buildSummaryAnalytics(),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _filteredData.isEmpty 
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _filteredData.length,
                        itemBuilder: (context, index) => _buildShadeGroup(_filteredData[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryAnalytics() {
    int totalColors = 0;
    for (var g in _reportData) {
      totalColors += (g['colours'] as List? ?? []).length;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        children: [
          _analyticsChip(LucideIcons.layoutGrid, '${_reportData.length}', 'LOT GROUPS'),
          const SizedBox(width: 12),
          _analyticsChip(LucideIcons.palette, '$totalColors', 'COLOR VARIANTS'),
        ],
      ),
    );
  }

  Widget _analyticsChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: const Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildActionIcons() {
    return Row(
      children: [
        if (_isGeneratingPdf)
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        else
          IconButton(
            icon: const Icon(LucideIcons.printer, size: 18, color: Color(0xFF64748B)),
            onPressed: () async {
              if (_filteredData.isEmpty) return;
              setState(() => _isGeneratingPdf = true);
              try {
                await ShadeCardPrintService().printShadeCard(_filteredData);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print Error: $e')));
              } finally {
                setState(() => _isGeneratingPdf = false);
              }
            },
          ),
        IconButton(
          icon: const Icon(LucideIcons.refreshCw, size: 18, color: Color(0xFF64748B)),
          onPressed: _fetchReport,
        ),
      ],
    );
  }

  Widget _buildCompactFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FILTER BY LOT GROUP', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedLot,
                      isDense: true,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                      items: _availableLots.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
                      onChanged: (v) => setState(() => _selectedLot = v!),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShadeGroup(Map<String, dynamic> group) {
    final List colors = group['colours'] ?? [];
    final List items = group['items'] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                group['groupName']?.toString().toUpperCase() ?? 'UNNAMED GROUP',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF1E293B), letterSpacing: 0.5),
              ),
              const SizedBox(width: 8),
              if (items.isNotEmpty)
                Expanded(
                  child: Text(
                    items.join(' • ').toUpperCase(),
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: colors.length,
            itemBuilder: (context, idx) => _buildSwatchCard(colors[idx]),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.02),
    );
  }

  Widget _buildSwatchCard(Map<String, dynamic> color) {
    final String? photo = color['photo'];
    final String name = color['name'] ?? 'UNKNOWN';
    final String gsm = color['gsm']?.toString() ?? 'N/A';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFFF1F5F9),
              child: photo != null
                  ? Image.network(
                      ApiConstants.getImageUrl(photo),
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(LucideIcons.image, size: 16, color: Color(0xFFCBD5E1)),
                    )
                  : const Icon(LucideIcons.image, size: 16, color: Color(0xFFCBD5E1)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'GSM: $gsm',
                  style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.palette, size: 40, color: const Color(0xFF94A3B8).withOpacity(0.3)),
          const SizedBox(height: 12),
          Text('No shade cards identified', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}
