import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/app_drawer.dart';
import '../reports/lot_allocation_summary_report.dart';
import 'package:share_plus/share_plus.dart';

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
  String _selectedDay = DateFormat('EEEE').format(DateTime.now());
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  double _dozen = 0;
  final _dozenController = TextEditingController();

  List<dynamic> _allocations = [];
  bool _isAllocating = false;

  List<dynamic> _assignments = [];
  double _dozenWeight = 0;
  double _foldingWt = 0;
  String _dia = '';
  String _gsm = '';

  double get _fabricRequiredKg => _dozen * (_dozenWeight + _foldingWt);
  int get _rollsRequired => (_fabricRequiredKg / 20).ceil();
  double get _setsRequired => _rollsRequired / 11;

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

      double plannedDozen = 0;
      if (entry != null) {
        plannedDozen = (entry['sizeQuantities'][_selectedSize] ?? 0).toDouble();
      }

      // Calculate already allocated dozen for this item and size
      double allocatedDozen = 0;
      if (_selectedPlan!['lotAllocations'] != null) {
        final alcs = _selectedPlan!['lotAllocations'] as List;
        for (var a in alcs) {
          if (a['itemName'] == _selectedItem && a['size'] == _selectedSize) {
            allocatedDozen += (a['dozen'] ?? 0).toDouble();
          }
        }
      }

      final double remaining = plannedDozen - allocatedDozen;

      setState(() {
        _dozen = remaining > 0 ? remaining : 0;
        _dozenController.text = _dozen.toString();

        if (assignment != null) {
          _dozenWeight = (assignment['dozenWeight'] ?? 0).toDouble();
          _foldingWt = (assignment['foldingWt'] ?? 0).toDouble();
          _dia = (assignment['dia'] ?? '').toString();
          _gsm = (assignment['gsm'] ?? '').toString();
        } else {
          _dozenWeight = 0;
          _foldingWt = 0;
          _dia = '';
          _gsm = '';
        }
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
      final List<Map<String, dynamic>> finalAllocations = _allocations.map((a) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(a as Map);
        return <String, dynamic>{
          ...map,
          'itemName': _selectedItem,
          'size': _selectedSize,
          'day': _selectedDay,
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'time': _selectedTime.format(context),
          'allocationId': 'ALC-${DateTime.now().millisecondsSinceEpoch}',
        };
      }).toList();

      final success = await _api.saveLotAllocation(
        _selectedPlan!['_id'],
        finalAllocations,
      );
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Allocations Saved Successfully')),
        );
        // Refresh plan to update balance
        await _loadPlans();
        // Clear form for next entry but keep same Day/Date
        setState(() {
          _selectedItem = null;
          _selectedSize = null;
          _dozen = 0;
          _dozenController.text = '0';
          _allocations = [];
        });
      }
    } catch (e) {
      _showError('Save failed: $e');
    } finally {
      setState(() => _isSaving = false);
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
      appBar: AppBar(
        title: const Text('LOT REQUIREMENT & ALLOCATION'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LotAllocationSummaryReportScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareViaWhatsApp,
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
                  _buildPlanSelector(),
                  const SizedBox(height: 16),
                  _buildDateTimeSelectors(),
                  const SizedBox(height: 20),
                  if (_selectedPlanId != null) _buildAllocationForm(),
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

  Widget _buildDateTimeSelectors() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDay,
                    decoration: const InputDecoration(labelText: 'DAY'),
                    items:
                        [
                              'Monday',
                              'Tuesday',
                              'Wednesday',
                              'Thursday',
                              'Friday',
                              'Saturday',
                            ]
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                    onChanged: (val) => setState(() => _selectedDay = val!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) setState(() => _selectedDate = date);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'DATE'),
                      child: Text(
                        DateFormat('dd-MM-yyyy').format(_selectedDate),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (time != null) setState(() => _selectedTime = time);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'TIME'),
                child: Text(_selectedTime.format(context)),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildInfoItem('DIA', _dia)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildInfoItem('GSM', _gsm)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCalcItem(
                          'FABRIC REQ',
                          '${_fabricRequiredKg.toStringAsFixed(2)} KG',
                        ),
                        _buildCalcItem('ROLLS REQ', '$_rollsRequired'),
                        _buildCalcItem(
                          'SETS REQ',
                          _setsRequired.toStringAsFixed(2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAllocating ? null : _runFifoAllocation,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(_isAllocating ? 'ALLOCATING...' : 'AUTO FIFO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetForm,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('NEXT PAGE'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCalcItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _resetForm() {
    setState(() {
      _selectedItem = null;
      _selectedSize = null;
      _dozen = 0;
      _dozenController.text = '0';
      _allocations = [];
      _dozenWeight = 0;
      _foldingWt = 0;
      _dia = '';
      _gsm = '';
    });
  }

  Widget _buildAllocationTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
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
                DataColumn(label: Text('SET NO')),
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
                        DataCell(Text(a['setNum'] ?? 'N/A')),
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

  void _shareViaWhatsApp() {
    if (_allocations.isEmpty) {
      _showError('No allocations to share');
      return;
    }

    final planStr = _selectedPlan != null ? _selectedPlan!['planId'] : 'N/A';
    String text = "*LOT ALLOCATION SUMMARY*\n\n";
    text += "Plan: $planStr\n";
    text += "Item: ${_selectedItem ?? 'N/A'}\n";
    text += "Size: ${_selectedSize ?? 'N/A'}\n";
    text += "Date: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}\n";
    text += "Day: $_selectedDay\n\n";

    text += "ALLOCATIONS:\n";
    for (var a in _allocations) {
      text += "- Lot: ${a['lotName']} (${a['lotNo']})\n";
      text +=
          "  Set: ${a['setNum'] ?? 'N/A'}, Dozen: ${a['dozen']}, Wt: ${a['weight']}kg\n";
      text += "  Loc: ${a['rackName'] ?? ''} / ${a['palletNumber'] ?? ''}\n\n";
    }

    Share.share(text);
  }
}
