import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:garments/services/mobile_api_service.dart';
import 'package:garments/core/theme/color_palette.dart';
import 'package:garments/services/lot_allocation_print_service.dart';
import 'package:garments/widgets/app_drawer.dart';
import 'package:garments/widgets/custom_dropdown_field.dart';
import 'package:share_plus/share_plus.dart';

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
  double _pendingDozenForSelection = 0;

  // Current FIFO result
  List<Map<String, dynamic>> _currentSets = [];
  int _totalSets = 0;

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

  // Formula: Required Weight / 20
  int get _rollsRequired {
    if (_fabricRequiredKg <= 0) return 0;
    
    // Total rolls estimate (weight / 20)
    final rolls = _fabricRequiredKg / 20;
    return rolls.round();
  }

  // Formula: Rolls Needed / 11 (rounded to nearest whole number)
  int get _setsRequired {
    if (_rollsRequired <= 0) return 0;
    
    final sets = (_rollsRequired / 11).round();
    return sets < 1 ? 1 : sets;
  }

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

    // 1. Subtract already saved allocations for this specific Item + Size in the DB
    final savedAllocations = plan['lotAllocations'] as List? ?? [];
    double allocatedInDb = 0;
    for (var alloc in savedAllocations) {
      if (alloc['itemName'] == _selectedItem &&
          alloc['size'] == _selectedSize) {
        allocatedInDb += (alloc['dozen'] as num?)?.toDouble() ?? 0;
      }
    }

    // 2. Subtract unsaved allocations in the CURRENT SESSION across ALL days
    double allocatedInSession = 0;
    _dayEntries.forEach((day, entries) {
      for (var entry in entries) {
        if (entry.itemName == _selectedItem && entry.size == _selectedSize) {
          allocatedInSession += entry.dozen;
        }
      }
    });

    double remaining = plannedDozen - allocatedInDb - allocatedInSession;
    if (remaining < 0) remaining = 0;

    setState(() {
      _pendingDozenForSelection = remaining > 0 ? remaining : 0;
      // Removed auto-filling of _dozenCtrl. User must explicitly type their daily target.
    });
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

    // Collect already allocated sets for this Item + Size to exclude them
    final excludedSets = <int>{};

    // 1. From saved allocations in DB for this plan
    final plan = _allPlans.firstWhere(
      (p) => p['_id'] == _selectedPlanId,
      orElse: () => null,
    );
    if (plan != null) {
      final savedAllocations = plan['lotAllocations'] as List? ?? [];
      for (var alloc in savedAllocations) {
        if (alloc['itemName'] == _selectedItem &&
            alloc['size'] == _selectedSize) {
          final sNo = (alloc['setNo'] as num?)?.toInt();
          if (sNo != null) excludedSets.add(sNo);
        }
      }
    }

    // 2. From unsaved entries in current session
    for (var day in _dayEntries.keys) {
      for (var entry in _dayEntries[day]!) {
        if (entry.itemName == _selectedItem && entry.size == _selectedSize) {
          for (var s in entry.sets) {
            final sNo = (s['setNo'] as num?)?.toInt();
            if (sNo != null) excludedSets.add(sNo);
          }
        }
      }
    }

    setState(() => _isAllocating = true);
    try {
      final result = await _api.getFifoAllocation(
        _selectedItem!,
        _selectedSize!,
        dozen,
        _selectedDia!,
        _dozenWeight + (double.tryParse(_foldingWtCtrl.text) ?? 0),
        excludedSets: excludedSets.isEmpty ? null : excludedSets.toList(),
      );
      setState(() {
        if (result != null) {
          _currentSets = List<Map<String, dynamic>>.from(
            result['allocations'] ?? [],
          );
          _totalSets = (result['totalSets'] as num?)?.toInt() ?? 0;
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
    });
    _showSuccess(
      'Item added to $_selectedDay. Add another item or click Next Day.',
    );
  }

  List<Map<String, dynamic>> _getGroupedSets(List<Map<String, dynamic>> sets) {
    if (sets.isEmpty) return [];
    final Map<String, Map<String, dynamic>> grouped = {};
    for (var s in sets) {
      final setNo = (s['setNo'] as num?)?.toInt() ?? 0;
      if (setNo == 0) continue;

      final itemName = s['itemName']?.toString() ?? '';
      final size = s['size']?.toString() ?? '';
      final dia = s['dia']?.toString() ?? '';
      final key = "${itemName}_${size}_${dia}_$setNo";

      if (!grouped.containsKey(key)) {
        grouped[key] = Map<String, dynamic>.from(s)
          ..['lotNames'] = [s['lotName']?.toString() ?? '']
          ..['lotNos'] = [s['lotNo']?.toString() ?? '']
          ..['racks'] = [s['rackName']?.toString() ?? '']
          ..['pallets'] = [s['palletNumber']?.toString() ?? ''];
      } else {
        final existing = grouped[key]!;
        final lotName = s['lotName']?.toString() ?? '';
        final lotNo = s['lotNo']?.toString() ?? '';
        final rack = s['rackName']?.toString() ?? '';
        final pallet = s['palletNumber']?.toString() ?? '';

        if (!(existing['lotNames'] as List).contains(lotName)) {
          (existing['lotNames'] as List).add(lotName);
        }
        if (!(existing['lotNos'] as List).contains(lotNo)) {
          (existing['lotNos'] as List).add(lotNo);
        }
        if (!(existing['racks'] as List).contains(rack)) {
          (existing['racks'] as List).add(rack);
        }
        if (!(existing['pallets'] as List).contains(pallet)) {
          (existing['pallets'] as List).add(pallet);
        }

        existing['setWeight'] =
            (existing['setWeight'] as num) + (s['setWeight'] as num);
        existing['lotBalance'] = s['lotBalance']; // Keep latest
      }
    }

    return grouped.values
        .map(
          (v) => Map<String, dynamic>.from(v)
            ..['lotName'] = (v['lotNames'] as List)
                .where((e) => e != "")
                .join(', ')
            ..['lotNo'] = (v['lotNos'] as List).where((e) => e != "").join(', ')
            ..['rackName'] = (v['racks'] as List)
                .where((e) => e != "")
                .join(', ')
            ..['palletNumber'] = (v['pallets'] as List)
                .where((e) => e != "")
                .join(', '),
        )
        .toList();
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

  // ─── Share ────────────────────────────────────────────────────────────────
  void _shareReport() {
    if (_reportRows.isEmpty) {
      _showError('No details to share.');
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('LOT ALLOCATION REPORT - ${_selectedPlanId ?? ""}');
    buffer.writeln('------------------------------------------');
    for (var r in _reportRows) {
      buffer.writeln(
        '${r['day']} | ${r['itemName']} | ${r['size']} | ${r['dozen']} dz | Lot: ${r['lotNo']} | Set: ${r['setNo']} | Rack: ${r['rackName']} | Pallet: ${r['palletNumber']}',
      );
    }
    Share.share(buffer.toString());
  }

  // ─── Edit / Delete Individual Allocation ──────────────────────────────────
  Future<void> _editAllocationRow(Map<String, dynamic> lot) async {
    final TextEditingController rackCtrl =
        TextEditingController(text: lot['racks'].join(', '));
    final TextEditingController palletCtrl =
        TextEditingController(text: lot['pallets'].join(', '));
    final TextEditingController dozenCtrl =
        TextEditingController(text: lot['dozen'].toString());

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Allocation: ${lot['itemName']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rackCtrl,
              decoration: const InputDecoration(labelText: 'Rack Name'),
            ),
            TextField(
              controller: palletCtrl,
              decoration: const InputDecoration(labelText: 'Pallet No'),
            ),
            TextField(
              controller: dozenCtrl,
              decoration: const InputDecoration(labelText: 'Dozen'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );

    if (confirmed == true && _selectedPlanId != null) {
      setState(() => _isSaving = true);
      try {
        final success = await _api.updateLotAllocation(
          _selectedPlanId!,
          lot['id'].toString(),
          {
            'rackName': rackCtrl.text,
            'palletNumber': palletCtrl.text,
            'dozen': double.tryParse(dozenCtrl.text) ?? lot['dozen'],
          },
        );
        if (success) {
          _showSuccess('Allocation updated!');
          _loadReport(); // Refresh
        } else {
          _showError('Update failed.');
        }
      } catch (e) {
        _showError('Error: $e');
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteAllocationRow(dynamic allocationId) async {
    if (allocationId == null || _selectedPlanId == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to remove this allocation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      try {
        final success = await _api.deleteLotAllocation(
          _selectedPlanId!,
          allocationId.toString(),
        );
        if (success) {
          _showSuccess('Allocation deleted.');
          _loadReport(); // Refresh
        } else {
          _showError('Deletion failed.');
        }
      } catch (e) {
        _showError('Error: $e');
      } finally {
        setState(() => _isSaving = false);
      }
    }
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
                  : 'FIFO ALLOCATIONS — $_totalSets Sets Allocated',
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
                '${entry.dozen} doz | ${entry.neededWeight.toStringAsFixed(1)} kg | ${_getGroupedSets(entry.sets).length} Sets',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dozenCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Dozen',
                      helperText: _pendingDozenForSelection > 0
                          ? 'Pending: ${_pendingDozenForSelection > 1000000 ? _pendingDozenForSelection.toStringAsExponential(2) : (_pendingDozenForSelection % 1 == 0 ? _pendingDozenForSelection.toInt() : _pendingDozenForSelection.toStringAsFixed(1))}'
                          : null,
                      helperStyle: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                _calcChip('Sets Required', '$_setsRequired Sets', Colors.teal),
                _calcChip('1 Set', '= 11 Rolls', Colors.grey),
              ],
            ),
            if (_totalSets > 0) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _calcChip('FIFO Sets Allocated', '$_totalSets', Colors.green),
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
    if (_currentSets.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No allocations yet. Run FIFO to see lot-wise rows.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // ── Group raw allocations by setNo ──────────────────────────────────────
    final Map<int, Map<String, dynamic>> bySet = {};
    final dozen = double.tryParse(_dozenCtrl.text) ?? 0;

    for (var s in _currentSets) {
      final setNo = (s['setNo'] as num?)?.toInt() ?? 0;
      if (setNo == 0) continue;

      if (!bySet.containsKey(setNo)) {
        bySet[setNo] = {
          'setNo': setNo,
          'lotName': s['lotName']?.toString() ?? '',
          'lotNo': s['lotNo']?.toString() ?? '',
          'dia': s['dia']?.toString() ?? '-',
          'racks': <String>{},
          'pallets': <String>{},
          'totalWeight': 0.0,
        };
      }

      final entry = bySet[setNo]!;
      final weight = (s['setWeight'] as num?)?.toDouble() ?? 0.0;
      final rack = s['rackName']?.toString() ?? '';
      final pallet = s['palletNumber']?.toString() ?? '';

      if (rack.isNotEmpty) (entry['racks'] as Set<String>).add(rack.trim());
      if (pallet.isNotEmpty) {
        (entry['pallets'] as Set<String>).add(pallet.trim());
      }
      entry['totalWeight'] = (entry['totalWeight'] as double) + weight;
    }

    final rows = bySet.values.toList()..sort((a, b) => a['setNo'].compareTo(b['setNo']));

    // ── Helper: format set range, e.g. [1,2,3] → "1 TO 3" / [5] → "5" ──────
    String setRange(List<int> nos) {
      if (nos.isEmpty) return '-';
      nos.sort();
      if (nos.length == 1) return 'Set ${nos.first}';
      return 'Set ${nos.first} TO ${nos.last}';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          columnSpacing: 14,
          dataRowMinHeight: 44,
          dataRowMaxHeight: double.infinity,
          columns: const [
            DataColumn(label: Text('LOT NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('LOT NO',   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('DIA',      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('SET\nREQUIRED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('SET NO',   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('RACK NAME',style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('PALLET NO',style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('TOTAL\nWEIGHT (kg)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('DOZEN',    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          ],
          rows: rows.asMap().entries.map((e) {
            final i = e.key;
            final row = e.value;
            final isEven = i % 2 == 0;
            final setNo = row['setNo'] as int;
            final racks = (row['racks'] as Set<String>).toList()..sort();
            final pallets = (row['pallets'] as Set<String>).toList()..sort();
            final weight = row['totalWeight'] as double;
            final isLastRow = i == rows.length - 1;

            // Dozen shown only on the last row (total for the allocation)
            final dozenDisplay = isLastRow
                ? (dozen % 1 == 0 ? dozen.toInt().toString() : dozen.toStringAsFixed(1))
                : '';

            return DataRow(
              color: WidgetStateProperty.all(isEven ? Colors.white : Colors.grey.shade50),
              cells: [
                DataCell(Text(row['lotName']?.toString() ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                DataCell(Text(row['lotNo']?.toString() ?? '-',   style: const TextStyle(fontSize: 12))),
                DataCell(Text(row['dia']?.toString() ?? '-',     style: const TextStyle(fontSize: 12, color: Colors.blue))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.withOpacity(0.4)),
                    ),
                    child: const Text(
                      '1 Set',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    'Set $setNo',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(Text(racks.join(', '), style: const TextStyle(fontSize: 12))),
                DataCell(Text(pallets.join(', '), style: const TextStyle(fontSize: 12))),
                DataCell(Text(
                  '${weight.toStringAsFixed(2)} kg',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                )),
                DataCell(Text(
                  dozenDisplay,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primary),
                )),
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
                    ElevatedButton.icon(
                      onPressed: _shareReport,
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('SHARE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
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

  // ─── Report list view — DAY-GROUPED format matching the layout image ────────
  Widget _buildReportListView(Color primary) {
    // ── 1. Group report rows by day ──────────────────────────────────────────
    final Map<String, List<Map<String, dynamic>>> byDay = {};
    for (final row in _reportRows) {
      final day = row['day']?.toString() ?? 'Unknown';
      byDay.putIfAbsent(day, () => []).add(row);
    }

    // Preserve weekday order
    final orderedDays = _kWeekDays.where(byDay.containsKey).toList();
    for (final d in byDay.keys) {
      if (!orderedDays.contains(d)) orderedDays.add(d);
    }

    // ── 2. Within each day, group by (itemName + size + lotNo) ──────────────
    Map<String, Map<String, dynamic>> groupByLot(List<Map<String, dynamic>> rows) {
      final Map<String, Map<String, dynamic>> g = {};
      for (final r in rows) {
        final key = '${r['itemName']}_${r['size']}_${r['lotNo']}_${r['dia']}';
        if (!g.containsKey(key)) {
          g[key] = {
            'id'         : r['_id'], // Subdocument _id
            'itemName'   : r['itemName'],
            'size'       : r['size'],
            'dozen'      : r['dozen'],
            'neededWeight': r['neededWeight'],
            'lotName'    : r['lotName'],
            'lotNo'      : r['lotNo'],
            'dia'        : r['dia'],
            'racks'      : <String>{},
            'pallets'    : <String>{},
            'setNos'     : <int>[],
            'totalWeight': 0.0,
          };
        }
        final entry = g[key]!;
        final setNo  = (r['setNo'] as num?)?.toInt() ?? 0;
        final wt     = (r['setWeight'] as num?)?.toDouble() ?? 0.0;
        final rack   = r['rackName']?.toString() ?? '';
        final pallet = r['palletNumber']?.toString() ?? '';
        if (setNo > 0 && !(entry['setNos'] as List<int>).contains(setNo)) {
          (entry['setNos'] as List<int>).add(setNo);
        }
        if (rack.isNotEmpty)   (entry['racks'] as Set<String>).add(rack);
        if (pallet.isNotEmpty) (entry['pallets'] as Set<String>).add(pallet);
        entry['totalWeight'] = (entry['totalWeight'] as double) + wt;
      }
      return g;
    }

    // ── 3. Helper: "1 TO 3" or "5" ──────────────────────────────────────────
    String setRange(List<int> nos) {
      if (nos.isEmpty) return '-';
      nos.sort();
      return nos.length == 1 ? '${nos.first}' : '${nos.first} TO ${nos.last}';
    }

    // ── 4. Column header style ───────────────────────────────────────────────
    const hStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 11);
    const dStyle = TextStyle(fontSize: 11);

    final cols = <DataColumn>[
      const DataColumn(label: Text('ITEM NAME', style: hStyle)),
      const DataColumn(label: Text('SIZE',      style: hStyle)),
      const DataColumn(label: Text('DOZEN',     style: hStyle)),
      const DataColumn(label: Text('NEED WT',   style: hStyle)),
      const DataColumn(label: Text('LOT NAME',  style: hStyle)),
      const DataColumn(label: Text('LOT NO',    style: hStyle)),
      const DataColumn(label: Text('DIA',       style: hStyle)),
      const DataColumn(label: Text('SET\nREQUIRED', style: hStyle)),
      const DataColumn(label: Text("SET NO'S",  style: hStyle)),
      const DataColumn(label: Text('RACK',      style: hStyle)),
      const DataColumn(label: Text('PALLET',    style: hStyle)),
      const DataColumn(label: Text('SET WEIGHT',style: hStyle)),
      const DataColumn(label: Text('ACTIONS', style: hStyle)),
    ];

    // ── 5. Build widgets ─────────────────────────────────────────────────────
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: orderedDays.map((day) {
          final dayRows = byDay[day]!;
          final lotMap  = groupByLot(dayRows);
          final lots    = lotMap.values.toList();

          final dataRows = lots.asMap().entries.map((e) {
            final i   = e.key;
            final lot = e.value;
            final setNos  = lot['setNos']  as List<int>;
            final racks   = (lot['racks']   as Set<String>).toList()..sort();
            final pallets = (lot['pallets'] as Set<String>).toList()..sort();
            final wt      = lot['totalWeight'] as double;
            final isEven  = i % 2 == 0;

            return DataRow(
              color: WidgetStateProperty.all(
                isEven ? Colors.white : Colors.grey.shade50,
              ),
              cells: [
                DataCell(Text(lot['itemName']?.toString() ?? '-', style: dStyle)),
                DataCell(Text(lot['size']?.toString()     ?? '-', style: dStyle)),
                DataCell(Text(lot['dozen']?.toString()    ?? '-', style: dStyle)),
                DataCell(Text(
                  '${(lot['neededWeight'] as num?)?.toStringAsFixed(0) ?? '-'}',
                  style: dStyle,
                )),
                DataCell(Text(lot['lotName']?.toString()  ?? '-', style: dStyle)),
                DataCell(Text(lot['lotNo']?.toString()    ?? '-', style: dStyle)),
                DataCell(Text(lot['dia']?.toString()      ?? '-',
                  style: dStyle.copyWith(color: Colors.blue))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color  : Colors.teal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border : Border.all(color: Colors.teal.withOpacity(0.4)),
                    ),
                    child: Text('${setNos.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ),
                ),
                DataCell(Text(setRange(setNos), style: dStyle.copyWith(fontWeight: FontWeight.w500))),
                DataCell(Text(racks.join(', '),   style: dStyle)),
                DataCell(Text(pallets.join(', '), style: dStyle)),
                DataCell(Text('${wt.toStringAsFixed(2)}',
                  style: dStyle.copyWith(color: Colors.deepPurple, fontWeight: FontWeight.bold))),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                        onPressed: () => _editAllocationRow(lot),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                        onPressed: () => _deleteAllocationRow(lot['id']),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── DAY HEADER — full width (inside vertical scroll = bounded) ─
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.08),
                  border: Border.all(color: primary.withOpacity(0.3)),
                ),
                child: Text(
                  'DAY - ${day.toUpperCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: primary,
                    letterSpacing: 1,
                  ),
                ),
              ),
              // ── TABLE — wrapped in its OWN horizontal scroll ───────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                  columnSpacing  : 14,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: double.infinity,
                  columns: cols,
                  rows   : dataRows,
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
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
