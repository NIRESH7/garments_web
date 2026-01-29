import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import '../../services/database_service.dart';

class MonthlySummaryReportScreen extends StatefulWidget {
  const MonthlySummaryReportScreen({super.key});

  @override
  State<MonthlySummaryReportScreen> createState() =>
      _MonthlySummaryReportScreenState();
}

class _MonthlySummaryReportScreenState
    extends State<MonthlySummaryReportScreen> {
  final _db = DatabaseService();
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    final db = await _db.database;
    // Calculate total inward for the month
    final inwardRes = await db.rawQuery('''
      SELECT SUM(ir.roll) as rolls, SUM(ir.weight) as weight 
      FROM inwards i JOIN inward_rows ir ON i.id = ir.inward_id 
      WHERE i.created_at LIKE '$_selectedMonth%'
    ''');

    // Calculate total outward for the month
    final outwardRes = await db.rawQuery('''
      SELECT COUNT(*) as rolls, SUM(oi.weight) as weight 
      FROM outwards o JOIN outward_items oi ON o.id = oi.outward_id 
      WHERE o.created_at LIKE '$_selectedMonth%'
    ''');

    // For mock/simplification, opening stock as 0 or sum of previous months
    final openingRes = await db.rawQuery('''
      SELECT SUM(ir.roll) as in_rolls, SUM(ir.weight) as in_weight 
      FROM inwards i JOIN inward_rows ir ON i.id = ir.inward_id 
      WHERE i.created_at < '$_selectedMonth-01'
    ''');
    final openingOutRes = await db.rawQuery('''
      SELECT COUNT(*) as out_rolls, SUM(oi.weight) as out_weight 
      FROM outwards o JOIN outward_items oi ON o.id = oi.outward_id 
      WHERE o.created_at < '$_selectedMonth-01'
    ''');

    setState(() {
      _summary = {
        'inward': inwardRes.first,
        'outward': outwardRes.first,
        'opening_rolls':
            ((openingRes.first['in_rolls'] ?? 0) as num).toInt() -
            ((openingOutRes.first['out_rolls'] ?? 0) as num).toInt(),
        'opening_weight':
            ((openingRes.first['in_weight'] ?? 0) as num).toDouble() -
            ((openingOutRes.first['out_weight'] ?? 0) as num).toDouble(),
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Summary')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildMonthSelector(),
                  const SizedBox(height: 32),
                  _buildSummarySection(
                    'Opening Stock',
                    _summary!['opening_rolls'],
                    _summary!['opening_weight'],
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildSummarySection(
                    'Total Inward',
                    _summary!['inward']['rolls'],
                    _summary!['inward']['weight'],
                    ColorPalette.success,
                  ),
                  const SizedBox(height: 16),
                  _buildSummarySection(
                    'Total Outward',
                    _summary!['outward']['rolls'],
                    _summary!['outward']['weight'],
                    ColorPalette.error,
                  ),
                  const Divider(height: 48),
                  _buildSummarySection(
                    'Closing Stock',
                    (_summary!['opening_rolls'] +
                            (_summary!['inward']['rolls'] ?? 0)) -
                        (_summary!['outward']['rolls'] ?? 0),
                    (_summary!['opening_weight'] +
                            (_summary!['inward']['weight'] ?? 0)) -
                        (_summary!['outward']['weight'] ?? 0),
                    ColorPalette.primary,
                    isBold: true,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ColorPalette.softShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.calendar,
            size: 18,
            color: ColorPalette.primary,
          ),
          const SizedBox(width: 12),
          Text(
            _selectedMonth,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 8),
          const Icon(
            LucideIcons.chevronDown,
            size: 16,
            color: ColorPalette.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(
    String title,
    dynamic rolls,
    dynamic weight,
    Color color, {
    bool isBold = false,
  }) {
    final numRolls = (rolls ?? 0) as num;
    final numWeight = (weight ?? 0.0) as num;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isBold ? color.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ColorPalette.softShadow,
        border: isBold ? Border.all(color: color.withOpacity(0.1)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                '${numRolls.toInt()} Rolls',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            '${numWeight.toDouble().toStringAsFixed(2)} Kg',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
