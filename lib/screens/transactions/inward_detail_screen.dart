import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/responsive_wrapper.dart';
import '../../core/constants/layout_constants.dart';
import 'lot_inward_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/inward_print_service.dart';

class InwardDetailScreen extends StatefulWidget {
  final Map<String, dynamic> inward;

  const InwardDetailScreen({super.key, required this.inward});

  @override
  State<InwardDetailScreen> createState() => _InwardDetailScreenState();
}

class _InwardDetailScreenState extends State<InwardDetailScreen> {
  bool _showStickers = false;
  bool _showAllQRs = false;

  Map<String, dynamic> get inward => widget.inward;

  @override
  Widget build(BuildContext context) {
    final stickers = _extractStickers();
    final isWeb = LayoutConstants.isWeb(context);

    return Scaffold(
      backgroundColor: ColorPalette.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: ColorPalette.border)),
          ),
          child: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, size: 18, color: ColorPalette.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'INWARD ANALYSIS',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: ColorPalette.textPrimary,
                letterSpacing: 1.0,
              ),
            ),
            actions: [
              _buildActionIcon(LucideIcons.pencil, () => _editInward(context), 'EDIT'),
              _buildActionIcon(LucideIcons.printer, () => _printReport(context), 'PRINT'),
              _buildActionIcon(LucideIcons.share2, () => _shareDetails(context), 'SHARE'),
              _buildActionIcon(LucideIcons.trash2, () => _deleteInward(context), 'DELETE', color: ColorPalette.error),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
      body: ResponsiveWrapper(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isWeb ? 40 : 16,
                vertical: 24,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionHeader('LOT SPECIFICATIONS', LucideIcons.box),
                  _buildModernHeaderGrid(isWeb),
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader('SOURCE & PRICING', LucideIcons.user),
                  _buildModernPartyCard(),
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader('QUALITY PERFORMANCE', LucideIcons.shieldCheck),
                  _buildProfessionalQualityDashboard(isWeb),
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader('DIA ENTRIES & DATA', LucideIcons.layers),
                  _buildModernDiaEntriesCard(),
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader('AUTHORIZATIONS', LucideIcons.penTool),
                  _buildModernSignaturesCard(),
                  const SizedBox(height: 24),
                  
                  _buildStickerHeader(context, stickers),
                ]),
              ),
            ),
            if (_showStickers && stickers.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isWeb ? 40 : 16),
                sliver: isWeb 
                  ? SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        mainAxisExtent: 460, // Increased to fit QR and Details without overflow
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildModernStickerItem(context, stickers[index]),
                        childCount: stickers.length,
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildModernStickerItem(context, stickers[index]),
                        ),
                        childCount: stickers.length,
                      ),
                    ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, VoidCallback onTap, String tooltip, {Color? color}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color ?? ColorPalette.textPrimary),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: ColorPalette.primary.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ColorPalette.textMuted,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05);
  }

  Widget _buildModernCard({required Widget child, Color? color, EdgeInsets? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      padding: padding,
      child: child,
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.02);
  }

  Widget _buildModernRow(String label, String value, {bool isStatus = false, Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: ColorPalette.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (isStatus)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (statusColor ?? ColorPalette.success).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(100), // Pill style
                    ),
                    child: Text(
                      value.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: statusColor ?? ColorPalette.success,
                        letterSpacing: 1.0,
                      ),
                    ),
                  )
                else
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ColorPalette.textPrimary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeaderGrid(bool isWeb) {
    if (!isWeb) return _buildModernHeaderCard();
    
    return _buildModernCard(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildModernRow('Inward No', inward['inwardNo'] ?? 'N/A'),
                  const Divider(height: 1, color: ColorPalette.border),
                  _buildModernRow('Lot Name', inward['lotName'] ?? 'N/A'),
                  const Divider(height: 1, color: ColorPalette.border),
                  _buildModernRow('Lot No', inward['lotNo'] ?? 'N/A'),
                  const Divider(height: 1, color: ColorPalette.border),
                  _buildModernRow('Inward Date', _formatDate(inward['inwardDate'])),
                ],
              ),
            ),
            const VerticalDivider(width: 1, color: ColorPalette.border),
            Expanded(
              child: Column(
                children: [
                  _buildModernRow('Time In', inward['inTime'] ?? 'N/A'),
                  const Divider(height: 1, color: ColorPalette.border),
                  _buildModernRow('Time Out', inward['outTime'] ?? 'N/A'),
                  const Divider(height: 1, color: ColorPalette.border),
                  _buildModernRow('Vehicle', inward['vehicleNo'] ?? 'N/A'),
                  const Divider(height: 1, color: ColorPalette.border),
                  _buildModernRow('DC No', inward['partyDcNo'] ?? 'N/A'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeaderCard() {
    return _buildModernCard(
      child: Column(
        children: [
          _buildModernRow('Inward No', inward['inwardNo'] ?? 'N/A'),
          const Divider(height: 1, color: ColorPalette.border),
          _buildModernRow('Lot Name', inward['lotName'] ?? 'N/A'),
          const Divider(height: 1, color: ColorPalette.border),
          _buildModernRow('Lot No', inward['lotNo'] ?? 'N/A'),
          const Divider(height: 1, color: ColorPalette.border),
          _buildModernRow('Inward Date', _formatDate(inward['inwardDate'])),
          const Divider(height: 1, color: ColorPalette.border),
          _buildModernRow('Time Log', '${inward['inTime'] ?? ''} - ${inward['outTime'] ?? ''}'),
          const Divider(height: 1, color: ColorPalette.border),
          _buildModernRow('Vehicle No', inward['vehicleNo'] ?? 'N/A'),
          const Divider(height: 1, color: ColorPalette.border),
          _buildModernRow('Party DC No', inward['partyDcNo'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildModernPartyCard() {
    return _buildModernCard(
      child: Column(
        children: [
          _buildModernRow('From Party', inward['fromParty'] ?? 'N/A'),
          const Divider(height: 1, color: ColorPalette.border),
          _buildModernRow('Process', inward['process'] ?? 'N/A'),
          const Divider(height: 1, color: ColorPalette.border),
          _buildModernRow('Contract Rate', FormatUtils.formatCurrency(double.tryParse(inward['rate']?.toString() ?? '0') ?? 0)),
        ],
      ),
    );
  }

  Widget _buildProfessionalQualityDashboard(bool isWeb) {
    return Column(
      children: [
        _buildModernCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _buildQualityGridRow(
                  isWeb,
                  [
                    _buildQualityTile('Quality Status', inward['qualityStatus'] ?? 'OK', inward['qualityImage']),
                    _buildQualityTile('GSM Check', inward['gsmStatus'] ?? 'OK', inward['gsmImage']),
                  ],
                ),
                const Divider(height: 1, color: ColorPalette.border),
                _buildQualityGridRow(
                  isWeb,
                  [
                    _buildQualityTile('Shade Match', inward['shadeStatus'] ?? 'OK', inward['shadeImage']),
                    _buildQualityTile('Washing Check', inward['washingStatus'] ?? 'OK', inward['washingImage']),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (inward['complaintText'] != null && inward['complaintText'].toString().isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildComplaintHighlight(),
        ],
      ],
    );
  }

  Widget _buildQualityGridRow(bool isWeb, List<Widget> children) {
    if (!isWeb) {
      return Column(children: [
        children[0],
        const Divider(height: 1, indent: 20, endIndent: 20, color: ColorPalette.border),
        children[1],
      ]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: children[0]),
          const VerticalDivider(width: 1, color: ColorPalette.border),
          Expanded(child: children[1]),
        ],
      ),
    );
  }

  Widget _buildQualityTile(String label, String status, String? image) {
    final bool isError = status.toUpperCase() != 'OK';
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textMuted, letterSpacing: 0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isError ? ColorPalette.error : ColorPalette.success).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: isError ? ColorPalette.error : ColorPalette.success),
                ),
              ),
            ],
          ),
          if (image != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => _viewFullImage(image),
                child: Stack(
                  children: [
                    Image.network(
                      ApiConstants.getImageUrl(image),
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 80, color: ColorPalette.background, child: const Icon(LucideIcons.image, size: 16, color: ColorPalette.border)),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(4)),
                        child: const Icon(LucideIcons.maximize2, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _viewFullImage(String image) {
     showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(icon: const Icon(LucideIcons.x, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: InteractiveViewer(
                child: Image.network(ApiConstants.getImageUrl(image), fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintHighlight() {
    return Container(
      decoration: BoxDecoration(
        color: ColorPalette.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorPalette.error.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.alertCircle, size: 14, color: ColorPalette.error),
              const SizedBox(width: 8),
              Text('COMPLAINT REMARKS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: ColorPalette.error, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            inward['complaintText'] ?? '',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ColorPalette.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDiaEntriesCard() {
    final entries = inward['diaEntries'] as List<dynamic>? ?? [];
    return _buildModernCard(
      child: Column(
        children: [
          if (entries.isEmpty)
             Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: Text('NO ENTRIES RECORDED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textMuted))),
              )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: ColorPalette.border),
              itemBuilder: (context, index) {
                final entry = entries[index] as Map<String, dynamic>;
                return _buildModernDiaRow(entry);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildModernDiaRow(Map<String, dynamic> entry) {
    final rate = double.tryParse(entry['rate']?.toString() ?? '0') ?? 0;
    final recWt = double.tryParse(entry['recWt']?.toString() ?? '0') ?? 0;
    final value = rate * recWt;
    final dia = entry['dia']?.toString() ?? '';

    // Extract storage details matching this DIA
    final storageDetails = inward['storageDetails'] as List<dynamic>? ?? [];
    final matchingStorage = storageDetails.firstWhere((s) => s != null && s['dia']?.toString() == dia, orElse: () => null);
    
    // Clean Racks and Pallets to remove nulls
    final String racks = (matchingStorage?['racks'] as List<dynamic>? ?? [])
      .where((r) => r != null && r.toString().isNotEmpty && r.toString().toLowerCase() != 'null')
      .join(', ');
      
    final String pallets = (matchingStorage?['pallets'] as List<dynamic>? ?? [])
      .where((p) => p != null && p.toString().isNotEmpty && p.toString().toLowerCase() != 'null')
      .join(', ');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DIA ${dia}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: ColorPalette.primary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.layers, size: 10, color: ColorPalette.textMuted),
                            const SizedBox(width: 4),
                            Text('RACKS: ${racks.isEmpty ? "NONE" : racks}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textMuted)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.package, size: 10, color: ColorPalette.textMuted),
                            const SizedBox(width: 4),
                            Text('PALLETS: ${pallets.isEmpty ? "NONE" : pallets}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('VAL: ${FormatUtils.formatCurrency(value)}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: ColorPalette.primary)),
                  Text('RATE: ${FormatUtils.formatCurrency(rate)}', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: ColorPalette.success)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildDataPoint('ROLLS', '${entry['roll'] ?? 0}'),
              _buildDataPoint('SETS', '${entry['sets'] ?? 0}'),
              _buildDataPoint('REC. WT', '${FormatUtils.formatWeight(entry['recWt'])} KG'),
              _buildDataPoint('DEL. WT', '${FormatUtils.formatWeight(entry['delivWt'])} KG'),
            ],
          ),
          const SizedBox(height: 20),
          _buildStickerSetBreakdown(matchingStorage),
        ],
      ),
    );
  }

  Widget _buildStickerSetBreakdown(Map<String, dynamic>? matchingStorage) {
    if (matchingStorage == null) return const SizedBox.shrink();
    final rows = matchingStorage['rows'] as List<dynamic>? ?? [];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32, color: ColorPalette.border),
        Text('STICKER SETS BREAKDOWN', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: ColorPalette.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        ...rows.map((row) {
          if (row == null) return const SizedBox.shrink();
          final String colour = row['colour']?.toString() ?? 'N/A';
          // Filter weights to remove empty or invalid entries
          final weights = (row['setWeights'] as List<dynamic>? ?? [])
            .where((w) => w != null && w.toString().trim().isNotEmpty && (double.tryParse(w.toString()) ?? 0) > 0)
            .toList();
            
          if (weights.isEmpty) return const SizedBox.shrink();

          final double total = weights.fold(0.0, (sum, w) => sum + (double.tryParse(w?.toString() ?? '0') ?? 0.0));
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ROLL ${weights.length} - ${colour.toUpperCase()} (${total.toStringAsFixed(1)})',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: ColorPalette.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  weights.join(', '),
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: ColorPalette.textSecondary, height: 1.4),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildDataPoint(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: ColorPalette.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? ColorPalette.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildModernSignaturesCard() {
    return _buildModernCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildModernSignatureItem('LOT INCHARGE', inward['lotInchargeSignature']),
            _buildModernSignatureItem('AUTHORIZED', inward['authorizedSignature']),
            _buildModernSignatureItem('MANAGING DIR.', inward['mdSignature']),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSignatureItem(String label, String? imagePath) {
    final bool hasImage = imagePath != null && imagePath.toString().isNotEmpty;
    return Column(
      children: [
        Container(
          height: 80,
          width: 100,
          decoration: BoxDecoration(
            color: hasImage ? Colors.transparent : ColorPalette.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ColorPalette.border),
          ),
          child: hasImage
              ? Image.network(ApiConstants.getImageUrl(imagePath), fit: BoxFit.contain)
              : Center(child: Text("MISSING", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: ColorPalette.border))),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildModernStickerItem(BuildContext context, Map<String, dynamic> item) {
    return _buildModernCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStickerAttribute('LOT NO', item['lotNo']?.toString() ?? 'N/A'),
                    _buildStickerAttribute('Lot Name', item['lotName']?.toString() ?? 'N/A'),
                    _buildStickerAttribute('Dia', item['dia']?.toString() ?? 'N/A'),
                    _buildStickerAttribute('Colour', item['colour']?.toString() ?? 'N/A'),
                    _buildStickerAttribute('Set No', item['setNo']?.toString() ?? 'N/A'),
                    _buildStickerAttribute('Roll Wt', '${item['weight']} kg'),
                    _buildStickerAttribute('Date', item['date']?.toString() ?? 'N/A'),
                  ],
                ),
              ),
              Column(
                children: [
                  _buildActionIcon(LucideIcons.printer, () => _printSingleSticker(item), 'PRINT STICKER', color: ColorPalette.primary),
                  _buildActionIcon(LucideIcons.share2, () => _shareSingleSticker(item), 'SHARE STICKER', color: ColorPalette.primary),
                ],
              ),
            ],
          ),
          if (_showAllQRs) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: ColorPalette.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: '${item['lotNo']}|${item['setNo']}|${item['weight']}',
                version: QrVersions.auto,
                size: 140,
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 12),
            Text('SCAN FOR AUTH', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5)),
          ],
        ],
      ),
    );
  }

  Widget _buildStickerAttribute(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text('$label :', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: ColorPalette.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: ColorPalette.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerHeader(BuildContext context, List<Map<String, dynamic>> stickers) {
    if (stickers.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorPalette.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('STICKER PREVIEWS', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: ColorPalette.textPrimary)),
              TextButton.icon(
                onPressed: () => setState(() => _showStickers = !_showStickers),
                icon: Icon(_showStickers ? LucideIcons.eyeOff : LucideIcons.eye, size: 14),
                label: Text(_showStickers ? "HIDE" : "SHOW"),
                style: TextButton.styleFrom(
                  foregroundColor: ColorPalette.primary,
                  textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (_showStickers) ...[
            const Divider(height: 32, color: ColorPalette.border),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Show QR Codes', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: ColorPalette.textPrimary)),
                      Text('Turn on to see scannable tags', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: ColorPalette.textMuted)),
                    ],
                  ),
                ),
                Switch(
                  value: _showAllQRs,
                  onChanged: (v) => setState(() => _showAllQRs = v),
                  activeColor: ColorPalette.primary,
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Future<void> _printSingleSticker(Map<String, dynamic> item) async {
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (pw.Context context) => pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('LOT STICKER', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.Divider(),
                _pwAttr('LOT NO', item['lotNo']),
                _pwAttr('Lot Name', item['lotName']),
                _pwAttr('Dia', item['dia']),
                _pwAttr('Colour', item['colour']),
                _pwAttr('Set No', item['setNo']),
                _pwAttr('Weight', '${item['weight']} kg'),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.BarcodeWidget(
                    data: '${item['lotNo']}|${item['setNo']}|${item['weight']}',
                    barcode: pw.Barcode.qrCode(),
                    width: 100,
                    height: 100,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Sticker_${item['setNo']}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error printing sticker: $e')));
    }
  }

  pw.Widget _pwAttr(String label, dynamic value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 50, child: pw.Text('$label:', style: const pw.TextStyle(fontSize: 8))),
          pw.Text(value?.toString() ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        ],
      ),
    );
  }

  Future<void> _shareSingleSticker(Map<String, dynamic> item) async {
    try {
       final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('LOT STICKER - ${item['lotNo']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 10),
              pw.BarcodeWidget(
                data: '${item['lotNo']}|${item['setNo']}|${item['weight']}',
                barcode: pw.Barcode.qrCode(),
                width: 80,
                height: 80,
              ),
            ],
          ),
        ),
      );
      final bytes = await doc.save();
      await Share.shareXFiles([XFile.fromData(bytes, mimeType: 'application/pdf', name: 'Sticker_${item['setNo']}.pdf')]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing sticker: $e')));
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr)).toUpperCase();
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _shareDetails(BuildContext context) async {
    try {
      final service = InwardPrintService();
      final pdfBytes = await service.generatePdfBytes(inward);
      final filename = 'Lot_Inward_${inward['lotNo'] ?? 'Details'}.pdf';
      await Share.shareXFiles([XFile.fromData(pdfBytes, mimeType: 'application/pdf', name: filename)], text: 'Inward Details - Lot ${inward['lotNo'] ?? ''}', subject: 'Lot Inward PDF');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error preparing sharing details: $e")));
    }
  }

  Future<void> _printReport(BuildContext context) async {
    try {
      final service = InwardPrintService();
      await service.printInwardReport(inward);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating report: $e')));
    }
  }

  void _editInward(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => LotInwardScreen(editInward: inward)));
  }

  Future<void> _deleteInward(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('DELETE RECORD', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE THIS INWARD LOG?', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('CANCEL', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ColorPalette.border))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: ColorPalette.error), child: Text('DELETE', style: GoogleFonts.inter(fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final api = MobileApiService();
        final success = await api.deleteInward(inward['_id']);
        if (context.mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inward deleted successfully')));
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete inward')));
          }
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting inward: $e')));
      }
    }
  }

  List<Map<String, dynamic>> _extractStickers() {
    final storageDetails = inward['storageDetails'] as List<dynamic>? ?? [];
    final List<Map<String, dynamic>> stickers = [];
    for (var s in storageDetails) {
      if (s == null) continue;
      final dia = (s['dia'] ?? '').toString();
      final rows = s['rows'] as List<dynamic>? ?? [];
      for (var r in rows) {
        if (r == null) continue;
        final colour = (r['colour'] ?? '').toString();
        if (colour.isNotEmpty) {
          final setWeights = r['setWeights'] as List<dynamic>? ?? [];
          final setLabels = r['setLabels'] as List<dynamic>? ?? [];
          for (int i = 0; i < setWeights.length; i++) {
            final weight = setWeights[i]?.toString() ?? '';
            if (weight.trim().isNotEmpty && (double.tryParse(weight) ?? 0) > 0) {
              final setNo = i < setLabels.length && (setLabels[i]?.toString().trim().isNotEmpty ?? false) ? setLabels[i].toString().trim() : (i + 1).toString();
              stickers.add({'lotNo': inward['lotNo']?.toString() ?? '', 'lotName': inward['lotName']?.toString() ?? '', 'dia': dia, 'colour': colour, 'weight': weight, 'date': _formatDate(inward['inwardDate']), 'setNo': setNo});
            }
          }
        }
      }
    }
    return stickers;
  }
}
