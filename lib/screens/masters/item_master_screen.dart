import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';

class ItemMasterScreen extends StatefulWidget {
  const ItemMasterScreen({super.key});

  @override
  State<ItemMasterScreen> createState() => _ItemMasterScreenState();
}

class _ItemMasterScreenState extends State<ItemMasterScreen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();

  String? _selectedGroupName;
  final List<String> _selectedItemNames = [];
  String? _selectedGsm;
  final List<String> _selectedColours = [];
  double _rate = 0;

  List<String> _groupNames = [];
  List<String> _itemNames = [];
  List<String> _gsmValues = [];
  List<String> _colours = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    final categories = await _api.getCategories();

    setState(() {
      _groupNames = _getValues(categories, [
        'Lot Name',
        'Group Name',
        'lot name',
      ]);
      _itemNames = _getValues(categories, [
        'Item',
        'Item Name',
        'item name',
        'Items',
      ]);
      _gsmValues = _getValues(categories, ['GSM', 'gsm']);
      _colours = _getValues(categories, [
        'Colour',
        'Colours',
        'colour',
        'color',
      ]);
      _isLoading = false;
    });
  }

  List<String> _getValues(List<dynamic> categories, dynamic nameOrNames) {
    try {
      final List<String> names = nameOrNames is List<String>
          ? nameOrNames
          : [nameOrNames.toString()];
      final cat = categories.firstWhere(
        (c) => names.any(
          (n) => c['name'].toString().toLowerCase() == n.toLowerCase(),
        ),
      );
      return List<String>.from(cat['values'] ?? []);
    } catch (e) {
      return [];
    }
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

      final data = {
        'groupName': _selectedGroupName,
        'itemNames': _selectedItemNames,
        'gsm': _selectedGsm,
        'colours': _selectedColours,
        'rate': _rate,
      };

      try {
        final success = await _api.createItemGroup(data);

        if (!mounted) return;

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item Group saved to Backend')),
          );
          setState(() {
            _selectedGroupName = null;
            _selectedItemNames.clear();
            _selectedGsm = null;
            _selectedColours.clear();
          });
        }
      } catch (e) {
        if (!mounted) return;
        _showError(e.toString());
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item Group Master')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedGroupName,
                      decoration: const InputDecoration(
                        labelText: 'Group Name',
                      ),
                      items: _groupNames
                          .map(
                            (i) => DropdownMenuItem(value: i, child: Text(i)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedGroupName = val),
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

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
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Rate',
                        hintText: 'Enter Rate',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (double.tryParse(val) == null)
                          return 'Invalid Number';
                        return null;
                      },
                      onSaved: (val) => _rate = double.tryParse(val!) ?? 0,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedGsm,
                      decoration: const InputDecoration(labelText: 'GSM'),
                      items: _gsmValues
                          .map(
                            (i) => DropdownMenuItem(value: i, child: Text(i)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedGsm = val),
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

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
                        child: const Text('Save Group'),
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
          onTap: () => _showMultiSelectDialog(
            label,
            items,
            selectedItems,
            onSelectionChanged,
          ),
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
                    children: selectedItems
                        .map(
                          (e) => Chip(
                            label: Text(e),
                            onDeleted: () {
                              final newList = List<String>.from(selectedItems)
                                ..remove(e);
                              onSelectionChanged(newList);
                            },
                          ),
                        )
                        .toList(),
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
                .where(
                  (item) =>
                      item.toLowerCase().contains(searchQuery.toLowerCase()),
                )
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
                      onChanged: (val) => setState(() => searchQuery = val),
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
