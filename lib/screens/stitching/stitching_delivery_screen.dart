import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/responsive_wrapper.dart';
import '../../widgets/modern_data_table.dart';

class StitchingDeliveryScreen extends StatefulWidget {
  const StitchingDeliveryScreen({super.key});
  @override
  State<StitchingDeliveryScreen> createState() => _StitchingDeliveryScreenState();
}

class _StitchingDeliveryScreenState extends State<StitchingDeliveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _api = MobileApiService();
  List<dynamic> _list = [];
  bool _loading = true;

  // Form
  final _formKey = GlobalKey<FormState>();
  final _cutNoCtrl = TextEditingController();
  final _itemNameCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _lotNoCtrl = TextEditingController();
  final _hsnCtrl = TextEditingController();
  final _diaCtrl = TextEditingController();
  final _vehicleNoCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _processCtrl = TextEditingController();
  final _foldingReqCtrl = TextEditingController();
  DateTime _dcDate = DateTime.now();
  List<Map<String, dynamic>> _colourRows = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _loadList();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _cutNoCtrl.dispose(); _itemNameCtrl.dispose(); _sizeCtrl.dispose();
    _lotNoCtrl.dispose(); _hsnCtrl.dispose(); _diaCtrl.dispose();
    _vehicleNoCtrl.dispose(); _rateCtrl.dispose(); _processCtrl.dispose();
    _foldingReqCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadList() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getStitchingDeliveries();
      if (mounted) setState(() { _list = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'cutNo': _cutNoCtrl.text.trim(),
      'itemName': _itemNameCtrl.text.trim(),
      'size': _sizeCtrl.text.trim(),
      'lotNo': _lotNoCtrl.text.trim(),
      'hsnCode': _hsnCtrl.text.trim(),
      'dia': _diaCtrl.text.trim(),
      'vehicleNo': _vehicleNoCtrl.text.trim(),
      'ratePerKg': double.tryParse(_rateCtrl.text) ?? 0,
      'process': _processCtrl.text.trim(),
      'foldingReqPerDozen': double.tryParse(_foldingReqCtrl.text) ?? 0,
      'dcDate': _dcDate.toIso8601String(),
      'colourRows': _colourRows,
      'totalValue': (_colourRows.fold<double>(0, (s, r) => s + ((r['foldingActualWt'] ?? 0) as num).toDouble())) *
          (double.tryParse(_rateCtrl.text) ?? 0),
    };
    final ok = await _api.createStitchingDelivery(data);
    if (mounted) setState(() => _saving = false);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('DC created successfully'), backgroundColor: Color(0xFF10B981)));
      _clearForm();
      _loadList();
      _tabCtrl.animateTo(0);
    }
  }

  void _clearForm() {
    _cutNoCtrl.clear(); _itemNameCtrl.clear(); _sizeCtrl.clear();
    _lotNoCtrl.clear(); _hsnCtrl.clear(); _diaCtrl.clear();
    _vehicleNoCtrl.clear(); _rateCtrl.clear(); _processCtrl.clear();
    _foldingReqCtrl.clear(); _colourRows = []; _dcDate = DateTime.now();
    setState(() {});
  }

  Widget _field(String label, TextEditingController ctrl, {bool req = false, TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF475569))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        validator: req ? (v) => (v?.isEmpty ?? true) ? 'Required' : null : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPalette.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              children: [
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                TabBar(
                  controller: _tabCtrl,
                  labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5),
                  unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12),
                  labelColor: const Color(0xFF475569),
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  indicatorColor: const Color(0xFF475569),
                  indicatorWeight: 2,
                  tabs: const [Tab(text: 'DC LIST'), Tab(text: 'NEW DC')],
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── LIST TAB ──────────────────────────────
          ResponsiveWrapper(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _loading
                    ? const Center(child: Padding(padding: EdgeInsets.all(80), child: CircularProgressIndicator(strokeWidth: 2)))
                    : ModernDataTable(
                        columns: const ['DC NO', 'ITEM NAME', 'SIZE', 'DATE', 'VALUE (₹)'],
                        showActions: false,
                        rows: _list.map((dc) {
                          final date = dc['dcDate'] != null
                              ? DateFormat('dd MMM yyyy').format(DateTime.parse(dc['dcDate']).toLocal())
                              : '-';
                          return {
                            'DC NO': dc['dcNo']?.toString() ?? '-',
                            'ITEM NAME': dc['itemName']?.toString() ?? '-',
                            'SIZE': dc['size']?.toString() ?? '-',
                            'DATE': date,
                            'VALUE (₹)': '₹${(dc['totalValue'] ?? 0).toStringAsFixed(0)}',
                          };
                        }).toList().cast<Map<String, dynamic>>(),
                        emptyMessage: 'No delivery notes found',
                      ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          // ── FORM TAB ──────────────────────────────
          ResponsiveWrapper(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionCard('DC DETAILS', [
                      // Date picker
                      InkWell(
                        onTap: () async {
                          final d = await showDatePicker(context: context, initialDate: _dcDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                          if (d != null) setState(() => _dcDate = d);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(6)),
                          child: Row(children: [
                            const Icon(LucideIcons.calendar, size: 16, color: Color(0xFF475569)),
                            const SizedBox(width: 10),
                            Text('DC Date: ${DateFormat('dd MMM yyyy').format(_dcDate)}', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A))),
                          ]),
                        ),
                      ),
                      _field('Cut No *', _cutNoCtrl, req: true),
                      Row(children: [
                        Expanded(child: _field('Item Name *', _itemNameCtrl, req: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _field('Size', _sizeCtrl)),
                      ]),
                      Row(children: [
                        Expanded(child: _field('Lot No', _lotNoCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _field('Dia', _diaCtrl)),
                      ]),
                      _field('HSN Code', _hsnCtrl),
                      _field('Vehicle No', _vehicleNoCtrl),
                      Row(children: [
                        Expanded(child: _field('Process', _processCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _field('Rate/Kg (₹)', _rateCtrl, type: TextInputType.number)),
                      ]),
                      _field('Folding Req/Dozen', _foldingReqCtrl, type: TextInputType.number),
                    ]),
                    const SizedBox(height: 16),
                    _sectionCard('COLOUR DETAILS', [
                      Row(
                        children: [
                          Text('Colour Rows', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF475569))),
                          const Spacer(),
                          InkWell(
                            onTap: () => setState(() => _colourRows.add({'colour': '', 'pcs': 0, 'foldingActualWt': 0})),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(4)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(LucideIcons.plus, size: 12, color: Color(0xFF475569)),
                                const SizedBox(width: 4),
                                Text('ADD ROW', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                              ]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(_colourRows.length, (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Expanded(flex: 2, child: TextFormField(
                            initialValue: _colourRows[i]['colour'] ?? '',
                            style: GoogleFonts.inter(fontSize: 12),
                            decoration: InputDecoration(labelText: 'Colour', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: const OutlineInputBorder(), labelStyle: GoogleFonts.inter(fontSize: 11)),
                            onChanged: (v) => _colourRows[i]['colour'] = v,
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(
                            initialValue: (_colourRows[i]['pcs'] ?? 0).toString(),
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(fontSize: 12),
                            decoration: InputDecoration(labelText: 'Pcs', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: const OutlineInputBorder(), labelStyle: GoogleFonts.inter(fontSize: 11)),
                            onChanged: (v) => _colourRows[i]['pcs'] = int.tryParse(v) ?? 0,
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(
                            initialValue: (_colourRows[i]['foldingActualWt'] ?? 0).toString(),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.inter(fontSize: 12),
                            decoration: InputDecoration(labelText: 'Fold Wt', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: const OutlineInputBorder(), labelStyle: GoogleFonts.inter(fontSize: 11)),
                            onChanged: (v) => _colourRows[i]['foldingActualWt'] = double.tryParse(v) ?? 0,
                          )),
                          IconButton(icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFFEF4444)), onPressed: () => setState(() => _colourRows.removeAt(i))),
                        ]),
                      )),
                    ]),
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: _saving ? null : _save,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: const Color(0xFF475569), borderRadius: BorderRadius.circular(6)),
                        child: Center(child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('SAVE DC', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.8, color: Colors.white))),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ), // ResponsiveWrapper
          ), // TabBarView second child
        ],
      ), // TabBarView
    ), // Expanded
  ], // Column children
), // body Column
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFF94A3B8), letterSpacing: 1)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
