import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/mobile_api_service.dart';
import '../../services/lot_allocation_print_service.dart';
import 'cutting_order_list_screen.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/custom_dropdown_field.dart';
import '../../core/constants/layout_constants.dart';

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
  List<String> _savedPlanNames = [];
  bool _isManualPlanEntry = false;

  List<String> _itemNames = [];
  Map<String, String?> _itemSizeTypeMap = {}; // Maps item name to its configured size type
  
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
        _itemNames = [];
        _itemSizeTypeMap = {};
        
        final matches = categories.where((c) {
          final name = (c['name'] ?? '').toString().toLowerCase();
          return ['item name', 'itemname', 'item'].contains(name);
        });

        for (var cat in matches) {
          final values = cat['values'] as List<dynamic>?;
          if (values != null) {
            for (var v in values) {
              if (v is Map) {
                final name = v['name']?.toString() ?? '';
                if (name.isNotEmpty) {
                  if (!_itemNames.contains(name)) _itemNames.add(name);
                  _itemSizeTypeMap[name] = v['sizeType']?.toString();
                }
              } else if (v is String && v.isNotEmpty) {
                if (!_itemNames.contains(v)) _itemNames.add(v);
              }
            }
          }
        }
        _isLoading = false;
      });

      // Load existing plans for the dropdown
      final plans = await _api.getCuttingOrders();
      if (plans != null && plans is List) {
        final List<String> uniqueNames = [];
        for (var p in plans) {
          final name = p['planName']?.toString() ?? '';
          if (name.isNotEmpty && !uniqueNames.contains(name)) {
            uniqueNames.add(name);
          }
        }
        setState(() {
          _savedPlanNames = uniqueNames;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error loading master data: $e');
      }
    }
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
        await _loadMasterData();
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

  void _updateSizeType(String newType) {
    if (_sizeType == newType) return;
    setState(() {
      _sizeType = newType;
      // Re-initialize sizeQuantities for all rows to match new sizes
      for (var entry in _cuttingEntries) {
        final oldQty = Map<String, dynamic>.from(entry['sizeQuantities']);
        final newSizes = _sizes;
        final newQty = {for (var s in newSizes) s.toString(): 0};
        
        // Preserve values for overlapping sizes (e.g., 75)
        oldQty.forEach((size, qty) {
          if (newQty.containsKey(size)) {
            newQty[size] = qty;
          }
        });
        
        entry['sizeQuantities'] = newQty;
      }
      
      // Re-calculate totals for all rows
      for (int i = 0; i < _cuttingEntries.length; i++) {
        _calculateTotal(i);
      }
    });
  }

  void _onItemChanged(int index, String? itemName) {
    if (itemName == null) return;
    setState(() {
      _cuttingEntries[index]['itemName'] = itemName;
      
      // Auto-update Size Type if item has a preferred one
      final preferredSizeType = _itemSizeTypeMap[itemName];
      if (preferredSizeType != null && (preferredSizeType == 'Senior' || preferredSizeType == 'Junior')) {
        _updateSizeType(preferredSizeType);
      }
    });
  }

  void _printPlanningSheet() {
    if (_cuttingEntries.isEmpty ||
        _cuttingEntries.every((e) => e['itemName'].isEmpty)) {
      _showError('No details to print.');
      return;
    }

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry loaded for editing — tap UPDATE to save'),
            backgroundColor: Color(0xFF2563EB),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  DateTime? _startDate;
  DateTime? _endDate;
  String _sizeType = 'Senior'; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Form(
              key: _formKey,
              child: Column(
                children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Row at the top of the form
                  Row(
                    children: [
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _printPlanningSheet,
                        icon: const Icon(LucideIcons.printer, size: 14),
                        label: Text('PRINT', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11)),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CuttingOrderListScreen()),
                          ).then((_) => _loadMasterData());
                        },
                        icon: const Icon(LucideIcons.list, size: 14),
                        label: Text('RECORDS', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11)),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _isSaving ? null : _savePlanningSheet,
                        icon: _isSaving 
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(LucideIcons.check, size: 14, color: Colors.white),
                        label: Text('SAVE', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5, color: Colors.white)),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPlanParams(),
                  const SizedBox(height: 24),
                  _buildEntryTable(),
                ],
              ),
            ),
          ),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanParams() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.fileEdit, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                'PLAN DETAILS',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PLAN NAME / REMARKS',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _isManualPlanEntry = !_isManualPlanEntry),
                icon: Icon(_isManualPlanEntry ? LucideIcons.history : LucideIcons.type, size: 12),
                label: Text(_isManualPlanEntry ? 'USE HISTORY' : 'TYPE NEW', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _isManualPlanEntry
              ? TextFormField(
                  controller: _planNameCtrl,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: _fieldDeco().copyWith(hintText: 'TYPE NEW PLAN NAME...'),
                )
              : CustomDropdownField(
                  label: '',
                  value: _savedPlanNames.contains(_planNameCtrl.text) ? _planNameCtrl.text : null,
                  items: _savedPlanNames,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _planNameCtrl.text = val);
                    }
                  },
                  hint: 'SELECT PREVIOUS PLAN...',
                ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFieldLabelled('PLAN TYPE', DropdownButtonFormField<String>(
                  value: _planType,
                  isDense: true,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),
                  decoration: _fieldDeco(),
                  items: ['Monthly', 'Yearly']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _planType = val!;
                      _planPeriod = _planType == 'Monthly'
                          ? DateFormat('yyyy-MM').format(DateTime.now())
                          : DateFormat('yyyy').format(DateTime.now());
                    });
                  },
                )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFieldLabelled('SIZE TYPE', DropdownButtonFormField<String>(
                  value: _sizeType,
                  isDense: true,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),
                  decoration: _fieldDeco(),
                  items: ['Senior', 'Junior']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) _updateSizeType(val);
                  },
                )),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFieldLabelled('FROM DATE', TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: _startDate != null ? DateFormat('dd MMM yyyy').format(_startDate!) : '',
                  ),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: _fieldDeco().copyWith(suffixIcon: const Icon(LucideIcons.calendar, size: 16)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) setState(() => _startDate = date);
                  },
                )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFieldLabelled('TO DATE', TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: _endDate != null ? DateFormat('dd MMM yyyy').format(_endDate!) : '',
                  ),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: _fieldDeco().copyWith(suffixIcon: const Icon(LucideIcons.calendar, size: 16)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) setState(() => _endDate = date);
                  },
                )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabelled(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _fieldDeco() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildEntryTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _addInitialRow,
              icon: const Icon(LucideIcons.plusCircle, size: 14),
              label: Text('ADD LINE', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 0,
                  horizontalMargin: 0,
                  headingRowHeight: 40,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 40,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                  border: const TableBorder(
                    verticalInside: BorderSide(color: Color(0xFFCBD5E1)),
                    horizontalInside: BorderSide(color: Color(0xFFCBD5E1)),
                    bottom: BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  columns: [
                    DataColumn(label: _excelHeader('ITEM NAME', 200)),
                    ..._sizes.map((s) => DataColumn(label: _excelHeader(s.toString(), 80))),
                    DataColumn(label: _excelHeader('DOZENS', 100)),
                    const DataColumn(label: SizedBox(width: 40)),
                  ],
                  rows: List.generate(_cuttingEntries.length, (index) {
                    final entry = _cuttingEntries[index];
                    return DataRow(
                      cells: [
                        DataCell(
                          Container(
                            width: 200,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: entry['itemName'].isEmpty ? null : entry['itemName'],
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.black, fontWeight: FontWeight.w600),
                              items: _itemNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                              onChanged: (v) => _onItemChanged(index, v),
                              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                            ),
                          ),
                        ),
                        ..._sizes.map((s) {
                          final sStr = s.toString();
                          return DataCell(
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: entry['sizeQuantities'][sStr] == 0 ? '' : entry['sizeQuantities'][sStr].toString(),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                                onChanged: (v) {
                                  setState(() {
                                    entry['sizeQuantities'][sStr] = int.tryParse(v) ?? 0;
                                    _calculateTotal(index);
                                  });
                                },
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: '-',
                                  hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
                                ),
                              ),
                            ),
                          );
                        }),
                        DataCell(
                          Container(
                            width: 100,
                            alignment: Alignment.center,
                            child: Text(
                              entry['totalDozens'].toString(),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              icon: const Icon(LucideIcons.trash2, color: Color(0xFFEF4444), size: 16),
                              onPressed: () => setState(() => _cuttingEntries.removeAt(index)),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _excelHeader(String label, double width) {
    return Container(
      width: width,
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w900,
          fontSize: 11,
          color: const Color(0xFF475569),
          letterSpacing: 1,
        ),
      ),
    );
  }
}
