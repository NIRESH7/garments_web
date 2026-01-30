import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/color_palette.dart';
import '../../services/database_service.dart';
import 'lot_inward_allocation_screen.dart';

class LotInwardScreen extends StatefulWidget {
  const LotInwardScreen({super.key});

  @override
  State<LotInwardScreen> createState() => _LotInwardScreenState();
}

class _LotInwardScreenState extends State<LotInwardScreen> {
  final _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  // Header Fields
  final DateTime _inwardDate = DateTime.now();
  final String _inTime = DateFormat('hh:mm a').format(DateTime.now());
  String? _outTime;
  
  String? _selectedLotName;
  String? _lotNumber;
  String? _selectedParty;
  String _process = "";
  
  final _vehicleController = TextEditingController();
  final _dcController = TextEditingController();

  // Master Data
  List<Map<String, dynamic>> _lotNames = [];
  List<Map<String, dynamic>> _parties = [];
  List<String> _dias = [];
  List<String> _colours = [];

  // Grouped Entry Data
  final List<DiaGroup> _diaGroups = [DiaGroup()];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    final db = await _db.database;
    final drops = await db.query('dropdowns');
    
    setState(() {
      _lotNames = drops.where((e) => e['category'] == 'Lot Name').toList();
      _parties = []; // Will load from 'parties' table below
      _dias = drops.where((e) => e['category'] == 'Dia').map((e) => e['value'] as String).toList();
      _colours = drops.where((e) => e['category'] == 'Colour').map((e) => e['value'] as String).toList();
    });

    final partiesData = await db.query('parties');
    setState(() {
      _parties = partiesData;
    });
  }

  Future<void> _onPartyChanged(String? partyName) async {
    if (partyName == null) return;
    final db = await _db.database;
    final res = await db.query('parties', where: 'name = ?', whereArgs: [partyName]);
    setState(() {
      _selectedParty = partyName;
      if (res.isNotEmpty) {
        _process = res.first['process'] ?? "Not Set";
      }
    });
  }

  void _addDiaGroup() {
    setState(() {
      _diaGroups.add(DiaGroup());
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Auto-fill out time on save
    _outTime = DateFormat('hh:mm a').format(DateTime.now());

    final db = await _db.database;
    final inwardId = const Uuid().v4();

    // 1. Save Header
    await db.insert('inwards', {
      'id': inwardId,
      'inward_date': _inwardDate.toIso8601String(),
      'lot_name': _selectedLotName,
      'lot_number': _lotNumber,
      'party': _selectedParty,
      'process': _process,
      'vehicle_number': _vehicleController.text,
      'dc_number': _dcController.text,
      'in_time': _inTime,
      'out_time': _outTime,
    });

    // 2. Save Rows
    for (var group in _diaGroups) {
      if (group.selectedDia == null) continue;
      for (var row in group.rows) {
        if (row.colour == null || row.weight <= 0) continue;
        await db.insert('inward_rows', {
          'id': const Uuid().v4(),
          'inward_id': inwardId,
          'dia': group.selectedDia,
          'colour': row.colour,
          'roll_count': row.rollCount,
          'delivered_weight': row.deliveredWeight,
          'received_weight': row.weight,
        });
      }
    }

    // 3. Prepare for next page
    List<Map<String, dynamic>> selectedLines = [];
    for (var group in _diaGroups) {
      if (group.selectedDia == null) continue;
      for (var row in group.rows) {
        if (row.colour == null || row.weight <= 0) continue;
        selectedLines.add({
          'dia': group.selectedDia,
          'colour': row.colour,
          'roll_count': row.rollCount,
        });
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lot Inward Saved Successfully')),
    );
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LotInwardAllocationScreen(
          inwardId: inwardId,
          selectedLines: selectedLines,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Lot Inward', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save & Continue'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 28),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'DIA-wise Entry Grid',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._diaGroups.asMap().entries.map((e) => _buildDiaGroup(e.value, e.key)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _addDiaGroup,
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF4A90E2)),
                label: const Text('Add Another DIA Group', style: TextStyle(color: Color(0xFF4A90E2), fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  side: const BorderSide(color: Color(0xFF4A90E2), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inward Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildReadOnlyField('Inward Date', DateFormat('dd-MM-yyyy').format(_inwardDate), Icons.calendar_today)),
              const SizedBox(width: 16),
              Expanded(child: _buildReadOnlyField('In Time', _inTime, Icons.access_time)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  'Lot Name', 
                  _selectedLotName, 
                  _lotNames.map((e) => e['value'] as String).toList(),
                  (val) => setState(() => _selectedLotName = val),
                  Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField('Lot Number', Icons.tag, (val) => _lotNumber = val),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            'From Party', 
            _selectedParty, 
            _parties.map((e) => e['name'] as String).toList(),
            _onPartyChanged,
            Icons.business,
          ),
          const SizedBox(height: 16),
          _buildReadOnlyField('Process (Auto-fetched)', _process, Icons.settings_suggest),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField('Vehicle Number', Icons.local_shipping_outlined, (val) => _vehicleController.text = val),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField('Party DC Number', Icons.receipt_long, (val) => _dcController.text = val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiaGroup(DiaGroup group, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF4A90E2).withOpacity(0.1), const Color(0xFF4A90E2).withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.circle_outlined, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text('DIA Selection:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF1A1A2E))),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8ECF0)),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: group.selectedDia,
                      hint: const Text('Select DIA', style: TextStyle(color: Colors.grey)),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A90E2)),
                      items: _dias.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontWeight: FontWeight.w500)))).toList(),
                      onChanged: (v) => setState(() => group.selectedDia = v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFE74C3C)),
                  onPressed: () => setState(() => _diaGroups.removeAt(index)),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE74C3C).withOpacity(0.1),
                  ),
                )
              ],
            ),
          ),
          _buildDiaSummary(group),
          const Divider(height: 1, color: Color(0xFFE8ECF0)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: const [
                    Expanded(flex: 2, child: Text('Colour', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                    SizedBox(width: 8),
                    Expanded(child: Text('Rolls', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey), textAlign: TextAlign.center)),
                    SizedBox(width: 8),
                    Expanded(child: Text('Deliv.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey), textAlign: TextAlign.center)),
                    SizedBox(width: 8),
                    Expanded(child: Text('Recv.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey), textAlign: TextAlign.center)),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: group.rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _buildGridRow(group, i),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: TextButton.icon(
              onPressed: () => setState(() => group.addRow()),
              icon: const Icon(Icons.add, size: 18, color: Color(0xFF4A90E2)),
              label: const Text('Add Row (Max 11)', style: TextStyle(color: Color(0xFF4A90E2), fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaSummary(DiaGroup group) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryText('Total Rolls', '${group.totalRolls}', const Color(0xFF4A90E2)),
          _summaryText('Sets', '${group.noOfSets}', const Color(0xFF27AE60)),
          _summaryText('Weight Diff', '${group.weightDiff.toStringAsFixed(2)} Kg', const Color(0xFFE67E22)),
          _summaryText('Loss %', '${group.lossPercent.toStringAsFixed(1)}%', const Color(0xFFE74C3C)),
        ],
      ),
    );
  }

  Widget _summaryText(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }

  Widget _buildGridRow(DiaGroup group, int i) {
    final row = group.rows[i];
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE8ECF0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isDense: true,
                value: row.colour,
                hint: const Text('Select', style: TextStyle(fontSize: 12, color: Colors.grey)),
                icon: const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF4A90E2)),
                items: _colours.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => row.colour = v),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildCompactField('0', (v) => setState(() => row.rollCount = int.tryParse(v) ?? 0)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildCompactField('0.0', (v) => setState(() => row.deliveredWeight = double.tryParse(v) ?? 0)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildCompactField('0.0', (v) => setState(() => row.weight = double.tryParse(v) ?? 0), highlight: true),
        ),
      ],
    );
  }

  Widget _buildCompactField(String hint, Function(String) onChanged, {bool highlight = false}) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF4A90E2).withOpacity(0.08) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: highlight ? const Color(0xFF4A90E2).withOpacity(0.3) : const Color(0xFFE8ECF0)),
      ),
      child: TextFormField(
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: highlight ? const Color(0xFF4A90E2) : const Color(0xFF1A1A2E)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF4A90E2)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, Function(String) onChanged) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF4A90E2)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDropdown(String label, String? current, List<String> items, Function(String?) onChanged, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: DropdownButtonFormField<String>(
        value: items.contains(current) ? current : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF4A90E2)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A90E2)),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 14)))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class DiaGroup {
  String? selectedDia;
  List<InwardRowData> rows = [InwardRowData()];

  void addRow() {
    if (rows.length < 11) {
      rows.add(InwardRowData());
    }
  }

  int get totalRolls => rows.fold(0, (sum, r) => sum + r.rollCount);
  int get noOfSets {
    double sets = totalRolls / 11;
    if (sets - sets.floor() > 0.5) return sets.ceil();
    return sets.floor();
  }
  double get totalDelivered => rows.fold(0, (sum, r) => sum + r.deliveredWeight);
  double get totalReceived => rows.fold(0, (sum, r) => sum + r.weight);
  double get weightDiff => totalReceived - totalDelivered;
  double get lossPercent => totalDelivered == 0 ? 0 : (weightDiff / totalDelivered) * 100;
}

class InwardRowData {
  String? colour;
  int rollCount = 0;
  double deliveredWeight = 0;
  double weight = 0;
}
