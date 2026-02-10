import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';

class PartyMasterScreen extends StatefulWidget {
  const PartyMasterScreen({super.key});

  @override
  State<PartyMasterScreen> createState() => _PartyMasterScreenState();
}

class _PartyMasterScreenState extends State<PartyMasterScreen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _mobileController = TextEditingController();
  final _gstController = TextEditingController();
  final _rateController = TextEditingController();

  String? _selectedProcess;
  List<String> _processes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    final categories = await _api.getCategories();
    final processCategory = categories.firstWhere(
      (c) => c['name'] == 'Process',
      orElse: () => {'values': []},
    );

    setState(() {
      _processes = List<String>.from(processCategory['values'] ?? []);
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final partyData = {
        'name': _nameController.text,
        'address': _addressController.text,
        'mobileNumber': _mobileController.text,
        'gstIn': _gstController.text,
        'rate': double.tryParse(_rateController.text) ?? 0.0,
        'process': _selectedProcess ?? '',
      };

      try {
        final success = await _api.createParty(partyData);

        if (!mounted) return;

        if (success) {
          _nameController.clear();
          _addressController.clear();
          _mobileController.clear();
          _gstController.clear();
          _rateController.clear();
          setState(() => _selectedProcess = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Party saved to Backend')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Party Master')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Party Name',
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mobileController,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedProcess,
                      decoration: const InputDecoration(labelText: 'Process'),
                      items: _processes
                          .map(
                            (p) => DropdownMenuItem(value: p, child: Text(p)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedProcess = val),
                      validator: (v) => v == null ? 'Required' : null,
                      hint: const Text('Select Process'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _gstController,
                      decoration: const InputDecoration(labelText: 'GST IN'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _rateController,
                      decoration: const InputDecoration(labelText: 'Rate'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save Party'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
