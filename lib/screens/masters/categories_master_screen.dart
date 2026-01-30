import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/database_service.dart';
import '../../core/theme/color_palette.dart';

class CategoriesMasterScreen extends StatefulWidget {
  const CategoriesMasterScreen({super.key});

  @override
  State<CategoriesMasterScreen> createState() => _CategoriesMasterScreenState();
}

class _CategoriesMasterScreenState extends State<CategoriesMasterScreen> {
  final _db = DatabaseService();
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _list = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final db = await _db.database;
    final res = await db.query('categories', orderBy: 'name ASC');
    setState(() {
      _list = res;
      _isLoading = false;
    });
  }

  Future<void> _add() async {
    if (_controller.text.isEmpty) return;
    try {
      final db = await _db.database;
      // Check duplicate
      final exists = await db.query(
        'categories', 
        where: 'name = ?',
        whereArgs: [_controller.text],
      );
      if (exists.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category already exists')),
        );
        return;
      }

      await db.insert('categories', {
        'id': const Uuid().v4(),
        'name': _controller.text,
      });
      _controller.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category Created')),
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _delete(String id) async {
    final db = await _db.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories Master')),
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
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'New Category Name',
                      hintText: 'e.g. Brand, Season, etc.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _add,
                      child: const Text('Create Category'),
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
                : _list.isEmpty
                    ? const Center(child: Text('No categories found.'))
                    : ListView.builder(
                        itemCount: _list.length,
                        itemBuilder: (context, index) {
                          final item = _list[index];
                          return ListTile(
                            leading: const Icon(Icons.category, color: Colors.blue),
                            title: Text(item['name']),
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
