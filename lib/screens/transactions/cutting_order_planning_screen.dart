import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/app_drawer.dart';
import '../../services/lot_allocation_print_service.dart';
import 'cutting_order_list_screen.dart';

class CuttingOrderPlanningScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const CuttingOrderPlanningScreen({super.key, this.initialData});

  @override
  State<CuttingOrderPlanningScreen> createState() =>
      _CuttingOrderPlanningScreenState();
}

class _CuttingOrderPlanningScreenState
    extends State<CuttingOrderPlanningScreen> {
  final _api = MobileApiService();
  final _printService = LotAllocationPrintService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;
  // ── Edit mode ────────────────────────────────────────────────────────────
  String? _editingId;          // null = create mode, non-null = edit mode

  String _planType = 'Monthly';
  String _planPeriod = DateFormat('yyyy-MM').format(DateTime.now());
  final _planNameCtrl = TextEditingController();

  List<String> _itemNames = [];
  List<int> get _sizes => _sizeType == 'Senior'
      ? [75, 80, 85, 90, 95, 100, 105, 110]
      : [50, 55, 60, 65, 70, 75];
  final List<Map<String, dynamic>> _cuttingEntries = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
    if (widget.initialData != null) {
      _editEntry(widget.initialData!);
    } else {
      _addInitialRow();
    }
  }

  void _addInitialRow() {
    setState(() {
      final entry = {
        'itemName': '',
        'sizeQuantities': {for (var s in _sizes) s.toString(): 0},
        'totalDozens': 0,
      };
      _cuttingEntries.add(entry);
    });
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _api.getCategories();
      setState(() {
        _itemNames = _getValues(categories, ['Item Name', 'itemName', 'item']);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error loading master data: $e');
      }
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

  void _calculateTotal(int index) {
    setState(() {
      int total = 0;
      final quantities =
          _cuttingEntries[index]['sizeQuantities'] as Map<String, dynamic>;
      quantities.forEach((key, value) {
        if (value is num) {
          total += value.toInt();
        } else if (value is String) {
          total += int.tryParse(value) ?? 0;
        }
      });
      _cuttingEntries[index]['totalDozens'] = total;
    });
  }

  Future<void> _savePlanningSheet() async {
    if (_isSaving) return;
    if (_cuttingEntries.any((e) => e['itemName'].isEmpty)) {
      _showError('Please select Item Name for all rows');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        'planName': _planNameCtrl.text.trim(),
        'planType': _planType,
        'planPeriod': _planPeriod,
        'startDate': _startDate?.toIso8601String(),
        'endDate': _endDate?.toIso8601String(),
        'sizeType': _sizeType,
        'cuttingEntries': _cuttingEntries,
        'status': 'Planned',
      };

      bool success;
      if (_editingId != null) {
        success = await _api.updateCuttingOrder(_editingId!, data);
      } else {
        success = await _api.saveCuttingOrder(data);
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_editingId != null
                ? 'Planning Sheet Updated Successfully'
                : 'Planning Sheet Saved Successfully')),
          );
          setState(() => _editingId = null);
        }
      } else {
        _showError('Failed to save planning sheet.');
      }
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      });
    }
  }

  void _printPlanningSheet() {
    if (_cuttingEntries.isEmpty ||
        _cuttingEntries.every((e) => e['itemName'].isEmpty)) {
      _showError('No details to print.');
      return;
    }

    // For current planning sheet (unsaved), cutting quantities are 0
    final entries = _cuttingEntries.map((e) {
      final newE = Map<String, dynamic>.from(e);
      newE['cuttingQuantities'] = {for (var s in _sizes) s.toString(): 0};
      return newE;
    }).toList();

    _printService.printCuttingOrderPlanning(
      _planType,
      _planPeriod,
      _startDate,
      _endDate,
      _sizeType,
      entries,
      _sizes,
    );
  }

  // ── Edit a previous entry ─────────────────────────────────────────────────
  void _editEntry(Map<String, dynamic> entry) {
    setState(() {
      _editingId = entry['_id']?.toString();
      _planNameCtrl.text = entry['planName']?.toString() ?? '';
      _planType  = entry['planType']?.toString()  ?? 'Monthly';
      _sizeType  = entry['sizeType']?.toString()  ?? 'Senior';
      _startDate = entry['startDate'] != null
          ? DateTime.tryParse(entry['startDate'].toString())
          : null;
      _endDate   = entry['endDate'] != null
          ? DateTime.tryParse(entry['endDate'].toString())
          : null;

      _cuttingEntries.clear();
      final entries = entry['cuttingEntries'] as List<dynamic>? ?? [];
      for (final e in entries) {
        final qty = (e['sizeQuantities'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
        ) ?? {for (final s in _sizes) s.toString(): 0};
        _cuttingEntries.add({
          'itemName': e['itemName']?.toString() ?? '',
          'sizeQuantities': qty,
          'totalDozens': e['totalDozens'] ?? 0,
        });
      }
      if (_cuttingEntries.isEmpty) _addInitialRow();
    });

    // Scroll to top so user sees the form
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Entry loaded for editing — tap UPDATE PLANNING SHEET to save'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  // ── Preview a previous entry ──────────────────────────────────────────────

  // ── Share a previous entry ────────────────────────────────────────────────

  // ── Print a previous entry ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CUTTING ORDER PLANNING'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.list, color: Colors.blue),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CuttingOrderListScreen()),
              );
            },
            tooltip: 'View Plans',
          ),
          IconButton(
            icon: const Icon(LucideIcons.printer),
            onPressed: _printPlanningSheet,
            tooltip: 'Print Planning Sheet',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildPlanParams(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEntryTable(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          offset: const Offset(0, -4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _savePlanningSheet,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 60,
                            vertical: 15,
                          ),
                          backgroundColor: primaryColor,
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
                                _editingId != null
                                    ? 'UPDATE PLANNING SHEET'
                                    : 'SAVE PLANNING SHEET',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  DateTime? _startDate;
  DateTime? _endDate;
  String _sizeType = 'Senior'; // 'Junior' (50-75) or 'Senior' (75-110)

  Widget _buildPlanParams() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _planNameCtrl,
              decoration: InputDecoration(
                labelText: 'PLAN NAME / REMARKS',
                hintText: 'e.g. Summer Collection 2026',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.edit_note),
                suffixIcon: null,
              ),
              onChanged: (val) {
                // Debounce or simple timer? For now, simple check
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _planType,
                    decoration: const InputDecoration(
                      labelText: 'PLAN TYPE',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Monthly', 'Yearly']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _planType = val!;
                        if (_planType == 'Monthly') {
                          _planPeriod = DateFormat(
                            'yyyy-MM',
                          ).format(DateTime.now());
                        } else {
                          _planPeriod = DateFormat(
                            'yyyy',
                          ).format(DateTime.now());
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sizeType,
                    decoration: const InputDecoration(
                      labelText: 'SIZE TYPE',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Senior', 'Junior']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _sizeType = val!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: _startDate != null
                          ? DateFormat('dd-MM-yyyy').format(_startDate!)
                          : '',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'FROM DATE',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: _endDate != null
                          ? DateFormat('dd-MM-yyyy').format(_endDate!)
                          : '',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'TO DATE',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryTable() {
    final primaryColor = Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PLANNING SHEET',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: primaryColor,
              ),
            ),
            TextButton.icon(
              onPressed: _addInitialRow,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('ADD LINE'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 15,
                horizontalMargin: 15,
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                border: TableBorder.symmetric(
                  inside: BorderSide(color: Colors.grey.shade300),
                ),
                columns: [
                  const DataColumn(
                    label: Text(
                      'ITEM NAME',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ..._sizes.map(
                    (s) => DataColumn(
                      label: Text(
                        s.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'DOZENS',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'ACTION',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: List.generate(_cuttingEntries.length, (index) {
                  final entry = _cuttingEntries[index];
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: entry['itemName'].isEmpty
                                ? null
                                : entry['itemName'],
                            items: _itemNames
                                .map(
                                  (name) => DropdownMenuItem(
                                    value: name,
                                    child: Text(name),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() => entry['itemName'] = val ?? '');
                            },
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Select Item',
                            ),
                          ),
                        ),
                      ),
                      ..._sizes.map((s) {
                        final sStr = s.toString();
                        return DataCell(
                          SizedBox(
                            width: 100, // Widened to fit large values better
                            child: TextFormField(
                              initialValue:
                                  entry['sizeQuantities'][sStr].toString() ==
                                      '0'
                                  ? ''
                                  : entry['sizeQuantities'][sStr].toString(),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLines: null, // Allow wrapping to the next line
                              onChanged: (val) {
                                setState(() {
                                  entry['sizeQuantities'][sStr] =
                                      int.tryParse(val) ?? 0;
                                  _calculateTotal(index);
                                });
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
                                border: InputBorder.none,
                                hintText: '0',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      DataCell(
                        Text(
                          entry['totalDozens'].toString(),
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => _cuttingEntries.removeAt(index));
                          },
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
