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

  // Static list of categories requested by the user
  final List<String> _staticCategoryNames = [
    'Colour',
    'Dia',
    'Item',
    'Item Name',
    'Lot Name',
    'GSM',
    'Dyeing',
    'Process',
    'Rack',
    'Pallet',
  ];

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
    setState(() => _isLoading = true);
    try {
      final res = await _api.getCategories();

      // Map server categories to our static list
      final List<Map<String, dynamic>> filteredCategories = [];

      for (var name in _staticCategoryNames) {
        // Find existing category on server (case-insensitive match)
        final serverCat = res.firstWhere(
          (c) => (c['name'] as String).toLowerCase() == name.toLowerCase(),
          orElse: () => null,
        );

        if (serverCat != null) {
          filteredCategories.add(serverCat);
        } else {
          // If category doesn't exist on server, we might need to create it later
          // or just show it as empty for now. For now, let's create a placeholder
          // so the user can see the option in the dropdown.
          filteredCategories.add({
            '_id': 'new_$name',
            'name': name,
            'values': [],
          });
        }
      }

      setState(() {
        _categories = filteredCategories;
        if (_categories.isNotEmpty && _selectedCategoryId == null) {
          _selectedCategoryId = _categories.first['_id'];
          _loadValues();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadValues() async {
    if (_selectedCategoryId == null) return;
    if (_selectedCategoryId!.startsWith('new_')) {
      setState(() => _values = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final category = _categories.firstWhere(
        (c) => c['_id'] == _selectedCategoryId,
      );
      setState(() {
        _values = category['values'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _add() async {
    if (_valueController.text.isEmpty || _selectedCategoryId == null) return;
    try {
      String categoryId = _selectedCategoryId!;

      // If it's a placeholder category, create it first
      if (categoryId.startsWith('new_')) {
        final categoryName = _categories.firstWhere(
          (c) => c['_id'] == _selectedCategoryId,
        )['name'];

        final success = await _api.createCategory(categoryName);
        if (success) {
          // Reload categories to get the real ID
          final res = await _api.getCategories();
          final newCat = res.firstWhere(
            (c) =>
                (c['name'] as String).toLowerCase() ==
                categoryName.toLowerCase(),
          );
          categoryId = newCat['_id'];
          setState(() => _selectedCategoryId = categoryId);
          await _loadCategories(); // Refresh local list
        } else {
          return;
        }
      }

      final success = await _api.addCategoryValue(
        categoryId,
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
                  DropdownMenu<String>(
                    initialSelection: _selectedCategoryId,
                    width:
                        MediaQuery.of(context).size.width -
                        96, // Matches container padding
                    label: const Text('Select Category'),
                    dropdownMenuEntries: _categories.map((c) {
                      return DropdownMenuEntry<String>(
                        value: c['_id'] as String,
                        label: c['name'] as String,
                      );
                    }).toList(),
                    onSelected: (val) {
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
