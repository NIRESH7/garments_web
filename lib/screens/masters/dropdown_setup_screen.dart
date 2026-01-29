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

  String _selectedCategory = 'dia';
  final List<String> _categories = [
    'dia',
    'colour',
    'size',
    'set',
    'process',
    'efficiency',
    'item_group',
    'party_name',
  ];

  Future<void> _add() async {
    if (_valueController.text.isEmpty) return;
    final db = await _db.database;
    await db.insert('dropdowns', {
      'id': const Uuid().v4(),
      'category': _selectedCategory,
      'value': _valueController.text,
    });
    _valueController.clear();
    setState(() {}); // Refresh list
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Added successfully')));
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
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCategory = val!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _valueController,
                    decoration: const InputDecoration(labelText: 'New Value'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _add,
                    child: const Text('Add Value'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _db.database.then(
                (db) => db.query(
                  'dropdowns',
                  where: 'category = ?',
                  whereArgs: [_selectedCategory],
                ),
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final items = snapshot.data!;
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(items[index]['value']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final db = await _db.database;
                        await db.delete(
                          'dropdowns',
                          where: 'id = ?',
                          whereArgs: [items[index]['id']],
                        );
                        setState(() {});
                      },
                    ),
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
