import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';

import '../../widgets/custom_dropdown_field.dart';

class ItemAssignmentScreen extends StatefulWidget {
  /// Pass existing assignment map to open in edit mode; null = create mode.
  final Map<String, dynamic>? existing;
  const ItemAssignmentScreen({super.key, this.existing});

  @override
  State<ItemAssignmentScreen> createState() => _ItemAssignmentScreenState();
}

class _ItemAssignmentScreenState extends State<ItemAssignmentScreen> {
  final _api = MobileApiService();

  String? _selectedItem, _selectedSize, _selectedDia, _selectedLotName;
  final _efficiencyController = TextEditingController();
  final _dozenWeightController = TextEditingController();
  final _layLengthController = TextEditingController();
  final _layPcsController = TextEditingController();
  final _wastePercentageController = TextEditingController();
  final _foldingWtController = TextEditingController();
  final _gsmController = TextEditingController();

  List<String> _items = [], _sizes = [], _dias = [], _lotNames = [];
  bool _isLoading = true;

  bool get _isEditMode => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    final categories = await _api.getCategories();

    // Fetch unique lot names from inwards
    List<String> lotNames = [];
    try {
      final inwards = await _api.getInwards();
      final seen = <String>{};
      for (final inw in inwards) {
        final name = inw['lotName']?.toString().trim() ?? '';
        if (name.isNotEmpty && seen.add(name)) {
          lotNames.add(name);
        }
      }
      lotNames.sort();
    } catch (_) {}

    setState(() {
      _items = _getValues(categories, 'Item Name');
      if (_items.isEmpty) {
        _items = _getValues(categories, 'Item');
      }
      _sizes = _getValues(categories, 'Size');
      _dias = _getValues(categories, 'Dia');
      _lotNames = lotNames;
      _isLoading = false;
    });

    // Pre-fill fields if editing
    if (_isEditMode) {
      final e = widget.existing!;
      setState(() {
        _selectedItem = e['fabricItem']?.toString();
        _selectedSize = e['size']?.toString();
        _selectedDia  = e['dia']?.toString();
        final lotName = e['lotName']?.toString() ?? '';
        // Add to list if not already present (edge case for old data)
        if (lotName.isNotEmpty && !_lotNames.contains(lotName)) {
          _lotNames = [..._lotNames, lotName]..sort();
        }
        _selectedLotName = lotName.isEmpty ? null : lotName;
      });
      _efficiencyController.text   = e['efficiency']?.toString()     ?? '';
      _dozenWeightController.text  = e['dozenWeight']?.toString()    ?? '';
      _layLengthController.text    = e['layLength']?.toString()      ?? '';
      _layPcsController.text       = e['layPcs']?.toString()         ?? '';
      _wastePercentageController.text = e['wastePercentage']?.toString() ?? '';
      _foldingWtController.text    = e['foldingWt']?.toString()      ?? '';
      _gsmController.text          = e['gsm']?.toString()            ?? '';
    }
  }

  void _onEfficiencyChanged(String val) {
    if (val.isNotEmpty) {
      final eff = double.tryParse(val) ?? 0;
      final waste = 100 - eff;
      _wastePercentageController.text = waste.toStringAsFixed(2);
    } else {
      _wastePercentageController.text = '';
    }
  }

  List<String> _getValues(List<dynamic> categories, String name) {
    try {
      final cat = categories.firstWhere(
        (c) => c['name'].toString().toLowerCase() == name.toLowerCase(),
      );
      final List<dynamic> values = cat['values'] ?? [];
      return values.map<String>((v) {
        if (v is Map) return v['name'].toString();
        return v.toString();
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _save() async {
    if (_selectedItem == null ||
        _selectedSize == null ||
        _selectedDia == null ||
        _efficiencyController.text.isEmpty ||
        _dozenWeightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    final efficiencyValue = double.tryParse(_efficiencyController.text) ?? 0.0;

    final data = {
      'fabricItem': _selectedItem,
      'size': _selectedSize,
      'dia': _selectedDia,
      'efficiency': efficiencyValue,
      'dozenWeight': double.tryParse(_dozenWeightController.text) ?? 0.0,
      'layLength': double.tryParse(_layLengthController.text) ?? 0.0,
      'layPcs': int.tryParse(_layPcsController.text) ?? 0,
      'wastePercentage':
          double.tryParse(_wastePercentageController.text) ?? 0.0,
      'foldingWt': double.tryParse(_foldingWtController.text) ?? 0.0,
      'lotName': _selectedLotName ?? '',
      'gsm': _gsmController.text.trim(),
    };

    bool success;
    if (_isEditMode) {
      success = await _api.updateAssignment(widget.existing!['_id'], data);
    } else {
      success = await _api.createAssignment(data);
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditMode ? 'Assignment Updated' : 'Assignment Saved Successfully')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditMode ? 'Failed to update assignment' : 'Failed to save assignment')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Assignment' : 'Item Assignment'),
      ),
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
                        _buildDropdown(
                          _items,
                          _selectedItem,
                          (v) => setState(() => _selectedItem = v),
                          'Fabric Item',
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdown(
                                _sizes,
                                _selectedSize,
                                (v) => setState(() => _selectedSize = v),
                                'Size',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDropdown(
                                _dias,
                                _selectedDia,
                                (v) => setState(() => _selectedDia = v),
                                'Dia',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Efficiency (%)'),
                                  TextField(
                                    controller: _efficiencyController,
                                    keyboardType: TextInputType.number,
                                    onChanged: _onEfficiencyChanged,
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. 85',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Folding Wt (Kg)'),
                                  TextField(
                                    controller: _foldingWtController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      hintText: '0.00',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Lot Name'),
                                  DropdownButtonFormField<String>(
                                    value: _selectedLotName,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      hintText: 'Select Lot',
                                      isDense: true,
                                    ),
                                    items: _lotNames.map((name) =>
                                      DropdownMenuItem(
                                        value: name,
                                        child: Text(name, overflow: TextOverflow.ellipsis),
                                      )
                                    ).toList(),
                                    onChanged: (v) => setState(() => _selectedLotName = v),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('GSM (Optional)'),
                                  TextField(
                                    controller: _gsmController,
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. 180',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                        const SizedBox(height: 20),

                        // Lay Length & Lay Pcs Row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Lay Length'),
                                  TextField(
                                    controller: _layLengthController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      hintText: '0.00',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Lay Pcs'),
                                  TextField(
                                    controller: _layPcsController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      hintText: '0',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Waste Percentage
                        _buildFieldLabel('Waste % (100 - Eff)'),
                        TextField(
                          controller: _wastePercentageController,
                          readOnly: true,
                          canRequestFocus: false,
                          enableInteractiveSelection: false,
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            filled: true,
                            fillColor: Color(0xFFF1F5F9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _save,
                    child: Text(_isEditMode ? 'Update Assignment' : 'Save Assignment'),
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
    String label, {
    String hint = "Select",
  }) {
    return CustomDropdownField(
      label: label,
      items: items,
      value: value,
      onChanged: onChanged,
      hint: hint,
    );
  }
}
