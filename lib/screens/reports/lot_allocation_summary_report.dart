import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:garments/services/mobile_api_service.dart';
import 'package:garments/core/theme/color_palette.dart';
import 'package:garments/widgets/app_drawer.dart';
import 'package:garments/services/lot_allocation_print_service.dart';

class LotAllocationSummaryReportScreen extends StatefulWidget {
  const LotAllocationSummaryReportScreen({super.key});

  @override
  State<LotAllocationSummaryReportScreen> createState() => _LotAllocationSummaryReportScreenState();
}

class _LotAllocationSummaryReportScreenState extends State<LotAllocationSummaryReportScreen> {
  final _api = MobileApiService();
  final _printService = LotAllocationPrintService();
  bool _isLoading = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  List<dynamic> _allAllocations = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final orders = await _api.getCuttingOrders();
      List<dynamic> allocations = [];
      for (var order in orders) {
        if (order['lotAllocations'] != null) {
          for (var alc in order['lotAllocations']) {
            // Check if allocation date (if exists) or order date is within range
            final dateStr = alc['date'] ?? order['date'];
            final date = DateTime.parse(dateStr.toString());
            if (date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
                date.isBefore(_endDate.add(const Duration(days: 1)))) {
              allocations.add({
                ...alc,
                'planId': order['planId'],
                'orderDate': date,
              });
            }
          }
        }
      }
      // Sort by date descending
      allocations.sort((a, b) => (b['orderDate'] as DateTime).compareTo(a['orderDate'] as DateTime));
      setState(() {
        _allAllocations = allocations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DAILY ALLOCATION REPORT'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printService.printDailyAllocations(_allAllocations, _startDate, _endDate),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allAllocations.isEmpty
                    ? const Center(child: Text('No allocations found for this range'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _allAllocations.length,
                        itemBuilder: (context, index) {
                          final alc = _allAllocations[index];
                          return _buildAllocationCard(alc);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    setState(() => _startDate = d);
                    _fetchData();
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FROM', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(DateFormat('dd-MM-yyyy').format(_startDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    setState(() => _endDate = d);
                    _fetchData();
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TO', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(DateFormat('dd-MM-yyyy').format(_endDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationCard(dynamic alc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, dd-MM-yyyy').format(alc['orderDate'] as DateTime),
                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                ),
                Text('Plan: ${alc['planId']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(child: _info('ITEM', alc['itemName'] ?? 'N/A')),
                Expanded(child: _info('SIZE', alc['size'] ?? 'N/A')),
                Expanded(child: _info('DOZEN', alc['dozen'].toString())),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _info('LOT NO', alc['lotNo'] ?? 'N/A')),
                Expanded(child: _info('DIA', alc['dia'] ?? 'N/A')),
                Expanded(child: _info('ROLLS', alc['rolls']?.toString() ?? 'N/A')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _info('SET NO', alc['setNum'] ?? 'N/A')),
                Expanded(child: _info('WEIGHT', '${alc['weight']} KG')),
                Expanded(child: _info('RACK/PALLET', '${alc['rackName'] ?? ''}/${alc['palletNumber'] ?? ''}')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
