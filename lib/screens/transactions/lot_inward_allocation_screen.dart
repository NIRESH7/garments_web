import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import '../../services/database_service.dart';

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
  final List<Map<String, dynamic>> _allocationData = [];

  @override
  void initState() {
    super.initState();
    _prepareData();
  }

  void _prepareData() {
    for (var line in widget.selectedLines) {
      int rolls = line['roll_count'] ?? 0;
      int sets = _calculateSets(rolls);
      
      _allocationData.add({
        'dia': line['dia'],
        'colour': line['colour'],
        'sets': sets,
        'pallet': TextEditingController(),
        'rack': TextEditingController(),
        'set_weights': List.generate(sets, (_) => TextEditingController()),
      });
    }
  }

  int _calculateSets(int rolls) {
    double s = rolls / 11;
    return (s - s.floor() > 0.5) ? s.ceil() : s.floor();
  }

  Future<void> _saveAllocation() async {
    final db = await _db.database;
    
    for (var alloc in _allocationData) {
      for (int i = 0; i < alloc['sets']; i++) {
        await db.insert('inward_sets_allocation', {
          'inward_id': widget.inwardId,
          'dia': alloc['dia'],
          'colour': alloc['colour'],
          'set_number': 'Set-${i + 1}',
          'weight': double.tryParse((alloc['set_weights'] as List)[i].text) ?? 0,
          'pallet_number': (alloc['pallet'] as TextEditingController).text,
          'rack_name': (alloc['rack'] as TextEditingController).text,
        });
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Allocation & Stickers Saved!')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Allocation & Stickers')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ..._allocationData.map(_buildAllocationCard),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveAllocation,
                style: ElevatedButton.styleFrom(backgroundColor: ColorPalette.success),
                child: const Text('Complete Inward & Print Stickers', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationCard(Map<String, dynamic> alloc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DIA: ${alloc['dia']} | Colour: ${alloc['colour']}', 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            const Divider(),
            Row(
              children: [
                Expanded(child: TextFormField(controller: alloc['pallet'], decoration: const InputDecoration(labelText: 'Pallet No'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: alloc['rack'], decoration: const InputDecoration(labelText: 'Rack Name'))),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Set Weights (Kg)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(alloc['sets'], (i) {
                return Column(
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: (alloc['set_weights'] as List)[i],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Set ${i + 1}',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Label ${i+1}', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                  ],
                );
              }),
            ),
            const SizedBox(height: 16),
            _buildStickerDocsPreview(alloc),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerDocsPreview(Map<String, dynamic> alloc) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sticker Data (Preview):', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('DIA: ${alloc['dia']} | COL: ${alloc['colour']} | PALLET: ${alloc['pallet'].text}', style: const TextStyle(fontSize: 9)),
        ],
      ),
    );
  }
}
