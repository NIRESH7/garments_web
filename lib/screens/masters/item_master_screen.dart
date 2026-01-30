import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/database_service.dart';

class ItemMasterScreen extends StatefulWidget {
  const ItemMasterScreen({super.key});

  @override
  State<ItemMasterScreen> createState() => _ItemMasterScreenState();
}

class _ItemMasterScreenState extends State<ItemMasterScreen> {
  final _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  String? _selectedLotName;
  String? _selectedItemName;
  String? _selectedGsm;
  String? _selectedColour;

  List<String> _lotNames = [];
  List<String> _itemNames = [];
  List<String> _gsmValues = [];
  List<String> _colours = [];

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    final db = await _db.database;
    
    // Load Lot Names
    final lots = await db.query(
      'dropdowns',
      where: 'category = ?',
      whereArgs: ['Lot Name'],
      orderBy: 'value ASC',
    );
    
    // Load Item Names
    final items = await db.query(
      'dropdowns',
      where: 'category = ?',
      whereArgs: ['Item Name'],
      orderBy: 'value ASC',
    );

    // Load GSMs
    final gsms = await db.query(
      'dropdowns',
      where: 'category = ?',
      whereArgs: ['GSM'],
      orderBy: 'value ASC',
    );

    // Load Colours
    final colours = await db.query(
      'dropdowns',
      where: 'category = ?',
      whereArgs: ['Colour'],
      orderBy: 'value ASC',
    );

    setState(() {
      _lotNames = lots.map((m) => m['value'] as String).toList();
      _itemNames = items.map((m) => m['value'] as String).toList();
      _gsmValues = gsms.map((m) => m['value'] as String).toList();
      _colours = colours.map((m) => m['value'] as String).toList();
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final db = await _db.database;
      
      await db.insert('items', {
        'id': const Uuid().v4(),
        'lot_name': _selectedLotName,
        'item_name': _selectedItemName,
        'gsm': _selectedGsm,
        'colour': _selectedColour,
        'item_group': '', 
        'size': '',
        'set_val': '',
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item saved')));
      
      setState(() {
        _selectedLotName = null;
        _selectedItemName = null;
        _selectedGsm = null;
        _selectedColour = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item Group Master')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
               DropdownButtonFormField<String>(
                value: _selectedLotName,
                decoration: const InputDecoration(labelText: 'Group Name'),
                items: _lotNames
                    .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedLotName = val),
                 validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedItemName,
                decoration: const InputDecoration(labelText: 'Item Name'),
                items: _itemNames
                    .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedItemName = val),
                 validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
               DropdownButtonFormField<String>(
                value: _selectedGsm,
                decoration: const InputDecoration(labelText: 'GSM'),
                items: _gsmValues
                    .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedGsm = val),
                 validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
               DropdownButtonFormField<String>(
                value: _selectedColour,
                decoration: const InputDecoration(labelText: 'Colour'),
                items: _colours
                    .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedColour = val),
                 validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save, 
                  child: const Text('Save Item')
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
