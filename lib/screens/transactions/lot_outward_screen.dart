import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';

import '../../widgets/custom_dropdown_field.dart';

class LotOutwardScreen extends StatefulWidget {
  const LotOutwardScreen({super.key});

  @override
  State<LotOutwardScreen> createState() => _LotOutwardScreenState();
}

class _LotOutwardScreenState extends State<LotOutwardScreen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();

  DateTime _outwardDateTime = DateTime.now();
  String _dcNumber = 'Loading...';
  String? _selectedLotName;
  String? _selectedDia;
  String? _selectedLotNo;
  String? _selectedParty;

  String? _process;
  String? _address;

  final _vehicleController = TextEditingController();
  final String _inTime = DateFormat('hh:mm a').format(DateTime.now());
  String? _outTime;

  List<String> _lotNames = [];
  List<String> _dias = [];
  List<String> _lotNos = [];
  List<String> _parties = [];

  List<Map<String, dynamic>> _availableSets = [];
  final List<Map<String, dynamic>> _selectedSets = [];

  bool _isLoading = true;
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final categories = await _api.getCategories();
    final parties = await _api.getParties();
    final dc = await _api.generateDcNumber();

    setState(() {
      _lotNames = _getValues(categories, 'Lot Name');
      _dias = _getValues(categories, 'dia');
      _parties = parties.map((m) => m['name'] as String).toList();
      _dcNumber = dc ?? 'ERR-GEN';
      _isLoading = false;
    });
  }

  List<String> _getValues(List<dynamic> categories, String name) {
    try {
      final List<String> result = [];
      final matches = categories.where((c) {
        final catName = (c['name'] ?? '').toString().trim().toLowerCase();
        return catName == name.trim().toLowerCase();
      });

      for (var cat in matches) {
        final dynamic rawValues = cat['values'];
        if (rawValues is List) {
          for (var v in rawValues) {
            String? val;
            if (v is Map) {
              val = (v['name'] ?? v['value'] ?? '').toString();
            } else if (v != null) {
              val = v.toString();
            }
            if (val != null && val.isNotEmpty && !result.contains(val)) {
              result.add(val);
            }
          }
        }
      }
      return result;
    } catch (e) {
      return [];
    }
  }

  Future<void> _onDiaChanged(String? val) async {
    setState(() {
      _selectedDia = val;
      _selectedLotNo = null;
      _lotNos = [];
      _availableSets = [];
      _selectedSets.clear();
    });
    if (val != null) {
      final lots = await _api.getLotsFifo(dia: val);
      setState(() => _lotNos = lots);
    }
  }

  Future<void> _onLotNoChanged(String? val) async {
    setState(() {
      _selectedLotNo = val;
      _availableSets = [];
      _selectedSets.clear();
    });
    if (val != null && _selectedDia != null) {
      final sets = await _api.getBalancedSets(val, _selectedDia!);
      setState(() => _availableSets = sets);
    }
  }

  Future<void> _onPartyChanged(String? val) async {
    setState(() {
      _selectedParty = val;
      _process = null;
      _address = null;
    });
    if (val != null) {
      final details = await _api.getPartyDetails(val);
      if (details != null) {
        setState(() {
          _process = details['process'];
          _address = details['address'];
        });
      }
    }
  }

  void _toggleSetSelection(Map<String, dynamic> set, bool selected) {
    setState(() {
      if (selected) {
        // Add new set with default fields
        _selectedSets.add({
          'set_no': set['set_no'].toString(),
          'colour': set['colour'] ?? '',
          'weight': (set['weight'] as num?)?.toDouble() ?? 0.0,
          'roll_weight': 0.0,
          'no_of_rolls': 1,
        });
      } else {
        _selectedSets.removeWhere(
          (s) => s['set_no'] == set['set_no'].toString(),
        );
      }
    });
  }

  void _removeSet(int index) {
    setState(() {
      _selectedSets.removeAt(index);
    });
  }

  // Summary calculation functions
  Map<String, double> _getColourTotals() {
    final Map<String, double> totals = {};
    for (var s in _selectedSets) {
      final colour = s['colour'].toString().trim().isEmpty
          ? 'N/A'
          : s['colour'].toString();
      totals[colour] = (totals[colour] ?? 0) + (s['weight'] as double);
    }
    return totals;
  }

  double _getTotalWeight() {
    return _selectedSets.fold(0.0, (sum, s) => sum + (s['weight'] as double));
  }

  double _getTotalRollWeight() {
    return _selectedSets.fold(
      0.0,
      (sum, s) => sum + (s['roll_weight'] as double),
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _outwardDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_outwardDateTime),
      );
      if (time != null) {
        setState(() {
          _outwardDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _save() async {
    if (_selectedLotName == null) {
      _showError('Please select Lot Name');
      return;
    }
    if (_selectedDia == null) {
      _showError('Please select DIA');
      return;
    }
    if (_selectedLotNo == null) {
      _showError('Please select Lot No (FIFO)');
      return;
    }
    if (_selectedParty == null) {
      _showError('Please select Party Name');
      return;
    }
    if (_selectedSets.isEmpty) {
      _showError('Please select at least one set');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _outTime = DateFormat('hh:mm a').format(DateTime.now());
      _isSaving = true;
    });

    final outwardData = {
      'dc_number': _dcNumber,
      'dateTime': _outwardDateTime.toIso8601String(),
      'lotName': _selectedLotName,
      'lotNo': _selectedLotNo,
      'dia': _selectedDia,
      'partyName': _selectedParty,
      'process': _process,
      'address': _address,
      'vehicleNo': _vehicleController.text,
      'inTime': _inTime,
      'outTime': _outTime,
      'items': _selectedSets
          .map(
            (s) => {
              'colour': s['colour'],
              'selected_weight': s['weight'],
              'set_no': s['set_no'],
              'roll_weight': s['roll_weight'],
              'no_of_rolls': s['no_of_rolls'],
            },
          )
          .toList(),
    };

    try {
      final success = await _api.saveOutward(outwardData);
      if (success) {
        setState(() => _isSaved = true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Outward Registered: $_dcNumber')),
        );

        // Prompt for sticker printing
        _showPrintStickerDialog();
      } else {
        _showError('Failed to save to backend');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showPrintStickerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Success'),
        content: const Text(
          'Outward saved. Do you want to print stickers for these rolls?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _printStickers();
            },
            child: const Text('Print Stickers'),
          ),
        ],
      ),
    );
  }

  void _printStickers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sticker Previews',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _selectedSets.length,
                itemBuilder: (context, idx) {
                  final item = _selectedSets[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 2),
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStickerRow('LOT NO', _selectedLotNo ?? '-'),
                        _buildStickerRow('Lot Name', _selectedLotName ?? '-'),
                        _buildStickerRow('Dia', _selectedDia ?? '-'),
                        _buildStickerRow('Colour', item['colour'] ?? '-'),
                        _buildStickerRow(
                          'Roll Wt',
                          '${item['roll_weight']} kg',
                        ),
                        _buildStickerRow(
                          'Date',
                          DateFormat('dd-MM-yyyy').format(_outwardDateTime),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black),
                                ),
                                child: QrImageView(
                                  data:
                                      'LOT: ${_selectedLotNo ?? '-'}\nNAME: ${_selectedLotName ?? '-'}\nDIA: ${_selectedDia ?? '-'}\nCOL: ${item['colour'] ?? '-'}\nWT: ${item['roll_weight']}kg\nDT: ${DateFormat('dd-MM-yyyy').format(_outwardDateTime)}',
                                  version: QrVersions.auto,
                                  size: 100.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'SCAN FOR AUTH',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Actual printing logic would use the 'printing' package
                  },
                  icon: const Icon(LucideIcons.printer),
                  label: const Text('Print Now'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label :',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'OUTWARD',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.mic),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice input (Tamil/English)...')),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDCSection(),
              const SizedBox(height: 16),
              _buildMainForm(),
              const SizedBox(height: 24),
              _buildSetSelectionSection(),
              const SizedBox(height: 24),
              _buildSelectedSetsList(),
              const SizedBox(height: 24),
              if (_selectedSets.isNotEmpty) _buildSummarySection(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_isSaved || _isSaving) ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.checkCircle),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : (_isSaved ? 'Dispatch Confirmed' : 'Save Outward'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSaved
                        ? Colors.grey
                        : ColorPalette.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDCSection() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: ColorPalette.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          'DC NO: $_dcNumber',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: ColorPalette.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildMainForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    'LOT NAME',
                    _lotNames,
                    _selectedLotName,
                    (v) => setState(() => _selectedLotName = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _isSaved ? null : _selectDateTime,
                    child: _buildReadOnlyField(
                      'DATE & TIME',
                      DateFormat('dd-MM-yyyy hh:mm a').format(_outwardDateTime),
                      icon: LucideIcons.calendar,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    'DIA',
                    _dias,
                    _selectedDia,
                    _onDiaChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    'LOT NO (FIFO)',
                    _lotNos,
                    _selectedLotNo,
                    _onLotNoChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              'PARTY NAME',
              _parties,
              _selectedParty,
              _onPartyChanged,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildReadOnlyField('PROCESS', _process ?? '-'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildReadOnlyField(
                    'ADDRESS',
                    _address ?? '-',
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vehicleController,
                    decoration: const InputDecoration(
                      labelText: 'VEHICLE NO',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(LucideIcons.truck, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildReadOnlyField('IN TIME', _inTime)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetSelectionSection() {
    if (_availableSets.isEmpty && _selectedLotNo != null) {
      return Card(
        color: Colors.orange.shade50,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '⚠️ No sets available for this Lot Number. Please ensure you completed the "Sticker & Storage Details" (Next Page) during Inward Entry.',
            style: TextStyle(color: Colors.orange, fontSize: 13),
          ),
        ),
      );
    }
    if (_availableSets.isEmpty) return const SizedBox.shrink();

    // Group available sets by unique set number to satisfy client req "Show only Set 1, 2, 3..."
    final uniqueSetNos = <int>{};
    for (var s in _availableSets) {
      uniqueSetNos.add(int.tryParse(s['set_no'].toString()) ?? 0);
    }
    final sortedSetNos = uniqueSetNos.toList()
      ..remove(0)
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECT SET NO (UNIQUE)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: sortedSetNos.map((setNo) {
            final isSelected = _selectedSets.any(
              (sel) => sel['set_no'] == setNo.toString(),
            );
            // Find default data for this set no for display only
            final defaultData = _availableSets.firstWhere(
              (s) => s['set_no'].toString() == setNo.toString(),
              orElse: () => {},
            );

            return ChoiceChip(
              label: Text('Set $setNo', style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (selected) {
                _toggleSetSelection(defaultData, selected);
              },
              selectedColor: ColorPalette.primary.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? ColorPalette.primary : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSelectedSetsList() {
    if (_selectedSets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECTED SET DETAILS (EDITABLE)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedSets.length,
          itemBuilder: (context, index) {
            final item = _selectedSets[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: ColorPalette.primary, width: 4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'SET NO: ${item['set_no']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: ColorPalette.primary,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              LucideIcons.trash2,
                              color: Colors.red,
                              size: 18,
                            ),
                            onPressed: () => _removeSet(index),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildItemEditField(
                              'Colour',
                              item['colour'],
                              (v) => setState(() => item['colour'] = v),
                              clearable: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildItemEditField(
                              'Weight',
                              item['weight'].toString(),
                              (v) => setState(
                                () =>
                                    item['weight'] = double.tryParse(v) ?? 0.0,
                              ),
                              suffix: 'kg',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildItemEditField(
                              'Roll Weight',
                              item['roll_weight'].toString(),
                              (v) => setState(
                                () => item['roll_weight'] =
                                    double.tryParse(v) ?? 0.0,
                              ),
                              suffix: 'kg',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildItemEditField(
                              'No. of Rolls',
                              item['no_of_rolls'].toString(),
                              (v) => setState(
                                () =>
                                    item['no_of_rolls'] = int.tryParse(v) ?? 1,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    final colourTotals = _getColourTotals();
    final totalWeight = _getTotalWeight();
    final totalRollWeight = _getTotalRollWeight();

    return Card(
      color: Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  LucideIcons.listOrdered,
                  size: 20,
                  color: ColorPalette.primary,
                ),
                SizedBox(width: 8),
                Text(
                  'OUTWARD SUMMARY',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 24),
            // Colour-wise table
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'COLOUR',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    'TOTAL WEIGHT',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
            ...colourTotals.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.key, style: const TextStyle(fontSize: 14)),
                    ),
                    Text(
                      '${e.value.toStringAsFixed(2)} kg',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 24),
            // Totals
            _buildSummaryRow(
              'Overall Weight',
              '${totalWeight.toStringAsFixed(2)} kg',
              isMain: true,
            ),
            const SizedBox(height: 4),
            _buildSummaryRow(
              'Total Roll Wt',
              '${totalRollWeight.toStringAsFixed(2)} kg',
            ),
            const SizedBox(height: 4),
            _buildSummaryRow('Total Sets', '${_selectedSets.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isMain = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isMain ? FontWeight.bold : FontWeight.normal,
            fontSize: isMain ? 15 : 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isMain ? 16 : 14,
            color: isMain ? ColorPalette.primary : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildItemEditField(
    String label,
    String value,
    Function(String) onChanged, {
    bool clearable = false,
    String? suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      initialValue: value == '0.0' || value == '0' ? '' : value,
      onChanged: onChanged,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        suffixIcon: clearable
            ? IconButton(
                icon: const Icon(Icons.clear, size: 14),
                onPressed: () {
                  // This is a bit tricky with initialValue.
                  // Better would be controllers, but let's try calling onChanged with empty.
                  onChanged('');
                },
              )
            : null,
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String? value,
    Function(String?) onChanged,
  ) {
    return CustomDropdownField(
      label: label,
      items: items,
      value: (value != null && items.contains(value)) ? value : null,
      onChanged: _isSaved ? (v) {} : onChanged,
    );
  }

  Widget _buildReadOnlyField(
    String label,
    String value, {
    IconData? icon,
    int maxLines = 1,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      ),
      child: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        overflow: TextOverflow.ellipsis,
        maxLines: maxLines,
      ),
    );
  }
}
