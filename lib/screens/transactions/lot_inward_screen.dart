import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import '../../services/database_service.dart';
import '../../services/scale_service.dart';

class LotInwardScreen extends StatefulWidget {
  const LotInwardScreen({super.key});

  @override
  State<LotInwardScreen> createState() => _LotInwardScreenState();
}

class _LotInwardScreenState extends State<LotInwardScreen> {
  final _db = DatabaseService();

  String? _lotNumber, _fromParty;
  final String _process = 'Auto Process';

  final List<InwardGridRow> _rows = List.generate(
    11,
    (index) => InwardGridRow(),
  );

  List<String> _lotNumbers = [], _parties = [], _dias = [], _colours = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> drops = await db.query('dropdowns');
    final List<Map<String, dynamic>> lots = await db.query('lots');

    setState(() {
      _lotNumbers = lots.map((m) => m['lot_number'] as String).toList();
      _parties = drops
          .where((m) => m['category'] == 'party_name')
          .map((m) => m['value'] as String)
          .toList();
      _dias = drops
          .where((m) => m['category'] == 'dia')
          .map((m) => m['value'] as String)
          .toList();
      _colours = drops
          .where((m) => m['category'] == 'colour')
          .map((m) => m['value'] as String)
          .toList();
    });
  }

  double get _totalWeight => _rows.fold(0, (sum, item) => sum + item.weight);
  int get _totalRolls => _rows.fold(0, (sum, item) => sum + item.roll);

  Future<void> _captureWeight(int index) async {
    final weight = await ScaleService.captureWeight();
    setState(() {
      _rows[index].weight = weight;
    });
  }

  Future<void> _save() async {
    if (_lotNumber == null || _fromParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Lot and Party')),
      );
      return;
    }

    final validRows = _rows
        .where((r) => r.weight > 0 && r.dia != null && r.colour != null)
        .toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one valid row')),
      );
      return;
    }

    final db = await _db.database;
    final inwardId = DateTime.now().millisecondsSinceEpoch.toString();

    await db.insert('inwards', {
      'id': inwardId,
      'lot_number': _lotNumber,
      'from_party': _fromParty,
      'process': _process,
      'created_at': DateTime.now().toIso8601String(),
    });

    for (var row in validRows) {
      await db.insert('inward_rows', {
        'inward_id': inwardId,
        'dia': row.dia,
        'colour': row.colour,
        'roll': row.roll,
        'weight': row.weight,
      });
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Inward saved successfully')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPalette.background,
      appBar: AppBar(
        title: const Text(
          'Lot Inward',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: ColorPalette.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Entry Grid',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ColorPalette.textPrimary,
                  ),
                ),
                Text(
                  'MAX 11 ROWS',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGrid(),
            const SizedBox(height: 32),
            _buildConclusion(),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorPalette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Confirm Inward & Print Labels',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 50),
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
          _buildHeaderDropdown(
            'Lot Number',
            _lotNumbers,
            (v) => setState(() => _lotNumber = v),
          ),
          const SizedBox(height: 16),
          _buildHeaderDropdown(
            'From Party',
            _parties,
            (v) => setState(() => _fromParty = v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _process,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Process (Auto-populated)',
              labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderDropdown(
    String label,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildGrid() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: const [
              Expanded(
                flex: 3,
                child: Text(
                  'Dia / Colour',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Roll',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Weight (Kg)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(width: 40),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _rows.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, color: Colors.grey.shade100),
          itemBuilder: (context, index) {
            final row = _rows[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildGridDropdown(
                          row.dia,
                          (v) => setState(() => row.dia = v),
                          _dias,
                          'Select Dia',
                        ),
                        const SizedBox(height: 4),
                        _buildGridDropdown(
                          row.colour,
                          (v) => setState(() => row.colour = v),
                          _colours,
                          'Select Colour',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        onChanged: (v) =>
                            setState(() => row.roll = int.tryParse(v) ?? 0),
                        decoration: const InputDecoration(
                          hintText: '0',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: ColorPalette.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: ColorPalette.primary.withOpacity(0.2),
                              ),
                            ),
                            child: TextField(
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: ColorPalette.primary,
                              ),
                              controller: TextEditingController.fromValue(
                                TextEditingValue(
                                  text: row.weight > 0
                                      ? row.weight.toString()
                                      : '',
                                  selection: TextSelection.collapsed(
                                    offset:
                                        (row.weight > 0
                                                ? row.weight.toString()
                                                : '')
                                            .length,
                                  ),
                                ),
                              ),
                              onChanged: (v) =>
                                  row.weight = double.tryParse(v) ?? 0,
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _captureWeight(index),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ColorPalette.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              LucideIcons.scale,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      icon: const Icon(
                        LucideIcons.trash2,
                        size: 18,
                        color: ColorPalette.error,
                      ),
                      onPressed: () =>
                          setState(() => _rows[index] = InwardGridRow()),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Container(
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
        ),
      ],
    );
  }

  Widget _buildGridDropdown(
    String? current,
    Function(String?) onChanged,
    List<String> items,
    String hint,
  ) {
    return DropdownButtonHideUnderline(
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: DropdownButton<String>(
          value: items.contains(current) ? current : null,
          hint: Text(hint, style: const TextStyle(fontSize: 10)),
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, size: 14),
          items: items
              .map(
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(i, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildConclusion() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ColorPalette.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ColorPalette.primary.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ConclusionItem(
            label: 'TOTAL ROLLS',
            value: '$_totalRolls',
            color: ColorPalette.textPrimary,
          ),
          _ConclusionItem(
            label: 'TOTAL WEIGHT',
            value: '${_totalWeight.toStringAsFixed(2)} Kg',
            color: ColorPalette.success,
          ),
        ],
      ),
    );
  }
}

class _ConclusionItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ConclusionItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: ColorPalette.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class InwardGridRow {
  String? dia, colour;
  int roll = 0;
  double weight = 0.0;
}
