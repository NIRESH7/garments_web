import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/custom_dropdown_field.dart';
import '../../widgets/modern_data_table.dart';
import '../../services/mobile_api_service.dart';
import 'lot_outward_screen.dart';

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

  final List<String> _kWeekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

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
    } catch (e) {
      _showError('Error loading data: $e');
      setState(() => _isLoading = false);
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

  bool _isMissingRackPallet(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text.isEmpty || text == 'n/a' || text == 'na' || text == 'null' || text == 'not assigned';
  }

  Future<List<Map<String, dynamic>>> _fillRackPalletFromInward(List<Map<String, dynamic>> allocations) async {
    final needsFix = allocations.any((a) => _isMissingRackPallet(a['rackName']) || _isMissingRackPallet(a['palletNumber']));
    if (!needsFix) return allocations;

    final lotNos = allocations.map((a) => a['lotNo']?.toString().trim() ?? '').where((l) => l.isNotEmpty).toSet();
    final Map<String, List<dynamic>> inwardByLot = {};
    for (final lNo in lotNos) {
      try {
        final inwards = await _api.getInwards(lotNo: lNo);
        inwardByLot[lNo] = inwards;
      } catch (_) {}
    }

    return allocations.map((a) {
      final lotNo = a['lotNo']?.toString().trim() ?? '';
      final dia = _normalizeDia(a['dia']);
      final setNo = _toSetNo(a['setNo']);
      var rack = a['rackName']?.toString().trim();
      var pallet = a['palletNumber']?.toString().trim();

      if (lotNo.isEmpty || dia.isEmpty || setNo.isEmpty) return a;
      if (!_isMissingRackPallet(rack) && !_isMissingRackPallet(pallet)) return a;

      final inwards = inwardByLot[lotNo] ?? const [];
      for (final inward in inwards) {
        dynamic storage = inward['storageDetails'];
        if (storage is String) {
          try { storage = jsonDecode(storage); } catch (_) { storage = null; }
        }
        final List<dynamic> storageList = storage is List ? storage : (storage is Map ? [storage] : const []);
        for (final sd in storageList) {
          if (_normalizeDia(sd['dia']) != dia) continue;
          final List<dynamic> labels = sd['setLabels'] ?? [];
          final racks = sd['racks'] ?? [];
          final pallets = sd['pallets'] ?? [];
          int idx = labels.indexWhere((l) => _toSetNo(l) == setNo);
          if (idx == -1) {
            final numericOnly = setNo.replaceAll(RegExp(r'[^0-9]'), '');
            if (numericOnly.isNotEmpty) idx = (int.tryParse(numericOnly) ?? 0) - 1;
          }
          if (idx >= 0 && idx < racks.length && _isMissingRackPallet(rack)) {
            final val = racks[idx]?.toString().trim();
            if (!_isMissingRackPallet(val)) rack = val;
          }
          if (idx >= 0 && idx < pallets.length && _isMissingRackPallet(pallet)) {
            final val = pallets[idx]?.toString().trim();
            if (!_isMissingRackPallet(val)) pallet = val;
          }
        }
      }
      return {...a, 'rackName': rack, 'palletNumber': pallet};
    }).toList();
  }

  void _onItemSelected(String? item) {
    setState(() {
      _selectedItem = item;
      _selectedLotName = null;
      _selectedSize = null;
      _selectedDia = null;
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
    if (_selectedPlanId == null || _selectedItem == null || _selectedSize == null) return;
    final plan = _allPlans.firstWhere((p) => p['_id'] == _selectedPlanId, orElse: () => null);
    if (plan == null) return;
    final entry = (plan['cuttingEntries'] as List).firstWhere((e) => e['itemName'] == _selectedItem, orElse: () => null);
    if (entry == null) return;
    double plannedDozen = (entry['sizeQuantities'][_selectedSize] ?? 0).toDouble();
    double allocatedInDb = (plan['lotAllocations'] as List? ?? []).where((a) => a['itemName'] == _selectedItem && a['size'] == _selectedSize).fold(0.0, (sum, a) => sum + ((a['dozen'] as num?)?.toDouble() ?? 0));
    double allocatedInSession = 0;
    _dayEntries.forEach((day, entries) { for (var e in entries) { if (e.itemName == _selectedItem && e.size == _selectedSize) allocatedInSession += e.dozen; } });
    double remaining = plannedDozen - allocatedInDb - allocatedInSession;
    setState(() => _pendingDozenForSelection = remaining > 0 ? remaining : 0);
  }

  void _fillFromAssignments() {
    if (_selectedItem == null) return;
    final itemMatches = _assignments.where((a) => a['fabricItem'].toString().trim().toLowerCase() == _selectedItem!.trim().toLowerCase()).toList();
    if (itemMatches.isEmpty) return;
    dynamic best;
    if (_selectedSize != null) {
      best = itemMatches.firstWhere((a) => a['size'].toString().trim().toLowerCase() == _selectedSize!.trim().toLowerCase(), orElse: () => itemMatches.first);
    } else { best = itemMatches.first; }

    setState(() {
      if (_selectedSize == null) _selectedSize = best['size']?.toString();
      if (_selectedLotName == null) {
        final ln = best['lotName']?.toString();
        if (_lotNames.contains(ln)) _selectedLotName = ln;
      }
      if (_selectedDia == null) {
        final d = best['dia']?.toString();
        if (_dias.contains(d)) _selectedDia = d;
      }
      _dozenWeightCtrl.text = best['dozenWeight']?.toString() ?? '';
      _foldingWtCtrl.text = best['foldingWt']?.toString() ?? '';
      _gsmCtrl.text = best['gsm']?.toString() ?? '';
      _efficiencyCtrl.text = best['efficiency']?.toString() ?? '100';
      _dozenWeight = double.tryParse(_dozenWeightCtrl.text) ?? 0;
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
      for (var a in (plan['lotAllocations'] as List? ?? [])) {
        if (a['itemName'] == _selectedItem && a['size'] == _selectedSize) {
          final sNo = _toSetNo(a['setNo']);
          final lotNo = a['lotNo']?.toString().trim();
          if (sNo.isNotEmpty) excludedSets.add(lotNo != null && lotNo.isNotEmpty ? '$lotNo|$sNo' : sNo);
        }
      }
    }
    _dayEntries.forEach((day, entries) {
      for (var e in entries) {
        if (e.itemName == _selectedItem && e.size == _selectedSize) {
          for (var s in e.sets) {
            final sNo = _toSetNo(s['setNo']);
            final lotNo = s['lotNo']?.toString().trim();
            if (sNo.isNotEmpty) excludedSets.add(lotNo != null && lotNo.isNotEmpty ? '$lotNo|$sNo' : sNo);
          }
        }
      }
    });

    setState(() => _isAllocating = true);
    try {
      final res = await _api.getFifoAllocation(
        _selectedItem!, _selectedSize!, dozen, _selectedDia!,
        _dozenWeight + (double.tryParse(_foldingWtCtrl.text) ?? 0),
        lotName: _selectedLotName, excludedSets: excludedSets.isEmpty ? null : excludedSets.toList()
      );
      final List<Map<String, dynamic>> allocations = List<Map<String, dynamic>>.from(res?['allocations'] ?? []);
      final resolved = await _fillRackPalletFromInward(allocations);
      setState(() {
        if (res != null) {
          _currentSets = resolved;
          _totalSets = (res['totalSets'] as num?)?.toInt() ?? 0;
          if (res['success'] == false) _showError(res['message'] ?? 'Insufficient stock');
        }
        _isAllocating = false;
      });
    } catch (e) {
      _showError('Allocation failed: $e');
      setState(() => _isAllocating = false);
    }
  }

  void _addItemToDay() {
    if (_currentSets.isEmpty) { _showError('Run FIFO first'); return; }
    final dozen = double.tryParse(_dozenCtrl.text) ?? 0;
    final entries = List<_DayEntry>.from(_currentDayEntries);
    final idx = entries.indexWhere((e) => e.itemName == _selectedItem && e.size == _selectedSize && e.dia == _selectedDia);
    if (idx != -1) {
      final old = entries[idx];
      entries[idx] = _DayEntry(
        itemName: old.itemName, size: old.size, dozen: old.dozen + dozen,
        dozenWeight: old.dozenWeight, dia: old.dia,
        neededWeight: old.neededWeight + _fabricRequiredKg,
        sets: [...old.sets, ..._currentSets]
      );
    } else {
      entries.add(_DayEntry(
        itemName: _selectedItem!, size: _selectedSize!, dozen: dozen, 
        dozenWeight: _dozenWeight, dia: _selectedDia!, 
        neededWeight: _fabricRequiredKg, sets: List.from(_currentSets)
      ));
    }
    setState(() {
      _dayEntries[_selectedDay] = entries;
      _currentSets = []; _selectedItem = null; _selectedSize = null; _selectedDia = null;
      _dozenCtrl.clear(); _dozenWeightCtrl.clear(); _foldingWtCtrl.clear();
      _gsmCtrl.clear(); _efficiencyCtrl.clear(); _wasteCtrl.clear();
      _dozenWeight = 0; _totalSets = 0;
    });
    _showSuccess('Item added to $_selectedDay');
  }

  void _nextDay() {
    if (_currentDayEntries.isEmpty && _currentSets.isEmpty) { _showError('No entries to record'); return; }
    if (_currentSets.isNotEmpty) { _addItemToDay(); return; }
    final idx = _kWeekDays.indexOf(_selectedDay);
    if (idx < _kWeekDays.length - 1) {
      setState(() {
        _selectedDay = _kWeekDays[idx + 1];
        _selectedDate = _dateForDayInSameWeek(_selectedDay);
      });
    }
  }

  Future<void> _saveDayAllocation({bool allWeek = false}) async {
    if (_selectedPlanId == null) return;
    List<String> days = allWeek ? _dayEntries.keys.toList() : [_selectedDay];
    if (_currentSets.isNotEmpty) _addItemToDay();
    if (!days.any((d) => (_dayEntries[d] ?? []).isNotEmpty)) { _showError('No allocations to save'); return; }

    setState(() => _isSaving = true);
    try {
      for (final day in days) {
        final entries = _dayEntries[day] ?? [];
        final dDate = _dateForDayInSameWeek(day);
        for (final entry in entries) {
          await _api.saveLotAllocation(
            _selectedPlanId!, entry.sets, day: day, 
            date: DateFormat('yyyy-MM-dd').format(dDate),
            itemName: entry.itemName, size: entry.size, 
            dozen: entry.dozen, neededWeight: entry.neededWeight
          );
        }
      }
      _showSuccess('Allocations saved successfully');
      setState(() { _dayEntries.clear(); _currentSets = []; });
      _loadReport();
    } catch (e) { _showError('Save failed: $e'); }
    setState(() => _isSaving = false);
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
    if (rows.isEmpty) return [];
    final Map<String, Map<String, dynamic>> grouped = {};
    for (var r in rows) {
      final lotNo = r['lotNo']?.toString() ?? '-';
      final setNo = _toSetNo(r['setNo']);
      final key = "${r['date']}_${r['itemName']}_${r['size']}_${r['dia']}";
      if (!grouped.containsKey(key)) {
        grouped[key] = Map<String, dynamic>.from(r)
          ..['lotNos'] = [lotNo]
          ..['sets'] = [setNo];
      } else {
        final existing = grouped[key]!;
        if (!(existing['lotNos'] as List).contains(lotNo)) (existing['lotNos'] as List).add(lotNo);
        if (setNo.isNotEmpty && !(existing['sets'] as List).contains(setNo)) (existing['sets'] as List).add(setNo);
        existing['weight'] = (double.tryParse(existing['weight']?.toString() ?? '0') ?? 0) + (double.tryParse(r['weight']?.toString() ?? '0') ?? 0);
      }
    }
    return grouped.values.map((v) => {
      ...v, 
      'lotInfo': (v['lotNos'] as List).join(', '),
      'setList': (v['sets'] as List).join(', ')
    }).toList();
  }

  String _formatWeight(dynamic w) {
    if (w == null) return '0.00';
    try { return double.parse(w.toString()).toStringAsFixed(2); } catch (_) { return '0.00'; }
  }

  void _showError(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red));
  void _showSuccess(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green));

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
                  _tabButton(0, 'MISSION CONTROL', LucideIcons.rocket),
                  const SizedBox(width: 8),
                  _tabButton(1, 'ALLOCATION REPORTS', LucideIcons.fileSpreadsheet),
                ],
              ),
              const SizedBox(height: 24),

              if (_tabIndex == 0) ...[
                if (isWeb) 
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildEntryForm(isWeb)),
                      const SizedBox(width: 32),
                      Expanded(flex: 3, child: _buildLivePreviewTable()),
                    ],
                  )
                else ...[
                  _buildEntryForm(isWeb),
                  const SizedBox(height: 32),
                  _buildLivePreviewTable(),
                ],
                const SizedBox(height: 32),
                _buildSessionQueue(isWeb),
              ] else ...[
                _buildHistorySection(isWeb),
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
      onTap: () => setState(() => _tabIndex = index),
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
                  items: _allPlans.map((p) => "${p['planName'] ?? 'Plan'} (${p['planType'] ?? ''} - ${p['planPeriod'] ?? ''})").toList(),
                  value: (() {
                    final plan = _allPlans.firstWhere((p) => p['_id'] == _selectedPlanId, orElse: () => null);
                    return plan != null ? "${plan['planName']} (${plan['planType']} - ${plan['planPeriod']})" : null;
                  })(),
                  onChanged: (v) {
                    final plan = _allPlans.firstWhere((p) => "${p['planName']} (${p['planType']} - ${p['planPeriod']})" == v, orElse: () => null);
                    if (plan != null) setState(() { _selectedPlanId = plan['_id']; _loadReport(); _updateRemainingDozen(); });
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
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDividerHeader('ALLOCATION SETTINGS'),
            const SizedBox(height: 24),
            CustomDropdownField(
              label: 'ITEM NAME',
              items: _masterItemNames,
              value: _selectedItem,
              onChanged: _onItemSelected,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: CustomDropdownField(label: 'SIZE', items: _masterSizes, value: _selectedSize, onChanged: _onSizeSelected)),
                const SizedBox(width: 12),
                Expanded(child: CustomDropdownField(label: 'DIA', items: _dias, value: _selectedDia, onChanged: (v) => setState(() { _selectedDia = v; _currentSets = []; }))),
              ],
            ),
            const SizedBox(height: 16),
            CustomDropdownField(label: 'LOT (PREF)', items: _lotNames, value: _selectedLotName, onChanged: (v) => setState(() { _selectedLotName = v; _currentSets = []; })),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputField('QUANTITY DOZEN', _dozenCtrl),
                      const SizedBox(height: 4),
                      Text('Pending Plan: ${_pendingDozenForSelection.toStringAsFixed(0)} Doz', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _pendingDozenForSelection > 0 ? const Color(0xFF3B82F6) : const Color(0xFFEF4444))),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildInputField('DOZEN WEIGHT (KG)', _dozenWeightCtrl)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildInputField('GSM', _gsmCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildInputField('FOLDING WT (KG)', _foldingWtCtrl)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildInputField('EFFICIENCY %', _efficiencyCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildInputField('WASTE %', _wasteCtrl, readOnly: true)),
              ],
            ),
            const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildEstimateChip('Target', '${_fabricRequiredKg.toStringAsFixed(2)}Kg', LucideIcons.target, Colors.blue),
                  _buildEstimateChip('Rolls', '±$_rollsRequired', LucideIcons.box, Colors.indigo),
                  _buildEstimateChip('Sets', '$_setsRequired', LucideIcons.layers, Colors.purple),
                  _buildEstimateChip('Rule', '1 Set = 11 Rolls', LucideIcons.info, const Color(0xFF64748B)),
                ],
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isAllocating ? null : _runAllocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              child: _isAllocating 
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('RUN FIFO ENGINE', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
          ],
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildDividerHeader('FIFO ALLOCATION PREVIEW — $_totalSets Sets Allocated')),
            if (_currentSets.isNotEmpty) 
              ActionChip(
                label: Text('SAVE THIS ITEM TO ${_selectedDay.toUpperCase()}', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white)), 
                onPressed: _addItemToDay, 
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
            : _currentSets.isEmpty 
              ? Center(child: Icon(LucideIcons.database, size: 64, color: const Color(0xFFF1F5F9)))
              : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1200,
              child: ModernDataTable(
                showActions: false,
                columns: const ['LOT NAME', 'LOT NO', 'DIA', 'SET REQUIRED', 'SET NO', 'RACK NAME', 'PALLET NO', 'TOTAL WEIGHT (kg)', 'DOZEN'],
                rows: _currentSets.map((s) => {
                  'LOT NAME': s['lotName']?.toString() ?? '-',
                  'LOT NO': s['lotNo']?.toString() ?? '-',
                  'DIA': s['dia']?.toString() ?? '-',
                  'SET REQUIRED': "${_setsRequired} Set",
                  'SET NO': "Set ${s['setNo'] ?? s['setNum'] ?? '-'}",
                  'RACK NAME': s['rackName'] ?? '-',
                  'PALLET NO': s['palletNumber']?.toString() ?? '-',
                  'TOTAL WEIGHT (kg)': "${_formatWeight(s['weight'])} kg",
                  'DOZEN': s['dozen']?.toString() ?? (double.tryParse(_dozenCtrl.text) ?? 0).toStringAsFixed(0),
                }).toList(),
                emptyMessage: '',
              ),
            ),
          ),
        ),
      ],
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
          ElevatedButton.icon(
            onPressed: _isSaving ? null : () => _saveDayAllocation(allWeek: true),
            icon: _isSaving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A))) : const Icon(LucideIcons.save),
            label: Text('FINALIZE WORK WEEK', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0F172A), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
            IconButton(onPressed: _loadReport, icon: const Icon(LucideIcons.refreshCw, size: 18, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          height: 600, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF1F5F9))),
          clipBehavior: Clip.antiAlias,
          child: _isLoadingReport ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1400,
              child: ModernDataTable(
                columns: const ['DATE', 'ITEM', 'SIZE', 'DOZEN', 'NEED WT', 'LOT NAME', 'LOT NO', 'DIA', 'SET REQUIRED', 'SET NO', 'RACK', 'PALLET', 'SET WEIGHT'],
                onShare: _navigateToOutward,
                onEdit: (row) => _showError('Edit operation initialized for ${row['ITEM']}'),
                onDelete: (row) => _showError('Archive operation initialized for ${row['ITEM']}'),
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
                  'SET WEIGHT': _formatWeight(r['weight']),
                }).toList(),
                emptyMessage: 'No activity logs found for this plan.',
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
}

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
