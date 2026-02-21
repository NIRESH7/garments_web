import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/app_drawer.dart';

class CuttingOrderEntryScreen extends StatefulWidget {
  const CuttingOrderEntryScreen({super.key});

  @override
  State<CuttingOrderEntryScreen> createState() =>
      _CuttingOrderEntryScreenState();
}

class _CuttingOrderEntryScreenState extends State<CuttingOrderEntryScreen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  String _planType = 'Monthly';
  String _planPeriod = DateFormat('yyyy-MM').format(DateTime.now());

  List<String> _itemNames = [];
  List<String> _dias = [];
  final List<int> _sizes = [75, 80, 85, 90, 95, 100, 105, 110];
  final List<Map<String, dynamic>> _cuttingEntries = [];

  // Lot Allocation State
  String? _selectedReqItem;
  String? _selectedReqSize;
  String? _selectedReqDia;
  
  double _reqDozen = 0;
  double _dozenWeight = 0;
  
  bool _isAllocating = false;
  
  final TextEditingController _reqDozenController = TextEditingController();
  final TextEditingController _reqLotNameController = TextEditingController();
  final TextEditingController _reqGsmController = TextEditingController();
  final TextEditingController _reqEfficiencyController = TextEditingController();
  final TextEditingController _dozenWeightController = TextEditingController();
  final TextEditingController _wastePercentageController = TextEditingController();

  // All lot allocations to save along with the order
  List<Map<String, dynamic>> _allLotAllocations = [];

  double get _fabricRequiredKg => _reqDozen * _dozenWeight;
  int get _rollsRequired => _fabricRequiredKg > 0 ? (_fabricRequiredKg / 20).ceil() : 0;

  @override
  void initState() {
    super.initState();
    _loadMasterData();
    _addInitialRow();
    
    _dozenWeightController.addListener(_onDozenWeightChanged);
    _reqEfficiencyController.addListener(_onEfficiencyChanged);
  }

  @override
  void dispose() {
    _reqDozenController.dispose();
    _reqLotNameController.dispose();
    _reqGsmController.dispose();
    _reqEfficiencyController.dispose();
    _dozenWeightController.dispose();
    _wastePercentageController.dispose();
    super.dispose();
  }

  void _onDozenWeightChanged() {
    setState(() {
      _dozenWeight = double.tryParse(_dozenWeightController.text) ?? 0;
    });
  }

  void _onEfficiencyChanged() {
    final eff = double.tryParse(_reqEfficiencyController.text) ?? 0;
    final waste = 100 - eff;
    _wastePercentageController.text = waste.toStringAsFixed(2);
  }

  void _addInitialRow() {
    setState(() {
      final entry = {
        'itemName': '',
        'sizeQuantities': {for (var s in _sizes) s.toString(): 0},
        'totalDozens': 0,
      };
      _cuttingEntries.add(entry);
    });
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _api.getCategories();
      setState(() {
        _itemNames = _getValues(categories, ['Item Name', 'itemName', 'item']);
        _dias = _getValues(categories, ['Dia']);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error loading master data: $e');
      }
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
      final quantities =
          _cuttingEntries[index]['sizeQuantities'] as Map<String, dynamic>;
      quantities.forEach((key, value) {
        if (value is num) {
          total += value.toInt();
        } else if (value is String) {
          total += int.tryParse(value) ?? 0;
        }
      });
      _cuttingEntries[index]['totalDozens'] = total;
    });
  }

  void _onReqItemSizeChanged() {
    if (_selectedReqItem != null && _selectedReqSize != null) {
      // Find dozen from cutting entries
      double calculatedDozen = 0;
      final entry = _cuttingEntries.firstWhere(
        (e) => e['itemName'] == _selectedReqItem,
        orElse: () => {},
      );
      if (entry.isNotEmpty && entry['sizeQuantities'] != null) {
        calculatedDozen = (entry['sizeQuantities'][_selectedReqSize] ?? 0).toDouble();
      }

      setState(() {
        _reqDozen = calculatedDozen;
        _reqDozenController.text = _reqDozen.toStringAsFixed(2);
      });
    }
  }

  Future<void> _runFifoAllocation() async {
    if (_selectedReqItem == null || _selectedReqSize == null || _selectedReqDia == null || _reqDozen <= 0) {
      _showError('Please select Item, Size, Dia and ensure Dozen > 0');
      return;
    }
    if (_dozenWeight <= 0) {
      _showError('Please enter a valid Dozen Weight');
      return;
    }

    setState(() => _isAllocating = true);
    try {
      final result = await _api.getFifoAllocation(
        _selectedReqItem!,
        _selectedReqSize!,
        _reqDozen,
        _selectedReqDia!,
        _dozenWeight,
      );
      setState(() {
        if (result != null) {
          final newAllocs = result['allocations'] ?? [];
          if (result['success'] == false) {
            _showError(result['message'] ?? 'Insufficient stock');
          }
          
          // Remove old allocations for this exact item/size
          _allLotAllocations.removeWhere((a) =>
              a['itemName'] == _selectedReqItem &&
              a['size'] == _selectedReqSize);

          // Add new ones
          for (var a in newAllocs) {
            _allLotAllocations.add({
              ...a,
              'itemName': _selectedReqItem,
              'size': _selectedReqSize,
              'dia': _selectedReqDia,
              'dozen': a['dozen'],
              'lotNameAssigned': _reqLotNameController.text, 
              'gsm': _reqGsmController.text, 
              'efficiency': _reqEfficiencyController.text,
              'dozenWeight': _dozenWeight,
            });
          }
        }
        _isAllocating = false;
      });
    } catch (e) {
      setState(() => _isAllocating = false);
      _showError('Allocation error: $e');
    }
  }

  Future<void> _saveCuttingOrder() async {
    if (_isSaving) return;
    if (_cuttingEntries.any((e) => e['itemName'].isEmpty)) {
      _showError('Please select Item Name for all rows in planning sheet');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        'planType': _planType,
        'planPeriod': _planPeriod,
        'cuttingEntries': _cuttingEntries,
        'lotAllocations': _allLotAllocations, 
      };

      final success = await _api.saveCuttingOrder(data);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cutting Plan & Allocations Saved Successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        _showError('Failed to save cutting order.');
      }
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: ColorPalette.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CUTTING ORDER ENTRY')),
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
                    _buildPlanParams(),
                    const SizedBox(height: 20),
                    _buildEntryTable(),
                    const SizedBox(height: 30),
                    const Divider(color: Colors.grey, thickness: 1),
                    const SizedBox(height: 20),
                    _buildLotRequirementSection(),
                    const SizedBox(height: 30),
                    Center(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveCuttingOrder,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 60,
                            vertical: 15,
                          ),
                          backgroundColor: ColorPalette.success,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'SAVE ASSIGNMENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPlanParams() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _planType,
                decoration: const InputDecoration(labelText: 'PLAN TYPE'),
                items: ['Monthly', 'Yearly']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _planType = val!;
                    if (_planType == 'Monthly') {
                      _planPeriod = DateFormat('yyyy-MM').format(DateTime.now());
                    } else {
                      _planPeriod = DateFormat('yyyy').format(DateTime.now());
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                readOnly: true,
                controller: TextEditingController(text: _planPeriod),
                decoration: const InputDecoration(
                  labelText: 'PLAN PERIOD',
                  suffixIcon: Icon(Icons.calendar_month),
                ),
                onTap: () async {
                  if (_planType == 'Monthly') {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDatePickerMode: DatePickerMode.year,
                    );
                    if (date != null) {
                      setState(
                        () => _planPeriod = DateFormat('yyyy-MM').format(date),
                      );
                    }
                  } else {
                    final year = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDatePickerMode: DatePickerMode.year,
                    );
                    if (year != null) {
                      setState(() => _planPeriod = year.year.toString());
                    }
                  }
                },
              ),
            ),
          ],
        ),
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
            const Text(
              'CUTTING ORDER PLANNING SHEET',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: ColorPalette.primary,
              ),
            ),
            TextButton.icon(
              onPressed: _addInitialRow,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('ADD LINE'),
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
                const DataColumn(label: Text('DOZENS', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: List.generate(_cuttingEntries.length, (index) {
                final entry = _cuttingEntries[index];
                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: entry['itemName'].isEmpty ? null : entry['itemName'],
                          items: _itemNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                          onChanged: (val) {
                            setState(() => entry['itemName'] = val ?? '');
                            _onReqItemSizeChanged(); // Update lot requirements if currently focused
                          },
                          decoration: const InputDecoration(border: InputBorder.none, hintText: 'Select Item'),
                        ),
                      ),
                    ),
                    ..._sizes.map((s) {
                      final sStr = s.toString();
                      return DataCell(
                        SizedBox(
                          width: 50,
                          child: TextFormField(
                            initialValue: entry['sizeQuantities'][sStr].toString() == '0' ? '' : entry['sizeQuantities'][sStr].toString(),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (val) {
                              setState(() {
                                entry['sizeQuantities'][sStr] = int.tryParse(val) ?? 0;
                                _calculateTotal(index);
                                _onReqItemSizeChanged(); // Trigger live updates
                              });
                            },
                            decoration: InputDecoration(border: InputBorder.none, hintText: '0', hintStyle: TextStyle(color: Colors.grey.shade400)),
                          ),
                        ),
                      );
                    }),
                    DataCell(Text(entry['totalDozens'].toString(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => _cuttingEntries.removeAt(index));
                        },
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLotRequirementSection() {
    List<String> plannedItemNames = _cuttingEntries.where((e) => e['itemName'].isNotEmpty).map((e) => e['itemName'].toString()).toSet().toList();
    List<String> plannedSizes = [];

    if (_selectedReqItem != null) {
      final entry = _cuttingEntries.firstWhere((e) => e['itemName'] == _selectedReqItem, orElse: () => {});
      if (entry.isNotEmpty) {
        final sizeQuants = entry['sizeQuantities'] as Map;
        plannedSizes = sizeQuants.keys.where((k) => (sizeQuants[k] ?? 0) > 0).map((k) => k.toString()).toList();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FABRIC / ITEM DETAILS',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ColorPalette.primary),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedReqItem,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Fabric Item'),
                  items: plannedItemNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedReqItem = val;
                      _selectedReqSize = null;
                      _onReqItemSizeChanged();
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: plannedSizes.contains(_selectedReqSize) ? _selectedReqSize : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Size'),
                        items: plannedSizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedReqSize = val;
                            _onReqItemSizeChanged();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _dias.contains(_selectedReqDia) ? _selectedReqDia : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Dia'),
                        items: _dias.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedReqDia = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reqLotNameController,
                  decoration: const InputDecoration(labelText: 'Lot Name', hintText: 'Enter Lot Name ✍️'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reqGsmController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'GSM', hintText: 'Enter GSM ✍️'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reqEfficiencyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Efficiency (%)', hintText: 'Enter Efficiency % ✍️'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'WEIGHT & CALCULATION',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ColorPalette.primary),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _dozenWeightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Dozen Weight (Kg)',
                    hintText: 'Enter Dozen Weight ✍️',
                    helperText: 'Manual override allowed',
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                       Column(
                        children: [
                          const Text('Dozen (Auto)', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          Text(_reqDozen.toStringAsFixed(2), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Fabric Required', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
                          Text('${_fabricRequiredKg.toStringAsFixed(2)} KG', style: const TextStyle(fontSize: 18, color: ColorPalette.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Rolls Required', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
                          Text('~$_rollsRequired Rolls', style: const TextStyle(fontSize: 18, color: ColorPalette.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isAllocating ? null : _runFifoAllocation,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(_isAllocating ? 'ALLOCATING FIFO...' : 'AUTO FIFO ALLOCATE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildFifoTable(),
        const SizedBox(height: 20),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel('Waste % (100 - Efficiency)'),
                TextFormField(
                  controller: _wastePercentageController,
                  readOnly: true, // Auto-calculated
                  decoration: const InputDecoration(
                    hintText: '0.00 %',
                    filled: true,
                    fillColor: Color(0xFFF1F5F9), 
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFifoTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FIFO LOT LOCATION (AUTO DISPLAY)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ColorPalette.primary),
        ),
        const SizedBox(height: 10),
        if (_allLotAllocations.isEmpty)
          const Text('No lots allocated yet. Run Auto FIFO for your items.', style: TextStyle(color: Colors.grey))
        else
          Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                columns: const [
                  DataColumn(label: Text('LOT NAME')),
                  DataColumn(label: Text('DIA')),
                  DataColumn(label: Text('RACK')),
                  DataColumn(label: Text('PALLET NO')),
                  DataColumn(label: Text('')), 
                ],
                rows: _allLotAllocations.map((a) => DataRow(
                  cells: [
                    DataCell(Text(a['lotName'] ?? '')),
                    DataCell(Text(a['dia'] ?? '')),
                    DataCell(Text(a['rackName'] ?? '')),
                    DataCell(Text(a['palletNumber'] ?? '')),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                        onPressed: () {
                          setState(() {
                            _allLotAllocations.remove(a);
                          });
                        },
                      )
                    )
                  ],
                )).toList(),
              ),
            ),
          ),
      ],
    );
  }
}
