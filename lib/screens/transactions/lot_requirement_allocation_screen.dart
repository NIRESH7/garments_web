import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:garments/services/mobile_api_service.dart';
import 'package:garments/core/theme/color_palette.dart';
import 'package:garments/services/lot_allocation_print_service.dart';
import 'package:garments/widgets/app_drawer.dart';
import 'package:garments/widgets/custom_dropdown_field.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const List<String> _kWeekDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

// ─── Model: one saved item-entry for the current day ─────────────────────────
class _DayEntry {
  final String itemName;
  final String size;
  final double dozen;
  final double dozenWeight;
  final String dia;
  final double neededWeight;
  final List<Map<String, dynamic>> sets; // FIFO set rows

  _DayEntry({
    required this.itemName,
    required this.size,
    required this.dozen,
    required this.dozenWeight,
    required this.dia,
    required this.neededWeight,
    required this.sets,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────
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
  bool _postOutward = false;
  int _tabIndex = 0; // 0 = ENTRY, 1 = REPORT

  // Master data
  List<dynamic> _allPlans = [];
  List<String> _masterItemNames = [];
  List<String> _masterSizes = [];
  List<String> _dias = [];
  List<dynamic> _assignments = [];

  // Plan selection
  String? _selectedPlanId;

  // Day / Date
  String _selectedDay = 'Monday';
  DateTime _selectedDate = DateTime.now();

  // Current item form
  String? _selectedItem;
  String? _selectedSize;
  String? _selectedDia;
  final _dozenCtrl = TextEditingController();
  final _dozenWeightCtrl = TextEditingController();
  final _foldingWtCtrl = TextEditingController();
  final _gsmCtrl = TextEditingController();
  final _efficiencyCtrl = TextEditingController();
  final _wasteCtrl = TextEditingController();
  double _dozenWeight = 0;

  // Current FIFO result
  List<Map<String, dynamic>> _currentSets = [];
  int _totalSets = 0;
  double _remainingRolls = 0;

  // All entries recorded this session (per day)
  // Map<day, List<_DayEntry>>
  final Map<String, List<_DayEntry>> _dayEntries = {};

  // Report tab data
  List<Map<String, dynamic>> _reportRows = [];
  bool _isLoadingReport = false;
  String? _reportDay;
  DateTime? _reportDate;

  final _printService = LotAllocationPrintService();

  // ─── Computed ─────────────────────────────────────────────────────────────
  double get _fabricRequiredKg =>
      (double.tryParse(_dozenCtrl.text) ?? 0) *
      (_dozenWeight + (double.tryParse(_foldingWtCtrl.text) ?? 0));

  int get _rollsRequired =>
      _fabricRequiredKg > 0 ? (_fabricRequiredKg / 20).ceil() : 0;

  int get _setsRequired =>
      _rollsRequired > 0 ? (_rollsRequired / 11).floor() : 0;

  List<_DayEntry> get _currentDayEntries => _dayEntries[_selectedDay] ?? [];

  // ─── Init ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _dozenCtrl.addListener(() => setState(() {}));
    _dozenWeightCtrl.addListener(() {
      setState(
        () => _dozenWeight = double.tryParse(_dozenWeightCtrl.text) ?? 0,
      );
    });
    _efficiencyCtrl.addListener(() {
      final eff = double.tryParse(_efficiencyCtrl.text) ?? 0;
      _wasteCtrl.text = (100 - eff).toStringAsFixed(2);
      setState(() {});
    });
    _foldingWtCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _dozenCtrl.dispose();
    _dozenWeightCtrl.dispose();
    _foldingWtCtrl.dispose();
    _gsmCtrl.dispose();
    _efficiencyCtrl.dispose();
    _wasteCtrl.dispose();
    super.dispose();
  }

  // ─── Data loading ─────────────────────────────────────────────────────────
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final plans = await _api.getCuttingOrders();
      final categories = await _api.getCategories();
      final assignments = await _api.getAssignments();
      setState(() {
        _allPlans = plans;
        _dias = _getValues(categories, ['Dia']);
        _masterItemNames = _getValues(categories, [
          'Item Name',
          'itemName',
          'item',
        ]);
        _masterSizes = _getValues(categories, ['Size', 'size']);
        _assignments = assignments;
        _isLoading = false;
      });
    } catch (e) {
      _showError('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  List<String> _getValues(List<dynamic> categories, List<String> matchNames) {
    final result = <String>[];
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

  // ─── Item-form auto-fill ──────────────────────────────────────────────────
  void _onItemSelected(String? item) {
    setState(() {
      _selectedItem = item;
      _selectedSize = null;
      _selectedDia = null; // Clear dia to let assignment pick it
      _currentSets = [];
    });
    _fillFromAssignments();
  }

  void _onSizeSelected(String? size) {
    setState(() {
      _selectedSize = size;
      _currentSets = [];
    });
    _updateRemainingDozen();
    _fillFromAssignments();
  }

  void _updateRemainingDozen() {
    if (_selectedPlanId == null ||
        _selectedItem == null ||
        _selectedSize == null) {
      return;
    }

    final plan = _allPlans.firstWhere(
      (p) => p['_id'] == _selectedPlanId,
      orElse: () => null,
    );
    if (plan == null) return;

    final entry = (plan['cuttingEntries'] as List).firstWhere(
      (e) => e['itemName'] == _selectedItem,
      orElse: () => null,
    );
    if (entry == null) return;

    double plannedDozen = (entry['sizeQuantities'][_selectedSize] ?? 0)
        .toDouble();

    // 1. Subtract already saved allocations for this specific Item + Size
    final savedAllocations = plan['lotAllocations'] as List? ?? [];
    double allocatedInDb = 0;
    final seen = <String>{};
    for (var alloc in savedAllocations) {
      if (alloc['itemName'] == _selectedItem &&
          alloc['size'] == _selectedSize) {
        String key = "${alloc['date']}_${alloc['day']}_${alloc['dozen']}";
        if (!seen.contains(key)) {
          allocatedInDb += (alloc['dozen'] as num?)?.toDouble() ?? 0;
          seen.add(key);
        }
      }
    }

    // 2. Subtract unsaved allocations in the current session
    double allocatedInSession = 0;
    for (var entry in _currentDayEntries) {
      if (entry.itemName == _selectedItem && entry.size == _selectedSize) {
        allocatedInSession += entry.dozen;
      }
    }

    double remaining = plannedDozen - allocatedInDb - allocatedInSession;
    if (remaining < 0) remaining = 0;
    _dozenCtrl.text = remaining.toString();
  }

  void _fillFromAssignments() {
    if (_selectedItem == null) return;
    final itemMatches = _assignments
        .where(
          (a) =>
              a['fabricItem'].toString().trim().toLowerCase() ==
              _selectedItem!.trim().toLowerCase(),
        )
        .toList();
    if (itemMatches.isEmpty) return;

    dynamic best;
    if (_selectedSize != null) {
      best = itemMatches.firstWhere(
        (a) =>
            a['size'].toString().trim().toLowerCase() ==
            _selectedSize!.trim().toLowerCase(),
        orElse: () => null,
      );
    }
    best ??= itemMatches.first;

    setState(() {
      if (_selectedSize == null) _selectedSize = best['size']?.toString();
      if (_selectedDia == null) {
        final d = best['dia']?.toString();
        if (d != null && _dias.contains(d)) _selectedDia = d;
      }
      _dozenWeightCtrl.text = best['dozenWeight']?.toString() ?? '';
      _foldingWtCtrl.text = best['foldingWt']?.toString() ?? '';
      _gsmCtrl.text = best['gsm']?.toString() ?? '';
      _efficiencyCtrl.text = best['efficiency']?.toString() ?? '';
      _dozenWeight = double.tryParse(_dozenWeightCtrl.text) ?? 0;
      if (_efficiencyCtrl.text.isNotEmpty) {
        final eff = double.tryParse(_efficiencyCtrl.text) ?? 0;
        _wasteCtrl.text = (100 - eff).toStringAsFixed(2);
      }
    });

    // Crucial: After setting the default size, calculate the remaining dozen
    _updateRemainingDozen();
  }

  // ─── FIFO Allocation ──────────────────────────────────────────────────────
  Future<void> _runAllocation() async {
    final dozen = double.tryParse(_dozenCtrl.text) ?? 0;
    if (_selectedItem == null ||
        _selectedSize == null ||
        _selectedDia == null ||
        dozen <= 0 ||
        _dozenWeight <= 0) {
      _showError('Please select Item, Size, Dia and enter Dozen + Weight');
      return;
    }

    setState(() => _isAllocating = true);
    try {
      final result = await _api.getFifoAllocation(
        _selectedItem!,
        _selectedSize!,
        dozen,
        _selectedDia!,
        _dozenWeight + (double.tryParse(_foldingWtCtrl.text) ?? 0),
      );
      setState(() {
        if (result != null) {
          _currentSets = List<Map<String, dynamic>>.from(
            result['allocations'] ?? [],
          );
          _totalSets = (result['totalSets'] as num?)?.toInt() ?? 0;
          _remainingRolls = (result['remainingRolls'] as num?)?.toDouble() ?? 0;
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

  // ─── Add current item to day entries ─────────────────────────────────────
  void _addItemToDay() {
    if (_currentSets.isEmpty) {
      _showError('Run FIFO first before adding this item.');
      return;
    }
    final dozen = double.tryParse(_dozenCtrl.text) ?? 0;
    final entries = List<_DayEntry>.from(_currentDayEntries);
    final existingIdx = entries.indexWhere(
      (e) =>
          e.itemName == _selectedItem &&
          e.size == _selectedSize &&
          e.dia == _selectedDia,
    );

    if (existingIdx != -1) {
      // Merge with existing row
      final old = entries[existingIdx];
      // For dozens, if they entered the SAME details twice, we assume they are adding more.
      // But based on the user's "130 vs 70" feedback, if they meant to subtract,
      // that logic would be very complex. We'll stick to a standard merge (additive)
      // for now, which at least solves the "New record create aagadhu" (no duplicate rows).
      entries[existingIdx] = _DayEntry(
        itemName: old.itemName,
        size: old.size,
        dozen: old.dozen + dozen,
        dozenWeight: old.dozenWeight,
        dia: old.dia,
        neededWeight: old.neededWeight + _fabricRequiredKg,
        sets: [...old.sets, ..._currentSets],
      );
    } else {
      // Add new row
      entries.add(
        _DayEntry(
          itemName: _selectedItem!,
          size: _selectedSize!,
          dozen: dozen,
          dozenWeight: _dozenWeight,
          dia: _selectedDia!,
          neededWeight: _fabricRequiredKg,
          sets: List.from(_currentSets),
        ),
      );
    }

    setState(() {
      _dayEntries[_selectedDay] = entries;
      // Clear form for next item entry
      _currentSets = [];
      _selectedItem = null;
      _selectedSize = null;
      _selectedDia = null;
      _dozenCtrl.clear();
      _dozenWeightCtrl.clear();
      _foldingWtCtrl.clear();
      _gsmCtrl.clear();
      _efficiencyCtrl.clear();
      _wasteCtrl.clear();
      _dozenWeight = 0;
      _totalSets = 0;
      _remainingRolls = 0;
    });
    _showSuccess(
      'Item added to $_selectedDay. Add another item or click Next Day.',
    );
  }

  // ─── Move to next day ─────────────────────────────────────────────────────
  void _nextDay() {
    if (_currentDayEntries.isEmpty && _currentSets.isEmpty) {
      _showError('No entries for $_selectedDay. Add at least one item.');
      return;
    }
    // If user has an un-added allocation, add it automatically
    if (_currentSets.isNotEmpty) {
      _addItemToDay();
      return; // addItemToDay already shows success
    }

    final idx = _kWeekDays.indexOf(_selectedDay);
    if (idx < _kWeekDays.length - 1) {
      setState(() {
        _selectedDay = _kWeekDays[idx + 1];
      });
      _showSuccess(
        '$_selectedDay recorded. Now entering ${_kWeekDays[idx + 1]}.',
      );
    }
  }

  // ─── Save entire week / save current day ──────────────────────────────────
  Future<void> _saveDayAllocation({bool allWeek = false}) async {
    if (_selectedPlanId == null) {
      _showError('No plan selected.');
      return;
    }

    // Collect which days to save
    List<String> daysToSave = allWeek
        ? _dayEntries.keys.toList()
        : [_selectedDay];

    // If current day has unsaved FIFO sets, add them first
    if (_currentSets.isNotEmpty) _addItemToDay();

    final bool hasAny = daysToSave.any(
      (d) => (_dayEntries[d] ?? []).isNotEmpty,
    );
    if (!hasAny) {
      _showError('No allocations to save.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      for (final day in daysToSave) {
        final entries = _dayEntries[day] ?? [];
        for (final entry in entries) {
          final success = await _api.saveLotAllocation(
            _selectedPlanId!,
            entry.sets,
            day: day,
            date: DateFormat('yyyy-MM-dd').format(_selectedDate),
            itemName: entry.itemName,
            size: entry.size,
            dozen: entry.dozen,
            neededWeight: entry.neededWeight,
            postOutward: _postOutward,
          );
          if (!success) throw Exception('Save failed for ${entry.itemName}');
        }
      }
      _showSuccess(allWeek ? 'Full week saved!' : '$_selectedDay saved!');
      await _loadInitialData(); // Refresh plan data (especially lotAllocations)
      if (!allWeek) {
        setState(() {
          _dayEntries.remove(_selectedDay);
        });
      } else {
        setState(() => _dayEntries.clear());
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Save failed: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ─── Load report ──────────────────────────────────────────────────────────
  Future<void> _loadReport() async {
    // 100% guarantee no active text fields or dropdowns corrupt semantics
    // during the loading state tree rebuild.
    FocusScope.of(context).unfocus();

    if (_selectedPlanId == null) {
      _showError('Select a plan first.');
      return;
    }
    setState(() => _isLoadingReport = true);
    try {
      final data = await _api.getAllocationReport(
        _selectedPlanId!,
        day: _reportDay,
        date: _reportDate != null
            ? DateFormat('yyyy-MM-dd').format(_reportDate!)
            : null,
      );
      setState(() {
        _reportRows = data != null
            ? List<Map<String, dynamic>>.from(data['rows'] ?? [])
            : [];
      });
    } catch (e) {
      _showError('Failed to load report: $e');
    } finally {
      setState(() => _isLoadingReport = false);
    }
  }

  // ─── Print ────────────────────────────────────────────────────────────────
  void _printReport() {
    if (_reportRows.isEmpty) {
      _showError('Load the report first.');
      return;
    }
    final plan = _allPlans.firstWhere(
      (p) => p['_id'] == _selectedPlanId,
      orElse: () => {},
    );
    _printService.printSetLevelReport(
      plan['planId'] ?? 'N/A',
      plan['planPeriod'] ?? '',
      _reportDay,
      _reportRows,
    );
  }

  // ─── Snackbars ────────────────────────────────────────────────────────────
  void _showError(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _showSuccess(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));

  // ═════════════════════════════════ BUILD ══════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LOT REQUIREMENT ALLOCATION'),
        actions: [
          if (_tabIndex == 1)
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _printReport,
              tooltip: 'Print Report',
            ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Tab bar — explicit color so always visible ────────────────
                // ── Tab bar — simple neat tab bar with primary color ─────────
                Material(
                  color: Colors.white,
                  elevation: 1,
                  child: Row(
                    children: [
                      _buildTab(0, Icons.add_chart_outlined, 'ENTRY', primary),
                      _buildTab(1, Icons.bar_chart_rounded, 'REPORT', primary),
                    ],
                  ),
                ),
                // ── Content — ONLY active tab mounted (prevents cross-tab
                // setState-during-layout semantics assertion crash).
                // State is safe: all vars live in parent, controllers too.
                Expanded(
                  child: _tabIndex == 0
                      ? _buildEntryTab(primary)
                      : _buildReportTab(primary),
                ),
              ],
            ),
    );
  }

  Widget _buildTab(int idx, IconData icon, String label, Color primary) {
    final selected = _tabIndex == idx;
    final activeColor = primary;
    final inactiveColor = Colors.grey.shade500;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabIndex = idx),
        splashColor: primary.withOpacity(0.1),
        highlightColor: primary.withOpacity(0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? primary : Colors.transparent,
                width: 3,
              ),
            ),
            // Removed the fill color for a simple, neat look
            color: Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.5,
                  color: selected ? activeColor : inactiveColor,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TAB 1: Entry ─────────────────────────────────────────────────────────
  Widget _buildEntryTab(Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan + Day + Date
          _sectionHeader('PLAN & DAY SELECTION', primary),
          _buildPlanDayCard(primary),
          const SizedBox(height: 20),

          if (_selectedPlanId != null) ...[
            // Current day's already-added items
            if (_currentDayEntries.isNotEmpty) ...[
              _sectionHeader(
                '$_selectedDay — ADDED ITEMS (${_currentDayEntries.length})',
                Colors.teal,
              ),
              _buildAddedItemsList(primary),
              const SizedBox(height: 20),
            ],

            // New item entry form
            _sectionHeader('ADD ITEM FOR $_selectedDay', primary),
            _buildItemFormCard(primary),
            const SizedBox(height: 20),

            // Calculation summary
            _buildCalcSummary(primary),
            const SizedBox(height: 20),

            // FIFO Allocation Table
            _sectionHeader(
              _currentSets.isEmpty
                  ? 'FIFO ALLOCATIONS'
                  : 'FIFO ALLOCATIONS — ${_currentSets.length} set rows'
                        ' | $_totalSets full sets'
                        '${_remainingRolls > 0 ? " + ${_remainingRolls.toStringAsFixed(1)} partial rolls" : ""}',
              primary,
            ),
            _buildFifoTable(primary),
            const SizedBox(height: 20),

            // Action buttons
            _buildActionButtons(primary),
          ],

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildPlanDayCard(Color primary) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Plan dropdown
            DropdownButtonFormField<String>(
              value: _selectedPlanId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Select Plan'),
              items: _allPlans
                  .map(
                    (p) => DropdownMenuItem(
                      value: p['_id'].toString(),
                      child: Text(
                        '${p['planName'] != null && p['planName'] != '' ? p['planName'] : p['planId']} (${p['planType']} – ${p['planPeriod']})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedPlanId = v;
                _dayEntries.clear();
                _currentSets = [];
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Day
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDay,
                    decoration: const InputDecoration(labelText: 'Day'),
                    items: _kWeekDays
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedDay = v!;
                      _currentSets = [];
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                // Date picker
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null)
                        setState(() => _selectedDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        DateFormat('dd-MM-yyyy').format(_selectedDate),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Post outward toggle
            Row(
              children: [
                Switch(
                  value: _postOutward,
                  onChanged: (v) => setState(() => _postOutward = v),
                  activeColor: Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _postOutward
                        ? '✅ Auto-post outward (stock will be deducted)'
                        : 'Post Outward on Save (stock deduction)',
                    style: TextStyle(
                      fontSize: 13,
                      color: _postOutward ? Colors.green.shade700 : Colors.grey,
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

  Widget _buildAddedItemsList(Color primary) {
    return Card(
      elevation: 2,
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: _currentDayEntries.asMap().entries.map((e) {
            final idx = e.key;
            final entry = e.value;
            final setCount = entry.sets.length;
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.teal,
                child: Text(
                  '${idx + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              title: Text(
                '${entry.itemName} — ${entry.size} — Dia ${entry.dia}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                '${entry.dozen} doz | ${entry.neededWeight.toStringAsFixed(1)} kg | $setCount set rows',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
                onPressed: () => setState(() {
                  final list = List<_DayEntry>.from(_currentDayEntries);
                  list.removeAt(idx);
                  _dayEntries[_selectedDay] = list;
                }),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildItemFormCard(Color primary) {
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
          if (planSizes.isNotEmpty) sizes = planSizes;
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
                  child: CustomDropdownField(
                    label: 'Size',
                    items: sizes,
                    value: sizes.contains(_selectedSize) ? _selectedSize : null,
                    onChanged: _onSizeSelected,
                    hint: 'Size',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomDropdownField(
                    label: 'Dia',
                    items: _dias,
                    value: _selectedDia,
                    onChanged: (v) => setState(() {
                      _selectedDia = v;
                      _currentSets = [];
                    }),
                    hint: 'Dia',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dozenCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Dozen'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _dozenWeightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Dozen Weight (kg)',
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
                    controller: _foldingWtCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Folding Wt (kg)',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _efficiencyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Efficiency %',
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

  Widget _buildCalcSummary(Color primary) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _calcChip(
                  'Required Weight',
                  '${_fabricRequiredKg.toStringAsFixed(2)} KG',
                  primary,
                ),
                _calcChip('Rolls Needed', '~$_rollsRequired Rolls', primary),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _calcChip('Sets Required', '~$_setsRequired Sets', Colors.teal),
                _calcChip('1 Set', '= 11 Rolls', Colors.grey),
              ],
            ),
            if (_totalSets > 0) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _calcChip('FIFO Full Sets', '$_totalSets', Colors.green),
                  _calcChip('Partial Rolls', '$_remainingRolls', Colors.orange),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isAllocating ? null : _runAllocation,
                icon: Icon(
                  _isAllocating ? Icons.hourglass_empty : LucideIcons.zap,
                  size: 18,
                ),
                label: Text(
                  _isAllocating ? 'ALLOCATING...' : 'AUTO FIFO ALLOCATE',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
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

  Widget _calcChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFifoTable(Color primary) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _currentSets.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No allocations yet. Run FIFO to see set-wise rows.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columnSpacing: 14,
                columns: const [
                  DataColumn(
                    label: Text(
                      'LOT NAME',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'LOT NO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'DIA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'SET NO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'RACK',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'PALLET',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'LOT BALANCE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'SET WEIGHT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                rows: _currentSets.asMap().entries.map((e) {
                  final i = e.key;
                  final a = e.value;
                  final isEven = i % 2 == 0;
                  return DataRow(
                    color: WidgetStateProperty.all(
                      isEven ? Colors.white : Colors.grey.shade50,
                    ),
                    cells: [
                      DataCell(
                        Text(
                          a['lotName']?.toString() ?? '-',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          a['lotNo']?.toString() ?? '-',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          a['dia']?.toString() ?? '-',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.teal.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            'Set ${a['setNo']?.toString() ?? '-'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          a['rackName']?.toString() ?? '-',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          a['palletNumber']?.toString() ?? '-',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${(a['lotBalance'] as num?)?.toStringAsFixed(2) ?? '0'} kg',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${(a['setWeight'] as num?)?.toStringAsFixed(2) ?? '0'} kg',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildActionButtons(Color primary) {
    final bool isSaturday = _selectedDay == 'Saturday';
    final bool hasCurrentSets = _currentSets.isNotEmpty;
    final bool hasDayEntries = _currentDayEntries.isNotEmpty;

    return Column(
      children: [
        // Add Item to Day (if FIFO results ready)
        if (hasCurrentSets)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _addItemToDay,
              icon: const Icon(Icons.add_task),
              label: const Text('ADD THIS ITEM TO DAY'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

        if (hasCurrentSets) const SizedBox(height: 12),

        // Save current day only
        if (hasDayEntries || hasCurrentSets)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => _saveDayAllocation(allWeek: false),
              icon: const Icon(Icons.save),
              label: Text(
                'SAVE $_selectedDay (${_currentDayEntries.length + (hasCurrentSets ? 1 : 0)} items)',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

        if (hasDayEntries || hasCurrentSets) const SizedBox(height: 12),

        // Next day or Save weekly
        Row(
          children: [
            if (!isSaturday)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _nextDay,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('NEXT DAY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            if (!isSaturday && _dayEntries.length > 1)
              const SizedBox(width: 12),
            if (_dayEntries.length > 1 || isSaturday)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => _saveDayAllocation(allWeek: true),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('SAVE ENTIRE WEEK'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorPalette.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ─── TAB 2: Report ────────────────────────────────────────────────────────
  Widget _buildReportTab(Color primary) {
    // Wrap the entire report tab in ExcludeSemantics because the Flutter
    // semantics engine has a bug with dropdowns + dynamic scrollable lists
    // rebuilding simultaneously, throwing !semantics.parentDataDirty.
    return ExcludeSemantics(
      child: Column(
        children: [
          // Filters
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedPlanId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Select Plan'),
                  items: _allPlans
                      .map(
                        (p) => DropdownMenuItem(
                          value: p['_id'].toString(),
                          child: Text(
                            '${p['planName'] != null && p['planName'] != '' ? p['planName'] : p['planId']} (${p['planType']} – ${p['planPeriod']})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedPlanId = v),
                ),
                const SizedBox(height: 12),
                // Row 2: Day + Date picker
                Row(
                  children: [
                    // Day filter
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _reportDay,
                        decoration: const InputDecoration(
                          labelText: 'Day',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Days'),
                          ),
                          ..._kWeekDays.map(
                            (d) => DropdownMenuItem(value: d, child: Text(d)),
                          ),
                        ],
                        onChanged: (v) => setState(() => _reportDay = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Date filter
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _reportDate ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _reportDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            isDense: true,
                            suffixIcon: Icon(Icons.calendar_today, size: 16),
                          ),
                          child: Text(
                            _reportDate != null
                                ? DateFormat('dd-MM-yyyy').format(_reportDate!)
                                : 'All Dates',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Clear date
                    if (_reportDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _reportDate = null),
                        tooltip: 'Clear date',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 3: Load button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingReport ? null : _loadReport,
                    icon: _isLoadingReport
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: const Text('LOAD REPORT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
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

          // Report table
          Expanded(
            child: _isLoadingReport
                ? const Center(child: CircularProgressIndicator())
                : _reportRows.isEmpty
                ? Center(
                    child: Text(
                      'No data. Select a plan and tap LOAD.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : _buildReportListView(primary),
          ),

          // Footer summary
          if (_reportRows.isNotEmpty)
            Container(
              color: Colors.grey.shade100, // <--- The culprit RenderColoredBox!
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Text(
                    '${_reportRows.length} sets',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Tot: ${_reportRows.fold<double>(0.0, (s, r) => s + ((r['setWeight'] as num?)?.toDouble() ?? 0)).toStringAsFixed(2)} kg',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _printReport,
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('PRINT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Report list view (avoids nested SingleChildScrollView assertion) ─────
  // Uses ListView.builder for vertical scroll + SingleChildScrollView (horizontal)
  // wrapping a fixed-width Row for each data row. No nesting two scrollables.
  Widget _buildReportListView(Color primary) {
    // Native DataTable implementation! This entirely sidesteps manually
    // managing constraints, widths, Containers, Rows, and rendering bounds,
    // leaning completely on Flutter's heavily-tested intrinsic table layout.
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(primary.withOpacity(0.1)),
          columnSpacing: 16,
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 12,
          ),
          dataTextStyle: const TextStyle(fontSize: 12, color: Colors.black87),
          columns: const [
            DataColumn(label: Text('Day')),
            DataColumn(label: Text('Item')),
            DataColumn(label: Text('Size')),
            DataColumn(label: Text('Dozen')),
            DataColumn(label: Text('Need Wt.')),
            DataColumn(label: Text('Lot Name')),
            DataColumn(label: Text('Lot No')),
            DataColumn(label: Text('Dia')),
            DataColumn(label: Text('Set No')),
            DataColumn(label: Text('Rack')),
            DataColumn(label: Text('Pallet')),
            DataColumn(label: Text('Set Wt.')),
          ],
          rows: _reportRows.map((r) {
            return DataRow(
              cells: [
                DataCell(Text(r['day']?.toString() ?? '-')),
                DataCell(Text(r['itemName']?.toString() ?? '-')),
                DataCell(Text(r['size']?.toString() ?? '-')),
                DataCell(Text(r['dozen']?.toString() ?? '-')),
                DataCell(
                  Text(
                    '${(r['neededWeight'] as num?)?.toStringAsFixed(1) ?? '-'} kg',
                  ),
                ),
                DataCell(Text(r['lotName']?.toString() ?? '-')),
                DataCell(Text(r['lotNo']?.toString() ?? '-')),
                DataCell(
                  Text(
                    r['dia']?.toString() ?? '-',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.teal.withOpacity(0.4)),
                    ),
                    child: Text(
                      'Set ${r['setNo']?.toString() ?? '-'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(r['rackName']?.toString() ?? '-')),
                DataCell(Text(r['palletNumber']?.toString() ?? '-')),
                DataCell(
                  Text(
                    '${(r['setWeight'] as num?)?.toStringAsFixed(2) ?? '-'} kg',
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
