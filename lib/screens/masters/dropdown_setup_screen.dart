import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/api_constants.dart';
import '../../widgets/custom_dropdown_field.dart';

class DropdownSetupScreen extends StatefulWidget {
  const DropdownSetupScreen({super.key});

  @override
  State<DropdownSetupScreen> createState() => _DropdownSetupScreenState();
}

class _DropdownSetupScreenState extends State<DropdownSetupScreen> {
  final _api = MobileApiService();
  final _valueController = TextEditingController();
  final _gsmController = TextEditingController();
  final _knittingDiaController = TextEditingController(); // for Dia category
  final _cuttingDiaController = TextEditingController(); // for Dia category
  XFile? _selectedXFile;
  final ImagePicker _picker = ImagePicker();

  // Static list of categories requested by the user
  final List<String> _staticCategoryNames = [
    'Colours',
    'Dia',
    'Item',
    'Item Name',
    'Lot Name',
    'GSM',
    'Size',
    'Efficiency',
    'Dyeing',
    'Process',
    'Party Name',
    'Rack Name',
    'Pallet No',
    'Accessories',
    'Accessories Group',
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
      // Map server categories to our static list with aliases
      final List<Map<String, dynamic>> filteredCategories = [];

      final Map<String, List<String>> categoryAliases = {
        'Colours': ['Colours', 'Colors', 'Colour', 'Color'],
        'Dia': ['Dia', 'dia'],
        'Item': ['Item', 'Items'],
        'Item Name': ['Item Name', 'ItemName', 'item name'],
        'Lot Name': ['Lot Name', 'LotName', 'lot name'],
        'GSM': ['GSM', 'Gsm', 'gsm'],
        'Size': ['Size', 'Sizes', 'size'],
        'Efficiency': ['Efficiency', 'Eff', 'efficiency'],
        'Rack Name': ['Rack Name', 'Rack', 'racks'],
        'Pallet No': ['Pallet No', 'Pallet', 'pallets'],
        'Accessories Group': ['Accessories Group', 'Accessory Group', 'accessories group', 'accessory group'],
      };

      for (var name in _staticCategoryNames) {
        final List<String> aliases = (categoryAliases[name] ?? [])
            .map((e) => e.toLowerCase().trim())
            .toList();
        if (!aliases.contains(name.toLowerCase().trim())) {
          aliases.add(name.toLowerCase().trim());
        }

        // Find existing category on server (case-insensitive and trimmed match against aliases)
        final serverCat = res.firstWhere((c) {
          final String serverName = (c['name'] as String? ?? '')
              .trim()
              .toLowerCase();
          return aliases.contains(serverName);
        }, orElse: () => <String, dynamic>{});

        if (serverCat.isNotEmpty) {
          filteredCategories.add(serverCat);
        } else {
          // If category doesn't exist on server, create a placeholder
          filteredCategories.add({
            '_id': 'new_$name',
            'name': name,
            'values': [],
          });
        }
      }

      setState(() {
        _categories = filteredCategories;
        if (_selectedCategoryId == null && _categories.isNotEmpty) {
          _selectedCategoryId = _categories.first['_id'];
        }
        // Always refresh values from the current categories list
        _syncValuesWithSelectedCategory();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _syncValuesWithSelectedCategory() {
    if (_selectedCategoryId == null) {
      _values = [];
      return;
    }

    if (_selectedCategoryId!.startsWith('new_')) {
      _values = [];
      return;
    }

    final category = _categories.firstWhere(
      (c) => c['_id'] == _selectedCategoryId,
      orElse: () => <String, dynamic>{},
    );
    final vals = category['values'];
    _values = (vals is List) ? vals : [];
  }

  void _loadValues() {
    setState(() {
      _syncValuesWithSelectedCategory();
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() => _selectedXFile = image);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _add() async {
    if (_valueController.text.isEmpty || _selectedCategoryId == null) return;
    setState(() => _isLoading = true);
    try {
      String categoryId = _selectedCategoryId!;

      // If it's a placeholder category, create it first
      if (categoryId.startsWith('new_')) {
        final categoryName = _categories.firstWhere(
          (c) => c['_id'] == _selectedCategoryId,
        )['name'];

        final success = await _api.createCategory(categoryName);
        if (success) {
          final res = await _api.getCategories();
          final newCat = res.firstWhere(
            (c) =>
                (c['name'] as String).toLowerCase() ==
                categoryName.toLowerCase(),
          );
          categoryId = newCat['_id'];
          setState(() => _selectedCategoryId = categoryId);
          await _loadCategories();
        } else {
          setState(() => _isLoading = false);
          return;
        }
      }

      String? photoUrl;
      if (_selectedXFile != null && (_isColoursCategory || _isAccessoriesCategory)) {
        photoUrl = await _api.uploadImage(_selectedXFile!);
      }

      final success = await _api.addCategoryValue(
        categoryId,
        _valueController.text.trim(),
        photo: photoUrl,
        gsm: _isColoursCategory ? _gsmController.text.trim() : null,
        knittingDia: _isDiaCategory ? _knittingDiaController.text.trim() : null,
        cuttingDia: _isDiaCategory ? _cuttingDiaController.text.trim() : null,
      );

      if (success) {
        _valueController.clear();
        _gsmController.clear();
        _knittingDiaController.clear();
        _cuttingDiaController.clear();
        setState(() => _selectedXFile = null);
        await _loadCategories();
        _loadValues();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Added successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(String value) async {
    if (_selectedCategoryId == null) return;
    final success = await _api.deleteCategoryValue(_selectedCategoryId!, value);
    if (success) {
      await _loadCategories();
      _loadValues();
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
                    label: 'Category',
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
                    decoration: InputDecoration(
                      labelText: _isDiaCategory ? 'Dia Name' : 'New Value',
                      hintText: _isDiaCategory ? 'Enter Dia (e.g. 60)' : 'Enter value to add',
                    ),
                  ),
                  if (_isColoursCategory || _isAccessoriesCategory) ...[
                    const SizedBox(height: 16),
                    if (_isColoursCategory) ...[
                      TextField(
                        controller: _gsmController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'GSM',
                          hintText: 'Enter GSM for this color',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        if (_selectedXFile != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                                  ? Image.network(
                                      _selectedXFile!.path,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(_selectedXFile!.path),
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            _selectedXFile == null
                                ? 'No image selected'
                                : 'Image selected: ${_selectedXFile!.path.split('/').last}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showImageSourceDialog,
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('Pick/Take Photo'),
                        ),
                      ],
                    ),
                  ],
                  if (_isDiaCategory) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _knittingDiaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Knitting Dia',
                        hintText: 'Enter Knitting Dia (e.g. 60)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _cuttingDiaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cutting Dia',
                        hintText: 'Enter Cutting Dia (e.g. 62)',
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _selectedCategoryId == null || _isLoading
                        ? null
                        : _add,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Add Value'),
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
                      final dynamic valueData = _values[index];
                      final String valueName = valueData is String
                          ? valueData
                          : (valueData['name'] ?? '');
                      final String? photoUrl = valueData is Map
                          ? valueData['photo']
                          : null;
                      final String? gsm = valueData is Map
                          ? valueData['gsm']
                          : null;

                      final isColoursCategory = _isColoursCategory;

                      return ListTile(
                        leading: (isColoursCategory || _isAccessoriesCategory)
                            ? (photoUrl != null && photoUrl.isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        ApiConstants.getImageUrl(photoUrl),
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                isColoursCategory 
                                                ? _colorCircle(valueName)
                                                : const Icon(Icons.image_not_supported),
                                      ),
                                    )
                                  : isColoursCategory 
                                      ? _colorCircle(valueName)
                                      : const Icon(Icons.inventory_2, color: Colors.blueGrey)
                            : null,
                        title: Text(_isDiaCategory ? 'Dia: $valueName' : valueName),
                        subtitle:
                            (isColoursCategory && gsm != null && gsm.isNotEmpty)
                            ? Text('GSM: $gsm')
                            : (() {
                                final dynamic kDiaRaw = valueData is Map
                                    ? valueData['knittingDia']
                                    : null;
                                final dynamic cDiaRaw = valueData is Map
                                    ? valueData['cuttingDia']
                                    : null;
                                final String kDia = kDiaRaw?.toString() ?? '';
                                final String cDia = cDiaRaw?.toString() ?? '';
                                
                                List<String> details = [];
                                if (kDia.isNotEmpty) details.add('K.Dia: $kDia');
                                if (cDia.isNotEmpty) details.add('C.Dia: $cDia');
                                
                                if (details.isNotEmpty) {
                                  return Text(details.join(' | '));
                                }
                                return null;
                              })(),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _delete(valueName),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _colorCircle(String value) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: _resolveColor(value),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _resolveColor(value).withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
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

  bool get _isDiaCategory {
    final name = _selectedCategoryName.toLowerCase().trim();
    return name == 'dia';
  }

  bool get _isColoursCategory {
    final name = _selectedCategoryName.toLowerCase();
    return name == 'colours' ||
        name == 'colors' ||
        name == 'colour' ||
        name == 'color';
  }

  bool get _isAccessoriesCategory {
    final name = _selectedCategoryName.toLowerCase().trim();
    return name == 'accessories';
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
