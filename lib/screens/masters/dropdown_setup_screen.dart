import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/custom_dropdown_field.dart';

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
    'Colours',
    'Dia',
    'Item',
    'Item Name',
    'Lot Name',
    'GSM',
    'Dyeing',
    'Process',
    'Rack Name',
    'Pallet No',
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
                  CustomDropdownField(
                    label: 'Select Category',
                    value:
                        _categories.any((c) => c['_id'] == _selectedCategoryId)
                        ? _categories.firstWhere(
                                (c) => c['_id'] == _selectedCategoryId,
                              )['name']
                              as String
                        : null,
                    items: _categories.map((c) => c['name'] as String).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final cat = _categories.firstWhere(
                          (c) => c['name'] == val,
                        );
                        setState(() {
                          _selectedCategoryId = cat['_id'];
                        });
                        _loadValues();
                      }
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
                      final value = _values[index] as String;
                      final isColoursCategory =
                          _selectedCategoryName == 'Colours';
                      return ListTile(
                        leading: isColoursCategory
                            ? Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: _resolveColor(value),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _resolveColor(
                                        value,
                                      ).withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              )
                            : null,
                        title: Text(
                          value.contains(' (#') ? value.split(' (#')[0] : value,
                        ),
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

  String get _selectedCategoryName {
    if (_selectedCategoryId == null) return '';
    final cat = _categories.firstWhere(
      (c) => c['_id'] == _selectedCategoryId,
      orElse: () => {'name': ''},
    );
    return cat['name'] as String? ?? '';
  }

  Color _resolveColor(String name) {
    final lower = name.toLowerCase().trim();
    const colorMap = <String, Color>{
      'red': Color(0xFFE53935),
      'dark red': Color(0xFFB71C1C),
      'light red': Color(0xFFEF9A9A),
      'blue': Color(0xFF1E88E5),
      'dark blue': Color(0xFF0D47A1),
      'light blue': Color(0xFF90CAF9),
      'sky blue': Color(0xFFA3C1E0),
      'royal blue': Color(0xFF4D63C3),
      'navy blue': Color(0xFF0A1747),
      'navy': Color(0xFF0A1747),
      'green': Color(0xFF43A047),
      'dark green': Color(0xFF1B5E20),
      'light green': Color(0xFFA5D6A7),
      'olive green': Color(0xFF6B8E23),
      'forest green': Color(0xFF228B22),
      'yellow': Color(0xFFFDD835),
      'golden yellow': Color(0xFFF9A825),
      'orange': Color(0xFFFB8C00),
      'dark orange': Color(0xFFE65100),
      'black': Color(0xFF212121),
      'jet black': Color(0xFF0A0A0A),
      'white': Color(0xFFFAFAFA),
      'off white': Color(0xFFF5F0E8),
      'cream': Color(0xFFFFF8E1),
      'ivory': Color(0xFFFFFFF0),
      'grey': Color(0xFF9E9E9E),
      'gray': Color(0xFF9E9E9E),
      'dark grey': Color(0xFF424242),
      'light grey': Color(0xFFE0E0E0),
      'charcoal': Color(0xFF36454F),
      'pink': Color(0xFFEC407A),
      'hot pink': Color(0xFFFF1493),
      'dusty rose': Color(0xFFDCAE96),
      'baby pink': Color(0xFFF8BBD0),
      'magenta': Color(0xFFD500F9),
      'purple': Color(0xFF7B1FA2),
      'violet': Color(0xFF7C21A6),
      'lavender': Color(0xFFCE93D8),
      'brown': Color(0xFF6D4C41),
      'chocolate brown': Color(0xFF5D3A1A),
      'dark brown': Color(0xFF3E2723),
      'tan': Color(0xFFD2B48C),
      'beige': Color(0xFFF5F5DC),
      'khaki': Color(0xFFC3B091),
      'maroon': Color(0xFF800000),
      'burgundy': Color(0xFF800020),
      'wine': Color(0xFF722F37),
      'teal': Color(0xFF008080),
      'turquoise': Color(0xFF40E0D0),
      'aqua': Color(0xFF00FFFF),
      'cyan': Color(0xFF00BCD4),
      'coral': Color(0xFFFF7F50),
      'salmon': Color(0xFFFA8072),
      'peach': Color(0xFFFFDAB9),
      'rust': Color(0xFFB7410E),
      'copper': Color(0xFFB87333),
      'gold': Color(0xFFFFD700),
      'silver': Color(0xFFC0C0C0),
      'indigo': Color(0xFF3F51B5),
      'mint': Color(0xFF98FF98),
      'sage': Color(0xFFBCB88A),
      'olive': Color(0xFF808000),
      'mustard': Color(0xFFFFDB58),
      'lemon': Color(0xFFFFF44F),
      'plum': Color(0xFF8E4585),
    };

    // Check for hex code in the name (e.g. "My Color #FF00FF")
    final hexMatch = RegExp(
      r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})',
    ).firstMatch(name);
    if (hexMatch != null) {
      try {
        String hex = hexMatch.group(1)!;
        if (hex.length == 3) {
          // Convert 3-digit hex to 6-digit
          hex = hex[0] * 2 + hex[1] * 2 + hex[2] * 2;
        }
        return Color(int.parse('0xFF$hex'));
      } catch (_) {}
    }

    // Direct match
    if (colorMap.containsKey(lower)) return colorMap[lower]!;

    // Partial match — check if any key is contained in the color name
    for (final entry in colorMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    // Default grey for unknown colors
    return const Color(0xFFBDBDBD);
  }
}
