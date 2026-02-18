import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/custom_dropdown_field.dart';
import 'package:share_plus/share_plus.dart';

class CuttingOrderEntryScreen extends StatefulWidget {
  const CuttingOrderEntryScreen({super.key});

  @override
  State<CuttingOrderEntryScreen> createState() => _CuttingOrderEntryScreenState();
}

class _CuttingOrderEntryScreenState extends State<CuttingOrderEntryScreen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  final DateTime _orderDate = DateTime.now();
  List<String> _itemNames = [];
  final List<int> _sizes = [75, 80, 85, 90, 95, 100, 105, 110];

  // Grid Data
  final List<Map<String, dynamic>> _cuttingEntries = [];
  final List<Map<String, dynamic>> _lotRequirements = [];
  List<String> _dias = [];
  List<String> _lotNamesMaster = [];
  List<String> _lotNumbers = [];
  List<String> _rackNames = [];
  List<String> _palletNumbers = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
    _addInitialRow();
    _addLotRequirementRow();
  }

  void _addInitialRow() {
    setState(() {
      final entry = {
        'itemName': '',
        'sizeQuantities': {for (var s in _sizes) s.toString(): 0},
        'total': 0,
      };
      _cuttingEntries.add(entry);
    });
  }

  void _addLotRequirementRow() {
    setState(() {
      _lotRequirements.add({
        'itemName': '',
        'size': '',
        'dozen': 0,
        'dia': '',
        'dozenWt': 0.0,
        'totalWt': 0.0,
        'roll': 0,
        'set': 0,
        'lotNumber': '',
        'lotName': '',
        'setNumber': '',
        'rackName': '',
        'palletNo': '',
        'availableSets': [], // To store fetched sets for dropdown
      });
    });
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _api.getCategories();
      final lotsMaster = await _api.getLots();
      final lotsDistinct = await _api.getDistinctLots();
      
      setState(() {
        _itemNames = _getValues(categories, ['Item Name', 'itemName', 'item']);
        _dias = _getValues(categories, ['Dia', 'dia']);
        _lotNamesMaster = _getValues(categories, ['Lot Name', 'lotname']);
        _rackNames = _getValues(categories, ['Rack Name', 'rack']);
        _palletNumbers = _getValues(categories, ['Pallet No', 'pallet', 'palletNo']);
        
        // Merge Lot Numbers from Master and Inward
        final Set<String> allLots = {};
        if (lotsMaster is List) {
          allLots.addAll(lotsMaster.map((l) => (l['lotNumber'] ?? '').toString()).where((s) => s.isNotEmpty));
        }
        if (lotsDistinct is List) {
          allLots.addAll(lotsDistinct.map((l) => (l['lotNumber'] ?? '').toString()).where((s) => s.isNotEmpty));
        }
        _lotNumbers = allLots.toList()..sort();
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error loading master data: $e');
    }
  }

  List<String> _getValues(List<dynamic> categories, List<String> matchNames) {
    final List<String> result = [];
    final matches = categories.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      return matchNames.any((m) => name == m.toLowerCase());
    });
    for (var cat in matches) {
      final values = cat['values'] as List<dynamic>?;
      if (values != null) {
        for (var v in values) {
          final val = (v is Map ? v['name'] : v).toString();
          if (val.isNotEmpty && !result.contains(val)) result.add(val);
        }
      }
    }
    return result;
  }

  void _calculateTotal(int index) {
    setState(() {
      int total = 0;
      final quantities = _cuttingEntries[index]['sizeQuantities'] as Map<String, dynamic>;
      quantities.forEach((key, value) {
        if (value is num) {
          total += value.toInt();
        } else if (value is String) {
          total += int.tryParse(value) ?? 0;
        }
      });
      _cuttingEntries[index]['total'] = total;
    });
  }

  Future<void> _fetchSetsForEntry(int index) async {
    final entry = _lotRequirements[index];
    final lotNo = entry['lotNumber'].toString();
    final dia = entry['dia'].toString();

    if (lotNo.isNotEmpty && dia.isNotEmpty) {
      try {
        final sets = await _api.getBalancedSets(lotNo, dia);
        setState(() {
          entry['availableSets'] = sets;
          // If current setNumber is not in new list, reset it? 
          // Or keep it if manual entry is allowed? 
          // For now, if current setNumber is invalid, clear it, Rack and Pallet
          final currentSet = entry['setNumber'].toString();
          final exists = sets.any((s) => s['set_no'].toString() == currentSet);
          if (!exists) {
             entry['setNumber'] = '';
             entry['rackName'] = '';
             entry['palletNo'] = '';
          }
        });
      } catch (e) {
        print('Error fetching sets: $e');
      }
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Clean up availableSets before saving to avoid cluttering payload (though backend ignores extra fields usually)
      final cleanRequirements = _lotRequirements.map((e) {
        final Map<String, dynamic> copy = Map.from(e);
        copy.remove('availableSets');
        return copy;
      }).toList();

      final data = {
        'date': DateFormat('yyyy-MM-dd').format(_orderDate),
        'cuttingEntries': _cuttingEntries,
        'lotRequirements': cleanRequirements,
      };

      final response = await _api.saveCuttingOrder(data);
      if (response) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cutting Order Saved Successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        _showError('Failed to save cutting order. Check server logs.');
      }
    } catch (e) {
      _showError('Failed to save cutting order: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CUTTING ORDER ENTRY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share functionality coming soon')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Print functionality coming soon')));
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateSection(),
                    const SizedBox(height: 20),
                    _buildEntryTable(),
                    const SizedBox(height: 30),
                    _buildLotRequirementTable(),
                    const SizedBox(height: 40),
                    Center(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 15),
                          backgroundColor: ColorPalette.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSaving 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('SAVE ENTRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          const Text('DATE: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          Text(DateFormat('dd-MM-yyyy').format(_orderDate), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEntryTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('CUTTING ORDER ENTRY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ColorPalette.primary)),
            TextButton.icon(
              onPressed: _addInitialRow,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('ADD ITEM LINE'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 15,
              horizontalMargin: 15,
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
              border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade300)),
              columns: [
                const DataColumn(label: Text('ITEM NAME', style: TextStyle(fontWeight: FontWeight.bold))),
                ..._sizes.map((s) => DataColumn(label: Text(s.toString(), style: const TextStyle(fontWeight: FontWeight.bold)))),
                const DataColumn(label: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: List.generate(_cuttingEntries.length, (index) {
                final entry = _cuttingEntries[index];
                return DataRow(cells: [
                  DataCell(
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: entry['itemName'].isEmpty ? null : entry['itemName'],
                        items: _itemNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                        onChanged: (val) => setState(() => entry['itemName'] = val ?? ''),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Select Item'),
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    ),
                  ),
                  ..._sizes.map((s) {
                    final sStr = s.toString();
                    return DataCell(
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                        initialValue: entry['sizeQuantities'][sStr].toString() == '0' ? '' : entry['sizeQuantities'][sStr].toString(),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (val) {
                            setState(() {
                              entry['sizeQuantities'][sStr] = int.tryParse(val) ?? 0;
                              _calculateTotal(index);
                            });
                          },
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '0',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                          ),
                        ),
                      ),
                    );
                  }),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                      child: Text(entry['total'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLotRequirementTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('LOT REQUIREMENT FOR CUTTING ORDER PLAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ColorPalette.primary)),
            TextButton.icon(
              onPressed: _addLotRequirementRow,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('ADD REQUIREMENT'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 15,
              horizontalMargin: 15,
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
              border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade300)),
              columns: const [
                DataColumn(label: Text('ITEM NAME', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('SIZE', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('DOZEN', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('DIA', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('DOZEN WT.', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('TOTAL WT.', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('ROLL', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('SET', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('LOT NUMBER', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('LOT NAME', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('SET NUMBER', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('RACK NAME', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('PALLET NO', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: List.generate(_lotRequirements.length, (index) {
                final entry = _lotRequirements[index];
                return DataRow(cells: [
                  // ITEM NAME
                  DataCell(
                     SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: entry['itemName'].isEmpty ? null : entry['itemName'],
                        items: _itemNames.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => entry['itemName'] = val ?? ''),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Select Item'),
                      ),
                    ),
                  ),
                  // SIZE
                  DataCell(
                    SizedBox(
                      width: 80,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: entry['size'].isEmpty ? null : entry['size'],
                        items: _sizes.map((s) => DropdownMenuItem(value: s.toString(), child: Text(s.toString()))).toList(),
                        onChanged: (val) => setState(() => entry['size'] = val ?? ''),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Size'),
                      ),
                    ),
                  ),
                  // DOZEN
                  DataCell(
                    SizedBox(
                      width: 70,
                      child: TextFormField(
                        initialValue: entry['dozen'].toString() == '0' ? '' : entry['dozen'].toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          setState(() {
                            entry['dozen'] = int.tryParse(val) ?? 0;
                            double dWt = double.tryParse(entry['dozenWt'].toString()) ?? 0.0;
                            entry['totalWt'] = (entry['dozen'] as int) * dWt;
                          });
                        },
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Qty'),
                      ),
                    ),
                  ),
                  // DIA
                  DataCell(
                    SizedBox(
                      width: 80,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: entry['dia'].isEmpty ? null : entry['dia'],
                        items: _dias.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (val) {
                           setState(() => entry['dia'] = val ?? '');
                           _fetchSetsForEntry(index);
                        },
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Dia'),
                      ),
                    ),
                  ),
                  // DOZEN WT
                  DataCell(
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        initialValue: entry['dozenWt'].toString() == '0.0' ? '' : entry['dozenWt'].toString(),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) {
                           setState(() {
                             entry['dozenWt'] = double.tryParse(val) ?? 0.0;
                             entry['totalWt'] = (int.tryParse(entry['dozen'].toString()) ?? 0) * (entry['dozenWt'] as double);
                           });
                        },
                        decoration: const InputDecoration(border: InputBorder.none, hintText: '0.00'),
                      ),
                    ),
                  ),
                  // TOTAL WT
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(double.tryParse(entry['totalWt'].toString())?.toStringAsFixed(3) ?? '0.000', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                    )
                  ),
                  // ROLL
                  DataCell(
                    SizedBox(
                      width: 60,
                      child: TextFormField(
                        initialValue: entry['roll'].toString() == '0' ? '' : entry['roll'].toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => setState(() => entry['roll'] = int.tryParse(val) ?? 0),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: '0'),
                      ),
                    ),
                  ),
                  // SET
                  DataCell(
                    SizedBox(
                      width: 60,
                      child: TextFormField(
                        initialValue: entry['set'].toString() == '0' ? '' : entry['set'].toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => setState(() => entry['set'] = int.tryParse(val) ?? 0),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: '0'),
                      ),
                    ),
                  ),
                  // LOT NUMBER
                  DataCell(
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: entry['lotNumber'].isEmpty ? null : entry['lotNumber'],
                        items: _lotNumbers.map((n) => DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          setState(() => entry['lotNumber'] = val ?? '');
                          _fetchSetsForEntry(index);
                        },
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Select Lot'),
                      ),
                    ),
                  ),
                  // LOT NAME
                  DataCell(
                     SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: entry['lotName'].isEmpty ? null : entry['lotName'],
                        items: _lotNamesMaster.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => entry['lotName'] = val ?? ''),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Select Name'),
                      ),
                    ),
                  ),
                  // SET NUMBER (UPDATED TO DROPDOWN)
                  DataCell(
                    SizedBox(
                      width: 80,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: entry['setNumber'].isEmpty ? null : entry['setNumber'],
                        items: (entry['availableSets'] as List<dynamic>?)?.map((s) {
                          final setNo = s['set_no'].toString();
                          return DropdownMenuItem(value: setNo, child: Text(setNo));
                        }).toList() ?? [],
                        onChanged: (val) {
                          setState(() {
                            entry['setNumber'] = val ?? '';
                            // Auto-populate Rack/Pallet
                            final setObj = (entry['availableSets'] as List<dynamic>?)?.firstWhere(
                              (s) => s['set_no'].toString() == val, orElse: () => null
                            );
                            if (setObj != null) {
                              entry['rackName'] = setObj['rack_name'] ?? '';
                              entry['palletNo'] = setObj['pallet_number'] ?? '';
                            }
                          });
                        },
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Set No'),
                      ),
                    ),
                  ),
                  // RACK NAME
                  DataCell(
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: entry['rackName'].isEmpty ? null : entry['rackName'],
                        items: _rackNames.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => entry['rackName'] = val ?? ''),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Select Rack'),
                      ),
                    ),
                  ),
                  // PALLET NO
                  DataCell(
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: entry['palletNo'].isEmpty ? null : entry['palletNo'],
                        items: _palletNumbers.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => entry['palletNo'] = val ?? ''),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Select Pallet'),
                      ),
                    ),
                  ),
                  // ACTION
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => setState(() => _lotRequirements.removeAt(index)),
                    ),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ],
    );
  }
}
