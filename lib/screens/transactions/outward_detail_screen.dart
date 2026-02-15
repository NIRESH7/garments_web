import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/outward_print_service.dart';
import '../../core/constants/api_constants.dart';

class OutwardDetailScreen extends StatelessWidget {
  final Map<String, dynamic> outward;

  const OutwardDetailScreen({super.key, required this.outward});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outward Details'),
        backgroundColor: Colors.orange,
        actions: [
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
    );
  }

  String _getImageUrl(dynamic path) {
    if (path == null || path.toString().isEmpty) return '';
    String imageUrl = path.toString();
    if (imageUrl.startsWith('http')) return imageUrl;
    imageUrl = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
    return '${ApiConstants.serverUrl}/$imageUrl';
  }

  Future<void> _shareDetails(BuildContext context) async {
    try {
      final sb = StringBuffer();
      sb.writeln("*LOT OUTWARD DETAILS (DC)*");
      sb.writeln("");

      sb.writeln("DC No: ${outward['dcNo'] ?? 'N/A'}");
      String formattedDate = 'N/A';
      if (outward['dateTime'] != null) {
        try {
          formattedDate = DateFormat(
            'dd-MM-yyyy',
          ).format(DateTime.parse(outward['dateTime']));
        } catch (e) {
          formattedDate = outward['dateTime'].toString();
        }
      }
      sb.writeln("Date: $formattedDate");
      sb.writeln("Party: ${outward['partyName'] ?? 'N/A'}");
      sb.writeln(
        "Lot: ${outward['lotName'] ?? 'N/A'} / ${outward['lotNo'] ?? 'N/A'}",
      );
      sb.writeln("DIA: ${outward['dia'] ?? 'N/A'}");
      sb.writeln("");

      final items = outward['items'] as List<dynamic>? ?? [];
      double grandTotalWeight = 0;
      int grandTotalRolls = 0;

      for (var set in items) {
        final setNo = set['set_no'] ?? 'N/A';
        final colours = set['colours'] as List<dynamic>? ?? [];
        for (var col in colours) {
          final cName = col['colour'] ?? 'N/A';
          final cWt = (col['weight'] as num?)?.toDouble() ?? 0.0;
          final cR = (col['no_of_rolls'] as num?)?.toInt() ?? 0;

          sb.writeln("Set $setNo - $cName: $cWt Kg ($cR Rolls)");
          grandTotalWeight += cWt;
          grandTotalRolls += cR;
        }
      }

      sb.writeln("");
      sb.writeln("-----------------------");
      sb.writeln("TOTAL SUMMARY");
      sb.writeln("Total Rolls: $grandTotalRolls");
      sb.writeln("Total Weight: ${grandTotalWeight.toStringAsFixed(2)} Kg");
      sb.writeln("-----------------------");
      sb.writeln("");

      sb.writeln("Signatures:");
      sb.writeln(
        "Lot Incharge: ${outward['lotInchargeSignature'] != null ? 'OK' : 'Missing'}",
      );
      sb.writeln(
        "Authorized: ${outward['authorizedSignature'] != null ? 'OK' : 'Missing'}",
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
      await service.printOutwardReport(outward);
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
                  outward['lotInchargeSignature'],
                ),
                _buildSignatureItem(
                  'Authorized',
                  outward['authorizedSignature'],
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
                  _getImageUrl(imagePath),
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
            _buildInfoRow('DC No', outward['dcNo'] ?? 'N/A'),
            _buildInfoRow('Lot Name', outward['lotName'] ?? 'N/A'),
            _buildInfoRow('Lot No', outward['lotNo'] ?? 'N/A'),
            _buildInfoRow('DIA', outward['dia'] ?? 'N/A'),
            if (outward['dateTime'] != null)
              _buildInfoRow(
                'Date',
                DateFormat(
                  'dd-MM-yyyy',
                ).format(DateTime.parse(outward['dateTime'])),
              ),
            _buildInfoRow('In Time', outward['inTime'] ?? 'N/A'),
            _buildInfoRow('Out Time', outward['outTime'] ?? 'N/A'),
            _buildInfoRow('Vehicle No', outward['vehicleNo'] ?? 'N/A'),
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
            _buildInfoRow('Party Name', outward['partyName'] ?? 'N/A'),
            _buildInfoRow('Process', outward['process'] ?? 'N/A'),
            _buildInfoRow('Address', outward['address'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    final items = outward['items'] as List<dynamic>? ?? [];

    double totalWeight = 0;
    for (var item in items) {
      totalWeight += (item['total_weight'] as num?)?.toDouble() ?? 0;
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
                    'Total: ${totalWeight.toStringAsFixed(2)} Kg',
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
                '${item['total_weight'] ?? 0} Kg',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
                          '${col['weight'] ?? 0} Kg',
                        ),
                      ),
                      Expanded(
                        child: _buildSmallInfo(
                          'Rolls',
                          '${col['no_of_rolls'] ?? 0}',
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
                    '${item['balance_weight'] ?? 0} Kg',
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
}
