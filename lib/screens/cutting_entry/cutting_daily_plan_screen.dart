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

  // Column widths (pixels) — matches the reference spreadsheet proportions
  static const double _wLotName     = 90.0;
  static const double _wLotNo       = 110.0;
  static const double _wDia         = 46.0;
  static const double _wSetNo       = 56.0;
  static const double _wItemName    = 120.0;
  static const double _wSize        = 46.0;
  static const double _wDozen       = 60.0;
  static const double _wLayLength   = 72.0;
  static const double _wLayPcs      = 56.0;
  static const double _wTiming      = 80.0;
  static const double _wMachine     = 84.0;
  static const double _wApproval    = 68.0;
  static const double _wActualTime  = 96.0;
  static const double _wDiff        = 54.0;
  static const double _wStatus      = 110.0;
  static const double _wDelete      = 40.0;
  static const double _rowH         = 48.0;
  static const double _headerH      = 38.0;

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

  Future<void> _fetchFromRequirements() async {
    setState(() => _loading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final allocations = await _api.getAllAllocationsByDate(dateStr);

      if (allocations.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No lot requirements found for this date.')));
        }
        setState(() => _loading = false);
        return;
      }

      setState(() {
        for (var alloc in allocations) {
          final exists = _planRows.any((r) =>
            r['lotNo'] == alloc['lotNo'] &&
            r['setNo'] == alloc['setNo'] &&
            r['itemName'] == alloc['itemName'] &&
            r['size'] == alloc['size']);

          if (!exists) {
            _planRows.add({
              'lotName': alloc['lotName'] ?? '',
              'lotNo': alloc['lotNo'] ?? '',
              'dia': alloc['dia'] ?? '',
              'setNo': (alloc['setNo'] ?? '').toString(),
              'itemName': alloc['itemName'] ?? '',
              'size': alloc['size'] ?? '',
              'dozen': (alloc['dozen'] ?? 0).toDouble(),
              'layLength': 0,
              'layPcs': 0,
              'timing': '',
              'machineNo': '',
              'approval': false,
              'actualTimeTaken': '',
              'diff': '',
              'spreadingLayStatus': 'Pending',
            });
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching: $e'), backgroundColor: Colors.red));
      }
      setState(() => _loading = false);
    }
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

  // ── Cell helpers ──────────────────────────────────────────────

  Widget _hCell(String text, double width) {
    return Container(
      width: width,
      height: _headerH,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFD9E1F2), // light blue-grey like Excel header
        border: Border(
          right: BorderSide(color: Colors.blueGrey.shade200),
          bottom: BorderSide(color: Colors.blueGrey.shade300, width: 1.5),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F3864),
          height: 1.2,
        ),
      ),
    );
  }

  Widget _inputCell(
    double width,
    String value,
    Function(String) onChange, {
    bool numeric = false,
    Color? bg,
  }) {
    return Container(
      width: width,
      height: _rowH,
      decoration: BoxDecoration(
        color: bg ?? Colors.white,
        border: Border(
          right: BorderSide(color: Colors.blueGrey.shade100),
          bottom: BorderSide(color: Colors.blueGrey.shade100),
        ),
      ),
      child: TextFormField(
        initialValue: value,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11.5, color: Colors.black87),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        ),
        onChanged: (v) {
          if (numeric) {
            onChange((num.tryParse(v) ?? 0).toString());
          } else {
            onChange(v);
          }
        },
      ),
    );
  }

  Widget _checkCell(double width, bool value, Function(bool) onChange) {
    return Container(
      width: width,
      height: _rowH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.blueGrey.shade100),
          bottom: BorderSide(color: Colors.blueGrey.shade100),
        ),
      ),
      child: Checkbox(
        value: value,
        onChanged: (v) => onChange(v ?? false),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        activeColor: Colors.indigo,
      ),
    );
  }

  Widget _dropCell(double width, String value, Function(String?) onChange) {
    return Container(
      width: width,
      height: _rowH,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.blueGrey.shade100),
          bottom: BorderSide(color: Colors.blueGrey.shade100),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusOptions.contains(value) ? value : 'Pending',
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 14),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          style: const TextStyle(fontSize: 10.5, color: Colors.black87),
          items: _statusOptions
              .map((s) => DropdownMenuItem(
                  value: s, child: Text(s, style: const TextStyle(fontSize: 10.5))))
              .toList(),
          onChanged: onChange,
        ),
      ),
    );
  }

  Widget _delCell(int index) {
    return Container(
      width: _wDelete,
      height: _rowH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.blueGrey.shade100)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.close, color: Colors.red.shade400, size: 16),
        onPressed: () => setState(() => _planRows.removeAt(index)),
      ),
    );
  }

  // ── Table ─────────────────────────────────────────────────────

  Widget _buildTable() {
    final totalW = _wLotName + _wLotNo + _wDia + _wSetNo + _wItemName +
        _wSize + _wDozen + _wLayLength + _wLayPcs + _wTiming +
        _wMachine + _wApproval + _wActualTime + _wDiff + _wStatus + _wDelete;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: Colors.blueGrey.shade200)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalW,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row
              Row(children: [
                _hCell('Lot Name',      _wLotName),
                _hCell('Lot No',        _wLotNo),
                _hCell('Dia',           _wDia),
                _hCell('Set No',        _wSetNo),
                _hCell('Item Name',     _wItemName),
                _hCell('Size',          _wSize),
                _hCell('Dozen',         _wDozen),
                _hCell('Lay\nLength',   _wLayLength),
                _hCell('Lay\nPcs',      _wLayPcs),
                _hCell('Timing',        _wTiming),
                _hCell('Machine\nNo',   _wMachine),
                _hCell('Approval',      _wApproval),
                _hCell('Actual\nTime',  _wActualTime),
                _hCell('Diff.',         _wDiff),
                _hCell('Spreading /\nLay Status', _wStatus),
                Container(
                  width: _wDelete, height: _headerH,
                  color: const Color(0xFFD9E1F2),
                ),
              ]),

              // ── Data rows
              if (_planRows.isEmpty)
                Container(
                  width: totalW,
                  height: 52,
                  color: const Color(0xFFFAFAFC),
                  alignment: Alignment.center,
                  child: Text(
                    'No rows. Tap "Add Cutting Row" to begin.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                )
              else
                ..._planRows.asMap().entries.map((e) {
                  final i = e.key;
                  final row = e.value;
                  final bg = i.isOdd ? const Color(0xFFF5F7FF) : Colors.white;
                  return Row(children: [
                    _inputCell(_wLotName,  row['lotName']  ?? '', (v) => setState(() => _planRows[i]['lotName']  = v), bg: bg),
                    _inputCell(_wLotNo,    row['lotNo']    ?? '', (v) => setState(() => _planRows[i]['lotNo']    = v), bg: bg),
                    _inputCell(_wDia,      (row['dia']     ?? '').toString(), (v) => setState(() => _planRows[i]['dia']     = v), bg: bg),
                    _inputCell(_wSetNo,    (row['setNo']   ?? '').toString(), (v) => setState(() => _planRows[i]['setNo']   = v), bg: bg),
                    _inputCell(_wItemName, row['itemName'] ?? '', (v) => setState(() => _planRows[i]['itemName'] = v), bg: bg),
                    _inputCell(_wSize,     (row['size']    ?? '').toString(), (v) => setState(() => _planRows[i]['size']    = v), bg: bg),
                    _inputCell(_wDozen,    (row['dozen']   ?? 0).toString(),  (v) => setState(() => _planRows[i]['dozen']   = num.tryParse(v) ?? 0), numeric: true, bg: bg),
                    _inputCell(_wLayLength,(row['layLength']?? 0).toString(), (v) => setState(() => _planRows[i]['layLength']= num.tryParse(v) ?? 0), numeric: true, bg: bg),
                    _inputCell(_wLayPcs,   (row['layPcs']  ?? 0).toString(),  (v) => setState(() => _planRows[i]['layPcs']  = num.tryParse(v) ?? 0), numeric: true, bg: bg),
                    _inputCell(_wTiming,   row['timing']   ?? '', (v) => setState(() => _planRows[i]['timing']   = v), bg: bg),
                    _inputCell(_wMachine,  row['machineNo']?? '', (v) => setState(() => _planRows[i]['machineNo']= v), bg: bg),
                    _checkCell(_wApproval, row['approval'] == true, (v) => setState(() => _planRows[i]['approval'] = v)),
                    _inputCell(_wActualTime, row['actualTimeTaken'] ?? '', (v) => setState(() => _planRows[i]['actualTimeTaken'] = v), bg: bg),
                    _inputCell(_wDiff,     row['diff']     ?? '', (v) => setState(() => _planRows[i]['diff']     = v), bg: bg),
                    _dropCell(_wStatus,    row['spreadingLayStatus'] ?? 'Pending', (v) => setState(() => _planRows[i]['spreadingLayStatus'] = v ?? 'Pending')),
                    _delCell(i),
                  ]);
                }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('EEEE').format(_selectedDate);
    final dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Cutting Daily Plan',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // ── Date / Day header bar (matches reference image)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Date picker chip
                InkWell(
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
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9E1F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blueGrey.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 14, color: Color(0xFF1F3864)),
                        const SizedBox(width: 6),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF1F3864)),
                            children: [
                              const TextSpan(
                                  text: 'Date  ',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500)),
                              TextSpan(
                                  text: dateStr,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const TextSpan(
                                  text: '    Day  ',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500)),
                              TextSpan(
                                  text: dayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_drop_down,
                            size: 18, color: Color(0xFF1F3864)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Fetch button
                TextButton.icon(
                  onPressed: _loading ? null : _fetchFromRequirements,
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Fetch from Lot Requirements',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1F3864),
                    backgroundColor: const Color(0xFFD9E1F2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          // ── Table area
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTable(),
                        const SizedBox(height: 12),

                        // Add Row button
                        OutlinedButton.icon(
                          onPressed: _addRow,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Cutting Row'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                            side: BorderSide(color: Colors.indigo.shade300),
                            foregroundColor: Colors.indigo.shade700,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Save button
                        ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F3864),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Save Plan',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
