import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/color_palette.dart';
import '../../services/outward_print_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/responsive_wrapper.dart';

class OutwardDetailScreen extends StatefulWidget {
  final Map<String, dynamic> outward;

  const OutwardDetailScreen({super.key, required this.outward});

  @override
  State<OutwardDetailScreen> createState() => _OutwardDetailScreenState();
}

class _OutwardDetailScreenState extends State<OutwardDetailScreen> {
  final _api = MobileApiService();
  late Map<String, dynamic> _outward;
  bool _isRecovering = false;

  @override
  void initState() {
    super.initState();
    _outward = Map<String, dynamic>.from(widget.outward);
    _recoverMetadata();
  }

  Future<void> _recoverMetadata() async {
    final items = _outward['items'] as List<dynamic>? ?? [];
    bool needsRecovery = false;

    for (var set in items) {
      final colours = set['colours'] as List<dynamic>? ?? [];
      for (var col in colours) {
        if (col['gsm'] == null || col['dia'] == null) {
          needsRecovery = true;
          break;
        }
      }
      if (needsRecovery) break;
    }

    if (!needsRecovery) return;

    final lotNo = _outward['lotNo']?.toString();
    final dia = _outward['dia']?.toString();

    if (lotNo == null || dia == null) return;

    setState(() => _isRecovering = true);

    try {
      // Pass the outward's own ID as excludeId so the backend
      // excludes this DC from stock subtraction, allowing us to
      // correctly recover the inward GSM/DIA metadata.
      final outwardId = _outward['_id']?.toString();
      final balancedSets = await _api.getBalancedSets(
        lotNo,
        dia,
        excludeId: outwardId,
      );
      if (balancedSets.isEmpty) {
        setState(() => _isRecovering = false);
        return;
      }

      for (var set in items) {
        final colours = set['colours'] as List<dynamic>? ?? [];
        for (var col in colours) {
          if (col['gsm'] == null || col['dia'] == null) {
            // Find matching colour in balanced sets
            final match = balancedSets.firstWhere(
              (s) =>
                  _isSetMatch(s['set_no']?.toString() ?? '', set['set_no']?.toString() ?? '') &&
                  s['colour']?.toString().trim().toLowerCase() ==
                      col['colour']?.toString().trim().toLowerCase(),
              orElse: () => {},
            );

            if (match.isNotEmpty) {
              col['gsm'] = _parseDouble(match['gsm']);
              col['dia'] = _parseDouble(match['dia']);
              col['cutting_dia'] = _parseDouble(match['cutting_dia']);
            }
          }
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Metadata recovery failed: $e');
    } finally {
      if (mounted) setState(() => _isRecovering = false);
    }
  }

  bool _isSetMatch(String s1, String s2) {
    if (s1.trim() == s2.trim()) return true;
    String clean(String s) {
      return s.toLowerCase().replaceAll('set', '').replaceAll('s-', '').replaceAll('-', '').trim();
    }
    final c1 = clean(s1);
    final c2 = clean(s2);
    if (c1 == c2) return true;
    final int? n1 = int.tryParse(c1);
    final int? n2 = int.tryParse(c2);
    if (n1 != null && n2 != null) return n1 == n2;
    return false;
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val.trim()) ?? 0.0;
    return 0.0;
  }

  Future<void> _shareDetails(BuildContext context) async {
    try {
      final sb = StringBuffer();
      sb.writeln("*LOT OUTWARD DETAILS (DC)*");
      sb.writeln("");

      sb.writeln("DC No: ${_outward['dcNo'] ?? 'N/A'}");
      String formattedDate = 'N/A';
      if (_outward['dateTime'] != null) {
        try {
          formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.parse(_outward['dateTime']));
        } catch (e) {
          formattedDate = _outward['dateTime'].toString();
        }
      }
      sb.writeln("Date: $formattedDate");
      sb.writeln("Party: ${_outward['partyName'] ?? 'N/A'}");
      sb.writeln("Lot: ${_outward['lotName'] ?? 'N/A'} / ${_outward['lotNo'] ?? 'N/A'}");
      sb.writeln("DIA: ${_outward['dia'] ?? 'N/A'}");
      sb.writeln("");

      final items = _outward['items'] as List<dynamic>? ?? [];
      double grandTotalWeight = 0;
      int grandTotalRolls = 0;

      for (var set in items) {
        final setNo = set['set_no'] ?? 'N/A';
        final rack = set['rack_name'] ?? 'N/A';
        final pallet = set['pallet_number'] ?? 'N/A';
        final colours = set['colours'] as List<dynamic>? ?? [];

        sb.writeln("Set $setNo (Rack: $rack, Pallet: $pallet)");
        for (var col in colours) {
          final cName = col['colour'] ?? 'N/A';
          final cWt = (col['weight'] as num?)?.toDouble() ?? 0.0;
          final cR = (col['no_of_rolls'] as num?)?.toInt() ?? 0;
          
          final gsm = (col['gsm'] as num?)?.toDouble() ?? 0.0;
          final dia = (col['cutting_dia'] as num?)?.toDouble() ?? (col['dia'] as num?)?.toDouble() ?? 0.0;
          final meters = _calculateMeters(cWt, gsm, dia);

          if (meters > 0) {
            sb.writeln("  - $cName: $cWt Kg ($cR Rolls, ${meters.toStringAsFixed(1)} M)");
          } else {
            sb.writeln("  - $cName: $cWt Kg ($cR Rolls)");
          }
          grandTotalWeight += cWt;
          grandTotalRolls += cR;
        }
        sb.writeln("");
      }

      sb.writeln("");
      sb.writeln("-----------------------");
      sb.writeln("TOTAL SUMMARY");
      sb.writeln("Total Rolls: $grandTotalRolls");
      sb.writeln("Total Weight: ${FormatUtils.formatWeight(grandTotalWeight)} Kg");
      sb.writeln("-----------------------");
      sb.writeln("");

      sb.writeln("Signatures:");
      sb.writeln("Lot Incharge: ${_outward['lotInchargeSignature'] != null ? 'OK' : 'Missing'}");
      sb.writeln("Authorized: ${_outward['authorizedSignature'] != null ? 'OK' : 'Missing'}");

      final whatsappUrl = "whatsapp://send?text=${Uri.encodeComponent(sb.toString())}";
      final url = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        final webUrl = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(sb.toString())}");
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch WhatsApp.")));
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error sharing: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('OUTWARD ANALYSIS', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1, color: ColorPalette.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: ColorPalette.textPrimary, size: 20),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: ColorPalette.border.withOpacity(0.5), height: 1),
        ),
        actions: [
          if (_isRecovering)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                   width: 14,
                   height: 14,
                   child: CircularProgressIndicator(
                     color: ColorPalette.primary,
                     strokeWidth: 1.5,
                   ),
                ),
              ),
            ),
          IconButton(
            onPressed: () => OutwardPrintService().printOutwardReport(_outward),
            icon: const Icon(LucideIcons.printer, size: 16, color: ColorPalette.textMuted),
          ),
          IconButton(
            onPressed: () => _shareDetails(context),
            icon: const Icon(LucideIcons.share2, size: 16, color: ColorPalette.textMuted),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveWrapper(
        maxWidth: 1200,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('DISPATCH INFORMATION'),
              const SizedBox(height: 16),
              _buildFlatInfoGrid([
                {'label': 'DC NO', 'value': _outward['dcNo'] ?? 'N/A'},
                {'label': 'LOT NAME', 'value': _outward['lotName'] ?? 'N/A'},
                {'label': 'LOT NO', 'value': _outward['lotNo'] ?? 'N/A'},
                {'label': 'DIA', 'value': _outward['dia']?.toString() ?? 'N/A'},
                if (_outward['dateTime'] != null)
                  {'label': 'DATE', 'value': DateFormat('dd-MM-yyyy').format(DateTime.parse(_outward['dateTime']))},
                {'label': 'IN TIME', 'value': _outward['inTime'] ?? 'N/A'},
                {'label': 'OUT TIME', 'value': _outward['outTime'] ?? 'N/A'},
                {'label': 'VEHICLE', 'value': _outward['vehicleNo'] ?? 'N/A'},
              ]),
              const SizedBox(height: 32),
              _buildSectionHeader('PARTY DETAILS'),
              const SizedBox(height: 16),
              _buildFlatInfoGrid([
                {'label': 'PARTY NAME', 'value': _outward['partyName'] ?? 'N/A'},
                {'label': 'PROCESS', 'value': _outward['process'] ?? 'N/A'},
                {'label': 'ADDRESS', 'value': _outward['address'] ?? 'N/A'},
              ]),
              const SizedBox(height: 32),
              _buildSectionHeader('DISPATCHED ITEMS'),
              const SizedBox(height: 16),
              _buildItemsTable(),
              const SizedBox(height: 48),
              _buildSectionHeader('VALIDATION SIGNATURES'),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildFlatSignatureItem('LOT INCHARGE', _outward['lotInchargeSignature']),
                  const SizedBox(width: 48),
                  _buildFlatSignatureItem('AUTHORIZED SIGNATORY', _outward['authorizedSignature']),
                ],
              ),
              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: ColorPalette.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 2,
          width: 32,
          decoration: BoxDecoration(
            color: ColorPalette.primary,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  Widget _buildFlatInfoGrid(List<Map<String, String>> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorPalette.border.withOpacity(0.5)),
      ),
      child: Wrap(
        spacing: 48,
        runSpacing: 24,
        children: items.map((item) => SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['label']!.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: ColorPalette.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item['value']!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ColorPalette.textPrimary,
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildItemsTable() {
    final items = _outward['items'] as List<dynamic>? ?? [];
    double totalWeight = 0;
    int grandTotalRolls = 0;
    for (var item in items) {
      totalWeight += (item['total_weight'] as num?)?.toDouble() ?? 0;
      if (item['colours'] != null) {
        for (var col in item['colours']) {
          grandTotalRolls += (col['no_of_rolls'] as num?)?.toInt() ?? 0;
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorPalette.border.withOpacity(0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                _buildTableHeader('SET NO', flex: 1),
                _buildTableHeader('RACK / PALLET', flex: 2),
                _buildTableHeader('COLOURS & DETAILS', flex: 5),
                _buildTableHeader('WEIGHT (KG)', flex: 2, align: TextAlign.right),
                _buildTableHeader('ROLLS', flex: 1, align: TextAlign.right),
              ],
            ),
          ),
          ...items.map((item) => _buildItemRow(item)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: ColorPalette.border.withOpacity(0.5))),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 8,
                  child: Text(
                    'GRAND TOTAL DISPATCHED',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: ColorPalette.textPrimary, letterSpacing: 1),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    FormatUtils.formatWeight(totalWeight),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: ColorPalette.primary),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    grandTotalRolls.toString(),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: ColorPalette.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String label, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final colours = item['colours'] as List<dynamic>? ?? [];
    int itemTotalRolls = 0;
    for (var col in colours) {
      itemTotalRolls += (col['no_of_rolls'] as num?)?.toInt() ?? 0;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ColorPalette.border.withOpacity(0.3))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              item['set_no']?.toString() ?? 'N/A',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: ColorPalette.textPrimary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${item['rack_name'] ?? 'N/A'} / ${item['pallet_number'] ?? 'N/A'}',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: ColorPalette.textMuted),
            ),
          ),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: colours.map((col) {
                final cWt = (col['weight'] as num?)?.toDouble() ?? 0.0;
                final gsm = (col['gsm'] as num?)?.toDouble() ?? 0.0;
                final dia = (col['cutting_dia'] as num?)?.toDouble() ?? (col['dia'] as num?)?.toDouble() ?? 0.0;
                final meters = _calculateMeters(cWt, gsm, dia);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        col['colour']?.toString() ?? 'N/A',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ColorPalette.textPrimary),
                      ),
                      if (meters > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${meters.toStringAsFixed(1)} M)',
                          style: GoogleFonts.inter(fontSize: 11, color: ColorPalette.textMuted),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              FormatUtils.formatWeight(item['total_weight']),
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: ColorPalette.textPrimary),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              itemTotalRolls.toString(),
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ColorPalette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatSignatureItem(String label, String? imagePath) {
    final bool hasImage = imagePath != null && imagePath.toString().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.8),
        ),
        const SizedBox(height: 12),
        Container(
          height: 80,
          width: 160,
          decoration: BoxDecoration(
            color: const Color(0xFFFDFDFD),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: ColorPalette.border.withOpacity(0.5)),
          ),
          child: hasImage
              ? Image.network(
                  ApiConstants.getImageUrl(imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => const Icon(LucideIcons.image, size: 20, color: ColorPalette.border),
                )
              : Center(
                  child: Text(
                    "PENDING",
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.border),
                  ),
                ),
        ),
      ],
    );
  }

  double _calculateMeters(double weight, double gsm, double dia) {
    if (weight <= 0 || gsm <= 0 || dia <= 0) return 0.0;
    try {
      return (weight * 1000.0) / (gsm * (dia * 2.0 / 39.37));
    } catch (e) {
      return 0.0;
    }
  }
}
