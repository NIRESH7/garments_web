import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/color_palette.dart';
import '../../services/database_service.dart';
import '../../services/api_service.dart';

class LotOutwardScreen extends StatefulWidget {
  const LotOutwardScreen({super.key});

  @override
  State<LotOutwardScreen> createState() => _LotOutwardScreenState();
}

class _LotOutwardScreenState extends State<LotOutwardScreen> {
  final _db = DatabaseService();
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  // --- Header Data ---
  DateTime _outwardDateTime = DateTime.now();
  String _dcNumber = 'Loading...';
  String? _selectedLotName;
  String? _selectedDia;
  String? _selectedLotNo;
  String? _selectedParty;
  
  String? _process;
  String? _address;
  
  final _vehicleController = TextEditingController();
  String _inTime = DateFormat('hh:mm a').format(DateTime.now());
  String? _outTime;

  List<String> _lotNames = [];
  List<String> _dias = [];
  List<String> _lotNos = [];
  List<String> _parties = [];
  
  List<Map<String, dynamic>> _availableSets = [];
  List<Map<String, dynamic>> _selectedSets = [];

  bool _isLoading = true;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final master = await _api.getMasterData();
    final dc = await _api.generateDcNumber();
    
    setState(() {
      _lotNames = master['lots'] ?? [];
      _dias = master['dias'] ?? [];
      _parties = master['parties'] ?? [];
      _dcNumber = dc ?? 'ERR-GEN';
      _isLoading = false;
    });
  }

  Future<void> _onDiaChanged(String? val) async {
    setState(() {
      _selectedDia = val;
      _selectedLotNo = null;
      _lotNos = [];
      _availableSets = [];
      _selectedSets = [];
    });
    if (val != null) {
      final lots = await _api.getLotsFifo(dia: val);
      setState(() => _lotNos = lots);
    }
  }

  Future<void> _onLotNoChanged(String? val) async {
    setState(() {
      _selectedLotNo = val;
      _availableSets = [];
      _selectedSets = [];
    });
    if (val != null && _selectedDia != null) {
      final sets = await _api.getBalancedSets(val, _selectedDia!);
      setState(() => _availableSets = sets);
    }
  }

  Future<void> _onPartyChanged(String? val) async {
    setState(() {
      _selectedParty = val;
      _process = null;
      _address = null;
    });
    if (val != null) {
      final details = await _api.getPartyDetails(val);
      if (details != null) {
        setState(() {
          _process = details['process'];
          _address = details['address'];
        });
      }
    }
  }

  void _toggleSetSelection(Map<String, dynamic> set, bool selected) {
    setState(() {
      if (selected) {
        _selectedSets.add(Map.from(set));
      } else {
        _selectedSets.removeWhere((s) => s['set_no'] == set['set_no'] && s['colour'] == set['colour']);
      }
    });
  }

  void _removeSet(int index) {
    setState(() {
      _selectedSets.removeAt(index);
    });
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _outwardDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_outwardDateTime),
      );
      if (time != null) {
        setState(() {
          _outwardDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || 
        _selectedLotName == null || 
        _selectedDia == null || 
        _selectedLotNo == null || 
        _selectedParty == null ||
        _selectedSets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all fields and select at least one set')));
      return;
    }

    setState(() {
      _outTime = DateFormat('hh:mm a').format(DateTime.now());
    });

    final outwardData = {
      'dc_number': _dcNumber,
      'outward_date_time': _outwardDateTime.toIso8601String(),
      'lot_name': _selectedLotName,
      'lot_number': _selectedLotNo,
      'dia': _selectedDia,
      'party_name': _selectedParty,
      'process': _process,
      'address': _address,
      'vehicle_no': _vehicleController.text,
      'in_time': _inTime,
      'out_time': _outTime,
      'items': _selectedSets.map((s) => {
        'colour': s['colour'],
        'selected_weight': s['weight'],
        'set_no': s['set_no']
      }).toList(),
    };

    final success = await _api.saveOutward(outwardData);
    if (success) {
      setState(() => _isSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Outward Registered: $_dcNumber')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save to backend')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('OUTWARD', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.printer),
            onPressed: _isSaved ? () {} : null,
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDCSection(),
              const SizedBox(height: 16),
              _buildMainForm(),
              const SizedBox(height: 24),
              _buildSetSelectionSection(),
              const SizedBox(height: 24),
              _buildSelectedSetsGrid(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaved ? null : _save,
                  icon: const Icon(LucideIcons.checkCircle),
                  label: Text(_isSaved ? 'Dispatch Confirmed' : 'Save Outward'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSaved ? Colors.grey : ColorPalette.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDCSection() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: ColorPalette.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          'DC NO: $_dcNumber',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: ColorPalette.primary),
        ),
      ),
    );
  }

  Widget _buildMainForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildDropdown('LOT NAME', _lotNames, _selectedLotName, (v) => setState(() => _selectedLotName = v))),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _isSaved ? null : _selectDateTime,
                    child: _buildReadOnlyField(
                      'DATE & TIME', 
                      DateFormat('dd-MM-yyyy hh:mm a').format(_outwardDateTime),
                      icon: LucideIcons.calendar,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildDropdown('DIA', _dias, _selectedDia, _onDiaChanged)),
                const SizedBox(width: 12),
                Expanded(child: _buildDropdown('LOT NO (FIFO)', _lotNos, _selectedLotNo, _onLotNoChanged)),
              ],
            ),
            const SizedBox(height: 16),
            _buildDropdown('PARTY NAME', _parties, _selectedParty, _onPartyChanged),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildReadOnlyField('PROCESS', _process ?? '-')),
                const SizedBox(width: 12),
                Expanded(child: _buildReadOnlyField('ADDRESS', _address ?? '-', maxLines: 1)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _vehicleController,
                  decoration: const InputDecoration(labelText: 'VEHICLE NO', border: OutlineInputBorder(), prefixIcon: Icon(LucideIcons.truck, size: 20)),
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildReadOnlyField('IN TIME', _inTime)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetSelectionSection() {
    if (_availableSets.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SELECT SET NO (BALANCE ONLY)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _availableSets.map((s) {
            final isSelected = _selectedSets.any((sel) => sel['set_no'] == s['set_no'] && sel['colour'] == s['colour']);
            return FilterChip(
              label: Text('${s['set_no']} (${s['colour']})'),
              selected: isSelected,
              onSelected: (selected) => _toggleSetSelection(s, selected),
              selectedColor: ColorPalette.primary.withOpacity(0.2),
              checkmarkColor: ColorPalette.primary,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSelectedSetsGrid() {
    if (_selectedSets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SELECTED SET DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedSets.length,
          itemBuilder: (context, index) {
            final item = _selectedSets[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${item['set_no']} - ${item['colour']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Bal: ${item['weight']} kg'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        initialValue: item['weight'].toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(suffixText: 'kg', isDense: true),
                        onChanged: (v) => item['weight'] = double.tryParse(v) ?? 0,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
                      onPressed: () => _removeSet(index),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: _isSaved ? null : onChanged,
      isExpanded: true,
    );
  }

  Widget _buildReadOnlyField(String label, String value, {IconData? icon, int maxLines = 1}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label, 
        border: const OutlineInputBorder(), 
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      ),
      child: Text(
        value, 
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), 
        overflow: TextOverflow.ellipsis,
        maxLines: maxLines,
      ),
    );
  }
}
