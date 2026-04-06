import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../services/mobile_api_service.dart';
import '../../services/scale_service.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/custom_dropdown_field.dart';

class AccessoriesMasterFormScreen extends StatefulWidget {
  final Map<String, dynamic>? editEntry;
  const AccessoriesMasterFormScreen({super.key, this.editEntry});

  @override
  State<AccessoriesMasterFormScreen> createState() => _AccessoriesMasterFormScreenState();
}

class _AccessoriesMasterFormScreenState extends State<AccessoriesMasterFormScreen> {
  final _api = MobileApiService();
  final _scaleService = ScaleService.instance;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isListening = false;
  bool _voiceMode = false;
  bool _scaleMode = false;

  // Master lists for dropdowns
  List<String> _groupList = [];
  List<String> _accessoryList = [];
  List<String> _itemList = [];
  List<String> _sizeList = [];
  List<String> _supplierList = [];
  List<String> _colorList = [];

  // Section 1: Accessories Group Setup Rows
  List<GroupSetupRow> _groupRows = [];

  // Section 2: Accessories Assign for Item Rows
  List<AssignmentRow> _assignRows = [];
  String? _selectedItemName;
  DateTime _assignmentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadDropdowns();
    if (widget.editEntry != null) {
      _populateData();
    } else {
      _addGroupRow();
      _addAssignRow();
    }
  }

  Future<void> _initSpeech() async {
    await _speech.initialize();
  }

  Future<void> _loadDropdowns() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _api.getCategories();
      setState(() {
        _groupList = _getValues(categories, ['Accessories Group', 'Accessory Group']);
        _accessoryList = _getValues(categories, ['Accessories', 'Accessory']);
        _itemList = _getValues(categories, ['Item Name', 'Item']);
        _sizeList = _getValues(categories, ['Size', 'Sizes']);
        _colorList = _getValues(categories, ['Colours', 'Colour', 'colour', 'color']);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<String> _getValues(List<dynamic> categories, List<String> names) {
    final lowerNames = names.map((n) => n.toLowerCase().trim()).toList();
    final cat = categories.firstWhere(
      (c) {
        final serverName = (c['name'] as String? ?? '').toLowerCase().trim();
        return lowerNames.contains(serverName);
      },
      orElse: () => null,
    );
    if (cat == null) return [];
    return (cat['values'] as List).map((v) {
      if (v is Map) return v['name'].toString();
      return v.toString();
    }).toList();
  }

  void _populateData() {
    final data = widget.editEntry!;
    if (data['groupSetup'] != null) {
      _groupRows = (data['groupSetup'] as List).map((e) => GroupSetupRow.fromMap(e)).toList();
    }
    if (data['itemAssignment'] != null) {
      _assignRows = (data['itemAssignment'] as List).map((e) => AssignmentRow.fromMap(e)).toList();
    }
  }

  void _addGroupRow() {
    setState(() {
      _groupRows.add(GroupSetupRow(date: DateTime.now()));
    });
  }

  void _addAssignRow() {
    setState(() {
      _assignRows.add(AssignmentRow());
    });
  }

  Future<void> _saveGroupSetup() async {
    if (_groupRows.isEmpty) return;
    setState(() => _isSaving = true);
    final data = {
      'date': DateTime.now().toIso8601String(),
      'groupSetup': _groupRows.map((e) => e.toMap()).toList(),
      'itemAssignment': [],
    };
    await _performSave(data);
  }

  Future<void> _saveItemAssignment() async {
    if (_assignRows.isEmpty || _selectedItemName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select Item and add at least one row')));
      return;
    }
    setState(() => _isSaving = true);
    
    // Assign the selected item name to all rows before saving
    final formattedRows = _assignRows.map((e) {
      final map = e.toMap();
      map['itemName'] = _selectedItemName;
      return map;
    }).toList();

    final data = {
      'date': _assignmentDate.toIso8601String(),
      'groupSetup': [],
      'itemAssignment': formattedRows,
    };
    await _performSave(data);
  }

  Future<void> _performSave(Map<String, dynamic> data) async {
    try {
      bool success;
      if (widget.editEntry != null) {
        success = await _api.updateAccessoriesMaster(widget.editEntry!['_id'], data);
      } else {
        success = await _api.createAccessoriesMaster(data);
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully')));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.editEntry != null ? 'Edit Accessories Master' : 'Accessories Master'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Group Setup'),
              Tab(text: 'Item Assignment'),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(
                _voiceMode ? Icons.mic : (_scaleMode ? Icons.scale : Icons.more_vert),
                color: _voiceMode ? Colors.orange : (_scaleMode ? Colors.blue.shade300 : null),
              ),
              onSelected: (val) {
                setState(() {
                  if (val == 'voice') {
                    _voiceMode = !_voiceMode;
                    if (_voiceMode) _scaleMode = false;
                  } else if (val == 'scale') {
                    _scaleMode = !_scaleMode;
                    if (_scaleMode) _voiceMode = false;
                  }
                });
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'voice',
                  child: Row(
                    children: [
                      Icon(Icons.mic, color: _voiceMode ? Colors.orange : Colors.grey),
                      const SizedBox(width: 8),
                      Text('Voice Mode', style: TextStyle(fontWeight: _voiceMode ? FontWeight.bold : null)),
                      const Spacer(),
                      if (_voiceMode) const Icon(Icons.check, size: 16, color: Colors.orange),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'scale',
                  child: Row(
                    children: [
                      Icon(Icons.scale, color: _scaleMode ? Colors.blue : Colors.grey),
                      const SizedBox(width: 8),
                      Text('Scale Mode', style: TextStyle(fontWeight: _scaleMode ? FontWeight.bold : null)),
                      const Spacer(),
                      if (_scaleMode) const Icon(Icons.check, size: 16, color: Colors.blue),
                    ],
                  ),
                ),
              ],
            ),
            if (_isSaving)
              const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white))
            else
              Builder(
                builder: (context) {
                  return IconButton(
                    onPressed: () {
                      final tabIndex = DefaultTabController.of(context).index;
                      if (tabIndex == 0) {
                        _saveGroupSetup();
                      } else {
                        _saveItemAssignment();
                      }
                    }, 
                    icon: const Icon(Icons.check)
                  );
                }
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: TabBarView(
                  children: [
                    // Tab 1: Accessories Group Setup
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._groupRows.asMap().entries.map((entry) => _buildGroupRow(entry.key, entry.value)),
                          Center(
                            child: TextButton.icon(
                              onPressed: _addGroupRow,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Add Group Row', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(foregroundColor: ColorPalette.primary),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveGroupSetup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorPalette.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _isSaving 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save),
                              label: const Text('Save Group Setup', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                    // Tab 2: Accessories Assign for Item - Header + Table
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAssignmentHeader(),
                          const SizedBox(height: 12),
                          _buildAssignmentTable(),
                          const SizedBox(height: 20),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveItemAssignment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorPalette.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _isSaving 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save),
                              label: const Text('Save Item Assignment', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton.icon(
                              onPressed: _addAssignRow,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Add Assign Row', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(foregroundColor: ColorPalette.primary),
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }



  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: ColorPalette.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorPalette.primary.withOpacity(0.1)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: ColorPalette.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildGroupRow(int index, GroupSetupRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Date: ${DateFormat('dd-MM-yyyy').format(row.date)}', style: TextStyle(color: Colors.grey.shade600)),
                ),
                IconButton(
                  onPressed: () => setState(() => _groupRows.removeAt(index)),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            CustomDropdownField(
              label: 'Accessories Group',
              value: row.group,
              items: _groupList,
              onChanged: (val) {
                setState(() {
                  row.group = val;
                  if (val?.toLowerCase().trim() == 'elastic') {
                    row.showColors = true;
                  } else {
                    row.showColors = false;
                  }
                });
              },
            ),
            CustomDropdownField(
              label: 'Accessories',
              value: row.accessory,
              items: _accessoryList,
              onChanged: (val) => setState(() => row.accessory = val),
            ),
            if (row.showColors) ...[
              CustomDropdownField(
                label: 'Colour',
                value: row.color,
                items: _colorList,
                onChanged: (val) => setState(() => row.color = val),
              ),
            ],
            const SizedBox(height: 8),
            _buildRowTextFields(row),
          ],
        ),
      ),
    );
  }

  Widget _buildRowTextFields(GroupSetupRow row) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _miniTextField('HSN Code', row.hsnController)),
            const SizedBox(width: 8),
            Expanded(child: _miniTextField('Unit', row.unitController)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _miniTextField('Tax', row.taxController)),
            const SizedBox(width: 8),
            Expanded(child: _miniTextField('Rate', row.rateController, keyboardType: TextInputType.number)),
          ],
        ),
        CustomDropdownField(
          label: 'Used In',
          value: row.usedIn,
          items: const ['stiching', 'cutting', 'othetrs'],
          onChanged: (val) => setState(() => row.usedIn = val),
        ),
        Row(
          children: [
            Expanded(child: _miniTextField('Max Stock', row.maxStockController, keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: _miniTextField('Min Stock', row.minStockController, keyboardType: TextInputType.number)),
          ],
        ),
        _miniTextField('Party / Supplier', row.supplierController),
        _miniTextField('Product Specification', row.specController),
      ],
    );
  }

  Widget _buildColorSelection(GroupSetupRow row) {
    final List<Color> availableColors = [Colors.black, Colors.white, Colors.red, Colors.blue, Colors.green, Colors.yellow];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Colors (for Elastic)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          children: availableColors.map((color) {
            final colorHex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
            final isSelected = row.colors.contains(colorHex);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    row.colors.remove(colorHex);
                  } else {
                    row.colors.add(colorHex);
                  }
                });
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAssignmentHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ITEM NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 4),
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _itemList.contains(_selectedItemName) ? _selectedItemName : null,
                      isExpanded: true,
                      hint: const Text('Select Item', style: TextStyle(fontSize: 13)),
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                      items: _itemList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => _selectedItemName = val),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _assignmentDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) setState(() => _assignmentDate = date);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: ColorPalette.primary),
                        const SizedBox(width: 8),
                        Text(DateFormat('dd-MM-yyyy').format(_assignmentDate), style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentTable() {
    const sizes = ['75', '80', '85', '90', '95', '100', '105', '110'];
    const double colGroup = 140.0;
    const double colName = 140.0;
    const double colSize = 80.0;
    const double colQty = 72.0;
    const double colSz = 60.0;
    const double colDel = 44.0;
    const double rowH = 48.0;
    const double headerH = 42.0;

    const totalW = colGroup + colName + colSize + colQty + colSz * 8 + colDel;

    // --- Cell builders ---
    Widget headerCell(String text, {double width = colGroup}) {
      return Container(
        width: width,
        height: headerH,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ColorPalette.primary, ColorPalette.primary.withOpacity(0.82)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border(right: BorderSide(color: Colors.white.withOpacity(0.25))),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
      );
    }

    Widget dropCell(String? value, List<String> items, void Function(String?) onChange,
        {double width = colGroup, Color rowBg = Colors.white}) {
      return Container(
        width: width,
        height: rowH,
        decoration: BoxDecoration(
          color: rowBg,
          border: Border(
            right: BorderSide(color: Colors.grey.shade200),
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(value) ? value : null,
            isExpanded: true,
            isDense: true,
            hint: Text('Select', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF1A1A2E)),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            icon: Icon(Icons.keyboard_arrow_down, size: 16, color: ColorPalette.primary.withOpacity(0.7)),
            items: items
                .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e,
                        style: const TextStyle(fontSize: 11.5),
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: onChange,
          ),
        ),
      );
    }

    Widget inputCell(TextEditingController ctrl,
        {double width = colSz, Color rowBg = Colors.white}) {
      return Container(
        width: width,
        height: rowH,
        decoration: BoxDecoration(
          color: rowBg,
          border: Border(
            right: BorderSide(color: Colors.grey.shade200),
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            hintText: '0',
            hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 11),
          ),
        ),
      );
    }

    return Card(
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table title bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF8F9FF),
            child: Row(
              children: [
                Icon(Icons.table_chart_outlined, size: 16, color: ColorPalette.primary),
                const SizedBox(width: 8),
                Text(
                  'ACC. ASSIGN FOR ITEM',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColorPalette.primary,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_assignRows.length} row${_assignRows.length != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Scrollable table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalW,
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      headerCell('Acc. Group', width: colGroup),
                      headerCell('Acc. Name', width: colName),
                      headerCell('Size', width: colSize),
                      headerCell('Qty/pcs', width: colQty),
                      ...sizes.map((s) => headerCell(s, width: colSz)),
                      Container(width: colDel, height: headerH, color: ColorPalette.primary),
                    ],
                  ),

                  // Data rows
                  if (_assignRows.isEmpty)
                    Container(
                      width: totalW,
                      height: 56,
                      color: const Color(0xFFFAFAFC),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 18, color: Colors.grey.shade400),
                          const SizedBox(width: 8),
                          Text(
                            'No rows yet. Tap "Add Assign Row" to begin.',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._assignRows.asMap().entries.map((entry) {
                      final i = entry.key;
                      final row = entry.value;
                      final isOdd = i.isOdd;
                      final rowBg = isOdd ? const Color(0xFFF5F6FF) : Colors.white;
                      return Row(
                        children: [
                          dropCell(row.group, _groupList,
                              (v) => setState(() => row.group = v),
                              width: colGroup, rowBg: rowBg),
                          dropCell(row.accessoryName, _accessoryList,
                              (v) => setState(() => row.accessoryName = v),
                              width: colName, rowBg: rowBg),
                          dropCell(row.size, _sizeList,
                              (v) => setState(() => row.size = v),
                              width: colSize, rowBg: rowBg),
                          inputCell(row.qtyPerPieceController,
                              width: colQty, rowBg: rowBg),
                          ...sizes.map((s) => inputCell(row.sizeControllers[s]!,
                              width: colSz, rowBg: rowBg)),
                          Container(
                            width: colDel,
                            height: rowH,
                            decoration: BoxDecoration(
                              color: rowBg,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.close, color: Colors.red.shade400, size: 18),
                              onPressed: () => setState(() => _assignRows.removeAt(i)),
                              tooltip: 'Remove row',
                            ),
                          ),
                        ],
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Keep old _buildAssignRow for any future reference but it's no longer used in Tab 2
  Widget _buildAssignRow(int index, AssignmentRow row) {
    return const SizedBox.shrink();
  }

  Widget _buildSizeGrid(AssignmentRow row) {
    final sizes = ['75', '80', '85', '90', '95', '100', '105', '110'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Size-wise Quantities',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: sizes.map((size) {
              return Container(
                width: 70, // Shrinked width
                margin: const EdgeInsets.only(right: 8, bottom: 8),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: ColorPalette.primary.withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: Center(
                        child: Text(
                          size,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: ColorPalette.primary, fontSize: 12),
                        ),
                      ),
                    ),
                    TextField(
                      controller: row.sizeControllers[size],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                      onTap: () {
                        if (_voiceMode) {
                          _startVoiceInputForSize(row, size);
                        } else if (_scaleMode) {
                          _captureScaleWeightForSize(row, size);
                        }
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                          borderSide: BorderSide(color: ColorPalette.primary),
                        ),
                        // REMOVED Suffix Icons inside the box as per feedback
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _miniTextField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _startVoiceInputForSize(AssignmentRow row, String size) async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }

    setState(() => _isListening = true);
    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final words = result.recognizedWords;
          final val = RegExp(r'\d+\.?\d*').firstMatch(words)?.group(0);
          if (val != null) {
            setState(() {
              row.sizeControllers[size]?.text = val;
              _isListening = false;
            });
          }
        }
      },
    );
  }

  Future<void> _captureScaleWeightForSize(AssignmentRow row, String size) async {
    try {
      final weight = await _scaleService.captureWeight();
      setState(() {
        row.sizeControllers[size]?.text = weight.toStringAsFixed(3);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scale Error: $e')));
    }
  }
}

class GroupSetupRow {
  DateTime date;
  String? group;
  String? accessory;
  String? usedIn;
  String? color;
  bool showColors = false;
  List<String> colors = [];

  final hsnController = TextEditingController();
  final unitController = TextEditingController();
  final taxController = TextEditingController();
  final rateController = TextEditingController();
  final maxStockController = TextEditingController();
  final minStockController = TextEditingController();
  final supplierController = TextEditingController();
  final specController = TextEditingController();

  GroupSetupRow({required this.date});

  static GroupSetupRow fromMap(Map<String, dynamic> map) {
    final row = GroupSetupRow(date: DateTime.parse(map['date']));
    row.group = map['group'];
    row.accessory = map['accessory'];
    row.usedIn = map['usedIn'];
    row.color = map['color']?.toString();
    row.colors = List<String>.from(map['colors'] ?? []);
    row.hsnController.text = map['hsnCode'] ?? '';
    row.unitController.text = map['unit'] ?? '';
    row.taxController.text = map['tax'] ?? '';
    row.rateController.text = (map['rate'] ?? '').toString();
    row.maxStockController.text = (map['maxStock'] ?? '').toString();
    row.minStockController.text = (map['minStock'] ?? '').toString();
    row.supplierController.text = map['supplier'] ?? '';
    row.specController.text = map['productSpec'] ?? '';
    row.showColors = row.group?.toLowerCase() == 'elastic';
    return row;
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'group': group,
      'accessory': accessory,
      'hsnCode': hsnController.text,
      'unit': unitController.text,
      'tax': taxController.text,
      'rate': double.tryParse(rateController.text) ?? 0,
      'usedIn': usedIn,
      'maxStock': double.tryParse(maxStockController.text) ?? 0,
      'minStock': double.tryParse(minStockController.text) ?? 0,
      'supplier': supplierController.text,
      'productSpec': specController.text,
      'color': color,
      'colors': colors,
    };
  }
}

class AssignmentRow {
  String? itemName;
  String? group;
  String? accessoryName;
  String? size;
  final qtyPerPieceController = TextEditingController();
  final Map<String, TextEditingController> sizeControllers = {
    '75': TextEditingController(),
    '80': TextEditingController(),
    '85': TextEditingController(),
    '90': TextEditingController(),
    '95': TextEditingController(),
    '100': TextEditingController(),
    '105': TextEditingController(),
    '110': TextEditingController(),
  };

  AssignmentRow();

  static AssignmentRow fromMap(Map<String, dynamic> map) {
    final row = AssignmentRow();
    row.itemName = map['itemName'];
    row.group = map['group'];
    row.accessoryName = map['accessoryName'];
    row.size = map['size'];
    row.qtyPerPieceController.text = (map['qtyPerPiece'] ?? '').toString();
    final sizeData = map['sizeWiseQuantities'] as Map? ?? {};
    sizeData.forEach((key, value) {
      if (row.sizeControllers.containsKey(key)) {
        row.sizeControllers[key]?.text = (value ?? '').toString();
      }
    });
    return row;
  }

  Map<String, dynamic> toMap() {
    final sizeWise = {};
    sizeControllers.forEach((key, controller) {
      sizeWise[key] = double.tryParse(controller.text) ?? 0;
    });
    return {
      'itemName': itemName,
      'group': group,
      'accessoryName': accessoryName,
      'size': size,
      'qtyPerPiece': double.tryParse(qtyPerPieceController.text) ?? 0,
      'sizeWiseQuantities': sizeWise,
    };
  }
}
