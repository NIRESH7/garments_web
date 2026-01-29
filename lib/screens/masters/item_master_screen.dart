import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/lot.dart';
import '../../services/database_service.dart';

class ItemMasterScreen extends StatefulWidget {
  const ItemMasterScreen({super.key});

  @override
  State<ItemMasterScreen> createState() => _ItemMasterScreenState();
}

class _ItemMasterScreenState extends State<ItemMasterScreen> {
  final _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _gsmController = TextEditingController();
  String? _itemGroup, _size, _set;

  List<String> _itemGroups = [], _sizes = [], _sets = [];

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> res = await db.query('dropdowns');
    setState(() {
      _itemGroups = res
          .where((m) => m['category'] == 'item_group')
          .map((m) => m['value'] as String)
          .toList();
      _sizes = res
          .where((m) => m['category'] == 'size')
          .map((m) => m['value'] as String)
          .toList();
      _sets = res
          .where((m) => m['category'] == 'set')
          .map((m) => m['value'] as String)
          .toList();
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final db = await _db.database;
      final item = Item(
        id: const Uuid().v4(),
        itemName: _nameController.text,
        gsm: _gsmController.text,
        itemGroup: _itemGroup!,
        size: _size!,
        setVal: _set!,
      );
      await db.insert('items', item.toMap());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item saved')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item Master')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gsmController,
                decoration: const InputDecoration(
                  labelText: 'GSM (Manual Entry)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                'Item Group',
                _itemGroups,
                (v) => setState(() => _itemGroup = v),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      'Size',
                      _sizes,
                      (v) => setState(() => _size = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdown(
                      'Set',
                      _sets,
                      (v) => setState(() => _set = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              ElevatedButton(onPressed: _save, child: const Text('Save Item')),
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
      validator: (v) => v == null ? 'Required' : null,
    );
  }
}
