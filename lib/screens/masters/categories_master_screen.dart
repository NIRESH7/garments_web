import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';

class CategoriesMasterScreen extends StatefulWidget {
  const CategoriesMasterScreen({super.key});

  @override
  State<CategoriesMasterScreen> createState() => _CategoriesMasterScreenState();
}

class _CategoriesMasterScreenState extends State<CategoriesMasterScreen> {
  final _api = MobileApiService();
  final _controller = TextEditingController();
  List<dynamic> _list = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final res = await _api.getCategories();
    setState(() {
      _list = res;
      _isLoading = false;
    });
  }

  Future<void> _add() async {
    if (_controller.text.isEmpty) return;
    try {
      final success = await _api.createCategory(_controller.text);
      if (success) {
        _controller.clear();
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Category Created')));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create category')),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _delete(String id) async {
    final success = await _api.deleteCategory(id);
    if (success) {
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete category')),
      );
    }
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
                          onPressed: () => _delete(item['_id']),
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
