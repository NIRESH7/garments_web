import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OutwardDetailScreen extends StatelessWidget {
  final Map<String, dynamic> outward;

  const OutwardDetailScreen({super.key, required this.outward});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outward Details'),
        backgroundColor: Colors.orange,
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
      totalWeight += (item['selected_weight'] as num?)?.toDouble() ?? 0;
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
                '${item['selected_weight'] ?? 0} Kg',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
