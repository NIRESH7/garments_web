import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/app_drawer.dart';

class LotRequirementAllocationScreen extends StatefulWidget {
  const LotRequirementAllocationScreen({super.key});

  @override
  State<LotRequirementAllocationScreen> createState() =>
      _LotRequirementAllocationScreenState();
}

class _LotRequirementAllocationScreenState
    extends State<LotRequirementAllocationScreen> {
  final _api = MobileApiService();
  bool _isLoading = false;
  bool _isAllocating = false;
  bool _isSaving = false;

  // Data from API
  List<dynamic> _allPlans = [];
  List<String> _itemNames = [];
  List<String> _dias = [];

  // Form State
  String? _selectedPlanId;
  String? _selectedItem;
  String? _selectedSize;
  String? _selectedDia;
  
  final TextEditingController _dozenController = TextEditingController();
  final TextEditingController _dozenWeightController = TextEditingController();
  final TextEditingController _lotNameController = TextEditingController();
  final TextEditingController _gsmController = TextEditingController();
  final TextEditingController _efficiencyController = TextEditingController();
  final TextEditingController _wasteController = TextEditingController();

  double _dozenBalance = 0;
  double _dozenWeight = 0;
  List<Map<String, dynamic>> _allocations = [];

  double get _fabricRequiredKg => (double.tryParse(_dozenController.text) ?? 0) * _dozenWeight;
  int get _rollsRequired => _fabricRequiredKg > 0 ? (_fabricRequiredKg / 20).ceil() : 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _dozenController.addListener(() => setState(() {}));
    _dozenWeightController.addListener(() {
      setState(() {
        _dozenWeight = double.tryParse(_dozenWeightController.text) ?? 0;
      });
    });
    _efficiencyController.addListener(() {
      final eff = double.tryParse(_efficiencyController.text) ?? 0;
      _wasteController.text = (100 - eff).toStringAsFixed(2);
    });
  }

  @override
  void dispose() {
    _dozenController.dispose();
    _dozenWeightController.dispose();
    _lotNameController.dispose();
    _gsmController.dispose();
    _efficiencyController.dispose();
    _wasteController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final plans = await _api.getCuttingOrders();
      final categories = await _api.getCategories();
      
      setState(() {
        _allPlans = plans;
        _dias = _getValues(categories, ['Dia']);
        _isLoading = false;
      });
    } catch (e) {
      _showError('Error loading data: $e');
      setState(() => _isLoading = false);
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

  void _onPlanSelected(String? planId) {
    setState(() {
      _selectedPlanId = planId;
      _selectedItem = null;
      _selectedSize = null;
      _itemNames = [];
      if (planId != null) {
        final plan = _allPlans.firstWhere((p) => p['_id'] == planId);
        final entries = plan['cuttingEntries'] as List;
        _itemNames = entries.map((e) => e['itemName'].toString()).toSet().toList();
      }
    });
  }

  void _onItemSelected(String? item) {
    setState(() {
      _selectedItem = item;
      _selectedSize = null;
    });
  }

  void _onSizeSelected(String? size) {
    setState(() {
      _selectedSize = size;
      if (_selectedPlanId != null && _selectedItem != null && size != null) {
        final plan = _allPlans.firstWhere((p) => p['_id'] == _selectedPlanId);
        final entry = (plan['cuttingEntries'] as List).firstWhere((e) => e['itemName'] == _selectedItem);
        final dozen = (entry['sizeQuantities'][size] ?? 0).toDouble();
        _dozenController.text = dozen.toString();
        _dozenBalance = dozen;
      }
    });
  }

  Future<void> _runAllocation() async {
    final dozen = double.tryParse(_dozenController.text) ?? 0;
    if (_selectedItem == null || _selectedSize == null || _selectedDia == null || dozen <= 0 || _dozenWeight <= 0) {
      _showError('Please select Item, Size, Dia and enter positive Dozen & Weight');
      return;
    }

    setState(() => _isAllocating = true);
    try {
      final result = await _api.getFifoAllocation(
        _selectedItem!,
        _selectedSize!,
        dozen,
        _selectedDia!,
        _dozenWeight,
      );
      setState(() {
        if (result != null) {
          _allocations = List<Map<String, dynamic>>.from(result['allocations'] ?? []);
          if (result['success'] == false) {
             _showError(result['message'] ?? 'Insufficient stock');
          }
        }
        _isAllocating = false;
      });
    } catch (e) {
      _showError('Allocation failed: $e');
      setState(() => _isAllocating = false);
    }
  }

  Future<void> _saveAllocation() async {
    if (_selectedPlanId == null || _allocations.isEmpty) {
      _showError('No allocations to save.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Prepare full allocation data for record
      final fullAllocations = _allocations.map((a) => {
        ...a,
        'itemName': _selectedItem,
        'size': _selectedSize,
        'dia': _selectedDia,
        'lotNameAssigned': _lotNameController.text,
        'gsm': _gsmController.text,
        'dozenWeight': _dozenWeight,
        'efficiency': _efficiencyController.text,
      }).toList();

      final success = await _api.saveLotAllocation(_selectedPlanId!, fullAllocations);
      if (success) {
        _showSuccess('Allocations Saved Successfully');
        Navigator.pop(context);
      } else {
        _showError('Failed to save allocations');
      }
    } catch (e) {
      _showError('Save failed: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    return Scaffold(
      appBar: AppBar(title: const Text('LOT REQUIREMENT ALLOCATION')),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildSectionHeader('PLAN SELECTION', primaryColor),
                   _buildPlanCard(),
                   const SizedBox(height: 20),
                   if (_selectedPlanId != null) ...[
                     _buildSectionHeader('REQUIREMENT DETAILS', primaryColor),
                     _buildRequirementCard(),
                     const SizedBox(height: 20),
                     _buildSectionHeader('WEIGHT & CALCULATION', primaryColor),
                     _buildCalculationCard(primaryColor),
                     const SizedBox(height: 20),
                     _buildSectionHeader('FIFO ALLOCATIONS', primaryColor),
                     _buildAllocationTable(primaryColor),
                     const SizedBox(height: 30),
                     _buildSaveButton(primaryColor),
                   ],
                   const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
      ),
    );
  }

  Widget _buildPlanCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DropdownButtonFormField<String>(
          value: _selectedPlanId,
          decoration: const InputDecoration(labelText: 'Select Saved Plan'),
          items: _allPlans.map((p) => DropdownMenuItem(
            value: p['_id'].toString(),
            child: Text('${p['planType']} - ${p['planPeriod']}'),
          )).toList(),
          onChanged: _onPlanSelected,
        ),
      ),
    );
  }

  Widget _buildRequirementCard() {
    List<String> sizes = [];
    if (_selectedPlanId != null && _selectedItem != null) {
      final plan = _allPlans.firstWhere((p) => p['_id'] == _selectedPlanId);
      final entry = (plan['cuttingEntries'] as List).firstWhere((e) => e['itemName'] == _selectedItem);
      sizes = (entry['sizeQuantities'] as Map).keys.where((k) => (entry['sizeQuantities'][k] ?? 0) > 0).map((k) => k.toString()).toList();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedItem,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Item Name'),
              items: _itemNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
              onChanged: _onItemSelected,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: sizes.contains(_selectedSize) ? _selectedSize : null,
                    decoration: const InputDecoration(labelText: 'Size'),
                    items: sizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: _onSizeSelected,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDia,
                    decoration: const InputDecoration(labelText: 'Dia'),
                    items: _dias.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) => setState(() => _selectedDia = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lotNameController,
              decoration: const InputDecoration(labelText: 'Assigned Lot Name', hintText: 'Enter Lot Name'),
            ),
            const SizedBox(height: 16),
             Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _gsmController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'GSM'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _efficiencyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Efficiency %'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationCard(Color primaryColor) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dozenController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Dozen (Modify)', helperText: 'Modify planned dozen if needed'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _dozenWeightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Dozen Weight (Kg)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCalcItem('Required Weight', '${_fabricRequiredKg.toStringAsFixed(2)} KG', primaryColor),
                  _buildCalcItem('Rolls Need', '~$_rollsRequired Rolls', primaryColor),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: _isAllocating ? null : _runAllocation,
                icon: const Icon(LucideIcons.zap, size: 18),
                label: Text(_isAllocating ? 'ALLOCATING...' : 'AUTO FIFO ALLOCATE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalcItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildAllocationTable(Color primaryColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _allocations.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('No allocations yet. Run FIFO to see lots.', style: TextStyle(color: Colors.grey))),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                columns: const [
                  DataColumn(label: Text('LOT NAME')),
                  DataColumn(label: Text('SET')),
                  DataColumn(label: Text('DIA')),
                  DataColumn(label: Text('RACK')),
                  DataColumn(label: Text('PALLET NO')),
                  DataColumn(label: Text('DOZEN')),
                ],
                rows: _allocations.map((a) => DataRow(
                  cells: [
                     DataCell(Text(a['lotName'] ?? '')),
                     DataCell(Text(a['sets']?.toString() ?? '-')),
                     DataCell(Text(a['dia'] ?? '')),
                     DataCell(Text(a['rackName'] ?? '')),
                     DataCell(Text(a['palletNumber'] ?? '')),
                     DataCell(Text(a['dozen']?.toString() ?? '0')),
                  ],
                )).toList(),
              ),
            ),
    );
  }

  Widget _buildSaveButton(Color primaryColor) {
    return Center(
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveAllocation,
         style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
          backgroundColor: ColorPalette.success,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isSaving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('SAVE LOT ALLOCATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
