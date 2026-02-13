import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';

import '../../widgets/custom_dropdown_field.dart';

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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    final parties = await _api.getParties();
    final categories = await _api.getCategories();

    final List<String> extractedProcesses = [];
    final processMatches = categories.where((c) {
      final String catName = (c['name'] ?? '').toString().trim().toLowerCase();
      return catName == 'process';
    });

    for (var cat in processMatches) {
      final dynamic rawValues = cat['values'];
      if (rawValues is List) {
        for (var v in rawValues) {
          if (v is Map) {
            extractedProcesses.add((v['name'] ?? '').toString());
          } else if (v != null) {
            extractedProcesses.add(v.toString());
          }
        }
      }
    }

    setState(() {
      _parties = parties.map((m) => m['name'] as String).toList();
      _processes = extractedProcesses
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      _formKey.currentState!.save();
      final lotData = {
        'lotNumber': _lotNumberController.text,
        'partyName': _partyName!,
        'process': _process!,
        'remarks': _remarksController.text,
      };

      try {
        final success = await _api.createLot(lotData);
        if (success) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lot created successfully in Backend'),
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Failed to create lot')));
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _isSaving = false);
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
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create Lot'),
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
    return CustomDropdownField(
      label: label,
      items: items,
      value: value,
      onChanged: onChanged,
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      hint: 'Select $label',
    );
  }
}
