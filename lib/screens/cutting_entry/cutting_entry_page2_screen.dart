import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data classes with TextEditingControllers for each editable field.
// Using controllers instead of initialValue avoids the
// "Cannot hit test a render box with no size" crash on setState rebuild.
// ─────────────────────────────────────────────────────────────────────────────

class _PartRow {
  final TextEditingController weightCtrl;
  final TextEditingController pcsCtrl;

  _PartRow({double weight = 0, int pcs = 0})
      : weightCtrl = TextEditingController(text: weight.toString()),
        pcsCtrl = TextEditingController(text: pcs.toString());

  factory _PartRow.fromMap(Map<String, dynamic> m) => _PartRow(
        weight: (m['weight'] as num?)?.toDouble() ?? 0,
        pcs: (m['noOfPcs'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'weight': double.tryParse(weightCtrl.text) ?? 0,
        'noOfPcs': int.tryParse(pcsCtrl.text) ?? 0,
      };

  void dispose() {
    weightCtrl.dispose();
    pcsCtrl.dispose();
  }
}

class _Part {
  String partName;
  final TextEditingController punchesCtrl;
  final List<_PartRow> rows;

  _Part({required this.partName, int punches = 1, List<_PartRow>? rows})
      : punchesCtrl = TextEditingController(text: punches.toString()),
        rows = rows ?? [_PartRow()];

  factory _Part.fromMap(Map<String, dynamic> m) {
    List<_PartRow> rows = [];
    final rawRows = m['rows'];
    if (rawRows is List) {
      rows = rawRows.whereType<Map>().map((r) => _PartRow.fromMap(Map<String, dynamic>.from(r))).toList();
    }
    if (rows.isEmpty) rows = [_PartRow()];
    return _Part(
      partName: m['partName']?.toString() ?? 'BACK',
      punches: (m['noOfPunches'] as num?)?.toInt() ?? 1,
      rows: rows,
    );
  }

  Map<String, dynamic> toMap() => {
        'partName': partName,
        'noOfPunches': int.tryParse(punchesCtrl.text) ?? 1,
        'rows': rows.map((r) => r.toMap()).toList(),
      };

  void dispose() {
    punchesCtrl.dispose();
    for (final r in rows) {
      r.dispose();
    }
  }
}

class _LayRow {
  final TextEditingController weightCtrl;
  final TextEditingController pcsCtrl;

  _LayRow({double weight = 0, int pcs = 0})
      : weightCtrl = TextEditingController(text: weight.toString()),
        pcsCtrl = TextEditingController(text: pcs.toString());

  factory _LayRow.fromMap(Map<String, dynamic> m) => _LayRow(
        weight: (m['weight'] as num?)?.toDouble() ?? 0,
        pcs: (m['noOfPunches'] as num?)?.toInt() ?? 0, // Model uses noOfPunches for lay balance pcs
      );

  Map<String, dynamic> toMap() => {
        'weight': double.tryParse(weightCtrl.text) ?? 0,
        'noOfPunches': int.tryParse(pcsCtrl.text) ?? 0, // Model uses noOfPunches for lay balance pcs
      };

  void dispose() {
    weightCtrl.dispose();
    pcsCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class CuttingEntryPage2Screen extends StatefulWidget {
  final String entryId;
  const CuttingEntryPage2Screen({super.key, required this.entryId});

  @override
  State<CuttingEntryPage2Screen> createState() =>
      _CuttingEntryPage2ScreenState();
}

class _CuttingEntryPage2ScreenState extends State<CuttingEntryPage2Screen> {
  final _api = MobileApiService();
  bool _loading = true;
  bool _saving = false;

  // Manual entry controllers
  final _cutterWasteCtrl = TextEditingController();
  final _offPatternCtrl = TextEditingController();

  // Calculated from Page 1
  Map<String, dynamic> _summary = {};

  // Part-wise and lay balance data
  final List<_Part> _parts = [];
  final List<_LayRow> _layBalanceRows = [_LayRow()];

  final List<String> _partNames = [
    'BACK', 'FRONT', 'FLAP OR SCALE', 'POCKET', 'PATTI OR POUCH',
    'COLLAR', 'SLEEVE', 'WAISTBAND', 'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cutterWasteCtrl.dispose();
    _offPatternCtrl.dispose();
    for (final p in _parts) p.dispose();
    for (final r in _layBalanceRows) r.dispose();
    super.dispose();
  }

  // ─── Load ─────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      setState(() => _loading = true);

      final results = await Future.wait([
        _api.getCuttingEntryById(widget.entryId).timeout(const Duration(seconds: 15)),
        _api.getCuttingEntryPage2(widget.entryId).timeout(const Duration(seconds: 15)),
      ]).catchError((err) {
        debugPrint('Error in parallel fetch: $err');
        return [null, null];
      });

      final Map<String, dynamic>? page1 =
          results[0] is Map ? Map<String, dynamic>.from(results[0] as Map) : null;
      final Map<String, dynamic>? page2 =
          results[1] is Map ? Map<String, dynamic>.from(results[1] as Map) : null;

      if (page1 != null) {
        List colourRows = [];
        if (page1['colourRows'] is String) {
          try { colourRows = jsonDecode(page1['colourRows']); } catch (_) {}
        } else if (page1['colourRows'] is List) {
          colourRows = page1['colourRows'];
        }

        double totalRollWT = 0, totalFolding = 0, totalEndBit = 0, totalMistake = 0;
        int totalDoz = 0;
        double totalPcs = 0;

        for (var r in colourRows) {
          if (r is Map) {
            totalRollWT  += double.tryParse(r['rollWT']?.toString()        ?? '0') ?? 0;
            totalFolding += double.tryParse(r['actualFolding']?.toString() ?? '0') ?? 0;
            totalEndBit  += double.tryParse(r['endBit']?.toString()        ?? '0') ?? 0;
            totalMistake += double.tryParse(r['mistake']?.toString()       ?? '0') ?? 0;
            totalDoz     += int.tryParse   (r['doz']?.toString()           ?? '0') ?? 0;
            totalPcs     += double.tryParse(r['totalPcs']?.toString()      ?? '0') ?? 0;
          }
        }

        final double totalDozWT = totalRollWT - totalFolding;
        final double noOfDoz    = totalDoz.toDouble();
        final double dozenPerWT = noOfDoz > 0 ? totalDozWT / noOfDoz : 0;
        final double layWeight  = totalDozWT - (totalEndBit + totalMistake);

        final isPage2Valid = page2 != null && page2.isNotEmpty;

        _cutterWasteCtrl.text = (isPage2Valid ? (page2['cutterWasteWT']   ?? 0) : 0).toString();
        _offPatternCtrl.text  = (isPage2Valid ? (page2['offPatternWaste'] ?? 0) : 0).toString();

        // Load parts
        if (isPage2Valid) {
          var rawParts = page2['parts'];
          if (rawParts is String) { try { rawParts = jsonDecode(rawParts); } catch (_) {} }
          if (rawParts is List) {
            for (final p in rawParts.whereType<Map>()) {
              _parts.add(_Part.fromMap(Map<String, dynamic>.from(p)));
            }
          }

          // Load lay balance rows
          var rawLay = page2['layBalance'];
          if (rawLay is String) { try { rawLay = jsonDecode(rawLay); } catch (_) {} }
          if (rawLay is List && rawLay.isNotEmpty) {
            _layBalanceRows.clear();
            for (final r in rawLay.whereType<Map>()) {
              _layBalanceRows.add(_LayRow.fromMap(Map<String, dynamic>.from(r)));
            }
          }
        }

        setState(() {
          _summary = {
            'totalRollWeight': totalRollWT,
            'totalFoldingWT':  totalFolding,
            'totalDozenWT':    totalDozWT,
            'noOfDoz':         noOfDoz,
            'dozenPerWT':      dozenPerWT,
            'endBit':          totalEndBit,
            'adas':            totalMistake,
            'layWeight':       layWeight,
            'totalPcs':        totalPcs,
            'cadWastePercent': double.tryParse((page1['cadEff'] ?? 0).toString()) ?? 0,
            'stickerNo':       page1['stickerNo'] ?? 'PENDING',
          };
        });
        _recalc();
      }
    } catch (e) {
      debugPrint('Error loading Page 2: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Recalc ────────────────────────────────────────────────────────────────

  void _recalc() {
    final double cutterWaste = double.tryParse(_cutterWasteCtrl.text) ?? 0;
    final double offPattern  = double.tryParse(_offPatternCtrl.text)  ?? 0;
    final double totalWaste  = cutterWaste + offPattern;
    final double layWeight   = (_summary['layWeight'] as num?)?.toDouble() ?? 0;
    double wastePercent = layWeight > 0 ? (totalWaste / layWeight * 100) : 0;
    if (wastePercent.isNaN || wastePercent.isInfinite) wastePercent = 0;
    final double cadWaste = (_summary['cadWastePercent'] as num?)?.toDouble() ?? 0;

    double cutWt = 0;
    for (final p in _parts) {
      for (final r in p.rows) {
        cutWt += double.tryParse(r.weightCtrl.text) ?? 0;
      }
    }

    double layBalWt = 0, layBalPcs = 0;
    for (final r in _layBalanceRows) {
      layBalWt  += double.tryParse(r.weightCtrl.text) ?? 0;
      layBalPcs += double.tryParse(r.pcsCtrl.text)   ?? 0;
    }

    setState(() {
      _summary['totalWasteWT']    = totalWaste;
      _summary['wastePercent']    = wastePercent;
      _summary['cutWeight']       = cutWt;
      _summary['layBalanceWeight']= layBalWt;
      _summary['layBalancePcs']   = layBalPcs;
      _summary['difference']      = cadWaste - wastePercent;
    });
  }

  // ─── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    _recalc();
    final data = {
      ..._summary,
      'cutterWasteWT':   double.tryParse(_cutterWasteCtrl.text) ?? 0,
      'offPatternWaste': double.tryParse(_offPatternCtrl.text)  ?? 0,
      'parts':           _parts.map((p) => p.toMap()).toList(),
      'layBalance':      _layBalanceRows.map((r) => r.toMap()).toList(),
    };
    final ok = await _api.saveCuttingEntryPage2(widget.entryId, data);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Sheet 2 saved!' : 'Failed to save'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) Navigator.pop(context);
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _f(dynamic v, {int d = 2}) {
    final x = (v as num?)?.toDouble() ?? 0.0;
    return (x.isNaN || x.isInfinite) ? '0.00' : x.toStringAsFixed(d);
  }

  // ─── Summary Card ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    final noOfDoz    = (_summary['noOfDoz']       as num?)?.toDouble() ?? 0;
    final cutWt      = (_summary['cutWeight']     as num?)?.toDouble() ?? 0;
    final waste      = (_summary['wastePercent']  as num?)?.toDouble() ?? 0;
    final cadWaste   = (_summary['cadWastePercent'] as num?)?.toDouble() ?? 0;
    final diff       = (_summary['difference']    as num?)?.toDouble() ?? 0;
    final lbWt       = (_summary['layBalanceWeight'] as num?)?.toDouble() ?? 0;

    final rows = <Map<String, dynamic>>[
      {'sn': 1,  'label': 'Total Roll Weight',                        'value': _summary['totalRollWeight']},
      {'sn': 2,  'label': 'Total Folding WT',                         'value': _summary['totalFoldingWT']},
      {'sn': 3,  'label': 'Lay Balance WT',                           'value': lbWt},
      {'sn': 4,  'label': 'Total Dozen WT\n(Roll wt − Folding)',      'value': _summary['totalDozenWT']},
      {'sn': 5,  'label': 'No. of Doz\n(All doz with loose pcs)',     'value': noOfDoz > 0 ? noOfDoz.toStringAsFixed(0) : '0', 'isStr': true},
      {'sn': 6,  'label': 'Dozen Per WT\n(Total doz wt ÷ No.of Doz)','value': _summary['dozenPerWT']},
      {'sn': 7,  'label': 'End Bit\n(1 page end bit total)',          'value': _summary['endBit']},
      {'sn': 8,  'label': 'Adas\n(1 page mistake total)',             'value': _summary['adas']},
      {'sn': 9,  'label': 'Lay Weight\n(Total doz wt − End bit − Adas)', 'value': _summary['layWeight']},
      {'sn': 10, 'label': 'Cut Weight\n(Part of cut weight total)',   'value': cutWt},
      {'sn': 11, 'label': 'Cutter Waste WT\n(Voice/weight machine)',  'ctrl': _cutterWasteCtrl},
      {'sn': 12, 'label': 'Off Pattern Waste\n(Voice/weight machine)','ctrl': _offPatternCtrl},
      {'sn': 13, 'label': 'Total Waste WT\n(Cutter Waste + Off Pattern)', 'value': _summary['totalWasteWT'] ?? 0.0},
      {'sn': 14, 'label': 'Waste %\n(Total waste ÷ Lay wt × 100)',   'value': waste,  'color': waste > 10 ? Colors.red : Colors.green},
      {'sn': 15, 'label': 'Cad Waste %\n(Auto feed)',                 'value': cadWaste},
      {'sn': 16, 'label': 'Difference\n(Cad Waste − Waste %)',        'value': diff,   'color': diff < 0 ? Colors.red : Colors.green},
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              const Icon(Icons.table_chart_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Weight Summary (Sheet 2)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: Text('Sticker: ${_summary['stickerNo'] ?? '-'}',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ]),
          ),
          // Table col headers
          Container(
            color: Colors.blue.shade50,
            child: Row(children: [
              _hCell('S.N', width: 36),
              Expanded(child: _hCell('Description', isExpanded: true)),
              _hCell('Total Weight', width: 110, right: true),
            ]),
          ),
          // Data rows
          ...rows.map((r) {
            final ctrl  = r['ctrl'] as TextEditingController?;
            final color = r['color'] as Color?;
            final isStr = r['isStr'] as bool? ?? false;
            final val   = r['value'];
            return _summaryRow(
              sn: r['sn'] as int,
              label: r['label'] as String,
              ctrl: ctrl,
              value: ctrl != null ? null : (isStr ? val?.toString() : val),
              isStr: isStr,
              valueColor: color,
              evenBg: (r['sn'] as int).isEven,
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _hCell(String t, {double? width, bool right = false, bool isExpanded = false}) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(t,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue.shade800)),
    );
    if (isExpanded) return child;
    return SizedBox(width: width, child: child);
  }

  Widget _summaryRow({
    required int sn,
    required String label,
    dynamic value,
    bool isStr = false,
    TextEditingController? ctrl,
    Color? valueColor,
    bool evenBg = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: evenBg ? Colors.grey.shade50 : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // S.N
          Container(
            width: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300))),
            child: Text('$sn',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          ),
          // Label
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ),
          // Value
          Container(
            width: 110,
            decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.shade300))),
            child: ctrl != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: TextFormField(
                      controller: ctrl,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _recalc(),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Text(
                      isStr ? (value?.toString() ?? '-') : _f(value),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: valueColor ?? Colors.black87),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  // ─── Part Summary Table ───────────────────────────────────────────────────

  Widget _buildPartSummaryTable() {
    final noOfDoz = (_summary['noOfDoz'] as num?)?.toDouble() ?? 1;

    double totalCutWT = 0, totalCuts = 0;
    final partData = _parts.map((p) {
      double wt = p.rows.fold(0.0, (s, r) => s + (double.tryParse(r.weightCtrl.text) ?? 0));
      double cuts = p.rows.length.toDouble();
      totalCutWT += wt;
      totalCuts  += cuts;
      return {'name': p.partName, 'cuts': cuts, 'wt': wt, 'avgDoz': noOfDoz > 0 ? wt / noOfDoz : 0.0};
    }).toList();

    double lbWt  = _layBalanceRows.fold(0.0, (s, r) => s + (double.tryParse(r.weightCtrl.text) ?? 0));
    double lbPcs = _layBalanceRows.fold(0.0, (s, r) => s + (double.tryParse(r.pcsCtrl.text)   ?? 0));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.teal.shade600,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(children: [
              Icon(Icons.grid_on, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Part-wise Summary',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
          ),
          // Header row
          Container(
            color: Colors.teal.shade50,
            child: Row(children: [
              _ptHCell('Part', flex: 3),
              _ptHCell('No of Cut'),
              _ptHCell('Part of\nCut WT.'),
              _ptHCell('AVG DOZ\nWT'),
            ]),
          ),
          // Part rows
          ...partData.map((r) => _ptDataRow(
                r['name'] as String,
                (r['cuts'] as double).toStringAsFixed(0),
                _f(r['wt']),
                _f(r['avgDoz']),
              )),
          // LAY BALANCE
          _ptDataRow(
            'LAY BALANCE',
            lbPcs.toStringAsFixed(0),
            _f(lbWt),
            _f(noOfDoz > 0 ? lbWt / noOfDoz : 0),
            bg: Colors.amber.shade50,
            bold: true,
          ),
          // TOTAL
          _ptDataRow(
            'TOTAL',
            (totalCuts + lbPcs).toStringAsFixed(0),
            _f(totalCutWT + lbWt),
            _f(noOfDoz > 0 ? (totalCutWT + lbWt) / noOfDoz : 0),
            bg: Colors.teal.shade50,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _ptHCell(String t, {int flex = 2}) => Expanded(
        flex: flex,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.teal.shade100))),
          child: Text(t,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
        ),
      );

  Widget _ptDataRow(String part, String cuts, String wt, String avg,
      {Color? bg, bool bold = false}) {
    final fw = bold ? FontWeight.bold : FontWeight.normal;
    return Container(
      decoration: BoxDecoration(
        color: bg ?? Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(children: [
        _ptDCell(part, flex: 3, fw: fw),
        _ptDCell(cuts, fw: fw),
        _ptDCell(wt,   fw: fw),
        _ptDCell(avg,  fw: fw),
      ]),
    );
  }

  Widget _ptDCell(String t, {int flex = 2, FontWeight? fw}) => Expanded(
        flex: flex,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade200))),
          child: Text(t, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: fw ?? FontWeight.normal)),
        ),
      );

  // ─── Part Entry Card ──────────────────────────────────────────────────────

  Widget _buildPartCard(int idx) {
    final part = _parts[idx];
    final totalPcs = (_summary['totalPcs'] as num?)?.toDouble() ?? 0;
    final punches  = int.tryParse(part.punchesCtrl.text) ?? 1;

    double partWt  = part.rows.fold(0.0, (s, r) => s + (double.tryParse(r.weightCtrl.text) ?? 0));
    double partPcs = part.rows.fold(0.0, (s, r) => s + (double.tryParse(r.pcsCtrl.text)   ?? 0));
    final autoP    = punches > 0 ? (totalPcs / punches).toStringAsFixed(1) : '0';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1.5,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Part name + delete
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(children: [
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _partNames.contains(part.partName) ? part.partName : _partNames[0],
                  isExpanded: true,
                  isDense: true,
                  items: _partNames.map((n) => DropdownMenuItem(
                    value: n,
                    child: Text(n, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  )).toList(),
                  onChanged: (v) => setState(() => part.partName = v ?? _partNames[0]),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() {
                _parts[idx].dispose();
                _parts.removeAt(idx);
                _recalc();
              }),
            ),
          ]),
        ),
        // No. of Punches
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xFFEEF2FF),
          child: Row(children: [
            const Text('No. of Punches:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: TextFormField(
                controller: part.punchesCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.indigo.shade200)),
                ),
                onChanged: (_) => setState(() => _recalc()),
              ),
            ),
            const Spacer(),
            Text('Rows: ${part.rows.length}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ]),
        ),
        // Column headers
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            const SizedBox(width: 32,
                child: Text('#', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            Expanded(flex: 2,
                child: Text('No. of Punches\n(Auto)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
            const SizedBox(width: 6),
            Expanded(flex: 2,
                child: Text('Weight (kg)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
            const SizedBox(width: 6),
            Expanded(flex: 2,
                child: Text('No. of Pcs',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
            const SizedBox(width: 28),
          ]),
        ),
        // Rows
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(children: [
            ...List.generate(part.rows.length, (ri) => _partRowWidget(idx, ri, autoP)),
          ]),
        ),
        // Footer
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(children: [
            TextButton.icon(
              icon: const Icon(Icons.add, size: 13),
              label: const Text('Add Row', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              onPressed: () => setState(() { part.rows.add(_PartRow()); }),
            ),
            const Spacer(),
            Text('WT: ${_f(partWt)}  Pcs: ${partPcs.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
      ]),
    );
  }

  Widget _partRowWidget(int pidx, int ri, String autoP) {
    final row = _parts[pidx].rows[ri];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        SizedBox(width: 32,
            child: Text('${ri + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600))),
        // Auto punches (read-only)
        Expanded(flex: 2,
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Text(autoP, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          )),
        const SizedBox(width: 6),
        // Weight
        Expanded(flex: 2,
          child: TextFormField(
            controller: row.weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Weight',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onChanged: (_) => _recalc(),
          )),
        const SizedBox(width: 6),
        // Pcs
        Expanded(flex: 2,
          child: TextFormField(
            controller: row.pcsCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Pcs',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onChanged: (_) => _recalc(),
          )),
        // Remove
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.orange),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: _partHasMultipleRows(pidx)
              ? () => setState(() {
                    _parts[pidx].rows[ri].dispose();
                    _parts[pidx].rows.removeAt(ri);
                    _recalc();
                  })
              : null,
        ),
      ]),
    );
  }

  bool _partHasMultipleRows(int pidx) => _parts[pidx].rows.length > 1;

  // ─── Lay Balance Card ─────────────────────────────────────────────────────

  Widget _buildLayBalanceCard() {
    double lbWt  = _layBalanceRows.fold(0.0, (s, r) => s + (double.tryParse(r.weightCtrl.text) ?? 0));
    double lbPcs = _layBalanceRows.fold(0.0, (s, r) => s + (double.tryParse(r.pcsCtrl.text)   ?? 0));

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber.shade700,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: const Row(children: [
            Icon(Icons.balance, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('LAY BALANCE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
        ),
        // Col headers
        Container(
          color: Colors.amber.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            const SizedBox(width: 32, child: Text('#', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: Text('Count\n(no. of rows)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900))),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: Text('Weight\n(Bit lay bal)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900))),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: Text('No. of Pcs',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900))),
            const SizedBox(width: 28),
          ]),
        ),
        // Rows
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(children: [
            ...List.generate(_layBalanceRows.length, (ri) => _layRowWidget(ri)),
          ]),
        ),
        // Footer
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(children: [
            TextButton.icon(
              icon: const Icon(Icons.add, size: 13),
              label: const Text('Add Row', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              onPressed: () => setState(() { _layBalanceRows.add(_LayRow()); }),
            ),
            const Spacer(),
            Text('WT: ${_f(lbWt)}  Pcs: ${lbPcs.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
      ]),
    );
  }

  Widget _layRowWidget(int ri) {
    final row = _layBalanceRows[ri];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        SizedBox(width: 32,
            child: Text('${ri + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600))),
        // Count
        Expanded(flex: 2,
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text(_layBalanceRows.length.toString(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          )),
        const SizedBox(width: 6),
        // Weight
        Expanded(flex: 2,
          child: TextFormField(
            controller: row.weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Weight',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onChanged: (_) => _recalc(),
          )),
        const SizedBox(width: 6),
        // Pcs
        Expanded(flex: 2,
          child: TextFormField(
            controller: row.pcsCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Pcs',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onChanged: (_) => _recalc(),
          )),
        // Remove
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.orange),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: _layBalanceRows.length > 1
              ? () => setState(() {
                    _layBalanceRows[ri].dispose();
                    _layBalanceRows.removeAt(ri);
                    _recalc();
                  })
              : null,
        ),
      ]),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_summary.isEmpty) {
      body = Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange.shade300),
          const SizedBox(height: 16),
          const Text('No base data found.', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    } else {
      try {
        body = SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 120),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // 1. Weight Summary
            _buildSummaryCard(),
            const SizedBox(height: 16),

            // 2. Part-wise Cut Entry
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.content_cut, color: Colors.indigo.shade700, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Text('Part-wise Cut Entry',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {
                        _parts.add(_Part(partName: _partNames[0]));
                      }),
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Add Part', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ]),
                  const Divider(height: 20),
                  if (_parts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text('No parts added yet.',
                            style: TextStyle(color: Colors.grey.shade500)),
                      ),
                    ),
                  ...List.generate(_parts.length, (i) => _buildPartCard(i)),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Lay Balance
            _buildLayBalanceCard(),
            const SizedBox(height: 16),

            // 4. Part Summary Table
            _buildPartSummaryTable(),
            const SizedBox(height: 20),
          ]),
        );
      } catch (e) {
        debugPrint('Rendering error in Sheet 2: $e');
        body = Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('A layout error occurred.', textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(e.toString(), textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Try Again')),
            ]),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Cutting Entry – Sheet 2',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Reload',
          ),
        ],
      ),
      body: SizedBox.expand(child: body),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
              ? const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Save Sheet 2',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
