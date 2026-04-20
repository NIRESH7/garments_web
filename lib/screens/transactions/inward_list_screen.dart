import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/layout/web_layout_wrapper.dart';
import '../../services/mobile_api_service.dart';
import '../../core/constants/api_constants.dart';
import 'inward_detail_screen.dart';
import 'lot_inward_screen.dart';

class InwardListScreen extends StatefulWidget {
  const InwardListScreen({super.key});

  @override
  State<InwardListScreen> createState() => InwardListScreenState();
}

class InwardListScreenState extends State<InwardListScreen> {
  final _api = MobileApiService();
  List<dynamic> _inwards = [];
  Map<String, String?> _colorPhotoMap = {};
  bool _isLoading = true;
  int _currentPage = 0;
  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    fetchInwards();
  }

  Future<void> fetchInwards() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await _api.getInwards();
      final categories = await _api.getCategories();
      
      final Map<String, String?> photoMap = {};
      try {
        final colorCat = categories.firstWhere(
          (c) => (c['name'] as String).toLowerCase() == 'colours',
          orElse: () => null,
        );
        if (colorCat != null && colorCat['values'] != null) {
          for (var v in colorCat['values']) {
            if (v is Map) {
              photoMap[v['name'].toString()] = v['photo']?.toString();
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _inwards = res;
          _colorPhotoMap = photoMap;
          _isLoading = false;
          _currentPage = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = LayoutConstants.isWeb(context);
    
    return Scaffold(
      backgroundColor: ColorPalette.background,
      body: isWeb ? _buildWebLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildWebLayout() {
    final int totalPages = (_inwards.length / _itemsPerPage).ceil();
    final int startIndex = _currentPage * _itemsPerPage;
    final List<dynamic> pagedInwards = _inwards.skip(startIndex).take(_itemsPerPage).toList();

    return WebLayoutWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _inwards.isEmpty
                    ? _buildEmptyState()
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ColorPalette.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              decoration: BoxDecoration(
                                color: ColorPalette.background.withOpacity(0.3),
                                border: const Border(bottom: BorderSide(color: ColorPalette.border)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 1, child: _buildTableHeaderCell('COLOR')),
                                  Expanded(flex: 3, child: _buildTableHeaderCell('LOT DETAILS')),
                                  Expanded(flex: 2, child: _buildTableHeaderCell('SOURCE PARTY')),
                                  Expanded(flex: 1, child: _buildTableHeaderCell('DATE')),
                                  Expanded(flex: 1, child: _buildTableHeaderCell('STATUS')),
                                  SizedBox(
                                    width: 100,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: InkWell(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const LotInwardScreen()),
                                        ).then((_) => fetchInwards()),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: ColorPalette.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: ColorPalette.primary.withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(LucideIcons.plus, size: 12, color: ColorPalette.primary),
                                              const SizedBox(width: 4),
                                              Text(
                                                'ADD NEW',
                                                style: GoogleFonts.inter(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: ColorPalette.primary,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: pagedInwards.length,
                                separatorBuilder: (context, index) => const Divider(height: 1, color: ColorPalette.border),
                                itemBuilder: (context, index) => _buildWebInwardRow(pagedInwards[index]),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
          if (_inwards.isNotEmpty) _buildPaginationFooter(totalPages),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(int totalPages) {
    return Container(
      padding: const EdgeInsets.only(top: 24, bottom: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildPaginationButton(
            icon: LucideIcons.chevronLeft,
            label: 'PREVIOUS',
            isActive: _currentPage > 0,
            onPressed: () => setState(() => _currentPage--),
          ),
          Gaps.w24,
          Text(
            'PAGE ${_currentPage + 1} OF ${totalPages == 0 ? 1 : totalPages}'.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ColorPalette.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          Gaps.w24,
          _buildPaginationButton(
            icon: LucideIcons.chevronRight,
            label: 'NEXT',
            isActive: _currentPage < totalPages - 1,
            onPressed: () => setState(() => _currentPage++),
            isTrailingIcon: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    bool isTrailingIcon = false,
  }) {
    return InkWell(
      onTap: isActive ? onPressed : null,
      borderRadius: BorderRadius.circular(4),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.3,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: ColorPalette.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isTrailingIcon) ...[
                Icon(icon, size: 14, color: ColorPalette.textPrimary),
                Gaps.w8,
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: ColorPalette.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              if (isTrailingIcon) ...[
                Gaps.w8,
                Icon(icon, size: 14, color: ColorPalette.textPrimary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: ColorPalette.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildMobileLayout() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _inwards.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _inwards.length,
                itemBuilder: (context, index) => _buildInwardCard(context, _inwards[index], index),
              );
  }

  Widget _buildWebInwardRow(Map<String, dynamic> item) {
    final hasIncharge = item['lotInchargeSignature'] != null;
    final hasAuthorized = item['authorizedSignature'] != null;
    final hasMd = item['mdSignature'] != null;
    
    // Extract colors from diaEntries
    final List<dynamic> entries = item['diaEntries'] ?? [];
    final Set<String> colorNames = entries.map((e) => e['color']?.toString() ?? e['colour']?.toString() ?? '').where((c) => c.isNotEmpty).toSet();
    final firstColor = colorNames.isNotEmpty ? colorNames.first : null;
    final photoUrl = firstColor != null ? _colorPhotoMap[firstColor] : null;

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => InwardDetailScreen(inward: item))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: GestureDetector(
                onTap: () {
                  if (photoUrl != null && photoUrl.isNotEmpty) {
                    _showImagePreview(firstColor ?? 'Color', photoUrl);
                  }
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: ColorPalette.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: ColorPalette.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (photoUrl != null && photoUrl.isNotEmpty)
                      ? Image.network(
                          ApiConstants.getImageUrl(photoUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(LucideIcons.palette, size: 12, color: ColorPalette.textMuted),
                        )
                      : const Icon(LucideIcons.palette, size: 12, color: ColorPalette.textMuted),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['lotName'] ?? 'Unnamed Lot').toString().toUpperCase(),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: ColorPalette.primary, letterSpacing: -0.2),
                  ),
                  Gaps.h4,
                  Text(
                    '${item['lotNo']} | ${item['dia']} Φ'.toUpperCase(),
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: ColorPalette.textMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                (item['fromParty'] ?? 'UNKNOWN').toString().toUpperCase(),
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ColorPalette.textPrimary),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                DateFormat('dd MMM yy').format(DateTime.parse(item['inwardDate'])).toUpperCase(),
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: ColorPalette.textSecondary),
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  _buildSignIndicator(LucideIcons.userCheck, hasIncharge),
                  Gaps.w4,
                  _buildSignIndicator(LucideIcons.shieldCheck, hasAuthorized),
                  Gaps.w4,
                  _buildSignIndicator(LucideIcons.award, hasMd),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: ColorPalette.textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.inbox, size: 48, color: ColorPalette.textMuted.withOpacity(0.2)),
          Gaps.h16,
          Text('NO INWARD RECORDS IDENTIFIED', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: ColorPalette.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildInwardCard(BuildContext context, Map<String, dynamic> item, int index) {
    final hasIncharge = item['lotInchargeSignature'] != null;
    final hasAuthorized = item['authorizedSignature'] != null;
    final hasMd = item['mdSignature'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorPalette.border),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => InwardDetailScreen(inward: item))),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildTypeIcon(),
              Gaps.w16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (item['lotName'] ?? 'Unnamed Lot').toString().toUpperCase(),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: ColorPalette.primary),
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM yy').format(DateTime.parse(item['inwardDate'])).toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 9, color: ColorPalette.textMuted, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Gaps.h4,
                    Text(
                      '${item['lotNo']} | ${item['dia']} Φ'.toUpperCase(),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: ColorPalette.textPrimary),
                    ),
                    Gaps.h4,
                    Text(
                      'SOURCE: ${item['fromParty']}'.toString().toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: ColorPalette.textSecondary),
                    ),
                    Gaps.h12,
                    Row(
                      children: [
                        _buildSignIndicator(LucideIcons.userCheck, hasIncharge),
                        Gaps.w8,
                        _buildSignIndicator(LucideIcons.shieldCheck, hasAuthorized),
                        Gaps.w8,
                        _buildSignIndicator(LucideIcons.award, hasMd),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, color: ColorPalette.textMuted, size: 14),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05);
  }

  Widget _buildTypeIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: ColorPalette.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(LucideIcons.inbox, color: ColorPalette.success, size: 20),
    );
  }

  Widget _buildSignIndicator(IconData icon, bool active) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: active ? ColorPalette.success.withOpacity(0.1) : ColorPalette.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 12, color: active ? ColorPalette.success : ColorPalette.textMuted.withOpacity(0.3)),
    );
  }

  void _showImagePreview(String valueName, String? photoUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(valueName, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (photoUrl != null && photoUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16), 
                  child: Image.network(
                    ApiConstants.getImageUrl(photoUrl), 
                    width: 200, 
                    height: 200, 
                    fit: BoxFit.cover, 
                    errorBuilder: (context, error, stackTrace) => _largeColorCircle(valueName)
                  )
                )
              else _largeColorCircle(valueName),
            ],
          ),
          actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')) ],
        );
      },
    );
  }

  Widget _largeColorCircle(String value) {
    final color = _resolveColor(value) ?? const Color(0xFFBDBDBD);
    return Container(
      width: 150, 
      height: 150, 
      decoration: BoxDecoration(
        color: color, 
        shape: BoxShape.circle, 
        border: Border.all(color: Colors.grey.shade300, width: 2), 
        boxShadow: [ 
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)) 
        ]
      )
    );
  }

  Color? _resolveColor(String name) {
    final lower = name.toLowerCase().trim();
    const colorMap = <String, Color>{
      'red': Color(0xFFE53935), 'blue': Color(0xFF1E88E5), 'green': Color(0xFF43A047),
      'yellow': Color(0xFFFDD835), 'orange': Color(0xFFFB8C00), 'black': Color(0xFF212121),
      'white': Color(0xFFFAFAFA), 'grey': Color(0xFF9E9E9E), 'pink': Color(0xFFEC407A),
      'purple': Color(0xFF7B1FA2), 'brown': Color(0xFF6D4C41), 'maroon': Color(0xFF800000),
      'teal': Color(0xFF008080), 'navy': Color(0xFF0A1747), 'gold': Color(0xFFFFD700),
    };
    final hexMatch = RegExp(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})').firstMatch(name);
    if (hexMatch != null) { try { String hex = hexMatch.group(1)!; if (hex.length == 3) hex = hex[0] * 2 + hex[1] * 2 + hex[2] * 2; return Color(int.parse('0xFF$hex')); } catch (_) {} }
    if (colorMap.containsKey(lower)) return colorMap[lower]!;
    final sortedKeys = colorMap.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sortedKeys) { if (lower.contains(key)) return colorMap[key]; }
    return null;
  }
}
