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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPalette.background,
      appBar: AppBar(
        title: Text('OUTWARD ANALYSIS', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1)),
        backgroundColor: Colors.white,
        foregroundColor: ColorPalette.textPrimary,
        actions: [
          if (_isRecovering)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                   width: 16,
                   height: 16,
                   child: CircularProgressIndicator(
                     color: ColorPalette.primary,
                     strokeWidth: 2,
                   ),
                ),
              ),
            ),
          IconButton(
            onPressed: () => OutwardPrintService().printOutwardReport(_outward),
            icon: Icon(LucideIcons.printer, size: 18),
          ),
          IconButton(
            onPressed: () => _shareDetails(context),
            icon: Icon(LucideIcons.share2, size: 18),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveWrapper(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 16),
              _buildPartyCard(),
              const SizedBox(height: 16),
              _buildItemsCard(),
              const SizedBox(height: 16),
              _buildSignaturesCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
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
          formattedDate = DateFormat(
            'dd-MM-yyyy',
          ).format(DateTime.parse(_outward['dateTime']));
        } catch (e) {
          formattedDate = _outward['dateTime'].toString();
        }
      }
      sb.writeln("Date: $formattedDate");
      sb.writeln("Party: ${_outward['partyName'] ?? 'N/A'}");
      sb.writeln(
        "Lot: ${_outward['lotName'] ?? 'N/A'} / ${_outward['lotNo'] ?? 'N/A'}",
      );
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
      sb.writeln(
        "Total Weight: ${FormatUtils.formatWeight(grandTotalWeight)} Kg",
      );
      sb.writeln("-----------------------");
      sb.writeln("");

      sb.writeln("Signatures:");
      sb.writeln(
        "Lot Incharge: ${_outward['lotInchargeSignature'] != null ? 'OK' : 'Missing'}",
      );
      sb.writeln(
        "Authorized: ${_outward['authorizedSignature'] != null ? 'OK' : 'Missing'}",
      );

      final whatsappUrl =
          "whatsapp://send?text=${Uri.encodeComponent(sb.toString())}";
      final url = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        final webUrl = Uri.parse(
          "https://wa.me/?text=${Uri.encodeComponent(sb.toString())}",
        );
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Could not launch WhatsApp.")),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error sharing: $e")));
      }
    }
  }

  Future<void> _printReport(BuildContext context) async {
    try {
      final service = OutwardPrintService();
      await service.printOutwardReport(_outward);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error printing: $e')));
      }
    }
  }

  Widget _buildSignaturesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Signatures (E-Signature)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSignatureItem(
                  'Lot Incharge',
                  _outward['lotInchargeSignature'],
                ),
                _buildSignatureItem(
                  'Authorized',
                  _outward['authorizedSignature'],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureItem(String label, String? imagePath) {
    final bool hasImage = imagePath != null && imagePath.toString().isNotEmpty;
    return Column(
      children: [
        Container(
          height: 60,
          width: 90,
          decoration: BoxDecoration(
            color: hasImage ? Colors.transparent : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasImage ? Colors.grey.shade200 : Colors.grey.shade100,
            ),
          ),
          child: hasImage
              ? Image.network(
                  ApiConstants.getImageUrl(imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => const Icon(
                    Icons.broken_image,
                    size: 20,
                    color: Colors.grey,
                  ),
                )
              : const Center(
                  child: Text(
                    "Missing",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dispatch Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow('DC No', _outward['dcNo'] ?? 'N/A'),
            _buildInfoRow('Lot Name', _outward['lotName'] ?? 'N/A'),
            _buildInfoRow('Lot No', _outward['lotNo'] ?? 'N/A'),
            _buildInfoRow('DIA', _outward['dia'] ?? 'N/A'),
            if (_outward['dateTime'] != null)
              _buildInfoRow(
                'Date',
                DateFormat(
                  'dd-MM-yyyy',
                ).format(DateTime.parse(_outward['dateTime'])),
              ),
            _buildInfoRow('In Time', _outward['inTime'] ?? 'N/A'),
            _buildInfoRow('Out Time', _outward['outTime'] ?? 'N/A'),
            _buildInfoRow('Vehicle No', _outward['vehicleNo'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Party Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow('Party Name', _outward['partyName'] ?? 'N/A'),
            _buildInfoRow('Process', _outward['process'] ?? 'N/A'),
            _buildInfoRow('Address', _outward['address'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
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

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dispatched Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Total: ${FormatUtils.formatWeight(totalWeight)} Kg | $grandTotalRolls Rolls',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            if (items.isEmpty)
              const Text('No items found')
            else
              ...items.map((item) => _buildItemRow(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    int itemTotalRolls = 0;
    if (item['colours'] != null) {
      for (var col in item['colours']) {
        itemTotalRolls += (col['no_of_rolls'] as num?)?.toInt() ?? 0;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Set No: ${item['set_no'] ?? 'N/A'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '${FormatUtils.formatWeight(item['total_weight'])} Kg | $itemTotalRolls Rolls',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'RACK: ${item['rack_name'] ?? 'Not Assigned'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'PALLET: ${item['pallet_number'] ?? 'Not Assigned'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (item['colours'] != null && (item['colours'] as List).isNotEmpty)
            Column(
              children: (item['colours'] as List).map((col) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSmallInfo(
                          'Colour',
                          col['colour'] ?? 'N/A',
                        ),
                      ),
                      Expanded(
                        child: _buildSmallInfo(
                          'Weight',
                          '${FormatUtils.formatWeight(col['weight'])} Kg',
                        ),
                      ),
                      Expanded(
                        child: _buildSmallInfo(
                          'Rolls',
                          '${col['no_of_rolls'] ?? 0}',
                        ),
                      ),
                      Expanded(
                        child: _buildSmallInfo(
                          'Meter',
                          () {
                            final gsm = (col['gsm'] as num?)?.toDouble() ?? 0.0;
                            final dia = (col['cutting_dia'] as num?)?.toDouble() ?? 
                                        (col['dia'] as num?)?.toDouble() ?? 0.0;
                            final m = _calculateMeters((col['weight'] as num?)?.toDouble() ?? 0.0, gsm, dia);
                            return m > 0 ? m.toStringAsFixed(1) : '-';
                          }(),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _buildSmallInfo('Colour', item['colour'] ?? 'N/A'),
                ),
                Expanded(
                  child: _buildSmallInfo(
                    'Balance',
                    '${FormatUtils.formatWeight(item['balance_weight'])} Kg',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
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
