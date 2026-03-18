import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';

class CuttingDailyPlanScreen extends StatefulWidget {
  const CuttingDailyPlanScreen({super.key});
  @override
  State<CuttingDailyPlanScreen> createState() => _CuttingDailyPlanScreenState();
}

class _CuttingDailyPlanScreenState extends State<CuttingDailyPlanScreen> {
  final _api = MobileApiService();
  bool _loading = false;
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _existingPlan;
  List<Map<String, dynamic>> _planRows = [];
  bool _saving = false;

  final List<String> _statusOptions = ['Pending', 'In Progress', 'Completed'];

  @override
  void initState() {
    super.initState();
    _loadForDate();
  }

  Future<void> _loadForDate() async {
    setState(() => _loading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final plans = await _api.getCuttingDailyPlans(date: dateStr);
    setState(() {
      if (plans.isNotEmpty) {
        _existingPlan = plans.first as Map<String, dynamic>;
        _planRows = List<Map<String, dynamic>>.from(
            (_existingPlan!['planRows'] as List?)
                    ?.map((r) => Map<String, dynamic>.from(r as Map)) ??
                []);
      } else {
        _existingPlan = null;
        _planRows = [];
      }
      _loading = false;
    });
  }

  void _addRow() {
    setState(() {
      _planRows.add({
        'lotName': '',
        'lotNo': '',
        'dia': '',
        'setNo': '',
        'itemName': '',
        'size': '',
        'dozen': 0,
        'layLength': 0,
        'layPcs': 0,
        'timing': '',
        'machineNo': '',
        'approval': false,
        'actualTimeTaken': '',
        'diff': '',
        'spreadingLayStatus': 'Pending',
      });
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final data = {
      'date': _selectedDate.toIso8601String(),
      'planRows': _planRows,
    };
    bool ok;
    if (_existingPlan != null) {
      ok = await _api.updateCuttingDailyPlan(
          _existingPlan!['_id']?.toString() ?? '', data);
    } else {
      ok = await _api.createCuttingDailyPlan(data);
    }
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Plan saved!' : 'Failed to save'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) _loadForDate();
    }
  }

  Widget _field(String label, String value, Function(String) onChange,
      {bool numeric = false}) {
    return TextFormField(
      initialValue: value,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      onChanged: (v) {
        if (numeric) {
          onChange((num.tryParse(v) ?? 0).toString());
        } else {
          onChange(v);
        }
      },
    );
  }

  Widget _buildPlanRowCard(int i) {
    final row = _planRows[i];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Row ${i + 1}',
                      style: TextStyle(
                          color: Colors.indigo.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: row['spreadingLayStatus'] ?? 'Pending',
                    isDense: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    items: _statusOptions
                        .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s,
                                style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (v) => setState(
                        () => _planRows[i]['spreadingLayStatus'] = v ?? 'Pending'),
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: row['approval'] == true,
                      onChanged: (v) =>
                          setState(() => _planRows[i]['approval'] = v ?? false),
                    ),
                    const Text('Approved',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: () => setState(() => _planRows.removeAt(i)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Item Name (full width)
            _field('Item Name', row['itemName'] ?? '',
                (v) => setState(() => _planRows[i]['itemName'] = v)),
            const SizedBox(height: 8),
            // Row 1: Lot Name + Lot No
            Row(
              children: [
                Expanded(
                  child: _field('Lot Name', row['lotName'] ?? '',
                      (v) => setState(() => _planRows[i]['lotName'] = v)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _field('Lot No', row['lotNo'] ?? '',
                      (v) => setState(() => _planRows[i]['lotNo'] = v)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Dia + Set No + Size
            Row(
              children: [
                Expanded(
                  child: _field('Dia', row['dia'] ?? '',
                      (v) => setState(() => _planRows[i]['dia'] = v)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _field('Set No', row['setNo'] ?? '',
                      (v) => setState(() => _planRows[i]['setNo'] = v)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _field('Size', row['size'] ?? '',
                      (v) => setState(() => _planRows[i]['size'] = v)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 3: Dozen + Lay Length + Lay Pcs
            Row(
              children: [
                Expanded(
                  child: _field(
                      'Dozen',
                      (row['dozen'] ?? 0).toString(),
                      (v) => setState(
                          () => _planRows[i]['dozen'] = num.tryParse(v) ?? 0),
                      numeric: true),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _field(
                      'Lay Length',
                      (row['layLength'] ?? 0).toString(),
                      (v) => setState(
                          () => _planRows[i]['layLength'] = num.tryParse(v) ?? 0),
                      numeric: true),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _field(
                      'Lay Pcs',
                      (row['layPcs'] ?? 0).toString(),
                      (v) => setState(
                          () => _planRows[i]['layPcs'] = num.tryParse(v) ?? 0),
                      numeric: true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 4: Timing + Machine No + Actual Time
            Row(
              children: [
                Expanded(
                  child: _field('Timing', row['timing'] ?? '',
                      (v) => setState(() => _planRows[i]['timing'] = v)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _field('Machine No', row['machineNo'] ?? '',
                      (v) => setState(() => _planRows[i]['machineNo'] = v)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _field('Actual Time', row['actualTimeTaken'] ?? '',
                      (v) => setState(() => _planRows[i]['actualTimeTaken'] = v)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Cutting Daily Plan',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Date selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (d != null) {
                  setState(() => _selectedDate = d);
                  _loadForDate();
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.indigo.shade200),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.indigo.shade50,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('EEEE, dd MMM yyyy').format(_selectedDate),
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.indigo.shade700),
                    ),
                    Icon(Icons.edit_calendar, color: Colors.indigo.shade600),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      ..._planRows.asMap().entries
                          .map((e) => _buildPlanRowCard(e.key)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _addRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Cutting Row'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Save Plan',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
