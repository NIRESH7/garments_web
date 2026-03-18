import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';
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
  final _diaCtrl = TextEditingController();
  final _actualDiaCtrl = TextEditingController();
  final _setNoCtrl = TextEditingController();
  final _dyedDcNoCtrl = TextEditingController();
  final _rackNameCtrl = TextEditingController();
  final _palletNoCtrl = TextEditingController();
  final _layMasterNameCtrl = TextEditingController();
  final _layLengthCtrl = TextEditingController();
  final _miniLayLengthCtrl = TextEditingController();
  final _layMarkingPcsCtrl = TextEditingController();
  final _miniMarkingPcsCtrl = TextEditingController();
  final _foldWtPerDozCtrl = TextEditingController();
  final _fixedGSMCtrl = TextEditingController();
  final _cutterStartTimeCtrl = TextEditingController();
  final _cutterEndTimeCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  DateTime _cuttingDate = DateTime.now();
  String _status = 'Pending';
  String? _entryId;

  // Colour rows
  List<Map<String, dynamic>> _colourRows = [];

  // Available items/lots for dropdown hints
  List<dynamic> _cuttingMasters = [];
  List<dynamic> _inwards = [];

  @override
  void initState() {
    super.initState();
    _entryId = widget.entryId;
    _loadMasters();
    if (_entryId != null) _loadEntry();
  }

  Future<void> _loadMasters() async {
    final masters = await _api.getCuttingMasters();
    final inwards = await _api.getInwards();
    setState(() {
      _cuttingMasters = masters;
      _inwards = inwards;
    });
  }

  Future<void> _loadEntry() async {
    try {
      setState(() => _loading = true);
      final data = await _api.getCuttingEntryById(_entryId!);
      if (data != null) {
        _itemNameCtrl.text = (data['itemName'] ?? '').toString();
        _sizeCtrl.text = (data['size'] ?? '').toString();
        _lotNoCtrl.text = (data['lotNo'] ?? '').toString();
        _diaCtrl.text = (data['dia'] ?? '').toString();
        _actualDiaCtrl.text = (data['actualDia'] ?? '').toString();
        _setNoCtrl.text = (data['setNo'] ?? '').toString();

        var dyedDcData = data['dyedDcNos'];
        if (dyedDcData is String) {
          try {
            dyedDcData = jsonDecode(dyedDcData);
          } catch (_) {}
        }
        if (dyedDcData is List) {
          _dyedDcNoCtrl.text = dyedDcData.join(', ');
        } else {
          _dyedDcNoCtrl.text = (dyedDcData ?? '').toString();
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
        _cutterStartTimeCtrl.text = (data['cutterStartTime'] ?? '').toString();
        _cutterEndTimeCtrl.text = (data['cutterEndTime'] ?? '').toString();
        _remarksCtrl.text = (data['remarks'] ?? '').toString();
        _status = (data['status'] ?? 'Pending').toString();
        if (data['cuttingDate'] != null) {
          _cuttingDate = DateTime.parse(data['cuttingDate'].toString()).toLocal();
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
    final row = _colourRows[idx];
    final freshLayer = (row['freshLayer'] as num?)?.toDouble() ?? 0;
    final miniLay = (row['miniLay'] as num?)?.toDouble() ?? 0;
    final layMarkingPcs = double.tryParse(_layMarkingPcsCtrl.text) ?? 0;
    final miniMarkingPcs = double.tryParse(_miniMarkingPcsCtrl.text) ?? 0;
    final foldWtPerDoz = double.tryParse(_foldWtPerDozCtrl.text) ?? 0;
    final layLength = double.tryParse(_layLengthCtrl.text) ?? 0;
    final miniLayLength = double.tryParse(_miniLayLengthCtrl.text) ?? 0;

    final totalPcs = (freshLayer * layMarkingPcs) + (miniLay * miniMarkingPcs);
    final doz = (totalPcs / 12).floor();
    final balancePcs = (doz * 12) - totalPcs;
    final foldReq = (totalPcs / 12) * foldWtPerDoz;
    final actualRollMtr = (freshLayer * layLength) + (miniLay * miniLayLength);

    final rollWT = (row['rollWT'] as num?)?.toDouble() ?? 0;
    final actualFolding = (row['actualFolding'] as num?)?.toDouble() ?? 0;
    final endBit = (row['endBit'] as num?)?.toDouble() ?? 0;
    final mistake = (row['mistake'] as num?)?.toDouble() ?? 0;

    final foldDiff = actualFolding - foldReq;
    final actRollWt = rollWT - actualFolding;
    final finalBal = actRollWt - (endBit + mistake);

    setState(() {
      _colourRows[idx] = {
        ..._colourRows[idx],
        'totalPcs': totalPcs.toInt(),
        'doz': doz,
        'balancePcs': balancePcs.toInt(),
        'foldReq': double.parse(foldReq.toStringAsFixed(3)),
        'actualRollMtr': double.parse(actualRollMtr.toStringAsFixed(3)),
        'foldDiff': double.parse(foldDiff.toStringAsFixed(3)),
        'actRollWt': double.parse(actRollWt.toStringAsFixed(3)),
        'finalBal': double.parse(finalBal.toStringAsFixed(3)),
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
      'dia': _diaCtrl.text.trim(),
      'actualDia': _actualDiaCtrl.text.trim(),
      'setNo': _setNoCtrl.text.trim(),
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
      'cutterStartTime': _cutterStartTimeCtrl.text.trim(),
      'cutterEndTime': _cutterEndTimeCtrl.text.trim(),
      'remarks': _remarksCtrl.text.trim(),
      'cuttingDate': _cuttingDate.toIso8601String(),
      'status': _status,
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
      VoidCallback? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        onChanged: onChanged != null ? (_) => onChanged() : null,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? 'Required' : null
            : null,
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
            // Colour input
            TextFormField(
              initialValue: row['colour']?.toString() ?? '',
              decoration: InputDecoration(
                labelText: 'Colour Name',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => _colourRows[idx]['colour'] = v,
            ),
            const SizedBox(height: 8),
            // Fresh Layer + Mini Lay (side by side)
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
                child: _buildRowField(
                    'Mini Lay', (row['miniLay'] ?? 0).toString(), (v) {
                  _colourRows[idx]['miniLay'] = double.tryParse(v) ?? 0;
                  _recalcRow(idx);
                }),
              ),
            ]),
            // Auto-calculated fields (read-only)
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
                  _calcChip('Fold Req', '${row['foldReq'] ?? 0}'),
                  _calcChip('Act Roll Mtr', '${row['actualRollMtr'] ?? 0}'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Manual fields
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
                child: _buildRowField('Return WT',
                    (row['returnWT'] ?? 0).toString(), (v) {
                  _colourRows[idx]['returnWT'] = double.tryParse(v) ?? 0;
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
                    'End Bit', (row['endBit'] ?? 0).toString(), (v) {
                  _colourRows[idx]['endBit'] = double.tryParse(v) ?? 0;
                  _recalcRow(idx);
                }),
              ),
            ]),
            Row(children: [
              Expanded(
                child:
                    _buildRowField('Mistake', (row['mistake'] ?? 0).toString(),
                        (v) {
                  _colourRows[idx]['mistake'] = double.tryParse(v) ?? 0;
                  _recalcRow(idx);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _buildRowField('Lay Bal', (row['layBal'] ?? 0).toString(),
                        (v) {
                  _colourRows[idx]['layBal'] = double.tryParse(v) ?? 0;
                }),
              ),
            ]),
            // Final totals
            if ((row['finalBal'] ?? 0) != 0 || (row['actRollWt'] ?? 0) != 0)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _calcChip('Fold Diff', '${row['foldDiff'] ?? 0}'),
                    _calcChip('Act Roll Wt', '${row['actRollWt'] ?? 0}'),
                    _calcChip('Final Bal', '${row['finalBal'] ?? 0}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowField(String label, String value, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: value,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                padding: const EdgeInsets.all(16),
                children: [
                  // Header info card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
                          // Dyed DC Nos
                          _buildTextField('Dyed DC Nos (comma separated)',
                              _dyedDcNoCtrl),
                          Row(children: [
                            Expanded(
                                child: _buildTextField(
                                    'Item Name *', _itemNameCtrl,
                                    required: true)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTextField('Size', _sizeCtrl)),
                          ]),
                          Row(children: [
                            Expanded(
                                child: _buildTextField('Lot No', _lotNoCtrl)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTextField('Set No', _setNoCtrl)),
                          ]),
                          Row(children: [
                            Expanded(child: _buildTextField('Dia', _diaCtrl)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTextField(
                                    'Actual Dia', _actualDiaCtrl)),
                          ]),
                          Row(children: [
                            Expanded(
                                child: _buildTextField(
                                    'Cutter Start', _cutterStartTimeCtrl)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTextField(
                                    'Cutter End', _cutterEndTimeCtrl)),
                          ]),
                          Row(children: [
                            Expanded(
                                child: _buildTextField(
                                    'Rack Name', _rackNameCtrl)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTextField(
                                    'Pallet No', _palletNoCtrl)),
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Lay Information'),
                          _buildTextField(
                              'Lay Master Name', _layMasterNameCtrl),
                          Row(children: [
                            Expanded(
                                child: _buildTextField(
                                    'Lay Length (m)', _layLengthCtrl,
                                    type: TextInputType.number,
                                    onChanged: () {
                              for (int i = 0; i < _colourRows.length; i++) {
                                _recalcRow(i);
                              }
                            })),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTextField(
                                    'Mini Lay Length', _miniLayLengthCtrl,
                                    type: TextInputType.number,
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
                                    type: TextInputType.number,
                                    onChanged: () {
                              for (int i = 0; i < _colourRows.length; i++) {
                                _recalcRow(i);
                              }
                            })),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTextField(
                                    'Mini Marking Pcs', _miniMarkingPcsCtrl,
                                    type: TextInputType.number,
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
                                    type: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTextField(
                                    'Fold Wt/Doz', _foldWtPerDozCtrl,
                                    type: TextInputType.number,
                                    onChanged: () {
                              for (int i = 0; i < _colourRows.length; i++) {
                                _recalcRow(i);
                              }
                            })),
                          ]),
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
                      padding: const EdgeInsets.all(16),
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
                  // Remarks
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Remarks'),
                          TextFormField(
                            controller: _remarksCtrl,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Enter any remarks...',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.all(12),
                            ),
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
    _diaCtrl.dispose();
    _actualDiaCtrl.dispose();
    _setNoCtrl.dispose();
    _dyedDcNoCtrl.dispose();
    _rackNameCtrl.dispose();
    _palletNoCtrl.dispose();
    _layMasterNameCtrl.dispose();
    _layLengthCtrl.dispose();
    _miniLayLengthCtrl.dispose();
    _layMarkingPcsCtrl.dispose();
    _miniMarkingPcsCtrl.dispose();
    _foldWtPerDozCtrl.dispose();
    _fixedGSMCtrl.dispose();
    _cutterStartTimeCtrl.dispose();
    _cutterEndTimeCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }
}
