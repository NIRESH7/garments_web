import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/mobile_api_service.dart';
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
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSaving = false;

  // Selection Data
  List<String> _groupList = [];
  List<String> _accessoryList = [];
  List<String> _itemList = [];
  List<String> _sizeList = [];
  List<String> _colorList = [];

  // Section 1: Accessories Group Setup
  List<GroupSetupRow> _groupRows = [];

  // Section 2: Accessories Assign for Item
  List<AssignmentRow> _assignRows = [];
  String? _selectedItemName;
  DateTime _assignmentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (widget.editEntry != null) {
      _populateData();
    } else {
      _addGroupRow();
      _addAssignRow();
    }
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

  Future<void> _loadDropdowns() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _api.getCategories();
      setState(() {
        _groupList = _getValues(categories, ['Accessories Group', 'Accessory Group']);
        _accessoryList = _getValues(categories, ['Accessories', 'Accessory']);
        _itemList = _getValues(categories, ['Item Name', 'Item']);
        _sizeList = _getValues(categories, ['Size', 'Sizes']);
        _colorList = _getValues(categories, ['Colours', 'Colour']);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _getValues(List<dynamic> categories, List<String> names) {
    final lowerNames = names.map((n) => n.toLowerCase().trim()).toList();
    for (var cat in categories) {
      final serverName = (cat['name'] as String? ?? '').toLowerCase().trim();
      if (lowerNames.contains(serverName)) {
        return (cat['values'] as List).map((v) => v is Map ? v['name'].toString() : v.toString()).toList();
      }
    }
    return [];
  }

  void _addGroupRow() => setState(() => _groupRows.add(GroupSetupRow(date: DateTime.now())));
  void _addAssignRow() => setState(() => _assignRows.add(AssignmentRow()));

  Future<void> _save(int tabIndex) async {
    if (tabIndex == 0 && _groupRows.isEmpty) return;
    if (tabIndex == 1 && (_assignRows.isEmpty || _selectedItemName == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Item and add at least one row')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> data = {
        'date': (tabIndex == 0 ? DateTime.now() : _assignmentDate).toIso8601String(),
        'groupSetup': tabIndex == 0 ? _groupRows.map((e) => e.toMap()).toList() : [],
        'itemAssignment': tabIndex == 1 ? _assignRows.map((e) {
          final m = e.toMap();
          m['itemName'] = _selectedItemName;
          return m;
        }).toList() : [],
      };

      final success = widget.editEntry != null 
        ? await _api.updateAccessoriesMaster(widget.editEntry!['_id'], data)
        : await _api.createAccessoriesMaster(data);

      if (success && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accessories Synchronized'), backgroundColor: ColorPalette.success));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF0F172A), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: null,
          centerTitle: false,
          actions: [
            Builder(
              builder: (context) => Container(
                margin: const EdgeInsets.only(right: 16),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _isSaving ? null : () => _save(DefaultTabController.of(context).index),
                    icon: _isSaving 
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: ColorPalette.primary))
                        : const Icon(LucideIcons.check, size: 14, color: Colors.white),
                    label: Text('SAVE', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5, color: Colors.white)),
                    style: TextButton.styleFrom(
                      backgroundColor: ColorPalette.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            labelColor: ColorPalette.primary,
            unselectedLabelColor: ColorPalette.textMuted,
            indicatorColor: ColorPalette.primary,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 2,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
            tabs: const [
              Tab(text: 'GROUP CONFIGURATION'),
              Tab(text: 'ITEM ASSIGNMENT'),
            ],
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : TabBarView(
              children: [
                _buildTabContent(_buildGroupSetupTab()),
                _buildTabContent(_buildItemAssignmentTab()),
              ],
            ),
      ),
    );
  }

  Widget _buildTabContent(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGroupSetupTab() {
    return Column(
      children: [
        ..._groupRows.asMap().entries.map((entry) => _buildGroupRow(entry.key, entry.value)),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: _addGroupRow,
          icon: const Icon(LucideIcons.plusCircle, size: 14),
          label: Text('APPEND CONFIGURATION ROW', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            side: const BorderSide(color: ColorPalette.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupRow(int index, GroupSetupRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(4), 
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 3, height: 12, color: ColorPalette.primary),
              const SizedBox(width: 8),
              Text(
                'GROUP CONFIGURATION #${index + 1}', 
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: ColorPalette.textPrimary, letterSpacing: 1.2),
              ),
              const Spacer(),
              IconButton(onPressed: () => setState(() => _groupRows.removeAt(index)), icon: const Icon(LucideIcons.minusCircle, color: ColorPalette.error, size: 18)),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: CustomDropdownField(label: 'ACCESSORY GROUP', items: _groupList, value: row.group, onChanged: (v) => setState(() => row.group = v))),
              const SizedBox(width: 24),
              Expanded(child: CustomDropdownField(label: 'SPECIFIC COMPONENT', items: _accessoryList, value: row.accessory, onChanged: (v) => setState(() => row.accessory = v))),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _miniTextField('HSN IDENTIFIER', row.hsnController)),
              const SizedBox(width: 16),
              Expanded(child: _miniTextField('UNIT TYPE', row.unitController)),
              const SizedBox(width: 16),
              Expanded(child: _miniTextField('STANDARD RATE', row.rateController)),
            ],
          ),
          const SizedBox(height: 24),
          _miniTextField('TECHNICAL SPECIFICATIONS', row.specController),
        ],
      ),
    );
  }

  Widget _buildItemAssignmentTab() {
    return Column(
      children: [
        _formCard(
          title: 'ASSIGNMENT CONTEXT',
          children: [
            Row(
              children: [
                Expanded(flex: 2, child: CustomDropdownField(label: 'TARGET PRODUCTION ITEM', items: _itemList, value: _selectedItemName, onChanged: (v) => setState(() => _selectedItemName = v))),
                const SizedBox(width: 24),
                Expanded(child: _datePickerField()),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        _formCard(
          title: 'ACCESSORY MATRIX REGISTRY',
          children: [
            _buildAssignmentTable(),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _addAssignRow,
              icon: const Icon(LucideIcons.plusCircle, size: 14),
              label: Text('APPEND ASSIGNMENT ROW', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                side: const BorderSide(color: ColorPalette.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssignmentTable() {
    const double colW = 160.0;
    const double szW = 75.0;
    final sizes = ['75', '80', '85', '90', '95', '100', '105', '110'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), 
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: ColorPalette.border),
            ),
            child: Row(
              children: [
                _tableHCell('GROUP', colW),
                _tableHCell('NAME', colW),
                _tableHCell('SIZE', szW),
                _tableHCell('RATE', szW),
                ...sizes.map((s) => _tableHCell(s, szW)),
                const SizedBox(width: 60),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Table Body
          ..._assignRows.asMap().entries.map((ent) {
            final idx = ent.key;
            final row = ent.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.white, 
                border: Border.all(color: ColorPalette.border.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  _tableBCell(CustomDropdownField(label: '', items: _groupList, value: row.group, onChanged: (v) => setState(() => row.group = v), isDense: true), colW),
                  _tableBCell(CustomDropdownField(label: '', items: _accessoryList, value: row.accessoryName, onChanged: (v) => setState(() => row.accessoryName = v), isDense: true), colW),
                  _tableBCell(CustomDropdownField(label: '', items: _sizeList, value: row.size, onChanged: (v) => setState(() => row.size = v), isDense: true), szW),
                  _tableBCell(_tableInputField(row.qtyPerPieceController), szW),
                  ...sizes.map((s) => _tableBCell(_tableInputField(row.sizeControllers[s]!), szW)),
                  SizedBox(width: 60, child: IconButton(onPressed: () => setState(() => _assignRows.removeAt(idx)), icon: const Icon(LucideIcons.minusCircle, size: 16, color: ColorPalette.error))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _tableHCell(String text, double width) {
    return Container(
      width: width, 
      padding: const EdgeInsets.all(12), 
      child: Text(
        text, 
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: ColorPalette.textPrimary, letterSpacing: 1),
      ),
    );
  }

  Widget _tableBCell(Widget child, double width) {
    return Container(width: width, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), child: child);
  }

  Widget _tableInputField(TextEditingController ctrl) {
    return TextFormField(
      controller: ctrl, 
      textAlign: TextAlign.center, 
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold), 
      decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '0'),
    );
  }

  Widget _formCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(4), 
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Row(
            children: [
              Container(width: 3, height: 12, color: ColorPalette.primary),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(), 
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: ColorPalette.textPrimary, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ...children,
        ],
      ),
    );
  }

  Widget _miniTextField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true, 
            fillColor: const Color(0xFFF9FAFB), 
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
          ),
        ),
      ],
    );
  }

  Widget _datePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROTOCOL DATE',
          style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(context: context, initialDate: _assignmentDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (date != null) setState(() => _assignmentDate = date);
          },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB), 
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: ColorPalette.border),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.calendar, size: 14, color: ColorPalette.primary), 
                const SizedBox(width: 12), 
                Text(
                  DateFormat('dd-MM-yyyy').format(_assignmentDate).toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: ColorPalette.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class GroupSetupRow {
  DateTime date;
  String? group;
  String? accessory;
  String? usedIn;
  final TextEditingController hsnController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController taxController = TextEditingController();
  final TextEditingController rateController = TextEditingController();
  final TextEditingController maxStockController = TextEditingController();
  final TextEditingController minStockController = TextEditingController();
  final TextEditingController supplierController = TextEditingController();
  final TextEditingController specController = TextEditingController();

  GroupSetupRow({required this.date});

  static GroupSetupRow fromMap(Map<String, dynamic> map) {
    final row = GroupSetupRow(date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()));
    row.group = map['group'];
    row.accessory = map['accessory'];
    row.usedIn = map['usedIn'];
    row.hsnController.text = (map['hsnCode'] ?? '').toString();
    row.unitController.text = (map['unit'] ?? '').toString();
    row.taxController.text = (map['tax'] ?? '').toString();
    row.rateController.text = (map['rate'] ?? '').toString();
    row.maxStockController.text = (map['maxStock'] ?? '').toString();
    row.minStockController.text = (map['minStock'] ?? '').toString();
    row.supplierController.text = (map['supplier'] ?? '').toString();
    row.specController.text = (map['specification'] ?? '').toString();
    return row;
  }

  Map<String, dynamic> toMap() => {
    'group': group,
    'accessory': accessory,
    'usedIn': usedIn,
    'hsnCode': hsnController.text,
    'unit': unitController.text,
    'tax': taxController.text,
    'rate': rateController.text,
    'maxStock': maxStockController.text,
    'minStock': minStockController.text,
    'supplier': supplierController.text,
    'specification': specController.text,
  };
}

class AssignmentRow {
  String? group;
  String? accessoryName;
  String? size;
  final TextEditingController qtyPerPieceController = TextEditingController();
  final Map<String, TextEditingController> sizeControllers = {
    for (var s in ['75', '80', '85', '90', '95', '100', '105', '110']) s: TextEditingController()
  };

  static AssignmentRow fromMap(Map<String, dynamic> map) {
    final row = AssignmentRow();
    row.group = map['group'];
    row.accessoryName = map['accessoryName'];
    row.size = map['size'];
    row.qtyPerPieceController.text = (map['qtyPerPiece'] ?? '').toString();
    final szMap = map['sizeWiseQty'] as Map? ?? {};
    szMap.forEach((k, v) {
      if (row.sizeControllers.containsKey(k)) row.sizeControllers[k]!.text = v.toString();
    });
    return row;
  }

  Map<String, dynamic> toMap() => {
    'group': group,
    'accessoryName': accessoryName,
    'size': size,
    'qtyPerPiece': qtyPerPieceController.text,
    'sizeWiseQty': sizeControllers.map((k, v) => MapEntry(k, v.text)),
  };
}
