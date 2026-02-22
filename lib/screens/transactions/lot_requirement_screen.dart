import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/app_drawer.dart';

class LotRequirementScreen extends StatefulWidget {
  const LotRequirementScreen({super.key});

  @override
  State<LotRequirementScreen> createState() => _LotRequirementScreenState();
}

class _LotRequirementScreenState extends State<LotRequirementScreen> {
  final _api = MobileApiService();
  bool _isLoading = false;
  bool _isSaving = false;

  List<dynamic> _plans = [];
  String? _selectedPlanId;

  Map<String, dynamic>? get _selectedPlan {
    if (_selectedPlanId == null) return null;
    try {
      return _plans.firstWhere((p) => p['_id'] == _selectedPlanId);
    } catch (_) {
      return null;
    }
  }

  String? _selectedItem;
  String? _selectedSize;
  double _dozen = 0;

  List<dynamic> _allocations = [];
  bool _isAllocating = false;

  List<dynamic> _assignments = [];
  double _dozenWeight = 0;

  double get _fabricRequiredKg => _dozen * _dozenWeight;
  int get _rollsRequired => (_fabricRequiredKg / 20).ceil();

  final _dozenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _dozenController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await _api.getCuttingOrders();
      final assignments = await _api.getAssignments();
      setState(() {
        _plans = plans;
        _assignments = assignments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error loading plans: $e');
    }
  }

  void _onPlanChanged(String? planId) {
    setState(() {
      _selectedPlanId = planId;
      _selectedItem = null;
      _selectedSize = null;
      _dozen = 0;
      _dozenController.text = '0';
      _allocations = [];
    });
  }

  void _onItemSizeChanged() {
    if (_selectedPlan != null &&
        _selectedItem != null &&
        _selectedSize != null) {
      final entries = _selectedPlan!['cuttingEntries'] as List;
      final entry = entries.firstWhere(
        (e) => e['itemName'] == _selectedItem,
        orElse: () => null,
      );

      // Find matching assignment
      final assignment = _assignments.firstWhere(
        (a) =>
            a['fabricItem'].toString().toLowerCase() ==
                _selectedItem!.toLowerCase() &&
            a['size'] == _selectedSize,
        orElse: () => null,
      );

      setState(() {
        if (entry != null) {
          _dozen = (entry['sizeQuantities'][_selectedSize] ?? 0).toDouble();
          _dozenController.text = _dozen.toString();
        }
        _dozenWeight = assignment != null
            ? (assignment['dozenWeight'] ?? 0).toDouble()
            : 0;
      });
    }
  }

  Future<void> _runFifoAllocation() async {
    if (_selectedItem == null || _selectedSize == null || _dozen <= 0) {
      _showError('Please select Item, Size and ensure Dozen > 0');
      return;
    }

    setState(() => _isAllocating = true);
    try {
      final result = await _api.getFifoAllocation(
        _selectedItem!,
        _selectedSize!,
        _dozen,
        _selectedPlan!['dia'],
        _selectedPlan!['dozenWeight'],
      );
      setState(() {
        if (result != null) {
          _allocations = result['allocations'] ?? [];
          if (result['success'] == false) {
            _showError(result['message'] ?? 'Insufficient stock');
          }
        }
        _isAllocating = false;
      });
    } catch (e) {
      setState(() => _isAllocating = false);
      _showError('Allocation error: $e');
    }
  }

  Future<void> _saveAllocation() async {
    if (_selectedPlan == null || _allocations.isEmpty) {
      _showError('No allocations to save');
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Add itemName, size, dozen to each allocation for record keeping
      final lotAllocations = _allocations
          .map(
            (a) => {
              ...a,
              'itemName': _selectedItem,
              'size': _selectedSize,
              'allocationId': 'ALC-${DateTime.now().millisecondsSinceEpoch}',
            },
          )
          .toList();

      final success = await _api.saveLotAllocation(
        _selectedPlan!['_id'],
        lotAllocations.cast<Map<String, dynamic>>(),
      );
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lot Allocation Saved Successfully')),
          );
          // Refresh plan data
          _loadPlans();
          setState(() {
            _allocations = [];
            _selectedItem = null;
            _selectedSize = null;
            _dozen = 0;
          });
        }
      } else {
        _showError('Failed to save allocation');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LOT REQUIREMENT & ALLOCATION')),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPlanSelector(),
                  const SizedBox(height: 20),
                  if (_selectedPlan != null) _buildAllocationForm(),
                  const SizedBox(height: 24),
                  if (_allocations.isNotEmpty) _buildAllocationTable(),
                  const SizedBox(height: 40),
                  if (_allocations.isNotEmpty)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveAllocation,
                        icon: const Icon(Icons.save),
                        label: Text(
                          _isSaving ? 'SAVING...' : 'CONFIRM ALLOCATION',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                          backgroundColor: ColorPalette.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String>(
          value: _selectedPlanId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'SELECT CUTTING PLAN (PLAN ID)',
          ),
          items: _plans
              .map(
                (p) => DropdownMenuItem<String>(
                  value: p['_id'].toString(),
                  child: Text('${p['planId']} (${p['planPeriod']})'),
                ),
              )
              .toList(),
          onChanged: _onPlanChanged,
        ),
      ),
    );
  }

  Widget _buildAllocationForm() {
    final entries = _selectedPlan!['cuttingEntries'] as List;
    final itemNames = entries
        .map((e) => e['itemName'].toString())
        .toSet()
        .toList();

    List<String> sizes = [];
    if (_selectedItem != null) {
      final entry = entries.firstWhere((e) => e['itemName'] == _selectedItem);
      final sizeQuants = entry['sizeQuantities'] as Map;
      sizes = sizeQuants.keys
          .where((k) => (sizeQuants[k] ?? 0) > 0)
          .map((k) => k.toString())
          .toList();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedItem,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'ITEM NAME'),
                    items: itemNames
                        .map(
                          (n) => DropdownMenuItem<String>(
                            value: n,
                            child: Text(n),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedItem = val;
                        _selectedSize = null;
                        _onItemSizeChanged();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: sizes.contains(_selectedSize) ? _selectedSize : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'SIZE'),
                    items: sizes
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(s),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedSize = val;
                        _onItemSizeChanged();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'DOZEN',
                helperText: 'Editable (auto-filled from plan)',
              ),
              controller: _dozenController,
              onChanged: (val) =>
                  setState(() => _dozen = double.tryParse(val) ?? 0),
            ),
            if (_selectedItem != null && _selectedSize != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'FABRIC REQUIRED',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                          Text(
                            '${_fabricRequiredKg.toStringAsFixed(2)} KG',
                            style: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          'ROLLS REQUIRED',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '~$_rollsRequired Rolls',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isAllocating ? null : _runFifoAllocation,
                icon: const Icon(Icons.auto_awesome),
                label: Text(_isAllocating ? 'ALLOCATING...' : 'AUTO FIFO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FIFO LOT ALLOCATIONS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
              columns: const [
                DataColumn(label: Text('LOT NAME')),
                DataColumn(label: Text('LOT NO')),
                DataColumn(label: Text('DIA')),
                DataColumn(label: Text('DOZEN')),
                DataColumn(label: Text('WEIGHT (KG)')),
                DataColumn(label: Text('RACK')),
                DataColumn(label: Text('PALLET')),
              ],
              rows: _allocations
                  .map(
                    (a) => DataRow(
                      cells: [
                        DataCell(Text(a['lotName'] ?? '')),
                        DataCell(Text(a['lotNo'] ?? '')),
                        DataCell(Text(a['dia'] ?? '')),
                        DataCell(Text(a['dozen'].toString())),
                        DataCell(Text(a['weight'].toString())),
                        DataCell(Text(a['rackName'] ?? '')),
                        DataCell(Text(a['palletNumber'] ?? '')),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
