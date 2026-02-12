import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
            _buildInfoRow(
              'Inward Date',
              DateFormat(
                'dd-MM-yyyy',
              ).format(DateTime.parse(inward['inwardDate'])),
            ),
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
                  '${ApiConstants.serverUrl}$image',
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
                  '${ApiConstants.serverUrl}${inward['complaintImage']}',
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
              Text(
                'Rate: ${entry['rate'] ?? 0}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
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
                  '${entry['delivWt'] ?? 0} Kg',
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
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _buildSmallInfo('Colour $colour', weightsText),
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
    final hasIncharge =
        inward['lotInchargeSignature'] != null &&
        inward['lotInchargeSignature'].toString().isNotEmpty;
    final hasAuthorized =
        inward['authorizedSignature'] != null &&
        inward['authorizedSignature'].toString().isNotEmpty;
    final hasMd =
        inward['mdSignature'] != null &&
        inward['mdSignature'].toString().isNotEmpty;

    if (!hasIncharge && !hasAuthorized && !hasMd)
      return const SizedBox.shrink();

    return Card(
      elevation: 2,
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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (hasIncharge)
                  _buildSignatureItem(
                    'Lot Incharge',
                    inward['lotInchargeSignature'],
                  ),
                if (hasAuthorized)
                  _buildSignatureItem(
                    'Authorized',
                    inward['authorizedSignature'],
                  ),
                if (hasMd) _buildSignatureItem('MD', inward['mdSignature']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureItem(String label, String? imagePath) {
    return Column(
      children: [
        if (imagePath != null)
          Container(
            height: 60,
            width: 100,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Image.network(
              '${ApiConstants.serverUrl}$imagePath',
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) =>
                  const Icon(Icons.broken_image, size: 20, color: Colors.grey),
            ),
          )
        else
          const SizedBox(height: 60, width: 100),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
