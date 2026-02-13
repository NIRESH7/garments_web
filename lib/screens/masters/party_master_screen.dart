import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/custom_dropdown_field.dart';
import 'party_history_screen.dart';

class PartyMasterScreen extends StatefulWidget {
  final Map<dynamic, dynamic>? editParty;
  const PartyMasterScreen({super.key, this.editParty});

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
    if (widget.editParty != null) {
      _nameController.text = widget.editParty!['name'] ?? '';
      _addressController.text = widget.editParty!['address'] ?? '';
      _mobileController.text = widget.editParty!['mobileNumber'] ?? '';
      _selectedProcess = widget.editParty!['process'];
      _gstController.text = widget.editParty!['gstIn'] ?? '';
      _rateController.text = (widget.editParty!['rate'] ?? '').toString();
    }
  }

  Future<void> _loadMasterData() async {
    final categories = await _api.getCategories();
    final processCategory = categories.firstWhere(
      (c) => c['name'] == 'Process',
      orElse: () => {'values': []},
    );

    setState(() {
      _processes = (processCategory['values'] as List).map<String>((v) {
        if (v is Map) return v['name'].toString();
        return v.toString();
      }).toList();
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
        bool success;
        if (widget.editParty != null) {
          success = await _api.updateParty(widget.editParty!['_id'], partyData);
        } else {
          success = await _api.createParty(partyData);
        }

        if (!mounted) return;

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.editParty != null ? 'Party updated' : 'Party saved',
              ),
            ),
          );
          if (widget.editParty != null) {
            Navigator.pop(context, true);
          } else {
            _nameController.clear();
            _addressController.clear();
            _mobileController.clear();
            _gstController.clear();
            _rateController.clear();
            setState(() => _selectedProcess = null);
          }
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
      appBar: AppBar(
        title: Text(widget.editParty != null ? 'Edit Party' : 'Party Master'),
        actions: [
          if (widget.editParty == null)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PartyHistoryScreen(),
                ),
              ),
            ),
        ],
      ),
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
                    CustomDropdownField(
                      label: 'Process',
                      value: _selectedProcess,
                      items: _processes,
                      onChanged: (val) =>
                          setState(() => _selectedProcess = val),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                      hint: 'Select Process',
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
                        child: Text(
                          widget.editParty != null
                              ? 'Update Party'
                              : 'Save Party',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
