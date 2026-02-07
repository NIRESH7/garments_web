import 'package:flutter/material.dart';
import '../../core/theme/color_palette.dart';
import '../../services/database_service.dart';
import '../../services/api_service.dart'; // Import ApiService

class LotInwardAllocationScreen extends StatefulWidget {
  final String inwardId;
  final List<Map<String, dynamic>> selectedLines;

  const LotInwardAllocationScreen({
    super.key,
    required this.inwardId,
    required this.selectedLines,
  });

  @override
  State<LotInwardAllocationScreen> createState() => _LotInwardAllocationScreenState();
}

class _LotInwardAllocationScreenState extends State<LotInwardAllocationScreen> {
  final _db = DatabaseService();
  final _api = ApiService(); // Init ApiService
  
  Map<String, dynamic>? _inwardHeader;
  List<String> _dias = [];
  String? _selectedDia;
  
  // Dropdown Data
  List<String> _colours = [];
  List<String> _racks = [];
  List<String> _pallets = [];

  final List<_RowData> _rows = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await _db.database;

    // Fetch Inward Header
    final inwardRes = await db.query('inward_entry', where: 'id = ?', whereArgs: [widget.inwardId]);
    if (inwardRes.isNotEmpty) {
      _inwardHeader = inwardRes.first;
    }

    // Fetch Dropdowns
    final dias = await db.query('dropdowns', where: 'category = ?', whereArgs: ['DIA'], orderBy: 'value ASC');
    final racks = await db.query('dropdowns', where: 'category = ?', whereArgs: ['Rack Name'], orderBy: 'value ASC');
    final pallets = await db.query('dropdowns', where: 'category = ?', whereArgs: ['Pallet No'], orderBy: 'value ASC');
    final colours = await db.query('dropdowns', where: 'category = ?', whereArgs: ['Colour'], orderBy: 'value ASC');

    setState(() {
      _dias = dias.map((e) => e['value'] as String).toList();
      _racks = racks.map((e) => e['value'] as String).toList();
      _pallets = pallets.map((e) => e['value'] as String).toList();
      _colours = colours.map((e) => e['value'] as String).toList();
      
      // Initialize Rows
      if (widget.selectedLines.isNotEmpty) {
        for (var line in widget.selectedLines) {
           if (_selectedDia == null && line['dia'] != null) {
             String d = line['dia'];
             if (!_dias.contains(d)) _dias.add(d);
             _selectedDia = d;
           }
           String? c = line['colour'];
           if (c != null && !_colours.contains(c)) {
             _colours.add(c);
           }
           
           _rows.add(_RowData(colour: c));
        }
      } else {
        _rows.add(_RowData());
      }
      
      _isLoading = false;
    });
  }

  void _addNewRow() {
    setState(() {
      _rows.add(_RowData());
    });
  }

  void _removeRow(int index) {
    setState(() {
      _rows.removeAt(index);
    });
  }

  Future<void> _save() async {
    // Validation
    if (_selectedDia == null) {
      _showError('Please select a DIA');
      return;
    }

    final db = await _db.database;
    final batch = db.batch();
    
    List<Map<String, dynamic>> allocationsToSave = [];

    int savedSetsCount = 0;

    for (int i = 0; i < _rows.length; i++) {
        final row = _rows[i];
        
        // Corrective Logic: If ANY data is entered in this row (Colour, Rack, Pallet, or any Set), 
        // then Colour, Rack, and Pallet become MANDATORY.
        bool hasAnySet = row.setControllers.any((c) => c.text.isNotEmpty);
        bool hasMeta = row.colour != null || row.rack != null || row.pallet != null;

        if (hasAnySet || hasMeta) {
          if (row.colour == null) {
            _showError('Row ${i + 1}: Colour is mandatory');
            return;
          }
          if (row.rack == null) {
            _showError('Row ${i + 1}: Rack Name is mandatory');
            return;
          }
          if (row.pallet == null) {
            _showError('Row ${i + 1}: Pallet No is mandatory');
            return;
          }
        } else {
          // Empty row, skip
          continue;
        }

        // Add sets
        for (int s = 0; s < row.setControllers.length; s++) {
          final val = row.setControllers[s].text;
          if (val.isNotEmpty) {
             var allocData = {
               'inward_id': widget.inwardId,
               'dia': _selectedDia,
               'colour': row.colour,
               'set_number': 'Set-${s + 1}',
               'weight': double.tryParse(val) ?? 0,
               'pallet_number': row.pallet, // Row level
               'rack_name': row.rack,       // Row level
               'created_at': DateTime.now().toIso8601String(),
             };
             
             batch.insert('inward_sets_allocation', allocData);
             allocationsToSave.add(allocData);
             savedSetsCount++;
          }
        }
    }

    if (savedSetsCount == 0) {
      _showError('No sets to save');
      return;
    }

    await batch.commit(noResult: true);
    
    // Save to Backend
    bool apiSuccess = await _api.saveAllocation(allocationsToSave);

    if (!mounted) return;
    
    String msg = 'Allocation Saved!';
    if (apiSuccess) {
      msg += ' (Synced to Backend)';
    } else {
      msg += ' (Local Only - Backend Failed)';
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    Navigator.pop(context); // Or navigate home
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lot Inward - Sticker & Storage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          )
        ],
      ),
      body: Column(
        children: [
          _buildHeaderSection(),
          const Divider(height: 1),
          // DIA Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('DIA Selection:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDia,
                    isDense: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: _dias.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => _selectedDia = val),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Main Table
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTable(),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addNewRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Row'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Save Button
           Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(backgroundColor: ColorPalette.success),
                child: const Text('Complete & Save', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    final h = _inwardHeader ?? {};
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade100,
      child: Column(
        children: [
          _buildHeaderRow('Inward Date', h['inward_date'] ?? '-', 'In Time', h['in_time'] ?? '-'),
          const SizedBox(height: 4),
          _buildHeaderRow('Lot Name', h['lot_name'] ?? '-', 'Lot No', h['lot_no'] ?? '-'),
          const SizedBox(height: 4),
          _buildHeaderRow('From Party', h['party_name'] ?? '-', 'Process', h['process'] ?? '-'),
          const SizedBox(height: 4),
          _buildHeaderRow('Vehicle No', h['vehicle_no'] ?? '-', 'Party DC', h['party_dc_no'] ?? '-'),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(String l1, String v1, String l2, String v2) {
    return Row(
      children: [
        Expanded(child: Text('$l1: $v1', style: const TextStyle(fontSize: 12))),
        Expanded(child: Text('$l2: $v2', style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  Widget _buildTable() {
    return Table(
      defaultColumnWidth: const FixedColumnWidth(100), 
      columnWidths: const {
        0: FixedColumnWidth(50),  // S.No
        1: FixedColumnWidth(140), // Colour
        2: FixedColumnWidth(120), // Rack
        3: FixedColumnWidth(120), // Pallet
        4: FixedColumnWidth(80),  // Set 1
        5: FixedColumnWidth(80),  // Set 2
        6: FixedColumnWidth(80),  // Set 3
        7: FixedColumnWidth(80),  // Set 4
      },
      border: TableBorder.all(color: Colors.grey.shade300),
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade200),
          children: [
            _buildTableHeader('S.No'),
            _buildTableHeader('Colour'),
            _buildTableHeader('Rack Name'),
            _buildTableHeader('Pallet No'),
            _buildTableHeader('Set-1\nDrop'),
            _buildTableHeader('Set-2\nDrop'),
            _buildTableHeader('Set-3\nDrop'),
            _buildTableHeader('Set-4\nDrop'),
          ],
        ),
        // Rows
        ..._rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return TableRow(
            children: [
              // S.No
              Container(
                 height: 50,
                 alignment: Alignment.center,
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Text('${index + 1}'),
                     if (_rows.length > 1) 
                       InkWell(child: const Icon(Icons.close, size: 14, color: Colors.red), onTap: () => _removeRow(index))
                   ],
                 )
              ),
              // Colour
              _buildDropdownCell(row.colour, _colours, (v) => setState(() => row.colour = v), hint: 'Colour'),
              // Rack
              _buildDropdownCell(row.rack, _racks, (v) => setState(() => row.rack = v), hint: 'Rack'),
              // Pallet
              _buildDropdownCell(row.pallet, _pallets, (v) => setState(() => row.pallet = v), hint: 'Pallet'),
              // Set 1
              _buildTextCell(row.setControllers[0]),
              // Set 2
              _buildTextCell(row.setControllers[1]),
              // Set 3
              _buildTextCell(row.setControllers[2]),
              // Set 4
              _buildTextCell(row.setControllers[3]),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildDropdownCell(String? value, List<String> items, ValueChanged<String?> onChanged, {String? hint}) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      alignment: Alignment.center,
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        hint: Text(hint ?? '', style: const TextStyle(fontSize: 10)),
        items: items.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11)))).toList(),
        onChanged: onChanged,
        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
      ),
    );
  }

  Widget _buildTextCell(TextEditingController controller) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      alignment: Alignment.center,
      child: TextFormField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 8)),
      ),
    );
  }
}

class _RowData {
  String? colour;
  String? rack;
  String? pallet;
  List<TextEditingController> setControllers;
  
  _RowData({this.colour}) : setControllers = List.generate(4, (_) => TextEditingController());
}