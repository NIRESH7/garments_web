import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/database_service.dart';
import '../../core/theme/color_palette.dart';

class DropdownSetupScreen extends StatefulWidget {
  const DropdownSetupScreen({super.key});

  @override
  State<DropdownSetupScreen> createState() => _DropdownSetupScreenState();
}

class _DropdownSetupScreenState extends State<DropdownSetupScreen> {
  final _db = DatabaseService();
  final _valueController = TextEditingController();
  
  String? _selectedCategory;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _values = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final db = await _db.database;
    final res = await db.query('categories', orderBy: 'name ASC');
    setState(() {
      _categories = res;
      // If categories exist but none selected, select first
      if (_categories.isNotEmpty && _selectedCategory == null) {
        _selectedCategory = _categories.first['name'] as String;
        _loadValues();
      }
    });
  }

  Future<void> _loadValues() async {
    if (_selectedCategory == null) return;
    setState(() => _isLoading = true);
    final db = await _db.database;
    final res = await db.query(
      'dropdowns',
      where: 'category = ?',
      whereArgs: [_selectedCategory],
      orderBy: 'value ASC',
    );
    setState(() {
      _values = res;
      _isLoading = false;
    });
  }

  Future<void> _add() async {
    if (_valueController.text.isEmpty || _selectedCategory == null) return;
    try {
      final db = await _db.database;
      await db.insert('dropdowns', {
        'id': const Uuid().v4(),
        'category': _selectedCategory,
        'value': _valueController.text,
      });
      _valueController.clear();
      await _loadValues();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added successfully')),
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _delete(String id) async {
    final db = await _db.database;
    await db.delete('dropdowns', where: 'id = ?', whereArgs: [id]);
    await _loadValues();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dropdown Setup')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: ColorPalette.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Select Category',
                      hintText: 'Choose a category to manage',
                    ),
                    items: _categories.map((c) {
                      return DropdownMenuItem<String>(
                        value: c['name'] as String,
                        child: Text(c['name'] as String),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategory = val;
                      });
                      _loadValues();
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _valueController,
                    decoration: const InputDecoration(
                      labelText: 'New Value',
                      hintText: 'Enter value to add',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _selectedCategory == null ? null : _add,
                    child: const Text('Add Value'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _values.isEmpty
                    ? Center(
                        child: Text(
                          _selectedCategory == null
                              ? 'Select a category first'
                              : 'No values found for $_selectedCategory',
                        ),
                      )
                    : ListView.builder(
                        itemCount: _values.length,
                        itemBuilder: (context, index) {
                          final item = _values[index];
                          return ListTile(
                            title: Text(item['value'] as String),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _delete(item['id']),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
