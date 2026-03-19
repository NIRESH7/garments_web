import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/mobile_api_service.dart';
import 'package:garments/dialogs/signature_pad_dialog.dart';
import '../../core/constants/api_constants.dart';
import 'cutting_entry_page2_screen.dart';

class CuttingEntryFormScreen extends StatefulWidget {
  final String? entryId;
  const CuttingEntryFormScreen({super.key, this.entryId});

  @override
  State<CuttingEntryFormScreen> createState() => _CuttingEntryFormScreenState();
}

class _CuttingEntryFormScreenState extends State<CuttingEntryFormScreen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _saving = false;

  // Header controllers
  final _itemNameCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _lotNoCtrl = TextEditingController();
  final _lotNameCtrl = TextEditingController();
  final _diaCtrl = TextEditingController();
  final _actualDiaCtrl = TextEditingController();
  final _setNoCtrl = TextEditingController();
  final _dyedDcNoCtrl = TextEditingController();
  final _cutNoCtrl = TextEditingController();
  final _trnNoCtrl = TextEditingController();
  final _rackNameCtrl = TextEditingController();
  final _palletNoCtrl = TextEditingController();
  final _layMasterNameCtrl = TextEditingController();
  final _layLengthCtrl = TextEditingController();
  final _miniLayLengthCtrl = TextEditingController();
  final _layMarkingPcsCtrl = TextEditingController();
  final _miniMarkingPcsCtrl = TextEditingController();
  final _foldWtPerDozCtrl = TextEditingController();
  final _fixedGSMCtrl = TextEditingController();
  final _fixedTimeToFinishLayCtrl = TextEditingController();
  final _cutterStartTimeCtrl = TextEditingController();
  final _cutterEndTimeCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _slipCheckedByCtrl = TextEditingController();
  final _enteredByCtrl = TextEditingController();
  final _authorizedSignCtrl = TextEditingController();
  final _inchargeSignCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();

  DateTime _cuttingDate = DateTime.now();
  DateTime? _weightDate;
  String _status = 'Pending';
  String? _entryId;
  String? _selectedDcNo;
  String? _stickerNo;

  XFile? _authorizedSignature;
  XFile? _inchargeSignature;
  String? _authorizedSignatureUrl;
  String? _inchargeSignatureUrl;

  // Colour rows
  List<Map<String, dynamic>> _colourRows = [];
  Map<String, dynamic> _page2Summary = {};

  // Available masters for dropdowns
  List<dynamic> _cuttingMasters = [];
  List<dynamic> _outwards = [];
  List<dynamic> _categoryMasters = [];
  List<String> _availableSizes = [];
  List<String> _availableItems = [];
  List<String> _availableSetNos = [];

  @override
  void initState() {
    super.initState();
    _entryId = widget.entryId;
    _loadMasters();
    if (_entryId != null) _loadEntry();
  }

  Future<void> _loadMasters() async {
    try {
      final masters = await _api.getCuttingMasters();
      final outwards = await _api.getOutwards();
      final cats = await _api.getCategories();
      
      setState(() {
        _cuttingMasters = masters;
        _outwards = outwards;
        _categoryMasters = cats;
        
        _availableItems = _cuttingMasters.map((m) => m['itemName'].toString()).toSet().toList();
        _availableSizes = _cuttingMasters.map((m) => m['size'].toString()).toSet().toList();
      });
    } catch (e) {
      debugPrint('Error loading masters: $e');
    }
  }

  void _onDcNoSelected(String dcNo) {
    final dc = _outwards.firstWhere((o) => o['dcNo'] == dcNo, orElse: () => null);
    if (dc != null) {
      setState(() {
        _selectedDcNo = dcNo;
        _dyedDcNoCtrl.text = dcNo;
        _lotNoCtrl.text = (dc['lotNo'] ?? '').toString();
        _lotNameCtrl.text = (dc['lotName'] ?? '').toString();
        _diaCtrl.text = (dc['dia'] ?? '').toString();
        
        // Auto-feed from outward items
          final items = dc['items'] as List?;
          if (items != null && items.isNotEmpty) {
            _availableSetNos = items
                .map((i) => (i['set_no'] ?? '').toString())
                .where((s) => s.isNotEmpty)
                .toSet()
                .toList();
            debugPrint('Available Set Nos: $_availableSetNos');
            if (_availableSetNos.isNotEmpty && _setNoCtrl.text.isEmpty) {
              _setNoCtrl.text = _availableSetNos.first;
            }
            _rackNameCtrl.text = (items.first['rack_name'] ?? '').toString();
            _palletNoCtrl.text = (items.first['pallet_number'] ?? '').toString();
          
          // R22, R23, R32: Populate colour rows from DC items
          final Map<String, Map<String, dynamic>> colorGroups = {};
          debugPrint('Items found in DC: ${items.length}');
          for (var item in items) {
            final colours = item['colours'] as List?;
            if (colours != null) {
              for (var c in colours) {
                final color = (c['colour'] ?? '').toString();
                final rollWt = (c['roll_weight'] ?? (c['weight'] ?? 0)).toDouble();
                final freshLayer = (c['fresh_layer'] ?? (c['no_of_rolls'] ?? 0)).toDouble();
                
                if (colorGroups.containsKey(color)) {
                  colorGroups[color]!['rollWT'] += rollWt;
                  colorGroups[color]!['freshLayer'] += freshLayer;
                } else {
                  colorGroups[color] = {
                    'colour': color,
                    'freshLayer': freshLayer,
                    'miniLay': 0.0,
                    'miniMarkingPcs': 0.0,
                    'rollWT': rollWt,
                    'actualFolding': 0.0,
                    'endBit': 0.0,
                    'mistake': 0.0,
                    'costingWeight': 0.0,
                    'cadEff': 0.0,
                  };
                }
              }
            }
          }
          _colourRows = colorGroups.values.toList();
          debugPrint('Colour rows populated: ${_colourRows.length}');
          for (int i = 0; i < _colourRows.length; i++) {
            _recalcRow(i);
          }
        }

        // Also try to find matching Cutting Master for this Lot Name/Item Name
        final master = _cuttingMasters.firstWhere(
          (m) => m['lotName'] == _lotNameCtrl.text || m['itemName'] == _itemNameCtrl.text,
          orElse: () => null
        );
        if (master != null) {
          _itemNameCtrl.text = (master['itemName'] ?? '').toString();
          _sizeCtrl.text = (master['size'] ?? '').toString();
          _layLengthCtrl.text = (master['layLengthMeter'] ?? 0).toString();
          _layMarkingPcsCtrl.text = (master['layPcs'] ?? 0).toString();
          _foldWtPerDozCtrl.text = (master['folding'] ?? 0).toString();
          _fixedTimeToFinishLayCtrl.text = (master['timeToComplete'] ?? '').toString();
          _fixedGSMCtrl.text = (master['gsm'] ?? master['fixedGSM'] ?? 0).toString();
          
          _categoryCtrl.text = (master['category'] ?? '').toString();
          _rackNameCtrl.text = (master['rack_name'] ?? _rackNameCtrl.text).toString();
          _slipCheckedByCtrl.text = (master['slipCheckedBy'] ?? '').toString();
        }
      });
    }
  }

  Future<void> _loadEntry() async {
    try {
      setState(() => _loading = true);
      final data = await _api.getCuttingEntryById(_entryId!);
      if (data != null) {
        _itemNameCtrl.text = (data['itemName'] ?? '').toString();
        _sizeCtrl.text = (data['size'] ?? '').toString();
        _lotNoCtrl.text = (data['lotNo'] ?? '').toString();
        _lotNameCtrl.text = (data['lotName'] ?? '').toString();
        _diaCtrl.text = (data['dia'] ?? '').toString();
        _actualDiaCtrl.text = (data['actualDia'] ?? '').toString();
        _setNoCtrl.text = (data['setNo'] ?? '').toString();
        _cutNoCtrl.text = (data['cutNo'] ?? '').toString();
        _trnNoCtrl.text = (data['trnNo'] ?? '').toString();

        var dyedDcData = data['dyedDcNos'];
        if (dyedDcData is String) {
          try {
            dyedDcData = jsonDecode(dyedDcData);
          } catch (_) {}
        }
        if (dyedDcData is List && dyedDcData.isNotEmpty) {
          _dyedDcNoCtrl.text = dyedDcData.join(', ');
          _selectedDcNo = dyedDcData.first.toString();
        } else {
          _dyedDcNoCtrl.text = (dyedDcData ?? '').toString();
          _selectedDcNo = _dyedDcNoCtrl.text.isNotEmpty ? _dyedDcNoCtrl.text : null;
        }

        _rackNameCtrl.text = (data['rackName'] ?? '').toString();
        _palletNoCtrl.text = (data['palletNo'] ?? '').toString();
        _layMasterNameCtrl.text = (data['layMasterName'] ?? '').toString();
        _layLengthCtrl.text = (data['layLength'] ?? '').toString();
        _miniLayLengthCtrl.text = (data['miniLayLength'] ?? '').toString();
        _layMarkingPcsCtrl.text = (data['layMarkingPcs'] ?? '').toString();
        _miniMarkingPcsCtrl.text = (data['miniMarkingPcs'] ?? '').toString();
        _foldWtPerDozCtrl.text = (data['foldWtPerDoz'] ?? '').toString();
        _fixedGSMCtrl.text = (data['fixedGSM'] ?? '').toString();
        _fixedTimeToFinishLayCtrl.text = (data['fixedTimeToFinishLay'] ?? '').toString();
        _cutterStartTimeCtrl.text = (data['cutterStartTime'] ?? '').toString();
        _cutterEndTimeCtrl.text = (data['cutterEndTime'] ?? '').toString();
        _remarksCtrl.text = (data['remarks'] ?? '').toString();
        
        _slipCheckedByCtrl.text = (data['slipCheckedBy'] ?? '').toString();
        _enteredByCtrl.text = (data['enteredBy'] ?? '').toString();
        _authorizedSignatureUrl = data['authorizedSign']?.toString();
        _inchargeSignatureUrl = data['inchargeSign']?.toString();
        _stickerNo = (data['stickerNo'] ?? '').toString();

        _status = (data['status'] ?? 'Pending').toString();
        if (data['cuttingDate'] != null) {
          _cuttingDate = DateTime.parse(data['cuttingDate'].toString()).toLocal();
        }
        if (data['weightDate'] != null) {
          _weightDate = DateTime.parse(data['weightDate'].toString()).toLocal();
        }
        if (data['enteredDate'] != null) {
          _enteredByCtrl.text += " & ${DateFormat('dd/MM/yyyy').format(DateTime.parse(data['enteredDate'].toString()).toLocal())}";
        }

        var rowsData = data['colourRows'];
        if (rowsData is String) {
          try {
            rowsData = jsonDecode(rowsData);
          } catch (_) {}
        }
        if (rowsData is List) {
          _colourRows = List<Map<String, dynamic>>.from(
              rowsData.map((r) => Map<String, dynamic>.from(r as Map)));
        } else {
          _colourRows = [];
        }

        // Load Page 2 summary for calculations
        final page2 = await _api.getCuttingEntryPage2(_entryId!);
        _page2Summary = page2 ?? {};

        // R32/R33: Populate available Set Nos and other DC-dependent fields if DC is selected
        if (_selectedDcNo != null && _outwards.isNotEmpty) {
          final dc = _outwards.firstWhere(
            (o) => o['dcNo'].toString() == _selectedDcNo,
            orElse: () => null
          );
          if (dc != null) {
            final items = dc['items'] as List?;
            if (items != null) {
              _availableSetNos = items
                  .map((i) => (i['set_no'] ?? '').toString())
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList();
              // If the current setNo is not in the list, add it to avoid dropdown errors
              if (_setNoCtrl.text.isNotEmpty && !_availableSetNos.contains(_setNoCtrl.text)) {
                _availableSetNos.add(_setNoCtrl.text);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading entry: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addColourRow() {
    setState(() {
      _colourRows.add({
        'colour': '',
        'freshLayer': 0,
        'miniLay': 0,
        'miniMarkingPcs': 0,
        'totalPcs': 0,
        'doz': 0,
        'balancePcs': 0,
        'returnWT': 0,
        'rollWT': 0,
        'actualFolding': 0,
        'endBit': 0,
        'mistake': 0,
        'layBal': 0,
      });
    });
  }

  void _recalcRow(int idx) {
    if (idx >= _colourRows.length) return;
    final row = _colourRows[idx];
    
    // Inputs from Header
    final layMarkingPcs = double.tryParse(_layMarkingPcsCtrl.text) ?? 0;
    final miniMarkingPcs = double.tryParse(_miniMarkingPcsCtrl.text) ?? 0;
    final layLength = double.tryParse(_layLengthCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final miniLayLength = double.tryParse(_miniLayLengthCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final foldWtPerDoz = double.tryParse(_foldWtPerDozCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final fixedGSM = double.tryParse(_fixedGSMCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final dia = double.tryParse(_diaCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    
    debugPrint('Recalc Row $idx: ll=$layLength, mll=$miniLayLength, gsm=$fixedGSM, dia=$dia, wt=${row['rollWT']}');

    // Calculate overall total pcs for waste allocation (R40-43)
    double overallTotalPcs = 0;
    for (var r in _colourRows) {
      final fl = (r['freshLayer'] as num?)?.toDouble() ?? 0;
      final ml = (r['miniLay'] as num?)?.toDouble() ?? 0;
      final mmp = (r['miniMarkingPcs'] as num?)?.toDouble() ?? 0;
      overallTotalPcs += (fl * layMarkingPcs) + (ml * mmp);
    }

    // Inputs from Row
    final freshLayer = (row['freshLayer'] as num?)?.toDouble() ?? 0;
    final miniLay = (row['miniLay'] as num?)?.toDouble() ?? 0;
    final rollWT = (row['rollWT'] as num?)?.toDouble() ?? 0;
    final actualFolding = (row['actualFolding'] as num?)?.toDouble() ?? 0;
    final endBit = (row['endBit'] as num?)?.toDouble() ?? 0;
    final mistake = (row['mistake'] as num?)?.toDouble() ?? 0;
    final costingWeight = (row['costingWeight'] as num?)?.toDouble() ?? 0;
    final cadEff = (row['cadEff'] as num?)?.toDouble() ?? 0;

    final rowMiniMarkingPcs = (row['miniMarkingPcs'] as num?)?.toDouble() ?? 0;
    
    // Formulas
    // 25. Total Pcs = ((Fresh lay count X Lay marking pcs)+(Mini lay count X Mini Marking pcs))
    final totalPcs = (freshLayer * layMarkingPcs) + (miniLay * rowMiniMarkingPcs);
    
    // 26. Doz = Total Pcs/12 (only Whole number)
    final doz = (totalPcs / 12).floor();
    
    // 27. Balance Pcs = Total Pcs - (doz X 12)
    final balancePcs = totalPcs - (doz * 12);

    // 30. Roll Mtr = Roll wt X 1000 / Lot inward gsm X Cuttable dia in mtr
    // Cuttable dia in mtr = (dia X 2 / 39.37)
    final cuttableDiaInMtr = (dia * 2 / 39.37);
    final rollMtr = fixedGSM > 0 && cuttableDiaInMtr > 0 
        ? (rollWT * 1000) / (fixedGSM * cuttableDiaInMtr) 
        : 0.0;

    // 31. Actual Roll Mtr = ((Fresh lay X Lay Length )+ (Mini Lay X Mini Lay Length ))
    final actualRollMtr = (freshLayer * layLength) + (miniLay * miniLayLength);

    // 33. Fold. Req = (Total pcs /12)*fold.wt per doz
    final foldReq = (totalPcs / 12) * foldWtPerDoz;

    // 35. Fold Diff. = Actual folding - Fold.Req
    final foldDiff = actualFolding - foldReq;

    // 36. Act. Roll Wt = Roll wt - Actual Folding
    final actRollWt = rollWT - actualFolding;

    // 16. DOZ WEIGHT = actRollWt / doz (if doz > 0)
    final dozWeight = doz > 0 ? actRollWt / doz : 0.0;

    // 18. DIFFRENCE (Weight) = costingWeight - dozWeight
    final weightDiff = costingWeight - dozWeight;

    // 40. Cutter Waste = Page 2 cutter waste wt / overall total pcs X Total pcs
    final page2CutterWaste = (_page2Summary['cutterWasteWT'] as num?)?.toDouble() ?? 0;
    final cutterWaste = overallTotalPcs > 0 ? (page2CutterWaste / overallTotalPcs) * totalPcs : 0.0;

    // 41. Off Waste = Page 2 Off pattern waste wt / overall total pcs X Total pcs
    final page2OffWaste = (_page2Summary['offPatternWaste'] as num?)?.toDouble() ?? 0;
    final offWaste = overallTotalPcs > 0 ? (page2OffWaste / overallTotalPcs) * totalPcs : 0.0;

    // 42. Total Waste = Cutter waste + Off waste
    final totalWaste = cutterWaste + offWaste;

    // 43. Cut Wt = Page 2 cut wt / over all total pcs X Total pcs
    final page2CutWt = (_page2Summary['cutWeight'] as num?)?.toDouble() ?? 0;
    final cutWt = overallTotalPcs > 0 ? (page2CutWt / overallTotalPcs) * totalPcs : 0.0;

    // 44. Final Bal = Act roll wt - (end bit + mistake + total waste)
    final finalBal = actRollWt - (endBit + mistake + totalWaste);

    // 45. Differ = Final bal - Cut wt
    final differ = finalBal - cutWt;

    // 20. ACTUAL EFF. % = 100 - (Total Waste / Lay Weight * 100) (as per R20 context)
    final double wastePercent = (_page2Summary['wastePercent'] as num?)?.toDouble() ?? 0;
    final actualEff = 100 - wastePercent;

    // 21. DIFFRENCE (Eff) = cadEff - actualEff
    final effDiff = cadEff - actualEff;

    setState(() {
      _colourRows[idx] = {
        ..._colourRows[idx],
        'totalPcs': totalPcs.toInt(),
        'doz': doz,
        'balancePcs': balancePcs.toInt(),
        'rollMtr': double.parse(rollMtr.toStringAsFixed(3)),
        'actualRollMtr': double.parse(actualRollMtr.toStringAsFixed(3)),
        'foldReq': double.parse(foldReq.toStringAsFixed(3)),
        'foldDiff': double.parse(foldDiff.toStringAsFixed(3)),
        'actRollWt': double.parse(actRollWt.toStringAsFixed(3)),
        'dozWeight': double.parse(dozWeight.toStringAsFixed(3)),
        'weightDifference': double.parse(weightDiff.toStringAsFixed(3)),
        'cutterWaste': double.parse(cutterWaste.toStringAsFixed(3)),
        'offWaste': double.parse(offWaste.toStringAsFixed(3)),
        'totalWaste': double.parse(totalWaste.toStringAsFixed(3)),
        'cutWt': double.parse(cutWt.toStringAsFixed(3)),
        'finalBal': double.parse(finalBal.toStringAsFixed(3)),
        'differ': double.parse(differ.toStringAsFixed(3)),
        'actualEff': double.parse(actualEff.toStringAsFixed(2)),
        'effDifference': double.parse(effDiff.toStringAsFixed(2)),
      };
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'itemName': _itemNameCtrl.text.trim(),
      'size': _sizeCtrl.text.trim(),
      'lotNo': _lotNoCtrl.text.trim(),
      'lotName': _lotNameCtrl.text.trim(),
      'dia': _diaCtrl.text.trim(),
      'actualDia': _actualDiaCtrl.text.trim(),
      'setNo': _setNoCtrl.text.trim(),
      'cutNo': _cutNoCtrl.text.trim(),
      'trnNo': _trnNoCtrl.text.trim(),
      'dyedDcNos': _dyedDcNoCtrl.text.trim().isNotEmpty
          ? _dyedDcNoCtrl.text.trim().split(',').map((e) => e.trim()).toList()
          : [],
      'rackName': _rackNameCtrl.text.trim(),
      'palletNo': _palletNoCtrl.text.trim(),
      'layMasterName': _layMasterNameCtrl.text.trim(),
      'layLength': double.tryParse(_layLengthCtrl.text) ?? 0,
      'miniLayLength': double.tryParse(_miniLayLengthCtrl.text) ?? 0,
      'layMarkingPcs': double.tryParse(_layMarkingPcsCtrl.text) ?? 0,
      'miniMarkingPcs': double.tryParse(_miniMarkingPcsCtrl.text) ?? 0,
      'foldWtPerDoz': double.tryParse(_foldWtPerDozCtrl.text) ?? 0,
      'fixedGSM': double.tryParse(_fixedGSMCtrl.text) ?? 0,
      'fixedTimeToFinishLay': _fixedTimeToFinishLayCtrl.text.trim(),
      'cutterStartTime': _cutterStartTimeCtrl.text.trim(),
      'cutterEndTime': _cutterEndTimeCtrl.text.trim(),
      'remarks': _remarksCtrl.text.trim(),
      'cuttingDate': _cuttingDate.toIso8601String(),
      'status': _status,
      'weightDate': _weightDate?.toIso8601String(),
      'slipCheckedBy': _slipCheckedByCtrl.text.trim(),
      'enteredBy': _enteredByCtrl.text.split('&').first.trim(),
      'enteredDate': DateTime.now().toIso8601String(),
      'authorizedSign': _authorizedSignature ?? _authorizedSignatureUrl,
      'inchargeSign': _inchargeSignature ?? _inchargeSignatureUrl,
      'colourRows': _colourRows,
    };

    bool ok;
    if (_entryId != null) {
      ok = await _api.updateCuttingEntry(_entryId!, data);
    } else {
      ok = await _api.createCuttingEntry(data);
    }
    setState(() => _saving = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_entryId != null ? 'Entry updated!' : 'Entry saved!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl,
      {bool required = false,
      TextInputType type = TextInputType.text,
      String? suffix,
      bool readOnly = false,
      VoidCallback? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        readOnly: readOnly,
        onChanged: onChanged != null ? (_) => onChanged() : null,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          filled: true,
          fillColor: readOnly ? Colors.grey.shade100 : Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> options,
      Function(String?) onChanged, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: options.contains(value) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        isExpanded: true,
        items: options.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: onChanged,
        validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
      ),
    );
  }

  Widget _buildColourRowCard(int idx) {
    final row = _colourRows[idx];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Colour ${idx + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: () => setState(() => _colourRows.removeAt(idx)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Colour dropdown or input
            _buildDropdownField(
                'Colour Name', row['colour']?.toString() ?? '', 
                _outwards.expand((o) {
                  final items = o['items'] as List? ?? [];
                  return items.expand((i) {
                    final cols = i['colours'] as List? ?? [];
                    return cols.map((c) => c['colour']?.toString() ?? '');
                  });
                }).toSet().where((c) => c.isNotEmpty).toList(), 
                (v) => setState(() => _colourRows[idx]['colour'] = v)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _buildRowField('Fresh Layer',
                    (row['freshLayer'] ?? 0).toString(), (v) {
                  _colourRows[idx]['freshLayer'] = double.tryParse(v) ?? 0;
                  _recalcRow(idx);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRowField('Mini Lay', (row['miniLay'] ?? 0).toString(), (v) {
                  _colourRows[idx]['miniLay'] = double.tryParse(v) ?? 0;
                  _recalcRow(idx);
                }),
              ),
            ]),
            Row(children: [
              Expanded(
                child: _buildRowField('Mini Marking Pcs', (row['miniMarkingPcs'] ?? 0).toString(), (v) {
                  _colourRows[idx]['miniMarkingPcs'] = double.tryParse(v) ?? 0;
                  _recalcRow(idx);
                }),
              ),
              const SizedBox(width: 8),
              const Spacer(),
            ]),
            // Calculated Block 1
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _calcChip('Total Pcs', '${row['totalPcs'] ?? 0}'),
                  _calcChip('Doz', '${row['doz'] ?? 0}'),
                  _calcChip('Bal Pcs', '${row['balancePcs'] ?? 0}'),
                  _calcChip('Roll Mtr', '${row['rollMtr'] ?? 0}'),
                  _calcChip('Act Roll Mtr', '${row['actualRollMtr'] ?? 0}'),
                  _calcChip('Fold Req', '${row['foldReq'] ?? 0}'),
                  _calcChip('Fold Diff', '${row['foldDiff'] ?? 0}'),
                  _calcChip('Act Roll WT', '${row['actRollWt'] ?? 0}'),
                  _calcChip('Doz WT', '${row['dozWeight'] ?? 0}'),
                  _calcChip('WT Diff', '${row['weightDifference'] ?? 0}'),
                  _calcChip('Cutter Waste', '${row['cutterWaste'] ?? 0}'),
                  _calcChip('Off Waste', '${row['offWaste'] ?? 0}'),
                  _calcChip('Total Waste', '${row['totalWaste'] ?? 0}'),
                  _calcChip('Cut WT', '${row['cutWt'] ?? 0}'),
                  _calcChip('Final Bal', '${row['finalBal'] ?? 0}'),
                  _calcChip('Differ', '${row['differ'] ?? 0}'),
                  _calcChip('Act Eff %', '${row['actualEff'] ?? 0}%'),
                  _calcChip('Eff Diff', '${row['effDifference'] ?? 0}%'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _buildRowField(
                    'Roll WT (kg)', (row['rollWT'] ?? 0).toString(), (v) {
                  _colourRows[idx]['rollWT'] = double.tryParse(v) ?? 0;
                  _recalcRow(idx);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRowField('Costing Weight',
                    (row['costingWeight'] ?? 0).toString(), (v) {
                  _colourRows[idx]['costingWeight'] = double.tryParse(v) ?? 0;
                  _recalcRow(idx);
                }),
              ),
            ]),
            Row(children: [
              Expanded(
                child: _buildRowField('Actual Folding',
                    (row['actualFolding'] ?? 0).toString(), (v) {
                  _colourRows[idx]['actualFolding'] = double.tryParse(v) ?? 0;
                  _recalcRow(idx);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRowField(
                    'CAD Eff %', (row['cadEff'] ?? 0).toString(), (v) {
                  _colourRows[idx]['cadEff'] = double.tryParse(v) ?? 0;
                  _recalcRow(idx);
                }),
              ),
            ]),
            Row(children: [
              Expanded(
                child: _buildRowField('End Bit', (row['endBit'] ?? 0).toString(), (v) {
                  _colourRows[idx]['endBit'] = double.tryParse(v) ?? 0;
                  _recalcRow(idx);
                }, suffix: 'V/W'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRowField('Mistake', (row['mistake'] ?? 0).toString(), (v) {
                  _colourRows[idx]['mistake'] = double.tryParse(v) ?? 0;
                  _recalcRow(idx);
                }, suffix: 'V/W'),
              ),
            ]),
            Row(children: [
              Expanded(
                child: _buildRowField('Return WT', (row['returnWT'] ?? 0).toString(), (v) {
                  _colourRows[idx]['returnWT'] = double.tryParse(v) ?? 0;
                  _recalcRow(idx);
                }, suffix: 'A/W'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRowField('Lay Bal', (row['layBal'] ?? 0).toString(), (v) {
                  _colourRows[idx]['layBal'] = double.tryParse(v) ?? 0;
                  _recalcRow(idx);
                }),
              ),
            ]),
            _buildRowField('Complaint in Roll', (row['complaint'] ?? '').toString(), (v) {
              _colourRows[idx]['complaint'] = v;
            }, suffix: 'A/I'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildRowField(String label, String value, Function(String) onChanged, {String? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        key: Key('${label}_${value}'),
        initialValue: value,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          suffixText: suffix,
          suffixStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }

  Widget _calcChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  void _openSignaturePad(Function(XFile?) onPick) async {
    final result = await showDialog<XFile?>(
      context: context,
      builder: (ctx) => const SignaturePadDialog(),
    );
    if (result != null) {
      onPick(result);
    }
  }

  Widget _buildSigBox(String label, XFile? file, Function(XFile?) onPick, {String? url}) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _openSignaturePad(onPick),
          child: Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(file.path, fit: BoxFit.contain)
                        : Image.file(File(file.path), fit: BoxFit.contain),
                  )
                : (url != null && url.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(ApiConstants.getImageUrl(url), fit: BoxFit.contain),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_note, color: Colors.grey.shade400),
                            Text("Tap to sign", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          ],
                        ),
                      ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          _entryId != null ? 'Edit Cutting Entry' : 'New Cutting Entry',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          if (_entryId != null)
            TextButton.icon(
              icon: const Icon(Icons.looks_two_outlined, size: 18),
              label: const Text('Page 2'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CuttingEntryPage2Screen(entryId: _entryId!),
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // Header info card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Basic Information'),
                          // Cutting date picker
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _cuttingDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() => _cuttingDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 18,
                                      color: Theme.of(context).primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cutting Date: ${DateFormat('dd MMM yyyy').format(_cuttingDate)}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Dyed DC No Dropdown
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<String>(
                              value: _outwards.any((o) => o['dcNo'].toString() == _selectedDcNo) ? _selectedDcNo : null,
                              decoration: InputDecoration(
                                labelText: 'Dyed DC No',
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.grey.shade300)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              items: _outwards.map((o) => DropdownMenuItem(
                                value: o['dcNo'].toString(),
                                child: Text(o['dcNo'].toString())
                              )).toList(),
                              onChanged: (v) => _onDcNoSelected(v!),
                            ),
                          ),
                          Row(children: [
                            Expanded(
                              child: _buildDropdownField(
                                'Item Name *',
                                _itemNameCtrl.text,
                                _availableItems,
                                (v) => setState(() => _itemNameCtrl.text = v!),
                                required: true
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDropdownField(
                                'Size',
                                _sizeCtrl.text,
                                _availableSizes,
                                (v) => setState(() => _sizeCtrl.text = v!)
                              ),
                            ),
                          ]),
                          Row(children: [
                            Expanded(child: _buildTextField('Lot No', _lotNoCtrl, readOnly: true)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildTextField('Lot Name', _lotNameCtrl, readOnly: true)),
                          ]),
                          Row(children: [
                            Expanded(child: _buildTextField('Dia', _diaCtrl, readOnly: true)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildTextField('Category', _categoryCtrl, readOnly: true)),
                          ]),
                          _buildTextField('Actual Dia', _actualDiaCtrl),

                          Row(children: [
                            Expanded(
                              child: _buildDropdownField(
                                'Set No',
                                _setNoCtrl.text,
                                _availableSetNos,
                                (v) => setState(() => _setNoCtrl.text = v!)
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: _buildTextField('Cut No', _cutNoCtrl, readOnly: true, suffix: '[Auto]')),
                          ]),
                          Row(children: [
                            Expanded(child: _buildTextField('TRN No.', _trnNoCtrl, readOnly: true, suffix: '[Auto]')),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _weightDate != null 
                                    ? 'Weight Date: ${DateFormat('dd/MM/yyyy').format(_weightDate!)}'
                                    : 'Weight Date: NOT SET',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ]),
                          Row(children: [
                            Expanded(child: _buildTextField('Cutter Start', _cutterStartTimeCtrl)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildTextField('Cutter End', _cutterEndTimeCtrl)),
                          ]),
                          Row(children: [
                            Expanded(child: _buildTextField('Rack Name', _rackNameCtrl)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildTextField('Pallet No', _palletNoCtrl)),
                          ]),
                          // Status dropdown
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<String>(
                              value: _status,
                              decoration: InputDecoration(
                                labelText: 'Status',
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.grey.shade300)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              items: ['Pending', 'In Progress', 'Completed']
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (v) => setState(() => _status = v!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Lay Information
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Lay Information'),
                          _buildDropdownField(
                              'Lay Master Name', _layMasterNameCtrl.text, 
                              ['SHASC', 'SECDING'], 
                              (v) => setState(() => _layMasterNameCtrl.text = v!)),
                          Row(children: [
                            Expanded(
                                child: _buildTextField(
                                    'Lay Length (m)', _layLengthCtrl,
                                    type: TextInputType.text,
                                    onChanged: () {
                              for (int i = 0; i < _colourRows.length; i++) {
                                _recalcRow(i);
                              }
                            })),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _buildTextField(
                                    'Mini Lay Length', _miniLayLengthCtrl,
                                    type: TextInputType.text,
                                    onChanged: () {
                              for (int i = 0; i < _colourRows.length; i++) {
                                _recalcRow(i);
                              }
                            })),
                          ]),
                          Row(children: [
                            Expanded(
                                child: _buildTextField(
                                    'Lay Marking Pcs', _layMarkingPcsCtrl,
                                    type: TextInputType.text,
                                    onChanged: () {
                              for (int i = 0; i < _colourRows.length; i++) {
                                _recalcRow(i);
                              }
                            })),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _buildTextField(
                                    'Mini Marking Pcs', _miniMarkingPcsCtrl,
                                    type: TextInputType.text,
                                    onChanged: () {
                              for (int i = 0; i < _colourRows.length; i++) {
                                _recalcRow(i);
                              }
                            })),
                          ]),
                          Row(children: [
                            Expanded(
                                child: _buildTextField(
                                    'Fixed GSM', _fixedGSMCtrl,
                                    type: TextInputType.number,
                                    onChanged: () {
                               for (int i = 0; i < _colourRows.length; i++) {
                                 _recalcRow(i);
                               }
                             })),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _buildTextField(
                                    'Fixed Time to Finish', _fixedTimeToFinishLayCtrl,
                                    readOnly: true)),
                          ]),
                          _buildTextField(
                              'Fold Wt/Doz', _foldWtPerDozCtrl,
                              type: TextInputType.number,
                              onChanged: () {
                               for (int i = 0; i < _colourRows.length; i++) {
                                 _recalcRow(i);
                               }
                             }),
                          const SizedBox(height: 16),
                          const Divider(),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Sticker Data Information:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Text('Sticker No 1:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(_stickerNo?.isNotEmpty == true ? _stickerNo! : '[Auto-Generated after Save]', 
                               style: TextStyle(fontSize: 12, color: _stickerNo?.isNotEmpty == true ? Colors.blue : Colors.blueGrey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Colour Rows
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle('Colour-wise Lay Details'),
                              const SizedBox(width: 8),
                              Flexible(
                                child: ElevatedButton.icon(
                                  onPressed: _addColourRow,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Colour', overflow: TextOverflow.ellipsis),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_colourRows.isEmpty)
                            Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'No colour rows added. Tap "Add Colour" to start.',
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 13),
                                ),
                              ),
                            ),
                          ...List.generate(_colourRows.length,
                              (i) => _buildColourRowCard(i)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Remarks & Signatures
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Remarks & Authorization'),
                          TextFormField(
                            controller: _remarksCtrl,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'Enter any remarks...',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField('SLIP CHECKED BY', _slipCheckedByCtrl),
                          _buildTextField('Entered By & Date', _enteredByCtrl, readOnly: true),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSigBox(
                                  'Authorized Sign',
                                  _authorizedSignature,
                                  (file) => setState(() => _authorizedSignature = file),
                                  url: _authorizedSignatureUrl,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildSigBox(
                                  'Incharge Sign',
                                  _inchargeSignature,
                                  (file) => setState(() => _inchargeSignature = file),
                                  url: _inchargeSignatureUrl,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  _entryId != null ? 'Update Entry' : 'Save Cutting Entry',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _itemNameCtrl.dispose();
    _sizeCtrl.dispose();
    _lotNoCtrl.dispose();
    _lotNameCtrl.dispose();
    _diaCtrl.dispose();
    _actualDiaCtrl.dispose();
    _setNoCtrl.dispose();
    _dyedDcNoCtrl.dispose();
    _cutNoCtrl.dispose();
    _trnNoCtrl.dispose();
    _rackNameCtrl.dispose();
    _palletNoCtrl.dispose();
    _layMasterNameCtrl.dispose();
    _layLengthCtrl.dispose();
    _miniLayLengthCtrl.dispose();
    _layMarkingPcsCtrl.dispose();
    _miniMarkingPcsCtrl.dispose();
    _foldWtPerDozCtrl.dispose();
    _fixedGSMCtrl.dispose();
    _fixedTimeToFinishLayCtrl.dispose();
    _cutterStartTimeCtrl.dispose();
    _cutterEndTimeCtrl.dispose();
    _remarksCtrl.dispose();
    _slipCheckedByCtrl.dispose();
    _enteredByCtrl.dispose();
    _authorizedSignCtrl.dispose();
    _inchargeSignCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }
}
