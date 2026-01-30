import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/database_service.dart';

class PartyMasterScreen extends StatefulWidget {
  const PartyMasterScreen({super.key});

  @override
  State<PartyMasterScreen> createState() => _PartyMasterScreenState();
}

class _PartyMasterScreenState extends State<PartyMasterScreen> {
  final _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _mobileController = TextEditingController();
  final _gstController = TextEditingController();
  final _rateController = TextEditingController();
  
  String? _selectedProcess;
  List<String> _processes = [];

  @override
  void initState() {
    super.initState();
    _loadProcesses();
  }

  Future<void> _loadProcesses() async {
    final db = await _db.database;
    final res = await db.query(
      'dropdowns',
      where: 'category = ?',
      // Ensure "Process" is the exact category name used in Categories Master.
      // Assuming user creates "Process" there or uses the seeded one.
      whereArgs: ['Process'], 
      orderBy: 'value ASC',
    );
    setState(() {
      _processes = res.map((e) => e['value'] as String).toList();
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final db = await _db.database;
      
      // Check for duplicate party name
      final exists = await db.query(
        'parties',
        where: 'name = ?',
        whereArgs: [_nameController.text],
      );
      
      if (exists.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Party name already exists')),
        );
        return;
      }

      await db.insert('parties', {
        'id': const Uuid().v4(),
        'name': _nameController.text,
        'address': _addressController.text,
        'mobile': _mobileController.text,
        'gst': _gstController.text,
        'rate': _rateController.text,
        'process': _selectedProcess,
      });
      
      _nameController.clear();
      _addressController.clear();
      _mobileController.clear();
      _gstController.clear();
      _rateController.clear();
      
      setState(() {
        _selectedProcess = null;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Party saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Party Master')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Party Name'),
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
                decoration: const InputDecoration(labelText: 'Mobile Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedProcess,
                decoration: const InputDecoration(labelText: 'Process'),
                items: _processes
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedProcess = val),
                 validator: (v) => v == null ? 'Required' : null,
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
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save, 
                  child: const Text('Save Party')
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
