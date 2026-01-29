import 'package:flutter/material.dart';
import '../../core/theme/color_palette.dart';
import '../../services/database_service.dart';

class InwardOutwardReportScreen extends StatefulWidget {
  const InwardOutwardReportScreen({super.key});

  @override
  State<InwardOutwardReportScreen> createState() =>
      _InwardOutwardReportScreenState();
}

class _InwardOutwardReportScreenState extends State<InwardOutwardReportScreen> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final db = await _db.database;
    final res = await db.rawQuery('''
      SELECT 
        l.lot_number,
        l.party_name,
        SUM(ir.roll) as in_rolls,
        SUM(ir.weight) as in_weight,
        (SELECT SUM(1) FROM outwards o JOIN outward_items oi ON o.id = oi.outward_id WHERE o.lot_number = l.lot_number) as out_rolls,
        (SELECT SUM(oi.weight) FROM outwards o JOIN outward_items oi ON o.id = oi.outward_id WHERE o.lot_number = l.lot_number) as out_weight
      FROM lots l
      LEFT JOIN inwards i ON l.lot_number = i.lot_number
      LEFT JOIN inward_rows ir ON i.id = ir.inward_id
      GROUP BY l.lot_number
    ''');

    setState(() {
      _data = res;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inward vs Outward')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _data.length,
              itemBuilder: (context, index) {
                final item = _data[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: ColorPalette.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['lot_number'] ?? 'N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        item['party_name'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ColorPalette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMovementBlock(
                              'INWARD',
                              item['in_rolls'] ?? 0,
                              item['in_weight'] ?? 0,
                              ColorPalette.primary,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey.shade100,
                          ),
                          Expanded(
                            child: _buildMovementBlock(
                              'OUTWARD',
                              item['out_rolls'] ?? 0,
                              item['out_weight'] ?? 0,
                              ColorPalette.error,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      _buildDifferenceRow(item),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMovementBlock(
    String label,
    dynamic rolls,
    dynamic weight,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$rolls Rolls',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          '${(weight as num).toStringAsFixed(2)} Kg',
          style: TextStyle(fontSize: 12, color: ColorPalette.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDifferenceRow(Map<String, dynamic> item) {
    final diffWeight =
        ((item['in_weight'] ?? 0) as num) - ((item['out_weight'] ?? 0) as num);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Remaining Weight',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        Text(
          '${diffWeight.toStringAsFixed(2)} Kg',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: ColorPalette.success,
          ),
        ),
      ],
    );
  }
}
