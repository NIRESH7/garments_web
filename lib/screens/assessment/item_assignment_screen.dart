import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';

class ItemAssignmentScreen extends StatefulWidget {
  const ItemAssignmentScreen({super.key});

  @override
  State<ItemAssignmentScreen> createState() => _ItemAssignmentScreenState();
}

class _ItemAssignmentScreenState extends State<ItemAssignmentScreen> {
  final _api = MobileApiService();

  String? _selectedItem, _selectedSize, _selectedDia, _selectedEfficiency;
  final _dozenWeightController = TextEditingController();

  List<String> _items = [], _sizes = [], _dias = [], _efficiencies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    final categories = await _api.getCategories();

    setState(() {
      _items = _getValues(
        categories,
        'Item Group',
      ); // Adjusted based on previous usage
      _sizes = _getValues(categories, 'size');
      _dias = _getValues(categories, 'dia');
      _efficiencies = _getValues(categories, 'efficiency');
      _isLoading = false;
    });
  }

  List<String> _getValues(List<dynamic> categories, String name) {
    try {
      final cat = categories.firstWhere(
        (c) => c['name'].toString().toLowerCase() == name.toLowerCase(),
      );
      return List<String>.from(cat['values'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<void> _save() async {
    if (_selectedItem == null ||
        _selectedSize == null ||
        _selectedDia == null ||
        _selectedEfficiency == null ||
        _dozenWeightController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    final data = {
      'itemName': _selectedItem,
      'size': _selectedSize,
      'dia': _selectedDia,
      'efficiency': _selectedEfficiency,
      'dozenWeight': double.tryParse(_dozenWeightController.text) ?? 0.0,
    };

    final success = await _api.createAssignment(data);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment Saved Successfully')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save assignment')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item Assignment')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: ColorPalette.softShadow,
                    ),
                    child: Column(
                      children: [
                        _buildFieldLabel('Fabric Item'),
                        _buildDropdown(
                          _items,
                          _selectedItem,
                          (v) => setState(() => _selectedItem = v),
                          'Select Item',
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Size'),
                                  _buildDropdown(
                                    _sizes,
                                    _selectedSize,
                                    (v) => setState(() => _selectedSize = v),
                                    'Select Size',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Dia'),
                                  _buildDropdown(
                                    _dias,
                                    _selectedDia,
                                    (v) => setState(() => _selectedDia = v),
                                    'Select Dia',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildFieldLabel('Efficiency (%)'),
                        _buildDropdown(
                          _efficiencies,
                          _selectedEfficiency,
                          (v) => setState(() => _selectedEfficiency = v),
                          'Select %',
                        ),
                        const SizedBox(height: 20),
                        _buildFieldLabel('Dozen Weight (Kg)'),
                        TextField(
                          controller: _dozenWeightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            suffixIcon: Icon(
                              LucideIcons.edit3,
                              size: 20,
                              color: ColorPalette.textMuted,
                            ),
                            helperText: 'Manual override supported',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save Assignment'),
                  ),

                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      side: BorderSide(color: Colors.grey.shade200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: ColorPalette.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: ColorPalette.textSecondary,
        ),
      ),
    );
  }

  Widget _buildDropdown(
    List<String> items,
    String? value,
    Function(String?) onChanged,
    String hint,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      hint: Text(hint, style: const TextStyle(fontSize: 14)),
      items: items
          .map(
            (i) => DropdownMenuItem(
              value: i,
              child: Text(i, style: const TextStyle(fontSize: 14)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
