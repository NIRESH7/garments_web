import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:garments/services/mobile_api_service.dart';
import 'package:garments/core/theme/color_palette.dart';
import 'package:garments/services/lot_allocation_print_service.dart';
import 'package:garments/core/storage/storage_service.dart';
import 'package:garments/widgets/app_drawer.dart';
import 'package:garments/widgets/custom_dropdown_field.dart';

const List<String> _kWeekDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday'
];


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
  List<String> _masterItemNames = [];
  List<String> _masterSizes = [];
  List<String> _dias = [];
  List<dynamic> _assignments = [];

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
  final TextEditingController _foldingWeightController =
      TextEditingController();

  double _dozenWeight = 0;
  List<Map<String, dynamic>> _allocations = [];
  List<Map<String, dynamic>> _allWeekAllocations = [];
  String _selectedDay = 'Monday';
  final _printServiceWeekly = LotAllocationPrintService();


  double get _fabricRequiredKg =>
      (double.tryParse(_dozenController.text) ?? 0) *
      (_dozenWeight + (double.tryParse(_foldingWeightController.text) ?? 0));
  int get _rollsRequired =>
      _fabricRequiredKg > 0 ? (_fabricRequiredKg / 20).ceil() : 0;

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
      setState(() {});
    });
    _foldingWeightController.addListener(() => setState(() {}));
    _gsmController.addListener(() => setState(() {}));
    _lotNameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _dozenController.dispose();
    _dozenWeightController.dispose();
    _lotNameController.dispose();
    _gsmController.dispose();
    _efficiencyController.dispose();
    _wasteController.dispose();
    _foldingWeightController.dispose();
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
        _masterItemNames = _getValues(categories, [
          'Item Name',
          'itemName',
          'item',
        ]);
        _masterSizes = _getValues(categories, ['Size', 'size']);
      });

      final assignments = await _api.getAssignments();
      setState(() {
        _assignments = assignments;
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
    });
  }

  void _onItemSelected(String? item) {
    setState(() {
      _selectedItem = item;
      _selectedSize = null;
      _updateFromAssignments();
    });
  }

  void _onSizeSelected(String? size) {
    setState(() {
      _selectedSize = size;
      if (_selectedPlanId != null && _selectedItem != null && size != null) {
        final plan = _allPlans.firstWhere((p) => p['_id'] == _selectedPlanId);
        final entry = (plan['cuttingEntries'] as List).firstWhere(
          (e) => e['itemName'] == _selectedItem,
          orElse: () => null,
        );
        if (entry != null) {
          final dozen = (entry['sizeQuantities'][size] ?? 0).toDouble();
          _dozenController.text = dozen.toString();
        }
      }
      _updateFromAssignments();
    });
  }

  void _onDiaSelected(String? dia) {
    setState(() {
      _selectedDia = dia;
      _updateFromAssignments();
    });
  }

  void _updateFromAssignments() {
    if (_selectedItem == null) return;

    // 1. Find all assignments for this item
    // Find potential matches
    final itemMatches = _assignments
        .where(
          (a) =>
              a['fabricItem'].toString().trim().toLowerCase() ==
              _selectedItem!.trim().toLowerCase(),
        )
        .toList();

    if (itemMatches.isEmpty) return;

    // 2. Try to find the best match (prioritize Size and Dia if selected)
    dynamic bestMatch;

    // Try exact Match (Item + Size + Dia)
    if (_selectedSize != null && _selectedDia != null) {
      bestMatch = itemMatches.firstWhere(
        (a) =>
            a['size'].toString().trim().toLowerCase() ==
                _selectedSize!.trim().toLowerCase() &&
            a['dia'].toString().trim().toLowerCase() ==
                _selectedDia!.trim().toLowerCase(),
        orElse: () => null,
      );
    }

    // Try Match (Item + Size)
    if (bestMatch == null && _selectedSize != null) {
      bestMatch = itemMatches.firstWhere(
        (a) =>
            a['size'].toString().trim().toLowerCase() ==
            _selectedSize!.trim().toLowerCase(),
        orElse: () => null,
      );
    }

    // Fallback to the first assignment for this item
    bestMatch ??= itemMatches.first;

    // 3. Auto-fill fields from the bestMatch
    if (bestMatch != null) {
      // Auto-fill Size if not selected
      if (_selectedSize == null) {
        final matchSize = bestMatch['size']?.toString();
        if (matchSize != null) {
          _selectedSize = matchSize;
          // Trigger the plan-sync logic for this size
          if (_selectedPlanId != null && _selectedItem != null) {
            final plan = _allPlans.firstWhere(
              (p) => p['_id'] == _selectedPlanId,
              orElse: () => null,
            );
            if (plan != null) {
              final entry = (plan['cuttingEntries'] as List).firstWhere(
                (e) => e['itemName'] == _selectedItem,
                orElse: () => null,
              );
              if (entry != null) {
                final dozen = (entry['sizeQuantities'][matchSize] ?? 0)
                    .toDouble();
                _dozenController.text = dozen.toString();
              }
            }
          }
        }
      }

      // Auto-fill Dia if not selected
      if (_selectedDia == null) {
        final matchDia = bestMatch['dia']?.toString();
        if (matchDia != null && _dias.contains(matchDia)) {
          _selectedDia = matchDia;
        }
      }

      // Fill Text Fields
      _lotNameController.text = bestMatch['lotName']?.toString() ?? '';
      _gsmController.text = bestMatch['gsm']?.toString() ?? '';
      _efficiencyController.text = bestMatch['efficiency']?.toString() ?? '';
      _dozenWeightController.text = bestMatch['dozenWeight']?.toString() ?? '';
      _foldingWeightController.text = bestMatch['foldingWt']?.toString() ?? '';

      // Update calculations
      final eff = double.tryParse(_efficiencyController.text) ?? 0;
      _wasteController.text = (100 - eff).toStringAsFixed(2);
      _dozenWeight = double.tryParse(_dozenWeightController.text) ?? 0;
    }
  }

  Future<void> _runAllocation() async {
    final dozen = double.tryParse(_dozenController.text) ?? 0;
    if (_selectedItem == null ||
        _selectedSize == null ||
        _selectedDia == null ||
        dozen <= 0 ||
        _dozenWeight <= 0) {
      _showError(
        'Please select Item, Size, Dia and enter positive Dozen & Weight',
      );
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
          _allocations = List<Map<String, dynamic>>.from(
            result['allocations'] ?? [],
          );
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

  void _nextDay() {
    if (_allocations.isEmpty) {
      _showError('No allocations for $_selectedDay. Run FIFO first.');
      return;
    }

    // 1. Store current day's allocations
    for (var a in _allocations) {
      _allWeekAllocations.add({
        ...a,
        'day': _selectedDay,
        'itemName': _selectedItem,
        'size': _selectedSize,
        'dia': _selectedDia,
        'lotNameAssigned': _lotNameController.text,
        'gsm': _gsmController.text,
        'dozenWeight': _dozenWeight,
        'efficiency': _efficiencyController.text,
        'foldingWeight': _foldingWeightController.text,
      });
    }

    // 2. Move to next day
    final currentIndex = _kWeekDays.indexOf(_selectedDay);
    if (currentIndex < _kWeekDays.length - 1) {
      setState(() {
        _selectedDay = _kWeekDays[currentIndex + 1];
        _allocations = []; // Clear for next day
        // Keep plan selected but clear item-specifics if desired, 
        // or keep them if client wants to reuse same setup
        _selectedItem = null;
        _selectedSize = null;
        _selectedDia = null;
        _lotNameController.clear();
        _dozenController.clear();
        _dozenWeightController.clear();
      });
      _showSuccess('Monday Data Recorded. Now select for $_selectedDay');
    }
  }

  Future<void> _saveWeeklyAllocation() async {
    // Collect Saturday's data if not already added
    if (_selectedDay == 'Saturday' && _allocations.isNotEmpty) {
      for (var a in _allocations) {
        if (!_allWeekAllocations.any((aw) => aw['day'] == 'Saturday' && aw['lotNo'] == a['lotNo'])) {
           _allWeekAllocations.add({
            ...a,
            'day': 'Saturday',
            'itemName': _selectedItem,
            'size': _selectedSize,
            'dia': _selectedDia,
            'lotNameAssigned': _lotNameController.text,
            'gsm': _gsmController.text,
            'dozenWeight': _dozenWeight,
            'efficiency': _efficiencyController.text,
            'foldingWeight': _foldingWeightController.text,
          });
        }
      }
    }

    if (_selectedPlanId == null || _allWeekAllocations.isEmpty) {
      _showError('No allocations to save.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final success = await _api.saveLotAllocation(
        _selectedPlanId!,
        _allWeekAllocations,
      );
      if (success) {
        _showSuccess('Weekly Allocations Saved Successfully');
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

  void _printWeekly() {
    if (_allWeekAllocations.isEmpty && _allocations.isEmpty) {
      _showError('No details to print.');
      return;
    }

    final plan = _allPlans.firstWhere((p) => p['_id'] == _selectedPlanId);
    final planId = plan['planId'] ?? 'N/A';
    final planPeriod = plan['planPeriod'] ?? 'N/A';

    // Temporary list for print if not saved yet
    List<Map<String, dynamic>> printList = List.from(_allWeekAllocations);
    if (_allocations.isNotEmpty) {
      for (var a in _allocations) {
        if (!printList.any((pl) => pl['day'] == _selectedDay && pl['lotNo'] == a['lotNo'])) {
          printList.add({...a, 'day': _selectedDay});
        }
      }
    }

    _printServiceWeekly.printWeeklyAllocations(planId, planPeriod, printList);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LOT REQUIREMENT ALLOCATION'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printWeekly,
            tooltip: 'Print Weekly Plan',
          ),
        ],
      ),

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
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: color,
        ),
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
          items: _allPlans
              .map(
                (p) => DropdownMenuItem(
                  value: p['_id'].toString(),
                  child: Text('${p['planType']} - ${p['planPeriod']}'),
                ),
              )
              .toList(),
          onChanged: _onPlanSelected,
        ),
      ),
    );
  }

  Widget _buildRequirementCard() {
    List<String> sizes = _masterSizes;
    if (_selectedPlanId != null && _selectedItem != null) {
      final plan = _allPlans.firstWhere(
        (p) => p['_id'] == _selectedPlanId,
        orElse: () => null,
      );
      if (plan != null) {
        final entry = (plan['cuttingEntries'] as List).firstWhere(
          (e) => e['itemName'] == _selectedItem,
          orElse: () => null,
        );
        if (entry != null) {
          final planSizes = (entry['sizeQuantities'] as Map).keys
              .where((k) => (entry['sizeQuantities'][k] ?? 0) > 0)
              .map((k) => k.toString())
              .toList();
          if (planSizes.isNotEmpty) {
            sizes = planSizes;
          }
        }
      }
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CustomDropdownField(
              label: 'Item Name',
              items: _masterItemNames,
              value: _selectedItem,
              onChanged: _onItemSelected,
              hint: 'Select Item',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDay,
                    decoration: const InputDecoration(labelText: 'Selection Day'),
                    items: _kWeekDays
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedDay = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomDropdownField(
                    label: 'Size',
                    items: sizes,
                    value: sizes.contains(_selectedSize) ? _selectedSize : null,
                    onChanged: _onSizeSelected,
                    hint: 'Select Size',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomDropdownField(
                    label: 'Dia',
                    items: _dias,
                    value: _selectedDia,
                    onChanged: _onDiaSelected,
                    hint: 'Select Dia',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            TextFormField(
              controller: _lotNameController,
              decoration: const InputDecoration(
                labelText: 'Assigned Lot Name',
                hintText: 'Enter Lot Name',
              ),
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
                    decoration: const InputDecoration(
                      labelText: 'Efficiency %',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _foldingWeightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Folding Weight (Kg)',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _wasteController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Waste %',
                      filled: true,
                      fillColor: Color(0xFFF1F5F9),
                    ),
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
                    decoration: const InputDecoration(
                      labelText: 'Dozen (Modify)',
                      helperText: 'Modify planned dozen if needed',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _dozenWeightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Dozen Weight (Kg)',
                    ),
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
                  _buildCalcItem(
                    'Required Weight',
                    '${_fabricRequiredKg.toStringAsFixed(2)} KG',
                    primaryColor,
                  ),
                  _buildCalcItem(
                    'Rolls Need',
                    '~$_rollsRequired Rolls',
                    primaryColor,
                  ),
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
                label: Text(
                  _isAllocating ? 'ALLOCATING...' : 'AUTO FIFO ALLOCATE',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
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

  Widget _buildCalcItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
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
              child: Center(
                child: Text(
                  'No allocations yet. Run FIFO to see lots.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                columns: const [
                  DataColumn(label: Text('LOT NAME')),
                  DataColumn(label: Text('LOT NO')),
                  DataColumn(label: Text('SET')),
                  DataColumn(label: Text('DIA')),
                  DataColumn(label: Text('RACK')),
                  DataColumn(label: Text('PALLET NO')),
                  DataColumn(label: Text('DOZEN')),
                ],
                rows: _allocations
                    .map(
                      (a) => DataRow(
                        cells: [
                          DataCell(Text(a['lotName'] ?? '')),
                          DataCell(Text(a['lotNo'] ?? '-')),
                          DataCell(Text(a['setNum']?.toString() ?? '-')),
                          DataCell(Text(a['dia']?.toString() ?? '')),
                          DataCell(Text(a['rackName'] ?? '')),
                          DataCell(Text(a['palletNumber'] ?? '')),
                          DataCell(Text(a['dozen']?.toString() ?? '0')),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }

  Widget _buildSaveButton(Color primaryColor) {
    final bool isSaturday = _selectedDay == 'Saturday';

    return Column(
      children: [
        if (!isSaturday)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _nextDay,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'NEXT DAY',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        if (!isSaturday) const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveWeeklyAllocation,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              backgroundColor: ColorPalette.success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    isSaturday ? 'SAVE WEEKLY ALLOCATION' : 'SAVE CURRENT ONLY',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
