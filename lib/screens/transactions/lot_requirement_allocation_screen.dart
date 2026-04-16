import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/custom_dropdown_field.dart';
import '../../widgets/modern_data_table.dart';
import '../../utils/pdf_font_helper.dart';
import '../../services/mobile_api_service.dart';
import 'lot_outward_screen.dart';

const List<String> _kWeekDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

class _DayEntry {
  final String itemName;
  final String size;
  final double dozen;
  final double dozenWeight;
  final String dia;
  final double neededWeight;
  final List<Map<String, dynamic>> sets;

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

class LotRequirementAllocationScreen extends StatefulWidget {
  const LotRequirementAllocationScreen({super.key});

  @override
  State<LotRequirementAllocationScreen> createState() => _LotRequirementAllocationScreenState();
}

class _LotRequirementAllocationScreenState extends State<LotRequirementAllocationScreen> {
  final _api = MobileApiService();

  bool _isLoading = false;
  bool _isAllocating = false;
  bool _isSaving = false;
  int _tabIndex = 0; // 0 = ENTRY, 1 = REPORT

  // Master data
  List<dynamic> _allPlans = [];
  List<String> _masterItemNames = [];
  List<String> _masterSizes = [];
  List<String> _lotNames = [];
  List<String> _dias = [];
  List<dynamic> _assignments = [];

  // Plan selection
  String? _selectedPlanId;

  // Day / Date
  String _selectedDay = 'Monday';
  DateTime _selectedDate = DateTime.now();

  // Current item form
  String? _selectedLotName;
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
  final Map<String, List<_DayEntry>> _dayEntries = {};

  // Report tab data
  List<Map<String, dynamic>> _reportRows = [];
  bool _isLoadingReport = false;
  String? _reportDay;
  DateTime? _reportDate;
  
  final ScrollController _previewScrollCtrl = ScrollController();
  final ScrollController _historyScrollCtrl = ScrollController();


  // ─── Computed ─────────────────────────────────────────────────────────────
  double get _fabricRequiredKg =>
      (double.tryParse(_dozenCtrl.text) ?? 0) *
      (_dozenWeight + (double.tryParse(_foldingWtCtrl.text) ?? 0));

  int get _rollsRequired {
    if (_fabricRequiredKg <= 0) return 0;
    return (_fabricRequiredKg / 20).round();
  }

  int get _setsRequired {
    if (_rollsRequired <= 0) return 0;
    final double sets = _rollsRequired / 11;
    final int wholeSets = sets.floor();
    final double fraction = sets - wholeSets;
    int roundedSets = (fraction > 0.5) ? (wholeSets + 1) : wholeSets;
    return roundedSets < 1 ? 1 : roundedSets;
  }

  List<_DayEntry> get _currentDayEntries => _dayEntries[_selectedDay] ?? [];

  Map<String, dynamic>? _selectedPlan() {
    if (_selectedPlanId == null) return null;
    final plan = _allPlans.firstWhere(
      (p) => p['_id'] == _selectedPlanId,
      orElse: () => null,
    );
    if (plan == null) return null;
    return Map<String, dynamic>.from(plan as Map);
  }

  List<String> _planItems() {
    final plan = _selectedPlan();
    if (plan == null) return _masterItemNames;
    final entries = List<dynamic>.from(plan['cuttingEntries'] ?? const []);
    final items = <String>{};
    for (final raw in entries) {
      final e = Map<String, dynamic>.from(raw as Map);
      final name = e['itemName']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final qty = Map<String, dynamic>.from(e['sizeQuantities'] ?? const {});
      final hasAnyQty = qty.values.any(
        (v) => (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0) > 0,
      );
      if (hasAnyQty) items.add(name);
    }
    return items.isEmpty ? _masterItemNames : items.toList();
  }

  List<String> _planSizesForItem(String? itemName) {
    if (itemName == null || itemName.isEmpty) return _masterSizes;
    final plan = _selectedPlan();
    if (plan == null) return _masterSizes;
    final entries = List<dynamic>.from(plan['cuttingEntries'] ?? const []);
    final e = entries
        .map((x) => Map<String, dynamic>.from(x as Map))
        .firstWhere(
          (x) =>
              (x['itemName']?.toString().trim().toLowerCase() ?? '') ==
              itemName.trim().toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
    if (e.isEmpty) return _masterSizes;
    final qty = Map<String, dynamic>.from(e['sizeQuantities'] ?? const {});
    final sizes = <String>[];
    for (final k in qty.keys) {
      final v = qty[k];
      final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
      if (n > 0) sizes.add(k.toString());
    }
    return sizes.isEmpty ? _masterSizes : sizes;
  }

  List<String> _planDiasForSelection(String? itemName, String? size) {
    // User requested: always show full DIA master list.
    return _dias;
  }

  DateTime _dateForDayInSameWeek(String day, {DateTime? anchor}) {
    final base = DateTime(
      (anchor ?? _selectedDate).year,
      (anchor ?? _selectedDate).month,
      (anchor ?? _selectedDate).day,
    );
    final dayIndex = _kWeekDays.indexOf(day);
    if (dayIndex < 0) return base;
    final monday = base.subtract(Duration(days: base.weekday - DateTime.monday));
    return monday.add(Duration(days: dayIndex));
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateForDayInSameWeek(_selectedDay, anchor: DateTime.now());
    _loadInitialData();
    _dozenCtrl.addListener(() => setState(() {}));
    _dozenWeightCtrl.addListener(() {
      setState(() => _dozenWeight = double.tryParse(_dozenWeightCtrl.text) ?? 0);
    });
    if (_efficiencyCtrl.text.isEmpty) _efficiencyCtrl.text = '100';
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
    _previewScrollCtrl.dispose();
    _historyScrollCtrl.dispose();
    super.dispose();
  }

  String _dayFromDate(DateTime date) {
    if (date.weekday >= DateTime.monday && date.weekday <= DateTime.saturday) {
      return _kWeekDays[date.weekday - DateTime.monday];
    }
    return _selectedDay;
  }

  List<Map<String, dynamic>> _getGroupedSets(List<Map<String, dynamic>> rawSets) {
    if (rawSets.isEmpty) return [];
    
    // Sort raw sets by set number for consistency
    rawSets.sort((a, b) {
      final nA = int.tryParse(_toSetNo(a['setNo']).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final nB = int.tryParse(_toSetNo(b['setNo']).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return nA.compareTo(nB);
    });

    return rawSets.map((s) => {
      'lotName': s['lotName']?.toString() ?? '-',
      'lotNo': s['lotNo']?.toString() ?? '-',
      'dia': s['dia']?.toString() ?? '-',
      'setCount': rawSets.length, // Total sets in this allocation
      'setRange': _toSetNo(s['setNo']), // Current set number (e.g. S-1)
      'rackName': s['rackName'] ?? '-',
      'palletNumber': s['palletNumber']?.toString() ?? '-',
      'setWeight': (s['setWeight'] as num?)?.toDouble() ?? 0.0,
    }).toList();
  }

  bool _isMissingRackPalletValue(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text.isEmpty ||
        text == 'n/a' ||
        text == 'na' ||
        text == 'null' ||
        text == 'not assigned';
  }

  String? _pickStorageValue(List<dynamic>? values, int setIndex) {
    if (values == null || values.isEmpty) return null;
    if (setIndex >= 0 && setIndex < values.length) {
      final candidate = values[setIndex]?.toString().trim();
      if (!_isMissingRackPalletValue(candidate)) return candidate;
    }
    return null;
  }

  String _normalizeDia(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '';
    final numericMatch = RegExp(r'-?\d+(\.\d+)?').firstMatch(raw.replaceAll(',', '.'));
    final numVal = numericMatch == null ? null : double.tryParse(numericMatch.group(0)!);
    if (numVal == null) return raw.toLowerCase().replaceAll(' ', '');
    if (numVal == numVal.truncateToDouble()) return numVal.toInt().toString();
    return numVal.toString();
  }

  String _toSetNo(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  Future<List<Map<String, dynamic>>> _fillRackPalletFromInward(List<Map<String, dynamic>> allocations) async {
    final needsFix = allocations.any((a) => _isMissingRackPalletValue(a['rackName']) || _isMissingRackPalletValue(a['palletNumber']));
    if (!needsFix) return allocations;

    final lotNos = allocations.map((a) => a['lotNo']?.toString().trim() ?? '').where((lotNo) => lotNo.isNotEmpty).toSet();
    final Map<String, List<dynamic>> inwardByLotNo = {};
    for (final lotNo in lotNos) {
      try {
        final inwards = await _api.getInwards(lotNo: lotNo);
        inwardByLotNo[lotNo] = inwards;
      } catch (_) {}
    }

    return allocations.map((a) {
      final lotNo = a['lotNo']?.toString().trim() ?? '';
      final dia = _normalizeDia(a['dia']);
      final setNo = _toSetNo(a['setNo']);
      var rackName = a['rackName']?.toString().trim();
      var palletNumber = a['palletNumber']?.toString().trim();

      if (lotNo.isEmpty || dia.isEmpty || setNo.isEmpty) return a;
      if (!_isMissingRackPalletValue(rackName) && !_isMissingRackPalletValue(palletNumber)) return a;

      final inwards = inwardByLotNo[lotNo] ?? const [];
      for (final inward in inwards) {
        if ((inward['lotNo']?.toString().trim() ?? '') != lotNo) continue;
        dynamic storage = inward['storageDetails'];
        if (storage is String) {
          try { storage = jsonDecode(storage); } catch (_) { storage = null; }
        }
        final List<dynamic> storageList = storage is List ? storage : (storage is Map ? [storage] : const []);
        for (final sd in storageList) {
          if (_normalizeDia(sd['dia']) != dia) continue;
          final setLabels = sd['setLabels'] as List<dynamic>?;
          int setIndex = -1;
          if (setLabels != null) setIndex = setLabels.indexWhere((l) => _toSetNo(l) == setNo);
          if (setIndex == -1) {
            final numericOnly = setNo.replaceAll(RegExp(r'[^0-9]'), '');
            if (numericOnly.isNotEmpty) setIndex = (int.tryParse(numericOnly) ?? 0) - 1;
          }
          if (_isMissingRackPalletValue(rackName)) rackName = _pickStorageValue(sd['racks'] as List?, setIndex) ?? rackName;
          if (_isMissingRackPalletValue(palletNumber)) palletNumber = _pickStorageValue(sd['pallets'] as List?, setIndex) ?? palletNumber;
          if (!_isMissingRackPalletValue(rackName) && !_isMissingRackPalletValue(palletNumber)) break;
        }
        if (!_isMissingRackPalletValue(rackName) && !_isMissingRackPalletValue(palletNumber)) break;
      }
      return {
        ...a,
        'rackName': _isMissingRackPalletValue(a['rackName']) && !_isMissingRackPalletValue(rackName) ? rackName : a['rackName'],
        'palletNumber': _isMissingRackPalletValue(a['palletNumber']) && !_isMissingRackPalletValue(palletNumber) ? palletNumber : a['palletNumber'],
      };
    }).toList();
  }

  // ─── Data loading ─────────────────────────────────────────────────────────
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final plans = await _api.getCuttingOrders();
      final categories = await _api.getCategories();
      final assignments = await _api.getAssignments();
      if (mounted) {
        setState(() {
          _allPlans = plans;
          _dias = _getValues(categories, ['Dia']);
          _masterItemNames = _getValues(categories, ['Item Name', 'itemName', 'item']);
          _masterSizes = _getValues(categories, ['Size', 'size']);
          _lotNames = _getValues(categories, ['Lot Name', 'lotName', 'lot name']);
          _assignments = assignments;
          if (_allPlans.isNotEmpty) {
            _selectedPlanId = _allPlans.first['_id'];
            _loadReport();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      _showError('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _getValues(List<dynamic> categories, List<String> matchNames) {
    final result = <String>[];
    for (var cat in categories) {
      final name = (cat['name'] ?? '').toString().toLowerCase();
      if (matchNames.any((m) => name == m.toLowerCase())) {
        final values = cat['values'] as List<dynamic>?;
        if (values != null) {
          for (var v in values) {
            final val = (v is Map ? v['name'] : v).toString();
            if (val.isNotEmpty && !result.contains(val)) result.add(val);
          }
        }
      }
    }
    return result;
  }

  void _onItemSelected(String? item) {
    setState(() {
      _selectedItem = item;
      _selectedLotName = null;
      final validSizes = _planSizesForItem(item);
      _selectedSize = validSizes.contains(_selectedSize) ? _selectedSize : null;
      final validDias = _planDiasForSelection(item, _selectedSize);
      _selectedDia = validDias.contains(_selectedDia) ? _selectedDia : null;
      _currentSets = [];
    });
    _fillFromAssignments();
  }

  void _onSizeSelected(String? size) {
    setState(() {
      _selectedSize = size;
      final validDias = _planDiasForSelection(_selectedItem, size);
      _selectedDia = validDias.contains(_selectedDia) ? _selectedDia : null;
      _currentSets = [];
    });
    _updateRemainingDozen();
    _fillFromAssignments();
  }

  void _updateRemainingDozen() {
    if (_selectedPlanId == null || _selectedItem == null || _selectedSize == null) return;

    final plan = _allPlans.firstWhere((p) => p['_id'] == _selectedPlanId, orElse: () => null);
    if (plan == null) return;

    final entry = (plan['cuttingEntries'] as List).firstWhere((e) => e['itemName'] == _selectedItem, orElse: () => null);
    if (entry == null) return;

    double plannedDozen = (entry['sizeQuantities'][_selectedSize] ?? 0).toDouble();

    // 1. Subtract already saved allocations for this specific Item + Size in the DB
    final savedAllocations = plan['lotAllocations'] as List? ?? [];
    double allocatedInDb = 0;
    for (var alloc in savedAllocations) {
      if (alloc['itemName'] == _selectedItem && alloc['size'] == _selectedSize) {
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
    });
  }

  void _fillFromAssignments() {
    if (_selectedItem == null) return;
    final itemMatches = _assignments
        .where((a) => a['fabricItem'].toString().trim().toLowerCase() == _selectedItem!.trim().toLowerCase())
        .toList();
    if (itemMatches.isEmpty) return;

    dynamic best;
    if (_selectedSize != null) {
      best = itemMatches.firstWhere(
        (a) => a['size'].toString().trim().toLowerCase() == _selectedSize!.trim().toLowerCase(),
        orElse: () => null,
      );
    }
    best ??= itemMatches.first;

    setState(() {
      if (_selectedSize == null) _selectedSize = best['size']?.toString();
      if (_selectedLotName == null) {
        final ln = best['lotName']?.toString();
        if (ln != null && _lotNames.contains(ln)) _selectedLotName = ln;
      }
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

    _updateRemainingDozen();
  }

  Future<void> _runAllocation() async {
    final dozen = double.tryParse(_dozenCtrl.text) ?? 0;
    if (_selectedItem == null || _selectedSize == null || _selectedDia == null || dozen <= 0 || _dozenWeight <= 0) {
      _showError('Please select Item, Size, Dia and enter Dozen + Weight');
      return;
    }

    final excludedSets = <String>{};

    final plan = _allPlans.firstWhere((p) => p['_id'] == _selectedPlanId, orElse: () => null);
    if (plan != null) {
      final savedAllocations = plan['lotAllocations'] as List? ?? [];
      for (var alloc in savedAllocations) {
        if (alloc['itemName'] == _selectedItem && alloc['size'] == _selectedSize) {
          final sNo = _toSetNo(alloc['setNo']);
          final lotNo = alloc['lotNo']?.toString().trim();
          if (sNo.isNotEmpty) {
            if (lotNo != null && lotNo.isNotEmpty) {
              excludedSets.add('$lotNo|$sNo');
            } else {
              excludedSets.add(sNo);
            }
          }
        }
      }
    }

    for (var day in _dayEntries.keys) {
      for (var entry in _dayEntries[day]!) {
        if (entry.itemName == _selectedItem && entry.size == _selectedSize) {
          for (var s in entry.sets) {
            final sNo = _toSetNo(s['setNo']);
            final lotNo = s['lotNo']?.toString().trim();
            if (sNo.isNotEmpty) {
              if (lotNo != null && lotNo.isNotEmpty) {
                excludedSets.add('$lotNo|$sNo');
              } else {
                excludedSets.add(sNo);
              }
            }
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
        lotName: _selectedLotName,
        excludedSets: excludedSets.isEmpty ? null : excludedSets.toList(),
      );
      final List<Map<String, dynamic>> allocations = List<Map<String, dynamic>>.from(result?['allocations'] ?? []);
      final resolvedAllocations = await _fillRackPalletFromInward(allocations);
      final int requiredSetCount = _setsRequired;
      final List<Map<String, dynamic>> finalSets = (requiredSetCount > 0 && resolvedAllocations.length > requiredSetCount)
          ? resolvedAllocations.take(requiredSetCount).toList()
          : resolvedAllocations;
      setState(() {
        if (result != null) {
          _currentSets = finalSets;
          _totalSets = finalSets.length;
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
      final old = entries[existingIdx];
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

  Future<void> _saveCurrentItemNow() async {
    if (_currentSets.isEmpty) {
      _showError('Run FIFO first before saving.');
      return;
    }
    _addItemToDay();
    await _saveDayAllocation(allWeek: false);
  }

  void _nextDay() {
    if (_currentDayEntries.isEmpty && _currentSets.isEmpty) {
      _showError('No entries for $_selectedDay. Add at least one item.');
      return;
    }
    // If user has an un-added allocation, add it automatically
    if (_currentSets.isNotEmpty) {
      _addItemToDay();
      return;
    }

    final idx = _kWeekDays.indexOf(_selectedDay);
    if (idx < _kWeekDays.length - 1) {
      setState(() {
        _selectedDay = _kWeekDays[idx + 1];
        _selectedDate = _dateForDayInSameWeek(_selectedDay);
      });
      _showSuccess(
        '$_selectedDay recorded. Now entering ${_kWeekDays[idx + 1]}.',
      );
    }
  }

  Future<void> _saveDayAllocation({bool allWeek = false}) async {
    if (_selectedPlanId == null) {
      _showError('No plan selected.');
      return;
    }

    List<String> daysToSave = allWeek ? _dayEntries.keys.toList() : [_selectedDay];
    if (_currentSets.isNotEmpty) _addItemToDay();

    final bool hasAny = daysToSave.any((d) => (_dayEntries[d] ?? []).isNotEmpty);
    if (!hasAny) {
      _showError('No allocations to save.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      for (final day in daysToSave) {
        final entries = _dayEntries[day] ?? [];
        final dayDate = _dateForDayInSameWeek(day);
        for (final entry in entries) {
          await _api.saveLotAllocation(
            _selectedPlanId!,
            entry.sets,
            day: day,
            date: DateFormat('yyyy-MM-dd').format(dayDate),
            itemName: entry.itemName,
            size: entry.size,
            dozen: entry.dozen,
            neededWeight: entry.neededWeight,
          );
        }
      }
      _showSuccess('Allocations saved successfully.');
      setState(() {
        _dayEntries.clear();
        _currentSets = [];
      });
      // Refresh plan data to update "Pending Plan" counts across the app
      await _loadInitialData(); // This is safer as it refreshes _allPlans too
      _loadReport();
    } catch (e) {
      _showError('Save failed: $e');
    }
    setState(() => _isSaving = false);
  }

  String _planDisplayLabel(Map<String, dynamic> plan) {
    final planName = plan['planName']?.toString() ?? 'Plan';
    final planType = plan['planType']?.toString() ?? '';
    final planPeriod = plan['planPeriod']?.toString() ?? '';
    final planId = plan['planId']?.toString() ?? '';
    return "$planName ($planType - $planPeriod) • $planId";
  }

  Future<void> _loadReport() async {
    if (_selectedPlanId == null) return;
    setState(() => _isLoadingReport = true);
    try {
      final res = await _api.getAllocationReport(_selectedPlanId!);
      final List<Map<String, dynamic>> rows = res != null ? List<Map<String, dynamic>>.from(res['rows'] ?? []) : <Map<String, dynamic>>[];
      setState(() { _reportRows = _groupReportRows(rows); _isLoadingReport = false; });
    } catch (e) { _showError('Report load failed: $e'); setState(() => _isLoadingReport = false); }
  }

  void _navigateToOutward(Map<String, dynamic> row) {
    final r = row['__original__'] ?? row;
    final initialData = {
      'lotName': r['lotName'] ?? (r['lotInfo']?.toString().split(',').first.trim()) ?? r['LOTS']?.toString().split(',').first.trim(),
      'lotNo': r['lotNo'] ?? (r['lotInfo']?.toString().split(',').first.trim()) ?? r['LOTS']?.toString().split(',').first.trim(),
      'dia': r['dia']?.toString() ?? r['DIA']?.toString(),
      'setNos': r['sets'] ?? [r['setNo'] ?? r['setNum'] ?? r['SET NO'] ?? ''],
    };
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LotOutwardScreen(initialOutwardData: initialData),
      ),
    );
  }

  List<Map<String, dynamic>> _groupReportRows(List<Map<String, dynamic>> rows) {
    if (rows == null || rows.isEmpty) return [];
    final Map<String, Map<String, dynamic>> grouped = {};
    for (var r in rows) {
      if (r == null) continue;
      final lotNo = r['lotNo']?.toString() ?? '-';
      final setNo = _toSetNo(r['setNo']);
      final allocationId = r['_id']?.toString();
      final key = "${r['date'] ?? 'no-date'}_${r['itemName'] ?? 'no-item'}_${r['size'] ?? 'no-size'}_${r['dia'] ?? 'no-dia'}";
      
      if (!grouped.containsKey(key)) {
        grouped[key] = Map<String, dynamic>.from(r)
          ..['lotNos'] = [lotNo]
          ..['sets'] = [setNo]
          ..['allocationIds'] = allocationId != null ? [allocationId] : <String>[];
      } else {
        final existing = grouped[key]!;
        final existingLotNos = (existing['lotNos'] as List? ?? []);
        if (!existingLotNos.contains(lotNo)) existingLotNos.add(lotNo);
        
        final existingSets = (existing['sets'] as List? ?? []);
        if (setNo.isNotEmpty && !existingSets.contains(setNo)) existingSets.add(setNo);
        
        final existingIds = (existing['allocationIds'] as List? ?? []);
        if (allocationId != null && !existingIds.contains(allocationId)) {
          existingIds.add(allocationId);
        }
        
        // Summing up values safely
        existing['setWeight'] = (double.tryParse(existing['setWeight']?.toString() ?? '0') ?? 0) + 
                               (double.tryParse(r['setWeight']?.toString() ?? '0') ?? 0);
                               
        // Also sum dozens and needed weight (added for accuracy)
        existing['dozen'] = (double.tryParse(existing['dozen']?.toString() ?? '0') ?? 0) + 
                            (double.tryParse(r['dozen']?.toString() ?? '0') ?? 0);
                            
        existing['neededWeight'] = (double.tryParse(existing['neededWeight']?.toString() ?? '0') ?? 0) + 
                                  (double.tryParse(r['neededWeight']?.toString() ?? '0') ?? 0);

        // Ensure rack/pallet info is preserved if missing from first row but present in others
        if ((existing['rackName'] == null || existing['rackName'] == '-' || existing['rackName'] == '') && r['rackName'] != null) {
          existing['rackName'] = r['rackName'];
        }
        if ((existing['palletNumber'] == null || existing['palletNumber'] == '-' || existing['palletNumber'] == '') && r['palletNumber'] != null) {
          existing['palletNumber'] = r['palletNumber'];
        }
      }
    }
    return grouped.values.map((v) => {
      ...v, 
      'lotInfo': (v['lotNos'] as List? ?? []).join(', '),
      'setList': (v['sets'] as List? ?? []).join(', ')
    }).toList();
  }

  Future<void> _deleteReportRow(Map<String, dynamic> row) async {
    if (_selectedPlanId == null) {
      _showError('No plan selected');
      return;
    }
    final original = row['__original__'] ?? row;
    final ids = List<String>.from(
      ((original['allocationIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty),
    );
    if (ids.isEmpty && original['_id'] != null) {
      ids.add(original['_id'].toString());
    }
    if (ids.isEmpty) {
      _showError('Allocation id not found');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Allocation'),
        content: Text('Delete ${ids.length} allocation record(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await _api.deleteLotAllocation(_selectedPlanId!, ids.join(','));
    if (success) {
      _showSuccess('Allocation deleted');
      await _loadReport();
    } else {
      _showError('Delete failed');
    }
  }

  Future<void> _editReportRow(Map<String, dynamic> row) async {
    if (_selectedPlanId == null) {
      _showError('No plan selected');
      return;
    }
    final original = row['__original__'] ?? row;
    final ids = List<String>.from(
      ((original['allocationIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty),
    );
    if (ids.isEmpty && original['_id'] != null) {
      ids.add(original['_id'].toString());
    }
    if (ids.isEmpty) {
      _showError('Allocation id not found');
      return;
    }

    final rackCtrl = TextEditingController(text: original['rackName']?.toString() ?? '');
    final palletCtrl = TextEditingController(text: original['palletNumber']?.toString() ?? '');
    final canEditWeights = ids.length == 1;
    final dozenCtrl = TextEditingController(
      text: canEditWeights ? (original['dozen']?.toString() ?? '0') : '',
    );
    final setWeightCtrl = TextEditingController(
      text: canEditWeights ? (original['setWeight']?.toString() ?? '0') : '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Allocation'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: rackCtrl,
                decoration: const InputDecoration(labelText: 'Rack Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: palletCtrl,
                decoration: const InputDecoration(labelText: 'Pallet Number'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dozenCtrl,
                enabled: canEditWeights,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Dozen',
                  helperText: canEditWeights ? null : 'Multiple sets selected: disabled',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: setWeightCtrl,
                enabled: canEditWeights,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Set Weight'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return;

    bool allOk = true;
    for (var i = 0; i < ids.length; i++) {
      final payload = <String, dynamic>{
        'rackName': rackCtrl.text.trim(),
        'palletNumber': palletCtrl.text.trim(),
      };
      if (canEditWeights && i == 0) {
        payload['dozen'] = double.tryParse(dozenCtrl.text.trim()) ?? 0;
        payload['setWeight'] = double.tryParse(setWeightCtrl.text.trim()) ?? 0;
      }
      final ok = await _api.updateLotAllocation(_selectedPlanId!, ids[i], payload);
      if (!ok) {
        allOk = false;
        break;
      }
    }

    if (allOk) {
      _showSuccess('Allocation updated');
      await _loadReport();
    } else {
      _showError('Update failed');
    }
  }

  String _formatWeight(dynamic w) {
    if (w == null) return '0.00';
    try { return double.parse(w.toString()).toStringAsFixed(2); } catch (_) { return '0.00'; }
  }

  void _showError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red));
  }
  
  void _showSuccess(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green));
  }

  Future<void> _printReport() async {
    if (_reportRows.isEmpty) { _showError('No report data to print'); return; }
    
     final doc = pw.Document();
     final fonts = await Future.wait([
       PdfFontHelper.bold,
       PdfFontHelper.regular,
     ]);
     final fontTitle = fonts[0];
     final fontHeader = fonts[0];
     final fontData = fonts[1];

    final plan = _allPlans.firstWhere((p) => p['_id'] == _selectedPlanId, orElse: () => null);
    final planTitle = plan != null ? "${plan['planName']} (${plan['planType']})" : 'Lot Allocation Report';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.only(left: 20, top: 20, bottom: 20, right: 60),
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Om Vinayaka Garments', style: pw.TextStyle(font: fontTitle, fontSize: 24)),
                pw.Text('IDEAL innerwear', style: pw.TextStyle(font: fontHeader, fontSize: 16)),
                pw.SizedBox(height: 4),
                pw.Text('SF No. 252/1, Merkalath Thottam North, Balaji Nagar, Poyampalayam,', style: pw.TextStyle(font: fontData, fontSize: 10)),
                pw.Text('Pooluvapatti (P.O), Tirupur - 2.', style: pw.TextStyle(font: fontData, fontSize: 10)),
                pw.Text('Phone: 97900 52254, 97900 52252', style: pw.TextStyle(font: fontData, fontSize: 10)),
                pw.Text('Email: idealovg@gmail.com | Web: www.idealinnerwear.com', style: pw.TextStyle(font: fontData, fontSize: 10)),
                pw.Text('GSTIN: 33BHNPS9629C1ZZ', style: pw.TextStyle(font: fontHeader, fontSize: 11, color: PdfColors.blue900)),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 10),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                 pw.Text('Report: $planTitle', style: pw.TextStyle(font: fontHeader, fontSize: 12)),
                 pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}', style: pw.TextStyle(font: fontData, fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.TableHelper.fromTextArray(
              headers: ['DATE & ITEM', 'S/D (DZ)', 'LOT & STORAGE', 'SETS ALLOCATED', 'WEIGHT (KG)'],
              data: _reportRows.map((r) => [
                "${r['date'] ?? '-'} | ${r['itemName'] ?? '-'}",
                "${r['size'] ?? '-'}/${r['dia'] ?? '-'} (${r['dozen'] ?? 0}Dz)",
                "${r['lotName'] ?? '-'}\nNo: ${r['lotNo'] ?? '-'}\nLoc: ${r['rackName'] ?? '-'}/${r['palletNumber'] ?? '-'}",
                r['setList'] ?? '-',
                _formatWeight(r['setWeight'] ?? r['total_weight'] ?? r['neededWeight']),
              ]).toList(),
              headerStyle: pw.TextStyle(font: fontHeader, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: pw.TextStyle(font: fontData, fontSize: 8),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5), // Date & Item
                1: const pw.FlexColumnWidth(1.8), // S/D (DZ)
                2: const pw.FlexColumnWidth(2.5), // Lot & Storage
                3: const pw.FlexColumnWidth(3.0), // Sets
                4: const pw.FlexColumnWidth(1.8), // Weight
              },
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                4: pw.Alignment.centerRight,
              },
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  Future<void> _shareWhatsApp() async {
    if (_reportRows.isEmpty) { _showError('No data to share'); return; }

    final plan = _allPlans.firstWhere((p) => p['_id'] == _selectedPlanId, orElse: () => null);
    final planTitle = plan != null ? "${plan['planName']} (${plan['planType']})" : 'Allocation Report';

    String text = "*LOT ALLOCATION REPORT*\n";
    text += "*Plan:* $planTitle\n";
    text += "*Date:* ${DateFormat('dd/MM/yyyy').format(DateTime.now())}\n\n";

    // Take current day or top 10 rows if too many
    final rowsToShare = _reportRows.length > 15 ? _reportRows.sublist(0, 15) : _reportRows;
    
    for (var r in rowsToShare) {
      text += "📦 *${r['itemName']}* | Sz: ${r['size']} | Dia: ${r['dia']}\n";
      text += "   Lot: ${r['lotNo']} | Sets: ${r['setList']}\n";
      text += "   Qty: ${r['dozen']} Doz | Wt: ${_formatWeight(r['setWeight'])}kg\n";
      text += "------------------\n";
    }

    if (_reportRows.length > 15) {
      text += "... and ${_reportRows.length - 15} more items.\n";
    }

    final url = "https://wa.me/?text=${Uri.encodeComponent(text)}";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      _showError('Could not launch WhatsApp');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isWeb = LayoutConstants.isWeb(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isWeb ? 32 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPremiumHeader(isWeb),
              const SizedBox(height: 32),
              
              // MISSION CONTROL TABS
              Row(
                children: [
                  _tabButton(0, 'ENTRY', LucideIcons.rocket),
                  const SizedBox(width: 8),
                  _tabButton(1, 'REPORT', LucideIcons.fileSpreadsheet),
                ],
              ),
              const SizedBox(height: 24),

              if (_tabIndex == 0) ...[
                _buildEntryForm(isWeb),
                const SizedBox(height: 32),
                _buildLivePreviewTable(),
                const SizedBox(height: 32),
                _buildSessionQueue(isWeb),
              ] else ...[
                KeyedSubtree(
                  key: const ValueKey('allocation_report_tab'),
                  child: _buildHistorySection(isWeb),
                ),
              ],
              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(int index, String label, IconData icon) {
    final active = _tabIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _tabIndex = index);
        if (index == 1) _loadReport();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? Colors.transparent : const Color(0xFFE2E8F0)),
          boxShadow: active ? [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : const Color(0xFF64748B), letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(bool isWeb) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(LucideIcons.rocket, size: 24, color: Color(0xFF0F172A)),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Lot Requirement Allocation', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -0.5)),
              ),
              if (isWeb) ...[
                 _headerStat('Session Status', _dayEntries.isEmpty ? 'Idle' : 'Active Queues', Colors.orange),
                 const SizedBox(width: 32),
                 _headerStat('Target Plan', _allPlans.length.toString(), Colors.blue),
                 const SizedBox(width: 32),
                 TextButton.icon(
                   onPressed: _isLoading ? null : _loadInitialData,
                   icon: const Icon(LucideIcons.refreshCw, size: 16, color: Color(0xFF2563EB)),
                   label: Text('REFRESH', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFF2563EB))),
                   style: TextButton.styleFrom(
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: const Color(0xFF2563EB).withOpacity(0.2))),
                   ),
                 ),
              ]
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: CustomDropdownField(
                  label: 'CURRENT MASTER PLAN',
                  items: _allPlans
                      .map<String>(
                        (p) => _planDisplayLabel(
                          Map<String, dynamic>.from(p as Map),
                        ),
                      )
                      .toList(),
                  value: (() {
                    final plan = _allPlans.firstWhere(
                      (p) => p['_id'] == _selectedPlanId,
                      orElse: () => null,
                    );
                    return plan != null
                        ? _planDisplayLabel(
                            Map<String, dynamic>.from(plan as Map),
                          )
                        : null;
                  })(),
                  onChanged: (v) {
                    final plan = _allPlans.firstWhere(
                      (p) =>
                          _planDisplayLabel(
                            Map<String, dynamic>.from(p as Map),
                          ) ==
                          v,
                      orElse: () => null,
                    );
                    if (plan != null) {
                      setState(() {
                        _selectedPlanId = plan['_id'];
                        _selectedItem = null;
                        _selectedSize = null;
                        _selectedDia = null;
                        _selectedLotName = null;
                        _currentSets = [];
                      });
                      _loadReport();
                      _updateRemainingDozen();
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDropdownField(
                  label: 'EXECUTION DAY',
                  items: _kWeekDays,
                  value: _selectedDay,
                  onChanged: (v) => setState(() { _selectedDay = v!; _selectedDate = _dateForDayInSameWeek(v); }),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EXECUTION DATE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.calendarDays, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 12),
                          Text(DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
        Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildEntryForm(bool isWeb) {
    final itemOptions = _planItems();
    final sizeOptions = _planSizesForItem(_selectedItem);
    final diaOptions = _planDiasForSelection(_selectedItem, _selectedSize);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDividerHeader('ALLOCATION SETTINGS'),
          const SizedBox(height: 24),
          CustomDropdownField(
            label: 'ITEM NAME',
            items: itemOptions,
            value: itemOptions.contains(_selectedItem) ? _selectedItem : null,
            onChanged: _onItemSelected,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: CustomDropdownField(
                  label: 'SIZE',
                  items: sizeOptions,
                  value: sizeOptions.contains(_selectedSize) ? _selectedSize : null,
                  onChanged: _onSizeSelected,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomDropdownField(
                  label: 'DIA',
                  items: diaOptions,
                  value: diaOptions.contains(_selectedDia) ? _selectedDia : null,
                  onChanged: (v) => setState(() {
                    _selectedDia = v;
                    _currentSets = [];
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          CustomDropdownField(
            label: 'LOT (PREF)',
            items: _lotNames,
            value: _selectedLotName,
            onChanged: (v) => setState(() {
              _selectedLotName = v;
              _currentSets = [];
            }),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputField('QUANTITY DOZEN', _dozenCtrl),
                    const SizedBox(height: 4),
                    Text(
                      'Pending Plan: ${_pendingDozenForSelection.toStringAsFixed(0)} Doz',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _pendingDozenForSelection > 0 ? const Color(0xFF3B82F6) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildInputField('DOZEN WEIGHT (KG)', _dozenWeightCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInputField('GSM', _gsmCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildInputField('FOLDING WT (KG)', _foldingWtCtrl)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildInputField('EFFICIENCY %', _efficiencyCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildInputField('WASTE %', _wasteCtrl, readOnly: true)),
            ],
          ),
          const SizedBox(height: 32),
          
          // ESTIMATE CHIPS (MOBILE PARITY)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEstimateChip('REQUIRED WEIGHT', '${_fabricRequiredKg.toStringAsFixed(2)}Kg', LucideIcons.target, const Color(0xFF2563EB)),
              _buildEstimateChip('ROLLS NEEDED', '±$_rollsRequired', LucideIcons.box, const Color(0xFF7C3AED)),
              _buildEstimateChip('SETS REQUIRED', '$_setsRequired', LucideIcons.layers, const Color(0xFFDB2777)),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.info, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text('RULE: 1 Set = 11 Rolls', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
              ],
            ),
          ),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isAllocating ? null : _runAllocation,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              elevation: 0,
            ),
            child: _isAllocating
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('RUN FIFO ENGINE', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateChip(String label, String value, IconData icon, Color color) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 8),
          Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: color.withOpacity(0.8))),
          Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildLivePreviewTable() {
    final groupedRows = _getGroupedSets(_currentSets);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildDividerHeader('FIFO ALLOCATION PREVIEW — $_totalSets Sets Allocated')),
            if (_currentSets.isNotEmpty) 
              ActionChip(
                label: Text(
                  _isSaving
                      ? 'SAVING...'
                      : 'SAVE THIS ITEM TO ${_selectedDay.toUpperCase()}',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
                onPressed: _isSaving ? null : _saveCurrentItemNow,
                backgroundColor: const Color(0xFF0D9488),
                side: BorderSide.none,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          constraints: const BoxConstraints(maxHeight: 540),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFF1F5F9))),
          clipBehavior: Clip.antiAlias,
          child: _isAllocating 
            ? const Center(child: CircularProgressIndicator()) 
            : groupedRows.isEmpty 
              ? Center(child: Icon(LucideIcons.database, size: 64, color: const Color(0xFFF1F5F9)))
              : Scrollbar(
                  controller: _previewScrollCtrl,
                  thumbVisibility: true,
                  interactive: true,
                  thickness: 14,
                  radius: const Radius.circular(8),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: SingleChildScrollView(
                      controller: _previewScrollCtrl,
                      physics: const AlwaysScrollableScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: groupedRows.isEmpty ? MediaQuery.of(context).size.width - 100 : 1800,
                        child: ModernDataTable(
                        showActions: false,
                        columns: const ['LOT NAME', 'LOT NO', 'DIA', 'SET REQUIRED', 'SET NO', 'RACK NAME', 'PALLET NO', 'TOTAL WEIGHT (kg)', 'DOZEN'],
                        rows: groupedRows.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final s = entry.value;
                          final isLast = idx == groupedRows.length - 1;
        
                          return {
                            'LOT NAME': s['lotName']?.toString() ?? '-',
                            'LOT NO': s['lotNo']?.toString() ?? '-',
                            'DIA': s['dia']?.toString() ?? '-',
                            'SET REQUIRED': _buildBadge("${s['setCount']} Set", const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
                            'SET NO': _buildBadge("Set ${s['setRange']}", const Color(0xFFF5F3FF), const Color(0xFF7C3AED)),
                            'RACK NAME': s['rackName'] ?? '-',
                            'PALLET NO': s['palletNumber']?.toString() ?? '-',
                            'TOTAL WEIGHT (kg)': _buildBadge("${_formatWeight(s['setWeight'])} kg", const Color(0xFFECFDF5), const Color(0xFF059669)),
                            'DOZEN': isLast 
                              ? Text((double.tryParse(_dozenCtrl.text) ?? 0).toStringAsFixed(0), 
                                     style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)))
                              : '',
                          };
                        }).toList(),
                        emptyMessage: '',
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withOpacity(0.1)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildSessionQueue(bool isWeb) {
    if (_dayEntries.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PENDING OPS QUEUE', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blue.shade200, letterSpacing: 1.5)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12, runSpacing: 8,
                  children: _dayEntries.keys.map((day) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(day, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(width: 8),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(6)), child: Text(_dayEntries[day]!.length.toString(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _saveDayAllocation(allWeek: true),
                icon: _isSaving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A))) : const Icon(LucideIcons.save),
                label: Text('FINALIZE WORK WEEK', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1), overflow: TextOverflow.ellipsis),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, 
                  foregroundColor: const Color(0xFF0F172A), 
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(bool isWeb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildDividerHeader('BATCH LOGISTICS HISTORY')),
            Row(
              children: [
                _actionIconButton(LucideIcons.printer, _printReport, 'PRINT REPORT', Colors.blue),
                const SizedBox(width: 8),
                _actionIconButton(LucideIcons.messageCircle, _shareWhatsApp, 'WHATSAPP SHARE', Colors.green),
                const SizedBox(width: 8),
                IconButton(onPressed: _loadReport, icon: const Icon(LucideIcons.refreshCw, size: 18, color: Color(0xFF64748B))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          height: 600, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF1F5F9))),
          clipBehavior: Clip.antiAlias,
          child: _isLoadingReport ? const Center(child: CircularProgressIndicator()) : Scrollbar(
            controller: _historyScrollCtrl,
            thumbVisibility: true,
            interactive: true,
            thickness: 14,
            trackVisibility: true,
            radius: const Radius.circular(8),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: SingleChildScrollView(
                controller: _historyScrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _reportRows.isEmpty ? 1000 : 2500,
                  child: ModernDataTable(
                  columns: const ['DATE', 'ITEM', 'SIZE', 'DOZEN', 'NEED WT', 'LOT NAME', 'LOT NO', 'DIA', 'SET REQUIRED', 'SET NO', 'RACK', 'PALLET', 'SET WEIGHT'],
                  onShare: _navigateToOutward,
                  onEdit: _editReportRow,
                  onDelete: _deleteReportRow,
                  rows: _reportRows.map((r) => {
                    '__original__': r,
                    'DATE': r['date'] ?? '-',
                    'ITEM': r['itemName'] ?? '-',
                    'SIZE': r['size'] ?? '-',
                    'DOZEN': (r['dozen'] ?? 0).toString(),
                    'NEED WT': _formatWeight(r['neededWeight']),
                    'LOT NAME': r['lotName'] ?? '-',
                    'LOT NO': r['lotNo'] ?? '-',
                    'DIA': r['dia']?.toString() ?? '-',
                    'SET REQUIRED': "${(r['sets'] as List?)?.length ?? 1}",
                    'SET NO': r['setList'] ?? '-',
                    'RACK': r['rackName'] ?? '-',
                    'PALLET': r['palletNumber']?.toString() ?? '-',
                    'SET WEIGHT': _formatWeight(r['setWeight']),
                  }).toList(),
                  emptyMessage: 'No activity logs found for this plan.',
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController ctrl, {bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC), 
            borderRadius: BorderRadius.circular(12), 
            border: Border.all(color: const Color(0xFFE2E8F0))
          ),
          child: TextField(
            controller: ctrl,
            readOnly: readOnly,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: readOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14), border: InputBorder.none),
          ),
        ),
      ],
    );
  }

  Widget _buildDividerHeader(String title) {
    return Row(
      children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8), letterSpacing: 1.5)),
        const SizedBox(width: 16),
        Expanded(child: Container(height: 1, color: const Color(0xFFF1F5F9))),
      ],
    );
  }

  Widget _actionIconButton(IconData icon, VoidCallback onTap, String tooltip, Color color) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
