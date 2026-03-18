import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';

class CuttingEntryPage2Screen extends StatefulWidget {
  final String entryId;
  const CuttingEntryPage2Screen({super.key, required this.entryId});

  @override
  State<CuttingEntryPage2Screen> createState() =>
      _CuttingEntryPage2ScreenState();
}

class _CuttingEntryPage2ScreenState extends State<CuttingEntryPage2Screen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  // Summary controllers
  final _cutterWasteCtrl = TextEditingController();
  final _offPatternCtrl = TextEditingController();

  // Calculated from Page 1 data (editable)
  Map<String, dynamic> _summary = {};

  // Part-wise entries
  List<Map<String, dynamic>> _parts = [];

  final List<String> _partNames = [
    'BACK', 'FRONT', 'FLAP OR SCALE', 'POCKET', 'PATTI OR POUCH',
    'COLLAR', 'SLEEVE', 'WAISTBAND', 'OTHER'
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('CuttingEntryPage2Screen init with entryId: ${widget.entryId}');
    _load();
  }

  Future<void> _load() async {
    try {
      debugPrint('Loading Page 2 data for entry: ${widget.entryId}');
      setState(() => _loading = true);

      // Fetch both Page 1 and Page 2 data in parallel with timeout to avoid hanging
      final results = await Future.wait([
        _api.getCuttingEntryById(widget.entryId).timeout(const Duration(seconds: 15)),
        _api.getCuttingEntryPage2(widget.entryId).timeout(const Duration(seconds: 15)),
      ]).catchError((err) {
        debugPrint('Error in parallel fetch: $err');
        return [null, null];
      });

      final page1 = results[0] as Map<String, dynamic>?;
      final page2 = results[1] as Map<String, dynamic>?;

      debugPrint('Page 1 data received: ${page1 != null}');
      debugPrint('Page 2 data received: ${page2 != null}');

      if (page1 != null) {
        // Safe conversion for potentially stringified data from backend
        List colourRows = [];
        if (page1['colourRows'] is String) {
          try {
            colourRows = jsonDecode(page1['colourRows']);
          } catch (_) {}
        } else if (page1['colourRows'] is List) {
          colourRows = page1['colourRows'];
        }

        debugPrint('Colour rows count: ${colourRows.length}');

        double totalRollWT = 0;
        double totalFolding = 0;
        double totalEndBit = 0;
        double totalMistake = 0;
        int totalDoz = 0;

        for (var r in colourRows) {
          if (r is Map) {
            totalRollWT += double.tryParse(r['rollWT']?.toString() ?? '0') ?? 0;
            totalFolding +=
                double.tryParse(r['actualFolding']?.toString() ?? '0') ?? 0;
            totalEndBit += double.tryParse(r['endBit']?.toString() ?? '0') ?? 0;
            totalMistake +=
                double.tryParse(r['mistake']?.toString() ?? '0') ?? 0;
            totalDoz += int.tryParse(r['doz']?.toString() ?? '0') ?? 0;
          }
        }

        double totalDozWT = totalRollWT - totalFolding;
        double noOfDoz = totalDoz.toDouble();
        double dozenPerWT = noOfDoz > 0 ? totalDozWT / noOfDoz : 0;
        double layWeight = totalDozWT - (totalEndBit + totalMistake);

        // Ensure we have some base values even if page2 is null or empty
        final isPage2Valid = page2 != null && page2.isNotEmpty;

        Map<String, dynamic> newSummary = {
          'totalRollWeight': totalRollWT,
          'totalFoldingWT': totalFolding,
          'layBalanceWT':
              double.tryParse((isPage2Valid ? page2['layBalanceWT'] : 0)?.toString() ?? '0') ?? 0,
          'totalDozenWT': totalDozWT,
          'noOfDoz': noOfDoz,
          'dozenPerWT': dozenPerWT,
          'endBit': totalEndBit,
          'adas': totalMistake,
          'layWeight': layWeight,
          'cutWeight':
              double.tryParse((isPage2Valid ? page2['cutWeight'] : 0)?.toString() ?? '0') ?? 0,
          'cadWastePercent': double.tryParse(
                  (isPage2Valid ? (page2['cadWastePercent'] ?? page1['cadEff'] ?? 0) : (page1['cadEff'] ?? 0))
                      .toString()) ??
              0,
          'totalWasteWT': 0.0,
          'wastePercent': 0.0,
          'difference': 0.0,
        };

        debugPrint('Summary prepared: $newSummary');

        _cutterWasteCtrl.text = (isPage2Valid ? (page2['cutterWasteWT'] ?? 0) : 0).toString();
        _offPatternCtrl.text = (isPage2Valid ? (page2['offPatternWaste'] ?? 0) : 0).toString();

        if (isPage2Valid) {
          var partsData = page2['parts'];
          if (partsData is String) {
            try {
              partsData = jsonDecode(partsData);
            } catch (_) {}
          }
          if (partsData is List) {
            _parts = List<Map<String, dynamic>>.from(
                partsData.whereType<Map>().map((p) => Map<String, dynamic>.from(p)));
          }
        }

        setState(() {
          _summary = newSummary;
        });

        _recalcSummary(); // Ensure initial calculations are done
      } else {
        debugPrint('Page 1 data IS NULL (or timed out)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not load data. Request may have timed out.')));
        }
        setState(() {
          _summary = {};
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading Page 2: $e');
      debugPrint('Stack trace: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _recalcSummary() {
    debugPrint('Recalculating summary...');
    try {
      final double trw = (_summary['totalRollWeight'] as num?)?.toDouble() ?? 0;
      final double tfw = (_summary['totalFoldingWT'] as num?)?.toDouble() ?? 0;
      final double tdw = trw - tfw;

      final double cutterWaste = double.tryParse(_cutterWasteCtrl.text) ?? 0;
      final double offPattern = double.tryParse(_offPatternCtrl.text) ?? 0;
      final double totalWaste = cutterWaste + offPattern;
      final double layWeight = (_summary['layWeight'] as num?)?.toDouble() ?? 0;
      double wastePercent =
          layWeight > 0 ? (totalWaste / layWeight * 100) : 0;

      // Handle NaN and Infinity
      if (wastePercent.isNaN || wastePercent.isInfinite) wastePercent = 0;

      final double cadWaste =
          (_summary['cadWastePercent'] as num?)?.toDouble() ?? 0;

      // Cut weight = sum of all part weights
      double cutWt = 0;
      for (var p in _parts) {
        if (p is Map) {
          final rows = (p['rows'] as List?) ?? [];
          for (var r in rows) {
            if (r is Map) {
              cutWt += (r['weight'] as num?)?.toDouble() ?? 0;
            }
          }
        }
      }

      setState(() {
        _summary['totalDozenWT'] = tdw;
        _summary['totalWasteWT'] = totalWaste;
        _summary['wastePercent'] = wastePercent;
        _summary['cutWeight'] = cutWt;
        _summary['difference'] = cadWaste - wastePercent;
      });
      debugPrint('Recalculation done: $_summary');
    } catch (e) {
      debugPrint('Error in _recalcSummary: $e');
    }
  }

  void _addPart() {
    setState(() {
      _parts.add({
        'partName': _partNames[0],
        'noOfPunches': 1,
        'rows': [{'weight': 0, 'noOfPcs': 0}],
      });
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    _recalcSummary();
    final data = {
      ..._summary,
      'cutterWasteWT': double.tryParse(_cutterWasteCtrl.text) ?? 0,
      'offPatternWaste': double.tryParse(_offPatternCtrl.text) ?? 0,
      'parts': _parts,
    };
    final ok = await _api.saveCuttingEntryPage2(widget.entryId, data);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Page 2 saved!' : 'Failed to save'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) Navigator.pop(context);
    }
  }

  Widget _buildSummaryRow(String label, dynamic value,
      {bool editable = false, TextEditingController? ctrl}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Fixed width label to avoid Expanded/Flexible constraints issues on web
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // Bounded container for the value area
          Expanded(
            child: editable && ctrl != null
                ? SizedBox(
                    height: 36,
                    child: TextFormField(
                      controller: ctrl,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => _recalcSummary(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6)),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                    ),
                  )
                : Container(
                    height: 36,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      () {
                        if (value is double) {
                          if (value.isNaN) return '0.000';
                          if (value.isInfinite) return 'Inf';
                          return value.toStringAsFixed(3);
                        }
                        return value?.toString() ?? '-';
                      }(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      textAlign: TextAlign.right,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartCard(int idx) {
    final part = _parts[idx];
    final rows = (part['rows'] as List?) ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _partNames.contains(part['partName'])
                        ? part['partName']
                        : _partNames[0],
                    isExpanded: true,
                    items: _partNames
                        .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _parts[idx]['partName'] = v ?? _partNames[0]),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => setState(() {
                    _parts.removeAt(idx);
                    _recalcSummary();
                  }),
                ),
              ],
            ),
            ...List.generate(rows.length, (ri) {
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Text('Row ${ri + 1}: ', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: (rows[ri]['weight'] ?? 0).toString(),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Weight',
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        onChanged: (v) {
                          _parts[idx]['rows'][ri]['weight'] =
                              double.tryParse(v) ?? 0;
                          _recalcSummary();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: (rows[ri]['noOfPcs'] ?? 0).toString(),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Pcs',
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        onChanged: (v) =>
                            _parts[idx]['rows'][ri]['noOfPcs'] = int.tryParse(v) ?? 0,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          size: 18, color: Colors.orange),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() {
                        if (rows.length > 1) {
                          (_parts[idx]['rows'] as List).removeAt(ri);
                          _recalcSummary();
                        }
                      }),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Row', style: TextStyle(fontSize: 12)),
              onPressed: () => setState(() {
                (_parts[idx]['rows'] as List).add({'weight': 0, 'noOfPcs': 0});
              }),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        'Building Page 2, loading: $_loading, summary empty: ${_summary.isEmpty}');

    Widget body;

    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_summary.isEmpty) {
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 48, color: Colors.orange.shade300),
            const SizedBox(height: 16),
            const Text('No base data found for this entry.',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    } else {
      try {
        body = Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Summary card
                Card(
                  elevation: 2,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.analytics_outlined,
                                size: 20, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            const Text('Weight Summary',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                            'Total Roll Weight', _summary['totalRollWeight']),
                        _buildSummaryRow(
                            'Total Folding WT', _summary['totalFoldingWT']),
                        _buildSummaryRow(
                            'Total Dozen WT', _summary['totalDozenWT']),
                        _buildSummaryRow(
                            'No. of Dozens', _summary['noOfDoz']),
                        _buildSummaryRow(
                            'Dozen Per WT', _summary['dozenPerWT']),
                        _buildSummaryRow('End Bit', _summary['endBit']),
                        _buildSummaryRow('Adas (Mistake)', _summary['adas']),
                        _buildSummaryRow('Lay Weight', _summary['layWeight']),
                        _buildSummaryRow(
                            'Cut Weight (from Parts)', _summary['cutWeight'] ?? 0.0),
                        _buildSummaryRow('Cutter Waste WT', null,
                            editable: true, ctrl: _cutterWasteCtrl),
                        _buildSummaryRow('Off Pattern Waste', null,
                            editable: true, ctrl: _offPatternCtrl),
                        _buildSummaryRow(
                            'Total Waste WT', _summary['totalWasteWT'] ?? 0.0),
                        _buildSummaryRow(
                            'Waste %', _summary['wastePercent'] ?? 0.0),
                        _buildSummaryRow(
                            'CAD Waste %', _summary['cadWastePercent'] ?? 0.0),
                        _buildSummaryRow(
                            'Difference', _summary['difference'] ?? 0.0),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Part-wise weight entry
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Part-wise Weight Entry',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: _addPart,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Part'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontSize: 12),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        if (_parts.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text('No parts added.',
                                  style: TextStyle(color: Colors.grey.shade500)),
                            ),
                          ),
                        ...List.generate(
                            _parts.length, (i) => _buildPartCard(i)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      } catch (e) {
        debugPrint('Rendering error in Page 2: $e');
        body = Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('A layout error occurred while rendering this page.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(e.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _load, child: const Text('Try Again')),
              ],
            ),
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
        title: const Text('Cutting Entry – Page 2',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
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
              : const Text('Save Page 2', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
