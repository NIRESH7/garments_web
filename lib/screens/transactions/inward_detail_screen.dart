import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_constants.dart';

class InwardDetailScreen extends StatelessWidget {
  final Map<String, dynamic> inward;

  const InwardDetailScreen({super.key, required this.inward});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inward Details'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareDetails(context),
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

    // Remove any redundant leading slashes to avoid // in URL
    imageUrl = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;

    return '${ApiConstants.serverUrl}/$imageUrl';
  }

  Future<void> _shareDetails(BuildContext context) async {
    try {
      final sb = StringBuffer();
      sb.writeln("*Inward Details*");
      sb.writeln("Inward No: ${inward['inwardNo'] ?? 'N/A'}");

      String formattedDate = 'N/A';
      if (inward['inwardDate'] != null) {
        try {
          formattedDate = DateFormat(
            'dd-MM-yyyy',
          ).format(DateTime.parse(inward['inwardDate']));
        } catch (e) {
          formattedDate = inward['inwardDate'].toString();
        }
      }
      sb.writeln("Date: $formattedDate");
      sb.writeln("Party: ${inward['fromParty'] ?? 'N/A'}");
      sb.writeln(
        "Lot: ${inward['lotName'] ?? 'N/A'} / ${inward['lotNo'] ?? 'N/A'}",
      );
      sb.writeln("--------------------------------");

      final entries = inward['diaEntries'] as List<dynamic>? ?? [];
      final storageDetails = inward['storageDetails'] as List<dynamic>? ?? [];

      for (var entry in entries) {
        if (entry == null) continue;
        final e = entry as Map<String, dynamic>;
        final dia = e['dia']?.toString();
        final rate = double.tryParse(e['rate']?.toString() ?? '0') ?? 0;
        final recWt = double.tryParse(e['recWt']?.toString() ?? '0') ?? 0;
        final value = rate * recWt;

        if (dia != null) sb.writeln("DIA: $dia");
        sb.writeln(
          "Rolls: ${e['recRoll'] ?? 0} | Wt: ${recWt.toStringAsFixed(2)} Kg",
        );
        sb.writeln("Rate: $rate | Value: ${value.toStringAsFixed(2)}");

        // Add Storage for this DIA
        if (dia != null && dia.isNotEmpty) {
          final storage = storageDetails.firstWhere(
            (s) => s != null && s['dia']?.toString() == dia,
            orElse: () => null,
          );
          if (storage != null) {
            final racks = (storage['racks'] as List<dynamic>? ?? [])
                .where((r) => r != null && r.toString().isNotEmpty)
                .join(', ');
            final pallets = (storage['pallets'] as List<dynamic>? ?? [])
                .where((p) => p != null && p.toString().isNotEmpty)
                .join(', ');
            if (racks.isNotEmpty) sb.writeln("Racks: $racks");
            if (pallets.isNotEmpty) sb.writeln("Pallets: $pallets");

            final rows = storage['rows'] as List<dynamic>? ?? [];
            for (var row in rows) {
              if (row == null) continue;
              final col = row['colour'] ?? '-';
              final tot = row['totalWeight'] ?? '-';
              sb.writeln(" - $col: $tot Kg");
            }
          }
        }
        sb.writeln("");
      }

      final whatsappUrl =
          "whatsapp://send?text=${Uri.encodeComponent(sb.toString())}";
      final url = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for some devices or if the deep link fails
        final webUrl = Uri.parse(
          "https://wa.me/?text=${Uri.encodeComponent(sb.toString())}",
        );
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Could not launch WhatsApp. Please ensure it is installed.",
                ),
              ),
            );
          }
        }
      }
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
                  _getImageUrl(image),
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
                  _getImageUrl(inward['complaintImage']),
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
                    'Val: ${value.toStringAsFixed(2)}',
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
                  '${entry['delWt'] ?? 0} Kg', // Corrected key
                ),
              ),
              Expanded(
                child: _buildSmallInfo('Rec. Wt', '${entry['recWt'] ?? 0} Kg'),
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
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _buildSmallInfo(
                            'Colour $colour ($totalWt)',
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
}
