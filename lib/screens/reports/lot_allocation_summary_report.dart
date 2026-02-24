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
  
  String? _selectedItemName;
  String? _selectedSize;
  List<String> _availableItemNames = [];
  List<String> _availableSizes = [];

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
      Set<String> itemNamesSet = {};
      Set<String> sizesSet = {};

      for (var order in orders) {
        // 1. Calculate required quantities from the plan
        Map<String, Map<String, double>> requiredMap = {};
        if (order['cuttingEntries'] != null) {
          for(var entry in order['cuttingEntries']) {
             final item = entry['itemName']?.toString();
             if(item != null) {
                requiredMap[item] = {};
                if(entry['sizeQuantities'] != null) {
                   (entry['sizeQuantities'] as Map).forEach((k, v) {
                       requiredMap[item]![k.toString()] = (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
                   });
                }
             }
          }
        }

        // 2. Calculate total allocated quantities for this plan
        Map<String, Map<String, double>> allocatedMap = {};
        if (order['lotAllocations'] != null) {
            for (var alc in order['lotAllocations']) {
                final item = alc['itemName']?.toString();
                final size = alc['size']?.toString();
                final dozen = (alc['dozen'] is num ? alc['dozen'].toDouble() : double.tryParse(alc['dozen'].toString()) ?? 0);
                if(item != null && size != null) {
                    allocatedMap.putIfAbsent(item, () => {});
                    allocatedMap[item]![size] = (allocatedMap[item]![size] ?? 0) + dozen;
                }
            }
        }

        // 3. Process allocations within date range
        if (order['lotAllocations'] != null) {
          for (var alc in order['lotAllocations']) {
            final dateStr = alc['date'] ?? order['date'];
            final date = DateTime.parse(dateStr.toString());
            
            final item = alc['itemName']?.toString();
            final size = alc['size']?.toString();
            double pending = 0;
            if(item != null && size != null) {
                 final req = requiredMap[item]?[size] ?? 0;
                 final alloc = allocatedMap[item]?[size] ?? 0;
                 pending = req - alloc;
                 if(pending < 0) pending = 0;
            }

            if (date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
                date.isBefore(_endDate.add(const Duration(days: 1)))) {
              allocations.add({
                ...alc,
                'planId': order['planId'],
                'orderDate': date,
                'pendingDozens': pending,
              });
              
              if (item != null && item.isNotEmpty) itemNamesSet.add(item);
              if (size != null && size.isNotEmpty) sizesSet.add(size);
            }
          }
        }
      }
      
      allocations.sort((a, b) => (b['orderDate'] as DateTime).compareTo(a['orderDate'] as DateTime));
      
      setState(() {
        _allAllocations = allocations;
        _availableItemNames = itemNamesSet.toList()..sort();
        _availableSizes = sizesSet.toList()..sort();
        
        // Reset selection if not in available list
        if (_selectedItemName != null && !_availableItemNames.contains(_selectedItemName)) {
           _selectedItemName = null;
        }
        if (_selectedSize != null && !_availableSizes.contains(_selectedSize)) {
           _selectedSize = null;
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  List<dynamic> get _filteredAllocations {
    return _allAllocations.where((alc) {
      bool matchesItem = _selectedItemName == null || alc['itemName'] == _selectedItemName;
      bool matchesSize = _selectedSize == null || alc['size']?.toString() == _selectedSize;
      return matchesItem && matchesSize;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DAILY ALLOCATION REPORT'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printService.printDailyAllocations(
              _filteredAllocations, 
              _startDate, 
              _endDate,
              itemName: _selectedItemName,
              size: _selectedSize,
            ),
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
                : _filteredAllocations.isEmpty
                    ? const Center(child: Text('No allocations found for this range/filter'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredAllocations.length,
                        itemBuilder: (context, index) {
                          final alc = _filteredAllocations[index];
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
        child: Column(
          children: [
            Row(
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedItemName,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Items')),
                      ..._availableItemNames.map((item) => DropdownMenuItem(value: item, child: Text(item)))
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedItemName = val;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Size',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedSize,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      ..._availableSizes.map((size) => DropdownMenuItem(value: size, child: Text(size)))
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedSize = val;
                      });
                    },
                  ),
                ),
              ],
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
                Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       const Text('DOZEN', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                       Row(
                         children: [
                           Text(alc['dozen'].toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                           const SizedBox(width: 4),
                           Text(
                             '(Pending: ${alc['pendingDozens']?.toString() ?? '0'})',
                             style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                           ),
                         ],
                       ),
                     ],
                   )
                ),
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
