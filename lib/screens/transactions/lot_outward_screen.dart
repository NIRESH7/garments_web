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

  String? _lotNumber, _setNo, _partyName;
  String _dcNumber = '';
  List<OutwardItem> _items = [];

  List<String> _lotNumbers = [], _setNos = [], _parties = [];

  @override
  void initState() {
    super.initState();
    _dcNumber = 'DC-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}';
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> drops = await db.query('dropdowns');
    final List<Map<String, dynamic>> lots = await db.query('lots');

    setState(() {
      _lotNumbers = lots.map((m) => m['lot_number'] as String).toList();
      _setNos = drops
          .where((m) => m['category'] == 'set')
          .map((m) => m['value'] as String)
          .toList();
      _parties = drops
          .where((m) => m['category'] == 'party_name')
          .map((m) => m['value'] as String)
          .toList();
    });
  }

  void _onSetSelected(String? set) {
    setState(() {
      _setNo = set;
      if (set != null) {
        // Mock fetching available weight from inward stock
        _items = [
          OutwardItem(
            colour: 'Red',
            availableWeight: 50.0,
            selectedWeight: 50.0,
          ),
          OutwardItem(
            colour: 'Blue',
            availableWeight: 35.5,
            selectedWeight: 35.5,
          ),
          OutwardItem(
            colour: 'Green',
            availableWeight: 22.1,
            selectedWeight: 22.1,
          ),
        ];
      }
    });
  }

  Future<void> _save() async {
    if (_lotNumber == null || _setNo == null || _partyName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all header fields')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stock items to dispatch')),
      );
      return;
    }

    final db = await _db.database;
    final outwardId = DateTime.now().millisecondsSinceEpoch.toString();

    await db.insert('outwards', {
      'id': outwardId,
      'lot_number': _lotNumber,
      'set_no': _setNo,
      'party_name': _partyName,
      'dc_number': _dcNumber,
      'created_at': DateTime.now().toIso8601String(),
    });

    for (var item in _items) {
      await db.insert('outward_items', {
        'outward_id': outwardId,
        'colour': item.colour,
        'weight': item.selectedWeight,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Outward saved successfully. DC: $_dcNumber')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lot Outward')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            if (_items.isNotEmpty) ...[
              Text(
                'Available Stock (Colour-wise)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildStockList(),
            ],
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Confirm Outward & Generate DC'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ColorPalette.softShadow,
      ),
      child: Column(
        children: [
          TextFormField(
            initialValue: _dcNumber,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'DC Number (Auto)'),
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            'Select Lot Number',
            _lotNumbers,
            (v) => setState(() => _lotNumber = v),
          ),
          const SizedBox(height: 16),
          _buildDropdown('Select Set No', _setNos, _onSetSelected),
          const SizedBox(height: 16),
          _buildDropdown(
            'Dispatch to Party',
            _parties,
            (v) => setState(() => _partyName = v),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildStockList() {
    return Column(
      children: _items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: ColorPalette.softShadow,
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ColorPalette.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.package,
                  color: ColorPalette.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.colour,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Avail: ${item.availableWeight} Kg',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ColorPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: item.selectedWeight.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  onChanged: (v) =>
                      item.selectedWeight = double.tryParse(v) ?? 0,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    filled: false,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  LucideIcons.x,
                  color: ColorPalette.error,
                  size: 18,
                ),
                onPressed: () => setState(() => _items.removeAt(index)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class OutwardItem {
  final String colour;
  final double availableWeight;
  double selectedWeight;

  OutwardItem({
    required this.colour,
    required this.availableWeight,
    required this.selectedWeight,
  });
}
