import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';

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
  List<Map<String, dynamic>> _cutDetails = [];
  List<Map<String, dynamic>> _accessories = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadList();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _cutNoCtrl.dispose();
    _itemNameCtrl.dispose();
    _sizeCtrl.dispose();
    _lotNoCtrl.dispose();
    _hsnCtrl.dispose();
    _diaCtrl.dispose();
    _vehicleNoCtrl.dispose();
    _rateCtrl.dispose();
    _processCtrl.dispose();
    _foldingReqCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadList() async {
    setState(() => _loading = true);
    final data = await _api.getStitchingDeliveries();
    setState(() {
      _list = data;
      _loading = false;
    });
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
      'cutDetails': _cutDetails,
      'accessories': _accessories,
      'totalValue': (_colourRows.fold<double>(0, (s, r) => s + ((r['foldingActualWt'] ?? 0) as num).toDouble())) *
          (double.tryParse(_rateCtrl.text) ?? 0),
    };
    final ok = await _api.createStitchingDelivery(data);
    setState(() => _saving = false);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('DC created!'), backgroundColor: Colors.green));
      _clearForm();
      _loadList();
      _tabCtrl.animateTo(0);
    }
  }

  void _clearForm() {
    _cutNoCtrl.clear();
    _itemNameCtrl.clear();
    _sizeCtrl.clear();
    _lotNoCtrl.clear();
    _hsnCtrl.clear();
    _diaCtrl.clear();
    _vehicleNoCtrl.clear();
    _rateCtrl.clear();
    _processCtrl.clear();
    _foldingReqCtrl.clear();
    _colourRows.clear();
    _cutDetails.clear();
    _accessories.clear();
    _dcDate = DateTime.now();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Stitching Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [Tab(text: 'DC List'), Tab(text: 'New DC')],
          labelColor: Colors.blue.shade700,
          indicatorColor: Colors.blue.shade700,
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // List tab
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _list.isEmpty
                  ? const Center(child: Text('No delivery notes found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _list.length,
                      itemBuilder: (context, i) {
                        final dc = _list[i];
                        final date = dc['dcDate'] != null
                            ? DateFormat('dd MMM yyyy').format(DateTime.parse(dc['dcDate']).toLocal())
                            : '-';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.local_shipping, color: Colors.teal.shade600, size: 22),
                            ),
                            title: Text('DC: ${dc['dcNo'] ?? '-'}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${dc['itemName'] ?? '-'} — ${dc['size'] ?? '-'}\n$date'),
                            isThreeLine: true,
                            trailing: Text('₹${dc['totalValue']?.toStringAsFixed(0) ?? '0'}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    ),
          // New DC form tab
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DC Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        // Date picker
                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _dcDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setState(() => _dcDate = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 18, color: Colors.teal),
                                const SizedBox(width: 8),
                                Text('DC Date: ${DateFormat('dd MMM yyyy').format(_dcDate)}'),
                              ],
                            ),
                          ),
                        ),
                        _buildField('Cut No *', _cutNoCtrl, required: true),
                        Row(children: [
                          Expanded(child: _buildField('Item Name *', _itemNameCtrl, required: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildField('Size', _sizeCtrl)),
                        ]),
                        Row(children: [
                          Expanded(child: _buildField('Lot No', _lotNoCtrl)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildField('Dia', _diaCtrl)),
                        ]),
                        _buildField('HSN Code', _hsnCtrl),
                        _buildField('Vehicle No', _vehicleNoCtrl),
                        Row(children: [
                          Expanded(child: _buildField('Process', _processCtrl)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildField('Rate/Kg (₹)', _rateCtrl, type: TextInputType.number)),
                        ]),
                        _buildField('Folding Req/Dozen', _foldingReqCtrl, type: TextInputType.number),
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
                            const Text('Colour Details', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: TextButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add', overflow: TextOverflow.ellipsis),
                                onPressed: () => setState(() => _colourRows.add({
                                  'colour': '', 'pcs': 0, 'foldingReqWt': 0,
                                  'foldingActualWt': 0, 'elasticReqMtr': 0,
                                })),
                              ),
                            ),
                          ],
                        ),
                        ...List.generate(_colourRows.length, (i) {
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
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: (_colourRows[i]['pcs'] ?? 0).toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Pcs', isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder()),
                                    onChanged: (v) => _colourRows[i]['pcs'] = int.tryParse(v) ?? 0,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: (_colourRows[i]['foldingActualWt'] ?? 0).toString(),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'Fold Act Wt', isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder()),
                                    onChanged: (v) => _colourRows[i]['foldingActualWt'] = double.tryParse(v) ?? 0,
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
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save DC', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
