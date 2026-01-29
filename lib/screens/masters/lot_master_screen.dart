import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/lot.dart';
import '../../services/database_service.dart';

class LotMasterScreen extends StatefulWidget {
  const LotMasterScreen({super.key});

  @override
  State<LotMasterScreen> createState() => _LotMasterScreenState();
}

class _LotMasterScreenState extends State<LotMasterScreen> {
  final _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  final _lotNumberController = TextEditingController();
  final _remarksController = TextEditingController();
  String? _partyName, _process;

  List<String> _parties = [], _processes = [];

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> res = await db.query('dropdowns');

    setState(() {
      _parties = res
          .where((m) => m['category'] == 'party_name')
          .map((m) => m['value'] as String)
          .toList();
      _processes = res
          .where((m) => m['category'] == 'process')
          .map((m) => m['value'] as String)
          .toList();
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final db = await _db.database;
      final lot = Lot(
        id: const Uuid().v4(),
        lotNumber: _lotNumberController.text,
        partyName: _partyName!,
        process: _process!,
        remarks: _remarksController.text,
      );
      await db.insert('lots', lot.toMap());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lot created successfully')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lot Master')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _lotNumberController,
                decoration: const InputDecoration(
                  labelText: 'Lot Number / Name',
                ),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                'Party Name',
                _parties,
                (val) => setState(() => _partyName = val),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                'Process Type',
                _processes,
                (val) => setState(() => _process = val),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks (Optional)',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 40),
              ElevatedButton(onPressed: _save, child: const Text('Create Lot')),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.1)),
                ),
                child: const Text(
                  'Note: Dia and Colour are captured during inward transactions, not at lot creation.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? 'Required' : null,
      hint: Text('Select $label'),
    );
  }
}
