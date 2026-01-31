import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/color_palette.dart';
import '../../services/database_service.dart';

class LotOutwardScreen extends StatefulWidget {
  const LotOutwardScreen({super.key});

  @override
  State<LotOutwardScreen> createState() => _LotOutwardScreenState();
}

class _LotOutwardScreenState extends State<LotOutwardScreen> {
  final _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  // --- Header Data ---
  final DateTime _outwardDate = DateTime.now();
  late String _inTime;
  String? _outTime;
  String? _lotNumber, _setNo, _partyName;
  String _dcNumber = '';
  final _vehicleController = TextEditingController();

  List<OutwardItem> _items = [];
  List<String> _lotNumbers = [], _setNos = [], _parties = [];
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    // Auto-generate DC Number and In-Time
    _dcNumber = 'DC-${DateFormat('yyyyMMdd').format(DateTime.now())}-${DateTime.now().millisecond}';
    _inTime = DateFormat('hh:mm a').format(DateTime.now());
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> drops = await db.query('dropdowns');
    // In a real app, you would fetch these from your 'lots' or 'inward' table
    setState(() {
      _lotNumbers = drops.where((m) => m['category'] == 'Lot Number').map((m) => m['value'] as String).toList();
      _setNos = ['Set-1', 'Set-2', 'Set-3', 'Set-4', 'Set-5'];
      _parties = drops.where((m) => m['category'] == 'Party').map((m) => m['value'] as String).toList();

      // Fallbacks if DB is empty
      if (_lotNumbers.isEmpty) _lotNumbers = ['L-9901', 'L-9902'];
      if (_parties.isEmpty) _parties = ['Client Alpha', 'Client Beta'];
    });
  }

  void _onSetSelected(String? set) {
    setState(() {
      _setNo = set;
      if (set != null) {
        // Mocking available stock fetching for the selected set
        _items = [
          OutwardItem(colour: 'Red', availableWeight: 50.0, selectedWeight: 50.0),
          OutwardItem(colour: 'Blue', availableWeight: 35.5, selectedWeight: 35.5),
        ];
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _lotNumber == null || _setNo == null || _partyName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all header fields')));
      return;
    }

    // Logic: Record Out-Time on Save
    setState(() {
      _outTime = DateFormat('hh:mm a').format(DateTime.now());
      _isSaved = true;
    });

    final db = await _db.database;
    final outwardId = DateTime.now().millisecondsSinceEpoch.toString();

    await db.insert('outwards', {
      'id': outwardId,
      'lot_number': _lotNumber,
      'set_no': _setNo,
      'party_name': _partyName,
      'dc_number': _dcNumber,
      'vehicle_no': _vehicleController.text,
      'in_time': _inTime,
      'out_time': _outTime,
      'created_at': DateTime.now().toIso8601String(),
    });

    for (var item in _items) {
      await db.insert('outward_items', {
        'outward_id': outwardId,
        'colour': item.colour,
        'weight': item.selectedWeight,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Outward Registered: $_dcNumber')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Lot Outward / Dispatch', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.printer),
            onPressed: _isSaved ? () => print("Printing DC...") : null,
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 24),
              if (_items.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text('Dispatch Item Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                ..._items.asMap().entries.map((e) => _buildStockItemCard(e.value, e.key)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaved ? null : _save,
                  icon: const Icon(LucideIcons.checkCircle),
                  label: Text(_isSaved ? 'Dispatch Confirmed' : 'Confirm Outward & Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSaved ? Colors.grey : ColorPalette.success,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildReadOnlyField('DC Number', _dcNumber)),
                const SizedBox(width: 8),
                Expanded(child: _buildReadOnlyField('Outward Date', DateFormat('dd-MM-yyyy').format(_outwardDate))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildDropdown('Lot Number', _lotNumbers, (v) => setState(() => _lotNumber = v))),
                const SizedBox(width: 8),
                Expanded(child: _buildDropdown('Set No', _setNos, _onSetSelected)),
              ],
            ),
            const SizedBox(height: 16),
            _buildDropdown('Dispatch to Party', _parties, (v) => setState(() => _partyName = v)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _vehicleController,
                  decoration: const InputDecoration(labelText: 'Vehicle Number', border: OutlineInputBorder()),
                )),
                const SizedBox(width: 8),
                Expanded(child: _buildReadOnlyField('In Time', _inTime)),
              ],
            ),
            if (_outTime != null) ...[
              const SizedBox(height: 12),
              _buildReadOnlyField('Out Time (Recorded)', _outTime!),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStockItemCard(OutwardItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: ColorPalette.primary, child: Icon(LucideIcons.package, size: 18, color: Colors.white)),
        title: Text(item.colour, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Available: ${item.availableWeight} Kg'),
        trailing: SizedBox(
          width: 100,
          child: TextFormField(
            initialValue: item.selectedWeight.toString(),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(suffixText: 'Kg', isDense: true),
            onChanged: (v) => item.selectedWeight = double.tryParse(v) ?? 0,
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(10)),
      child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDropdown(String label, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
    );
  }
}

class OutwardItem {
  final String colour;
  final double availableWeight;
  double selectedWeight;
  OutwardItem({required this.colour, required this.availableWeight, required this.selectedWeight});
}