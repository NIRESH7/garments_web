import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/layout_constants.dart';
import '../../widgets/custom_dropdown_field.dart';
import '../../widgets/responsive_wrapper.dart';
import '../../widgets/modern_data_table.dart';
import 'item_group_history_screen.dart';

class ItemMasterScreen extends StatefulWidget {
  final Map<dynamic, dynamic>? editGroup;
  const ItemMasterScreen({super.key, this.editGroup});

  @override
  State<ItemMasterScreen> createState() => _ItemMasterScreenState();
}

class _ItemMasterScreenState extends State<ItemMasterScreen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();

  final _rateController = TextEditingController();
  String? _selectedGroupName;
  final List<String> _selectedItemNames = [];
  String? _selectedGsm;
  final List<String> _selectedColours = [];
  double _rate = 0;

  List<String> _groupNames = [];
  List<String> _itemNames = [];
  List<String> _gsmValues = [];
  List<String> _colours = [];
  List<Map<String, dynamic>> _itemGroups = [];
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    if (widget.editGroup != null) {
      _selectedGroupName = widget.editGroup!['groupName'];
      _selectedItemNames.addAll(List<String>.from(widget.editGroup!['itemNames'] ?? []));
      _selectedGsm = widget.editGroup!['gsm'];
      _selectedColours.addAll(List<String>.from(widget.editGroup!['colours'] ?? []));
      _rate = (widget.editGroup!['rate'] as num?)?.toDouble() ?? 0;
      _rateController.text = _rate.toString();
    }
  }

  List<Map<String, dynamic>> get _filteredItemGroups {
    if (_searchQuery.isEmpty) return _itemGroups;
    return _itemGroups.where((item) {
      final name = item['groupName']?.toString().toLowerCase() ?? '';
      final items = (item['itemNames'] as List?)?.join(' ').toLowerCase() ?? '';
      return name.contains(_searchQuery) || items.contains(_searchQuery);
    }).toList();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _api.getCategories();
      final groupsData = await _api.getItemGroups();
      
      setState(() {
        _groupNames = _getValues(categories, ['Lot Name', 'Group Name', 'lot name']);
        _itemNames = _getValues(categories, ['Item', 'Item Name', 'item name', 'Items']);
        _gsmValues = _getValues(categories, ['GSM', 'gsm']);
        _colours = _getValues(categories, ['Colour', 'Colours', 'colour', 'color']);
        _itemGroups = List<Map<String, dynamic>>.from(groupsData);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _getValues(List<dynamic> categories, List<String> names) {
    try {
      final List<String> result = [];
      final matches = categories.where((c) {
        final catName = (c['name'] ?? '').toString().trim().toLowerCase();
        return names.any((n) => catName == n.trim().toLowerCase());
      });

      for (var cat in matches) {
        final dynamic rawValues = cat['values'];
        if (rawValues is List) {
          for (var v in rawValues) {
            String? val;
            if (v is Map) { val = (v['name'] ?? v['value'] ?? '').toString(); }
            else if (v != null) { val = v.toString(); }
            if (val != null && val.isNotEmpty && !result.contains(val)) { result.add(val); }
          }
        }
      }
      return result;
    } catch (e) { return []; }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      _formKey.currentState!.save();

      if (_selectedItemNames.isEmpty) { _showError('Please select at least one Item Name'); setState(() => _isSaving = false); return; }
      if (_selectedColours.isEmpty) { _showError('Please select at least one Colour'); setState(() => _isSaving = false); return; }

      final data = {
        'groupName': _selectedGroupName,
        'itemNames': _selectedItemNames,
        'gsm': _selectedGsm,
        'colours': _selectedColours,
        'rate': _rate,
      };

      try {
        bool success;
        if (widget.editGroup != null) {
          success = await _api.updateItemGroup(widget.editGroup!['_id'], data);
        } else {
          success = await _api.createItemGroup(data);
        }

        if (!mounted) return;

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.editGroup != null ? 'Item Group specifications updated' : 'Item Group documented'), backgroundColor: ColorPalette.success));
          if (widget.editGroup != null) { Navigator.pop(context, true); }
          else {
            setState(() { _selectedGroupName = null; _selectedItemNames.clear(); _selectedGsm = null; _selectedColours.clear(); _rateController.clear(); });
            await _loadAllData();
          }
        }
      } catch (e) { if (mounted) _showError('Registry Error: $e'); }
      finally { if (mounted) setState(() => _isSaving = false); }
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final success = await _api.deleteItemGroup(item['_id']);
    if (success) { await _loadAllData(); }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: ColorPalette.error));
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = LayoutConstants.isMobile(context);

    return Scaffold(
      backgroundColor: ColorPalette.background,
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ITEM GROUP MASTER',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                color: ColorPalette.textPrimary,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'CONFIGURATION & SPECIFICATIONS',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: ColorPalette.textMuted,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: ColorPalette.textPrimary, size: 20),
        actions: [
          _buildSearchOverlay(isMobile),
          IconButton(
            onPressed: _loadAllData,
            icon: const Icon(LucideIcons.refreshCw, size: 16, color: ColorPalette.textMuted),
          ),
          Gaps.w16,
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveWrapper(
              maxWidth: 1400,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. REGISTRATION MODULE
                      _buildRegistrationModule(isMobile),
                      
                      Gaps.h32,

                      // 2. DATABASE SECTION
                      _buildDatabaseHeader(),
                      
                      Gaps.h16,

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: ValueKey(_filteredItemGroups.length),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ColorPalette.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ModernDataTable(
                            columns: const ['groupName', 'gsm', 'rate_formatted'],
                            rows: _filteredItemGroups.map((group) => {
                              ...group,
                              'items': (group['itemNames'] as List?)?.join(', ') ?? '-',
                              'rate_formatted': '₹ ${(group['rate'] ?? 0).toString()}',
                            }).toList(),
                            onDelete: _delete,
                            emptyMessage: 'No registered groups found in registry',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildGroupDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GROUP IDENTITY',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        CustomDropdownField(
          label: '',
          value: _selectedGroupName,
          items: _groupNames,
          onChanged: (val) => setState(() => _selectedGroupName = val),
          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          hint: 'Select group...',
        ),
      ],
    );
  }

  Widget _buildGSMDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GSM SPECIFICATION',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        CustomDropdownField(
          label: '',
          value: _selectedGsm,
          items: _gsmValues,
          onChanged: (val) => setState(() => _selectedGsm = val),
          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          hint: 'Select GSM...',
        ),
      ],
    );
  }

  Widget _buildRateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STANDARD RATE',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        TextFormField(
          controller: _rateController,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: ColorPalette.textPrimary),
          decoration: InputDecoration(
            hintText: '₹ Base rate',
            hintStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted.withOpacity(0.6)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (val) { if (val == null || val.isEmpty) return 'Required'; if (double.tryParse(val) == null) return 'Invalid Number'; return null; },
          onSaved: (val) => _rate = double.tryParse(val!) ?? 0,
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorPalette.textPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: _isSaving
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(
                widget.editGroup != null ? 'FINALIZE UPDATES' : 'COMMIT REGISTRY',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
              ),
      ),
    );
  }

  Widget _buildMultiSelectField({
    required String label,
    required List<String> items,
    required List<String> selectedItems,
    required IconData icon,
    required ValueChanged<List<String>> onSelectionChanged,
  }) {
    final searchController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        StatefulBuilder(builder: (context, setMenuState) {
          return MenuAnchor(
            alignmentOffset: const Offset(0, 4),
            style: MenuStyle(
              backgroundColor: WidgetStateProperty.all(Colors.white),
              surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
              elevation: WidgetStateProperty.all(8),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: ColorPalette.border),
                ),
              ),
              padding: WidgetStateProperty.all(EdgeInsets.zero),
            ),
            menuChildren: [
              Container(
                width: 350,
                height: 450,
                decoration: const BoxDecoration(color: Colors.white),
                child: Column(
                  children: [
                    // Search Bar at Top
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: searchController,
                        onChanged: (val) => setMenuState(() {}),
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted),
                          prefixIcon: const Icon(LucideIcons.search, size: 14, color: ColorPalette.textMuted),
                          filled: true,
                          fillColor: ColorPalette.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: ColorPalette.border),
                    // Checkbox List
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: items.where((i) => i.toLowerCase().contains(searchController.text.toLowerCase())).map((item) {
                          final isSelected = selectedItems.contains(item);
                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(item, style: GoogleFonts.inter(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? ColorPalette.primary : ColorPalette.textPrimary)),
                            activeColor: ColorPalette.primary,
                            dense: true,
                            onChanged: (val) {
                              final newList = List<String>.from(selectedItems);
                              if (val == true) {
                                newList.add(item);
                              } else {
                                newList.remove(item);
                              }
                              onSelectionChanged(newList);
                              setMenuState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            builder: (context, controller, child) {
              return InkWell(
                onTap: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: ColorPalette.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          child: selectedItems.isEmpty
                              ? Text('Assign items...', style: GoogleFonts.inter(color: ColorPalette.textMuted.withOpacity(0.5), fontSize: 13))
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: selectedItems
                                      .map((e) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(color: ColorPalette.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            Text(e, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: ColorPalette.primary)),
                                            const SizedBox(width: 4),
                                            GestureDetector(
                                                onTap: () {
                                                  final newList = List<String>.from(selectedItems)..remove(e);
                                                  onSelectionChanged(newList);
                                                },
                                                child: const Icon(LucideIcons.x, size: 12, color: ColorPalette.primary))
                                          ])))
                                      .toList())),
                      const Icon(LucideIcons.plus, size: 16, color: ColorPalette.textMuted),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  Widget _buildSearchOverlay(bool isMobile) {
    if (isMobile) return const SizedBox.shrink();
    return Container(
      width: 240,
      height: 36,
      margin: const EdgeInsets.only(right: 16),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search groups...',
          hintStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted),
          prefixIcon: const Icon(LucideIcons.search, size: 14, color: ColorPalette.textMuted),
          filled: true,
          fillColor: ColorPalette.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
        ),
      ),
    );
  }

  Widget _buildDatabaseHeader() {
    return Row(
      children: [
        Text(
          'REGISTRY DATABASE',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: ColorPalette.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        Gaps.w12,
        Text(
          '(${_filteredItemGroups.length} ENTRIES)',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textMuted),
        ),
      ],
    );
  }

  Widget _buildRegistrationModule(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorPalette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildGroupDropdown(),
                        const SizedBox(height: 24),
                        _buildGSMDropdown(),
                        const SizedBox(height: 24),
                        _buildRateField(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      children: [
                        _buildMultiSelectField(
                          label: 'Assigned Item Names', 
                          items: _itemNames, 
                          selectedItems: _selectedItemNames, 
                          icon: LucideIcons.tag, 
                          onSelectionChanged: (list) => setState(() { _selectedItemNames.clear(); _selectedItemNames.addAll(list); })
                        ),
                        const SizedBox(height: 24),
                        _buildMultiSelectField(
                          label: 'Available Colours', 
                          items: _colours, 
                          selectedItems: _selectedColours, 
                          icon: LucideIcons.palette, 
                          onSelectionChanged: (list) => setState(() { _selectedColours.clear(); _selectedColours.addAll(list); })
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildGroupDropdown(), const SizedBox(height: 24),
                  _buildGSMDropdown(), const SizedBox(height: 24),
                  _buildRateField(), const SizedBox(height: 24),
                  _buildMultiSelectField(label: 'Assigned Item Names', items: _itemNames, selectedItems: _selectedItemNames, icon: LucideIcons.tag, onSelectionChanged: (list) => setState(() { _selectedItemNames.clear(); _selectedItemNames.addAll(list); })),
                  const SizedBox(height: 24),
                  _buildMultiSelectField(label: 'Available Colours', items: _colours, selectedItems: _selectedColours, icon: LucideIcons.palette, onSelectionChanged: (list) => setState(() { _selectedColours.clear(); _selectedColours.addAll(list); })),
                ],
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: isMobile ? double.infinity : 200,
              child: _buildSubmitButton(),
            ),
          ],
        ),
      ),
    );
  }
}
