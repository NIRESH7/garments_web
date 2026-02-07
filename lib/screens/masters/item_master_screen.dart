import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/database_service.dart';
import '../../services/api_service.dart'; // Import ApiService

class ItemMasterScreen extends StatefulWidget {
  const ItemMasterScreen({super.key});

  @override
  State<ItemMasterScreen> createState() => _ItemMasterScreenState();
}

class _ItemMasterScreenState extends State<ItemMasterScreen> {
  final _db = DatabaseService();
  final _api = ApiService(); // Initialize ApiService
  final _formKey = GlobalKey<FormState>();

  String? _selectedGroupName; // Was Lot Name
  final List<String> _selectedItemNames = [];
  String? _selectedGsm;
  final List<String> _selectedColours = [];

  List<String> _groupNames = [];
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
    
    // Load Group Names (formerly Lot Name)
    final groups = await db.query(
      'dropdowns',
      where: 'category = ?',
      whereArgs: ['Lot Name'], // Keeping category query 'Lot Name' if table data hasn't changed
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
      _groupNames = groups.map((m) => m['value'] as String).toList();
      _itemNames = items.map((m) => m['value'] as String).toList();
      _gsmValues = gsms.map((m) => m['value'] as String).toList();
      _colours = colours.map((m) => m['value'] as String).toList();
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      if (_selectedItemNames.isEmpty) {
        _showError('Please select at least one Item Name');
        return;
      }
      if (_selectedColours.isEmpty) {
        _showError('Please select at least one Colour');
        return;
      }

      final db = await _db.database;
      final batch = db.batch();
      
      List<Map<String, dynamic>> itemsToSave = [];

      // Cartesian product: Group -> Item -> Colour
      for (var item in _selectedItemNames) {
        for (var color in _selectedColours) {
           var itemData = {
            'id': const Uuid().v4(),
            'lot_name': _selectedGroupName, 
            'item_name': item,
            'gsm': _selectedGsm,
            'colour': color,
            'item_group': '', 
            'size': '',
            'set_val': '',
          };
          
          batch.insert('items', itemData);
          itemsToSave.add(itemData);
        }
      }

      await batch.commit(noResult: true);
      
      // Save to Backend
      bool apiSuccess = await _api.saveItems(itemsToSave);
      
      if (!mounted) return;
      
      String msg = 'Saved ${_selectedItemNames.length * _selectedColours.length} item combinations.';
      if (apiSuccess) {
        msg += ' (Synced to Backend)';
      } else {
        msg += ' (Local Only - Backend Failed)';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      
      setState(() {
        _selectedGroupName = null;
        _selectedItemNames.clear();
        _selectedGsm = null;
        _selectedColours.clear();
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               DropdownButtonFormField<String>(
                value: _selectedGroupName,
                decoration: const InputDecoration(labelText: 'Group Name'), // Renamed from Lot Name
                items: _groupNames
                    .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedGroupName = val),
                 validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Item Names Multi Select
              _buildMultiSelectField(
                label: 'Item Names',
                items: _itemNames,
                selectedItems: _selectedItemNames,
                onSelectionChanged: (list) => setState(() {
                  _selectedItemNames.clear();
                  _selectedItemNames.addAll(list);
                }),
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

              // Colours Multi Select
              _buildMultiSelectField(
                label: 'Colours',
                items: _colours,
                selectedItems: _selectedColours,
                onSelectionChanged: (list) => setState(() {
                  _selectedColours.clear();
                  _selectedColours.addAll(list);
                }),
              ),
              
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save, 
                  child: const Text('Save Group')
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectField({
    required String label,
    required List<String> items,
    required List<String> selectedItems,
    required ValueChanged<List<String>> onSelectionChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _showMultiSelectDialog(label, items, selectedItems, onSelectionChanged),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: selectedItems.isEmpty
                ? const Text('Select...', style: TextStyle(color: Colors.grey))
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: selectedItems.map((e) => Chip(
                      label: Text(e),
                      onDeleted: () {
                        final newList = List<String>.from(selectedItems)..remove(e);
                        onSelectionChanged(newList);
                      },
                    )).toList(),
                  ),
          ),
        ),
      ],
    );
  }

  void _showMultiSelectDialog(
    String label,
    List<String> items,
    List<String> selectedItems,
    ValueChanged<List<String>> onSelectionChanged,
  ) {
    final tempSelected = List<String>.from(selectedItems);
    String searchQuery = '';
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredItems = items
                .where((item) => item.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();
            
            return AlertDialog(
              title: Text('Select $label'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) => setState(() => searchQuery = val), // Use internal SetState
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final isSelected = tempSelected.contains(item);
                          return CheckboxListTile(
                            title: Text(item),
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  tempSelected.add(item);
                                } else {
                                  tempSelected.remove(item);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    onSelectionChanged(tempSelected);
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
