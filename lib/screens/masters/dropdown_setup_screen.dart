import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';

class DropdownSetupScreen extends StatefulWidget {
  const DropdownSetupScreen({super.key});

  @override
  State<DropdownSetupScreen> createState() => _DropdownSetupScreenState();
}

class _DropdownSetupScreenState extends State<DropdownSetupScreen> {
  final _api = MobileApiService();
  final _valueController = TextEditingController();

  String? _selectedCategoryId;
  List<dynamic> _categories = [];
  List<dynamic> _values = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final res = await _api.getCategories();
    setState(() {
      _categories = res;
      if (_categories.isNotEmpty && _selectedCategoryId == null) {
        _selectedCategoryId = _categories.first['_id'];
        _loadValues();
      }
    });
  }

  Future<void> _loadValues() async {
    if (_selectedCategoryId == null) return;
    setState(() => _isLoading = true);
    final category = _categories.firstWhere(
      (c) => c['_id'] == _selectedCategoryId,
    );
    setState(() {
      _values = category['values'] ?? [];
      _isLoading = false;
    });
  }

  Future<void> _add() async {
    if (_valueController.text.isEmpty || _selectedCategoryId == null) return;
    try {
      final success = await _api.addCategoryValue(
        _selectedCategoryId!,
        _valueController.text,
      );
      if (success) {
        _valueController.clear();
        await _loadCategories(); // Reload all to get updated values
        await _loadValues();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Added successfully')));
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _delete(String value) async {
    if (_selectedCategoryId == null) return;
    final success = await _api.deleteCategoryValue(_selectedCategoryId!, value);
    if (success) {
      await _loadCategories();
      await _loadValues();
    }
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
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Select Category',
                      hintText: 'Choose a category to manage',
                    ),
                    items: _categories.map((c) {
                      return DropdownMenuItem<String>(
                        value: c['_id'] as String,
                        child: Text(c['name'] as String),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategoryId = val;
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
                    onPressed: _selectedCategoryId == null ? null : _add,
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
                      _selectedCategoryId == null
                          ? 'Select a category first'
                          : 'No values found',
                    ),
                  )
                : ListView.builder(
                    itemCount: _values.length,
                    itemBuilder: (context, index) {
                      final value = _values[index];
                      return ListTile(
                        title: Text(value as String),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _delete(value),
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
