import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/database_service.dart';
import '../../core/theme/color_palette.dart';

class SimpleMasterScreen extends StatefulWidget {
  final String title;
  final String category;

  const SimpleMasterScreen({
    super.key,
    required this.title,
    required this.category,
  });

  @override
  State<SimpleMasterScreen> createState() => _SimpleMasterScreenState();
}

class _SimpleMasterScreenState extends State<SimpleMasterScreen> {
  final _db = DatabaseService();
  final _valueController = TextEditingController();
  List<Map<String, dynamic>> _values = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  Future<void> _loadValues() async {
    setState(() => _isLoading = true);
    final db = await _db.database;
    final res = await db.query(
      'dropdowns',
      where: 'category = ?',
      whereArgs: [widget.category],
      orderBy: 'value ASC',
    );
    setState(() {
      _values = res;
      _isLoading = false;
    });
  }

  Future<void> _add() async {
    if (_valueController.text.isEmpty) return;
    try {
      final db = await _db.database;
      await db.insert('dropdowns', {
        'id': const Uuid().v4(),
        'category': widget.category,
        'value': _valueController.text,
      });
      _valueController.clear();
      await _loadValues(); // Refresh list explicitely
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added successfully')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      appBar: AppBar(title: Text(widget.title)),
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
                  TextField(
                    controller: _valueController,
                    decoration: InputDecoration(
                      labelText: 'New ${widget.title} Value',
                      hintText: 'Enter value here',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _add,
                      child: const Text('Add Value'),
                    ),
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
                    ? const Center(
                        child: Text('No values found. Add one above!'),
                      )
                    : ListView.builder(
                        itemCount: _values.length,
                        itemBuilder: (context, index) {
                          final item = _values[index];
                          return ListTile(
                            title: Text(item['value'] as String),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _delete(item['id'] as String),
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
