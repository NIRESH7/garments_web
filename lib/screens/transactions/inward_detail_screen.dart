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
            if (inward['complaintText'] != null &&
                inward['complaintText'].toString().isNotEmpty)
              _buildComplaintCard(),
            const SizedBox(height: 16),
            _buildDiaEntriesCard(),
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

  Widget _buildQualityCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quality Check',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow('Status', inward['qualityStatus'] ?? 'OK'),
            if (inward['qualityImage'] != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Quality Image:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  '${ApiConstants.serverUrl}${inward['qualityImage']}',
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
              ...entries.map((entry) => _buildDiaEntryRow(entry)),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaEntryRow(Map<String, dynamic> entry) {
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
