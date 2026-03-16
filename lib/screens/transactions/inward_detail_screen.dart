import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../services/mobile_api_service.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inward Details'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editInward(context),
            tooltip: 'Edit Inward',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteInward(context),
            tooltip: 'Delete Inward',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printReport(context),
            tooltip: 'Print Report',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareDetails(context),
            tooltip: 'Share Details',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeaderCard(),
                const SizedBox(height: 16),
                _buildPartyCard(),
                const SizedBox(height: 16),
                _buildQualityCard(),
                const SizedBox(height: 16),
                _buildCheckCard(
                  title: 'GSM Check',
                  statusField: 'gsmStatus',
                  imageField: 'gsmImage',
                ),
                const SizedBox(height: 16),
                _buildCheckCard(
                  title: 'Shade Matching',
                  statusField: 'shadeStatus',
                  imageField: 'shadeImage',
                ),
                const SizedBox(height: 16),
                _buildCheckCard(
                  title: 'Washing Check',
                  statusField: 'washingStatus',
                  imageField: 'washingImage',
                ),
                const SizedBox(height: 16),
                if (inward['complaintText'] != null &&
                    inward['complaintText'].toString().isNotEmpty)
                  _buildComplaintCard(),
                const SizedBox(height: 16),
                _buildDiaEntriesCard(),
                const SizedBox(height: 16),
                _buildSignaturesCard(),
                const SizedBox(height: 16),
                _buildStickerHeader(context, stickers),
              ]),
            ),
          ),
          if (_showStickers && stickers.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _buildStickerItem(context, stickers[index]),
                  childCount: stickers.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Future<void> _shareDetails(BuildContext context) async {
    try {
      final service = InwardPrintService();
      final pdfBytes = await service.generatePdfBytes(inward);

      final filename = 'Lot_Inward_${inward['lotNo'] ?? 'Details'}.pdf';

      await Share.shareXFiles(
        [XFile.fromData(pdfBytes, mimeType: 'application/pdf', name: filename)],
        text: 'Inward Details - Lot ${inward['lotNo'] ?? ''}',
        subject: 'Lot Inward PDF',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error preparing sharing details: $e")),
        );
      }
    }
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
              'Lot Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow('Inward No', inward['inwardNo'] ?? 'N/A'),
            _buildInfoRow('Lot Name', inward['lotName'] ?? 'N/A'),
            _buildInfoRow('Lot No', inward['lotNo'] ?? 'N/A'),
            _buildInfoRow('Inward Date', () {
              try {
                return DateFormat(
                  'dd-MM-yyyy',
                ).format(DateTime.parse(inward['inwardDate']));
              } catch (e) {
                return inward['inwardDate'] ?? 'N/A';
              }
            }()),
            _buildInfoRow('In Time', inward['inTime'] ?? 'N/A'),
            _buildInfoRow('Out Time', inward['outTime'] ?? 'N/A'),
            _buildInfoRow('Vehicle No', inward['vehicleNo'] ?? 'N/A'),
            _buildInfoRow('Party DC No', inward['partyDcNo'] ?? 'N/A'),
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
            _buildInfoRow('From Party', inward['fromParty'] ?? 'N/A'),
            _buildInfoRow('Process', inward['process'] ?? 'N/A'),
            _buildInfoRow('Rate', '${inward['rate'] ?? 0}'),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckCard({
    required String title,
    required String statusField,
    required String imageField,
  }) {
    final status = inward[statusField] ?? 'OK';
    final image = inward[imageField];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow('Status', status),
            if (image != null) ...[
              const SizedBox(height: 8),
              Text(
                '$title Image:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  ApiConstants.getImageUrl(image),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(
                    height: 100,
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQualityCard() {
    return _buildCheckCard(
      title: 'Quality Check',
      statusField: 'qualityStatus',
      imageField: 'qualityImage',
    );
  }

  Widget _buildComplaintCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Complaint',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const Divider(),
            _buildInfoRow('Remarks', inward['complaintText'] ?? ''),
            if (inward['complaintImage'] != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Complaint Image:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  ApiConstants.getImageUrl(inward['complaintImage']),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiaEntriesCard() {
    final entries = inward['diaEntries'] as List<dynamic>? ?? [];
    final storageDetails =
        inward['storageDetails'] as List<dynamic>? ?? const [];
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DIA Entries',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (entries.isEmpty)
              const Text('No DIA entries found')
            else
              ...entries.map((entry) {
                final dia = (entry as Map<String, dynamic>)['dia']?.toString();
                Map<String, dynamic>? storageForDia;
                if (dia != null && dia.isNotEmpty) {
                  for (final s in storageDetails) {
                    final sMap = s as Map<String, dynamic>;
                    if (sMap['dia']?.toString() == dia) {
                      storageForDia = sMap;
                      break;
                    }
                  }
                }
                return _buildDiaEntryRow(entry, storageForDia);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaEntryRow(
    Map<String, dynamic> entry,
    Map<String, dynamic>? storage,
  ) {
    final rate = double.tryParse(entry['rate']?.toString() ?? '0') ?? 0;
    final recWt = double.tryParse(entry['recWt']?.toString() ?? '0') ?? 0;
    final value = rate * recWt;

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
                'DIA: ${entry['dia'] ?? 'N/A'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rate: ${entry['rate'] ?? 0}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Val: ${FormatUtils.formatCurrency(value)}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSmallInfo('Rolls', '${entry['roll'] ?? 0}'),
              ),
              Expanded(child: _buildSmallInfo('Sets', '${entry['sets'] ?? 0}')),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildSmallInfo(
                  'Del. Wt',
                  '${FormatUtils.formatWeight(entry['delivWt'])} Kg', // Corrected key
                ),
              ),
              Expanded(
                child: _buildSmallInfo(
                  'Rec. Wt',
                  '${FormatUtils.formatWeight(entry['recWt'])} Kg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildSmallInfo(
                  'Rec. Rolls',
                  '${entry['recRoll'] ?? 0}',
                ),
              ),
            ],
          ),
          if (storage != null) ...[
            const SizedBox(height: 8),
            const Divider(),
            const Text(
              'Storage Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Builder(
              builder: (_) {
                final racks = (storage['racks'] as List<dynamic>? ?? [])
                    .where((r) => r != null && r.toString().trim().isNotEmpty)
                    .map((r) => r.toString())
                    .toList();
                final pallets = (storage['pallets'] as List<dynamic>? ?? [])
                    .where((p) => p != null && p.toString().trim().isNotEmpty)
                    .map((p) => p.toString())
                    .toList();
                final rows = storage['rows'] as List<dynamic>? ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (racks.isNotEmpty)
                      _buildSmallInfo('Racks', racks.join(', ')),
                    if (pallets.isNotEmpty)
                      _buildSmallInfo('Pallets', pallets.join(', ')),
                    if (rows.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Sticker Sets',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      ...rows.map((r) {
                        final rMap = r as Map<String, dynamic>;
                        final colour = rMap['colour']?.toString() ?? '-';
                        final stickerRollNo = rMap['rollNo']?.toString() ?? '';
                        final weights =
                            (rMap['setWeights'] as List<dynamic>? ?? [])
                                .where(
                                  (w) =>
                                      w != null &&
                                      w.toString().trim().isNotEmpty,
                                )
                                .map((w) => w.toString())
                                .toList();
                        final weightsText = weights.isEmpty
                            ? '-'
                            : weights.join(', ');
                        final totalWt = rMap['totalWeight']?.toString() ?? '-';
                        final displayLabel = stickerRollNo.isNotEmpty 
                            ? 'Roll $stickerRollNo - $colour ($totalWt)'
                            : 'Colour $colour ($totalWt)';
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _buildSmallInfo(
                            displayLabel,
                            weightsText,
                          ),
                        );
                      }),
                    ],
                  ],
                );
              },
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSignatureItem(
                  'Lot Incharge',
                  inward['lotInchargeSignature'],
                ),
                _buildSignatureItem(
                  'Authorized',
                  inward['authorizedSignature'],
                ),
                _buildSignatureItem('MD', inward['mdSignature']),
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

  Future<void> _printReport(BuildContext context) async {
    try {
      final service = InwardPrintService();
      await service.printInwardReport(inward);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating report: $e')));
      }
    }
  }

  void _editInward(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LotInwardScreen(editInward: inward),
      ),
    );
  }

  Future<void> _deleteInward(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Inward'),
        content: const Text('Are you sure you want to delete this inward?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final api = MobileApiService();
        final success = await api.deleteInward(inward['_id']);
        if (context.mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Inward deleted successfully')),
            );
            Navigator.pop(context, true); // Return true to indicate deletion
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete inward')),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting inward: $e')));
        }
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
            if (weight.trim().isNotEmpty) {
              final setNo =
                  i < setLabels.length &&
                      (setLabels[i]?.toString().trim().isNotEmpty ?? false)
                  ? setLabels[i].toString().trim()
                  : (i + 1).toString();
              stickers.add({
                'lotNo': inward['lotNo']?.toString() ?? '',
                'lotName': inward['lotName']?.toString() ?? '',
                'dia': dia,
                'colour': colour,
                'weight': weight,
                'date': () {
                  try {
                    return DateFormat('dd-MM-yyyy').format(
                      DateTime.parse(
                        inward['inwardDate'] ?? DateTime.now().toString(),
                      ),
                    );
                  } catch (e) {
                    return inward['inwardDate'] ?? '';
                  }
                }(),
                'setNo': setNo,
              });
            }
          }
        }
      }
    }
    return stickers;
  }

  Widget _buildStickerHeader(
    BuildContext context,
    List<Map<String, dynamic>> stickers,
  ) {
    if (stickers.isEmpty) return const SizedBox.shrink();

    if (!_showStickers) {
      return Card(
        child: InkWell(
          onTap: () => setState(() => _showStickers = true),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sticker Previews',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${stickers.length} stickers available',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sticker Previews',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.visibility_off, size: 16),
                  label: const Text('Hide'),
                  onPressed: () => setState(() => _showStickers = false),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: const Text(
                      'Show QR Codes',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Turn on to see scannable tags',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _showAllQRs,
                    dense: true,
                    onChanged: (val) => setState(() => _showAllQRs = val),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print, color: Colors.blue),
                      tooltip: 'Print All Stickers',
                      onPressed: () => _printStickersAsPdf(context, stickers),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.blue),
                      tooltip: 'Share All Stickers',
                      onPressed: () => _shareStickersAsPdf(context, stickers),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerItem(BuildContext context, Map<String, dynamic> item) {
    final rawWt = item['weight']?.toString() ?? '0';
    final weightDouble = double.tryParse(rawWt) ?? 0.0;
    final displayWeight = weightDouble.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2),
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStickerRow('LOT NO', item['lotNo']),
              _buildStickerRow('Lot Name', item['lotName']),
              _buildStickerRow('Dia', item['dia']),
              _buildStickerRow('Colour', item['colour']),
              _buildStickerRow('Set No', item['setNo'].toString()),
              _buildStickerRow('Roll Wt', '$displayWeight kg'),
              _buildStickerRow('Date', item['date']),
              const SizedBox(height: 12),
              if (_showAllQRs)
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black),
                        ),
                        child: QrImageView(
                          data:
                              'LOT: ${item['lotNo']}\nNAME: ${item['lotName']}\nDIA: ${item['dia']}\nCOL: ${item['colour']}\nSET: ${item['setNo']}\nWT: ${displayWeight}kg\nDT: ${item['date']}',
                          version: QrVersions.auto,
                          size: 100.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'SCAN FOR AUTH',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code, color: Colors.grey, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'QR Code Hidden',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.print, color: Colors.blue),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Print Sticker',
                  onPressed: () {
                    _printStickersAsPdf(context, [item]);
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.blue),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Share Sticker PDF',
                  onPressed: () {
                    _shareStickersAsPdf(context, [item]);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100, // Increased width for bold label
            child: Text(
              '$label :',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ), // Increased from 14
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ), // Made bold and increased from 14
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfRow(
    String label,
    String value, {
    double fontSize = 9,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.1),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 45, // Increased width for bold label
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: fontSize,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSingleSticker(Map<String, dynamic> item) {
    final rawWt = item['weight']?.toString() ?? '0';
    final weightDouble = double.tryParse(rawWt) ?? 0.0;
    final displayWeight = weightDouble.toStringAsFixed(2);

    final qrData =
        'LOT: ${item['lotNo']}\nNAME: ${item['lotName']}\nDIA: ${item['dia']}\nCOL: ${item['colour']}\nSET: ${item['setNo']}\nWT: ${displayWeight}kg\nDT: ${item['date']}';

    return pw.Container(
      width: double.infinity,
      height: double.infinity,
      padding: const pw.EdgeInsets.all(1),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Text fields at top with smaller font size 9
          _buildPdfRow('LOT', item['lotNo']?.toString() ?? '', fontSize: 9),
          _buildPdfRow('Name', item['lotName']?.toString() ?? '', fontSize: 9),
          _buildPdfRow('Dia', item['dia']?.toString() ?? '', fontSize: 9),
          _buildPdfRow('Col', item['colour']?.toString() ?? '', fontSize: 9),
          _buildPdfRow('Set', item['setNo']?.toString() ?? '', fontSize: 9),
          _buildPdfRow('Wt', '$displayWeight kg', fontSize: 9),
          _buildPdfRow('Dt', item['date']?.toString() ?? '', fontSize: 9),

          pw.SizedBox(height: 2),

          // QR code at bottom centre
          pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(
                  width: 32,
                  height: 32,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                  ),
                ),
                pw.SizedBox(height: 0.5),
                pw.Text(
                  'SCAN FOR AUTH',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Document _generateStickersPdf(List<Map<String, dynamic>> stickerList) {
    final pdf = pw.Document();

    for (int i = 0; i < stickerList.length; i += 2) {
      final item1 = stickerList[i];
      final item2 = (i + 1 < stickerList.length) ? stickerList[i + 1] : null;

      final isSingle = item2 == null;
      final pageFormat = isSingle
          ? PdfPageFormat(50 * PdfPageFormat.mm, 50 * PdfPageFormat.mm)
          : PdfPageFormat(100 * PdfPageFormat.mm, 50 * PdfPageFormat.mm);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(2),
          build: (pw.Context context) {
            if (isSingle) {
              return _buildSingleSticker(item1);
            } else {
              return pw.Row(
                children: [
                  pw.Expanded(child: _buildSingleSticker(item1)),
                  pw.SizedBox(width: 2),
                  pw.Expanded(child: _buildSingleSticker(item2)),
                ],
              );
            }
          },
        ),
      );
    }
    return pdf;
  }

  Future<void> _shareStickersAsPdf(
    BuildContext context,
    List<Map<String, dynamic>> stickerList,
  ) async {
    try {
      final pdf = _generateStickersPdf(stickerList);

      final pdfBytes = await pdf.save();

      final filename = 'Stickers_${inward['lotNo'] ?? 'Details'}.pdf';

      await Share.shareXFiles(
        [XFile.fromData(pdfBytes, mimeType: 'application/pdf', name: filename)],
        text: 'Stickers - Lot ${inward['lotNo'] ?? ''}',
        subject: 'Sticker Labels PDF',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error preparing sticker PDF: $e")),
        );
      }
    }
  }

  Future<void> _printStickersAsPdf(
    BuildContext context,
    List<Map<String, dynamic>> stickerList,
  ) async {
    try {
      final pdf = _generateStickersPdf(stickerList);

      final pageFormat = stickerList.length == 1
          ? PdfPageFormat(50 * PdfPageFormat.mm, 50 * PdfPageFormat.mm)
          : PdfPageFormat(100 * PdfPageFormat.mm, 50 * PdfPageFormat.mm);

      await Printing.layoutPdf(
        format: pageFormat,
        onLayout: (PdfPageFormat defaultFormat) async => pdf.save(),
        name: 'Stickers_${inward['lotNo'] ?? 'Details'}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error printing stickers: $e")));
      }
    }
  }
}
