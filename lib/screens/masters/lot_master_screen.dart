import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';

class LotMasterScreen extends StatefulWidget {
  const LotMasterScreen({super.key});

  @override
  State<LotMasterScreen> createState() => _LotMasterScreenState();
}

class _LotMasterScreenState extends State<LotMasterScreen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();

  final _lotNumberController = TextEditingController();
  final _remarksController = TextEditingController();
  String? _partyName, _process;

  List<String> _parties = [], _processes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    final parties = await _api.getParties();
    final categories = await _api.getCategories();
    final processCategory = categories.firstWhere(
      (c) => c['name'] == 'Process',
      orElse: () => {'values': []},
    );

    setState(() {
      _parties = parties.map((m) => m['name'] as String).toList();
      _processes = List<String>.from(processCategory['values'] ?? []);
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final lotData = {
        'lotNumber': _lotNumberController.text,
        'partyName': _partyName!,
        'process': _process!,
        'remarks': _remarksController.text,
      };

      final success = await _api.createLot(lotData);
      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lot created successfully in Backend')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to create lot')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lot Master')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                      _partyName,
                      (val) => setState(() => _partyName = val),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      'Process Type',
                      _processes,
                      _process,
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
                    ElevatedButton(
                      onPressed: _save,
                      child: const Text('Create Lot'),
                    ),
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
    String? value,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
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
