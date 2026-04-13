import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/responsive_wrapper.dart';
import '../../widgets/modern_data_table.dart';

class IronPackingDcScreen extends StatefulWidget {
  const IronPackingDcScreen({super.key});
  @override
  State<IronPackingDcScreen> createState() => _IronPackingDcScreenState();
}

class _IronPackingDcScreenState extends State<IronPackingDcScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _api = MobileApiService();
  List<dynamic> _outwards = [];
  List<dynamic> _inwards = [];
  bool _loading = true;

  final _formKey = GlobalKey<FormState>();
  final _itemNameCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _cutNoCtrl = TextEditingController();
  final _partyCtrl = TextEditingController();
  final _processCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  String _type = 'outward';
  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _colourRows = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _itemNameCtrl.dispose(); _sizeCtrl.dispose(); _cutNoCtrl.dispose();
    _partyCtrl.dispose(); _processCtrl.dispose(); _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await _api.getIronPackingDcs();
      if (mounted) setState(() {
        _outwards = all.where((d) => d['type'] == 'outward').toList();
        _inwards = all.where((d) => d['type'] == 'inward').toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final pcs = _colourRows.fold<int>(0, (s, r) => s + ((r['totalPcs'] ?? 0) as num).toInt());
    final rate = double.tryParse(_rateCtrl.text) ?? 0;
    final data = {
      'type': _type,
      'itemName': _itemNameCtrl.text.trim(),
      'size': _sizeCtrl.text.trim(),
      'cutNo': _cutNoCtrl.text.trim(),
      'party': _partyCtrl.text.trim(),
      'process': _processCtrl.text.trim(),
      'rate': rate,
      'value': pcs * rate / 100,
      'date': _date.toIso8601String(),
      'colourRows': _colourRows,
    };
    final ok = await _api.createIronPackingDc(data);
    if (mounted) setState(() => _saving = false);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully'), backgroundColor: Color(0xFF10B981)));
      _load();
      _tabCtrl.animateTo(0);
    }
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

  Widget _dcTable(List<dynamic> list) {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(80), child: CircularProgressIndicator(strokeWidth: 2)));
    return ModernDataTable(
      columns: const ['DC NO', 'ITEM NAME', 'SIZE', 'DATE', 'VALUE (₹)'],
      showActions: false,
      rows: list.map((dc) {
        final date = dc['date'] != null
            ? DateFormat('dd MMM yyyy').format(DateTime.parse(dc['date']).toLocal())
            : '-';
        return {
          'DC NO': dc['packingDcNo']?.toString() ?? '-',
          'ITEM NAME': dc['itemName']?.toString() ?? '-',
          'SIZE': dc['size']?.toString() ?? '-',
          'DATE': date,
          'VALUE (₹)': '₹${(dc['value'] ?? 0).toStringAsFixed(0)}',
        };
      }).toList().cast<Map<String, dynamic>>(),
      emptyMessage: 'No records found',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPalette.background,
      appBar: AppBar(
        toolbarHeight: 60,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 18, color: Color(0xFF475569)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('IRON & PACKING DC', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: 16, letterSpacing: 0.5)),
        iconTheme: const IconThemeData(color: Color(0xFF475569)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(children: [
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabCtrl,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5),
                unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12),
                labelColor: const Color(0xFF475569),
                unselectedLabelColor: const Color(0xFF94A3B8),
                indicatorColor: const Color(0xFF475569),
                indicatorWeight: 2,
                tabs: const [Tab(text: 'OUTWARD'), Tab(text: 'INWARD GRN'), Tab(text: 'NEW DC')],
              ),
            ),
          ]),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Outward
          ResponsiveWrapper(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
            child: SingleChildScrollView(child: Column(children: [_dcTable(_outwards), const SizedBox(height: 40)])),
          ),
          // Inward GRN
          ResponsiveWrapper(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
            child: SingleChildScrollView(child: Column(children: [_dcTable(_inwards), const SizedBox(height: 40)])),
          ),
          // New DC form
          ResponsiveWrapper(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: ['outward', 'inward'].map((t) {
                          final selected = _type == t;
                          return InkWell(
                            onTap: () => setState(() => _type = t),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(4), boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))] : []),
                              child: Text(t == 'outward' ? 'PACKING DC (OUT)' : 'PACKING GRN (IN)',
                                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8), letterSpacing: 0.3)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DC DETAILS', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFF94A3B8), letterSpacing: 1)),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () async {
                              final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2030));
                              if (d != null) setState(() => _date = d);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(6)),
                              child: Row(children: [
                                const Icon(LucideIcons.calendar, size: 16, color: Color(0xFF475569)),
                                const SizedBox(width: 10),
                                Text('Date: ${DateFormat('dd MMM yyyy').format(_date)}', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A))),
                              ]),
                            ),
                          ),
                          _field('Item Name *', _itemNameCtrl, req: true),
                          Row(children: [
                            Expanded(child: _field('Size', _sizeCtrl)),
                            const SizedBox(width: 16),
                            Expanded(child: _field('Cut No', _cutNoCtrl)),
                          ]),
                          _field('Party', _partyCtrl),
                          Row(children: [
                            Expanded(child: _field('Process', _processCtrl)),
                            const SizedBox(width: 16),
                            Expanded(child: _field('Rate', _rateCtrl, type: TextInputType.number)),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text('COLOUR / PCS', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFF94A3B8), letterSpacing: 1)),
                            const Spacer(),
                            InkWell(
                              onTap: () => setState(() => _colourRows.add({'colour': '', 'totalPcs': 0})),
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
                          ]),
                          const SizedBox(height: 12),
                          ..._colourRows.asMap().entries.map((entry) {
                            final i = entry.key;
                            return Padding(
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
                                  initialValue: (_colourRows[i]['totalPcs'] ?? 0).toString(),
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.inter(fontSize: 12),
                                  decoration: InputDecoration(labelText: 'Pcs', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: const OutlineInputBorder(), labelStyle: GoogleFonts.inter(fontSize: 11)),
                                  onChanged: (v) => _colourRows[i]['totalPcs'] = int.tryParse(v) ?? 0,
                                )),
                                IconButton(icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFFEF4444)), onPressed: () => setState(() => _colourRows.removeAt(i))),
                              ]),
                            );
                          }),
                        ],
                      ),
                    ),
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
            ),
          ),
        ],
      ),
    );
  }
}
