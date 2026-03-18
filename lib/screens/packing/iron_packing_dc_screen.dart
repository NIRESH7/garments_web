import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';

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
  List<Map<String, dynamic>> _accessories = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _itemNameCtrl.dispose();
    _sizeCtrl.dispose();
    _cutNoCtrl.dispose();
    _partyCtrl.dispose();
    _processCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _api.getIronPackingDcs();
    setState(() {
      _outwards = all.where((d) => d['type'] == 'outward').toList();
      _inwards = all.where((d) => d['type'] == 'inward').toList();
      _loading = false;
    });
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
      'accessories': _accessories,
    };
    final ok = await _api.createIronPackingDc(data);
    setState(() => _saving = false);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved!'), backgroundColor: Colors.green));
      _load();
      _tabCtrl.animateTo(0);
    }
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        validator: required ? (v) => (v?.isEmpty ?? true) ? 'Required' : null : null,
      ),
    );
  }

  Widget _dcCard(Map<String, dynamic> dc) {
    final date = dc['date'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(dc['date']).toLocal())
        : '-';
    final isOutward = dc['type'] == 'outward';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOutward ? Colors.orange.shade100 : Colors.green.shade100,
          child: Icon(
            isOutward ? Icons.local_shipping : Icons.receipt_long,
            color: isOutward ? Colors.orange : Colors.green,
          ),
        ),
        title: Text('DC: ${dc['packingDcNo'] ?? '-'}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${dc['itemName'] ?? '-'} — ${dc['size'] ?? '-'}\n$date'),
        isThreeLine: true,
        trailing: Text('₹${(dc['value'] ?? 0).toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Iron & Packing DC', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Outward'),
            Tab(text: 'Inward GRN'),
            Tab(text: 'New DC'),
          ],
          labelColor: Colors.orange.shade700,
          indicatorColor: Colors.orange,
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Outward list
          _loading ? const Center(child: CircularProgressIndicator())
              : _outwards.isEmpty
                  ? const Center(child: Text('No outward DCs found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _outwards.length,
                      itemBuilder: (_, i) => _dcCard(_outwards[i] as Map<String, dynamic>),
                    ),
          // Inward list
          _loading ? const Center(child: CircularProgressIndicator())
              : _inwards.isEmpty
                  ? const Center(child: Text('No inward GRNs found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _inwards.length,
                      itemBuilder: (_, i) => _dcCard(_inwards[i] as Map<String, dynamic>),
                    ),
          // New DC form
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Type selector
                Row(
                  children: ['outward', 'inward'].map((t) {
                    final selected = _type == t;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: InkWell(
                          onTap: () => setState(() => _type = t),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selected ? Colors.orange : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                t == 'outward' ? 'Packing DC (Out)' : 'Packing GRN (In)',
                                style: TextStyle(
                                  color: selected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context, initialDate: _date,
                              firstDate: DateTime(2020), lastDate: DateTime(2030));
                            if (d != null) setState(() => _date = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(children: [
                              const Icon(Icons.calendar_today, size: 18),
                              const SizedBox(width: 8),
                              Text('Date: ${DateFormat('dd MMM yyyy').format(_date)}'),
                            ]),
                          ),
                        ),
                        _buildField('Item Name *', _itemNameCtrl, required: true),
                        Row(children: [
                          Expanded(child: _buildField('Size', _sizeCtrl)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildField('Cut No', _cutNoCtrl)),
                        ]),
                        _buildField('Party', _partyCtrl),
                        Row(children: [
                          Expanded(child: _buildField('Process', _processCtrl)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildField('Rate', _rateCtrl, type: TextInputType.number)),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Colour rows
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Colour/Pcs', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: TextButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add', overflow: TextOverflow.ellipsis),
                                onPressed: () => setState(() => _colourRows.add({'colour': '', 'totalPcs': 0})),
                              ),
                            ),
                          ],
                        ),
                        ..._colourRows.asMap().entries.map((e) {
                          final i = e.key;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: _colourRows[i]['colour'] ?? '',
                                    decoration: const InputDecoration(labelText: 'Colour', isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder()),
                                    onChanged: (v) => _colourRows[i]['colour'] = v,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: (_colourRows[i]['totalPcs'] ?? 0).toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Pcs', isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder()),
                                    onChanged: (v) => _colourRows[i]['totalPcs'] = int.tryParse(v) ?? 0,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                  onPressed: () => setState(() => _colourRows.removeAt(i)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
