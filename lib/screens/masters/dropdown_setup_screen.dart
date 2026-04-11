import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/layout_constants.dart';
import '../../widgets/custom_dropdown_field.dart';
import '../../widgets/responsive_wrapper.dart';

import '../../widgets/modern_data_table.dart';

class DropdownSetupScreen extends StatefulWidget {
  const DropdownSetupScreen({super.key});

  @override
  State<DropdownSetupScreen> createState() => _DropdownSetupScreenState();
}

class _DropdownSetupScreenState extends State<DropdownSetupScreen> {
  final _api = MobileApiService();
  final _valueController = TextEditingController();
  final _gsmController = TextEditingController();
  final _knittingDiaController = TextEditingController(); 
  final _cuttingDiaController = TextEditingController(); 
  XFile? _selectedXFile;
  final ImagePicker _picker = ImagePicker();

  final List<String> _staticCategoryNames = [
    'Colours', 'Dia', 'Item', 'Item Name', 'Lot Name', 'GSM', 'Size', 
    'Efficiency', 'Dyeing', 'Process', 'Party Name', 'Rack Name', 
    'Pallet No', 'Accessories', 'Accessories Group',
  ];

  String? _selectedCategoryId;
  List<dynamic> _categories = [];
  List<dynamic> _values = [];
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  List<dynamic> get _filteredValues {
    if (_searchQuery.isEmpty) return _values;
    return _values.where((v) {
      String name = '';
      if (v is String) name = v;
      else if (v is Map) name = v['name']?.toString() ?? '';
      return name.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getCategories();
      final List<Map<String, dynamic>> filteredCategories = [];
      final Set<String> matchedIds = {};

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

        final serverCat = res.firstWhere((c) {
          final String serverName = (c['name'] as String? ?? '').trim().toLowerCase();
          return aliases.contains(serverName);
        }, orElse: () => <String, dynamic>{});

        if (serverCat.isNotEmpty) {
          filteredCategories.add(serverCat);
          matchedIds.add(serverCat['_id'].toString());
        } else {
          filteredCategories.add({'_id': 'new_$name', 'name': name, 'values': []});
        }
      }

      for (var serverCat in res) {
        final String id = serverCat['_id'].toString();
        if (!matchedIds.contains(id)) filteredCategories.add(serverCat);
      }

      setState(() {
        _categories = filteredCategories;
        if (_selectedCategoryId == null && _categories.isNotEmpty) {
          _selectedCategoryId = _categories.first['_id'];
        }
        _syncValuesWithSelectedCategory();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _syncValuesWithSelectedCategory() {
    if (_selectedCategoryId == null) { _values = []; return; }
    if (_selectedCategoryId!.startsWith('new_')) { _values = []; return; }
    final category = _categories.firstWhere((c) => c['_id'] == _selectedCategoryId, orElse: () => <String, dynamic>{});
    final vals = category['values'];
    _values = (vals is List) ? vals : [];
  }

  void _loadValues() { setState(() => _syncValuesWithSelectedCategory()); }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) setState(() => _selectedXFile = image);
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(LucideIcons.image, size: 20), title: Text('Gallery', style: GoogleFonts.inter(fontSize: 14)), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
              ListTile(leading: const Icon(LucideIcons.camera, size: 20), title: Text('Camera', style: GoogleFonts.inter(fontSize: 14)), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
              const SizedBox(height: 8),
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
      if (categoryId.startsWith('new_')) {
        final categoryName = _categories.firstWhere((c) => c['_id'] == _selectedCategoryId)['name'];
        final success = await _api.createCategory(categoryName);
        if (success) {
          final res = await _api.getCategories();
          final newCat = res.firstWhere((c) => (c['name'] as String).toLowerCase() == categoryName.toLowerCase());
          categoryId = newCat['_id'];
          setState(() => _selectedCategoryId = categoryId);
          await _loadCategories();
        } else { setState(() => _isLoading = false); return; }
      }

      String? photoUrl;
      if (_selectedXFile != null && (_isColoursCategory || _isAccessoriesCategory)) {
        photoUrl = await _api.uploadImage(_selectedXFile!);
      }

      final success = await _api.addCategoryValue(
        categoryId, _valueController.text.trim(), photo: photoUrl,
        gsm: _isColoursCategory ? _gsmController.text.trim() : null,
        knittingDia: _isDiaCategory ? _knittingDiaController.text.trim() : null,
        cuttingDia: _isDiaCategory ? _cuttingDiaController.text.trim() : null,
      );

      if (success) {
        _valueController.clear(); _gsmController.clear(); _knittingDiaController.clear(); _cuttingDiaController.clear();
        setState(() => _selectedXFile = null);
        await _loadCategories(); _loadValues();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registry entry finalized'), backgroundColor: ColorPalette.success));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: ColorPalette.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final valueName = item['name'].toString();
    if (_selectedCategoryId == null) return;
    final success = await _api.deleteCategoryValue(_selectedCategoryId!, valueName);
    if (success) { await _loadCategories(); _loadValues(); }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = LayoutConstants.isMobile(context);

    // Prepare table rows from values
    final List<Map<String, dynamic>> tableRows = _values.map((v) {
      if (v is String) return {'name': v};
      if (v is Map) return Map<String, dynamic>.from(v);
      return {'name': v.toString()};
    }).toList();

    return Scaffold(
      backgroundColor: ColorPalette.background,
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'REGISTRY SETUP',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                color: ColorPalette.textPrimary,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'DROPDOWN DATA MANAGEMENT',
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
            onPressed: _loadCategories,
            icon: const Icon(LucideIcons.refreshCw, size: 16, color: ColorPalette.textMuted),
          ),
          Gaps.w16,
        ],
      ),
      body: ResponsiveWrapper(
        maxWidth: 1400,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. REGISTRATION MODULE
              _buildRegistrationModule(isMobile),
              
              Gaps.h32,

              // 2. DATABASE SECTION
              _buildDatabaseHeader(),
              
              Gaps.h16,

              _isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(64.0), child: CircularProgressIndicator()))
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      key: ValueKey('${_selectedCategoryId}_${_filteredValues.length}'),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ColorPalette.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ModernDataTable(
                        columns: const ['name'],
                        rows: _filteredValues.map((v) {
                          if (v is String) return {'name': v};
                          if (v is Map) return Map<String, dynamic>.from(v);
                          return {'name': v.toString()};
                        }).toList(),
                        onDelete: _delete,
                        emptyMessage: _selectedCategoryId == null ? 'Select a category context' : 'No entries documented yet',
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
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
          hintText: 'Search values...',
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
          '(${_filteredValues.length} ENTRIES)',
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
            if (!isMobile) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _buildCategoryDropdown()), const SizedBox(width: 20),
              Expanded(child: _buildValueTextField()),
            ]) else ...[ _buildCategoryDropdown(), const SizedBox(height: 24), _buildValueTextField() ],
            
            if (_isColoursCategory || _isAccessoriesCategory || _isDiaCategory) const SizedBox(height: 24),
            
            if (!isMobile) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_isColoursCategory) Expanded(child: _buildGSMField()),
              if (_isDiaCategory) ...[ Expanded(child: _buildKnittingDiaField()), const SizedBox(width: 20), Expanded(child: _buildCuttingDiaField()) ],
              if (_isColoursCategory || _isAccessoriesCategory) ...[
                if (_isColoursCategory) const SizedBox(width: 20),
                Expanded(child: _buildImagePicker(isMobile)),
              ],
            ]) else ...[
              if (_isColoursCategory) ...[ _buildGSMField(), const SizedBox(height: 24) ],
              if (_isDiaCategory) ...[ _buildKnittingDiaField(), const SizedBox(height: 24), _buildCuttingDiaField(), const SizedBox(height: 24) ],
              if (_isColoursCategory || _isAccessoriesCategory) _buildImagePicker(isMobile),
            ],
            
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, child: _buildSubmitButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONTEXT CATEGORY',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        CustomDropdownField(
          label: '',
          value: _categories.any((c) => c['_id'] == _selectedCategoryId) ? _categories.firstWhere((c) => c['_id'] == _selectedCategoryId)['name'] as String : null,
          items: _categories.map((c) => c['name'] as String).toList(),
          onChanged: (val) { if (val != null) { final cat = _categories.firstWhere((c) => c['name'] == val); setState(() => _selectedCategoryId = cat['_id']); _loadValues(); } },
        ),
      ],
    );
  }

  Widget _buildValueTextField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isDiaCategory ? 'PRIMARY DIMENSION' : 'ENTRY LABEL',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        TextField(
          controller: _valueController,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: ColorPalette.textPrimary),
          decoration: InputDecoration(
            hintText: _isDiaCategory ? 'e.g. 60' : 'Enter classification value...',
            hintStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted.withOpacity(0.6)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildGSMField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GSM REFERENCE',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        TextField(
          controller: _gsmController, keyboardType: TextInputType.number,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: ColorPalette.textPrimary),
          decoration: InputDecoration(
            hintText: 'Reference weight...',
            hintStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted.withOpacity(0.6)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildKnittingDiaField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KNITTING DIA',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        TextField(
          controller: _knittingDiaController, keyboardType: TextInputType.number,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: ColorPalette.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. 60',
            hintStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted.withOpacity(0.6)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildCuttingDiaField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CUTTING DIA',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        TextField(
          controller: _cuttingDiaController, keyboardType: TextInputType.number,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: ColorPalette.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. 62',
            hintStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted.withOpacity(0.6)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IDENTITY ATTACHMENT',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: ColorPalette.border)),
          child: Row(children: [
            if (_selectedXFile != null) Padding(padding: const EdgeInsets.only(right: 8), child: ClipRRect(borderRadius: BorderRadius.circular(2), child: kIsWeb ? Image.network(_selectedXFile!.path, width: 24, height: 24, fit: BoxFit.cover) : Image.file(File(_selectedXFile!.path), width: 24, height: 24, fit: BoxFit.cover)))
            else Container(width: 24, height: 24, decoration: BoxDecoration(color: ColorPalette.background, borderRadius: BorderRadius.circular(2), border: Border.all(color: ColorPalette.border)), child: Icon(LucideIcons.image, size: 12, color: ColorPalette.textMuted.withOpacity(0.5))),
            const SizedBox(width: 8),
            Expanded(child: Text(_selectedXFile == null ? 'Attach photo...' : 'Identity ready', style: GoogleFonts.inter(color: ColorPalette.textMuted, fontSize: 11, fontWeight: FontWeight.w500))),
            IconButton(onPressed: _showImageSourceDialog, icon: const Icon(LucideIcons.camera, size: 16, color: ColorPalette.textPrimary), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: _selectedCategoryId == null || _isLoading ? null : _add,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorPalette.textPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: _isLoading
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(
                'SAVE ENTRY',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
              ),
      ),
    );
  }

  String get _selectedCategoryName {
    if (_selectedCategoryId == null) return '';
    final cat = _categories.firstWhere((c) => c['_id'] == _selectedCategoryId, orElse: () => {'name': ''});
    return cat['name'] as String? ?? '';
  }

  bool get _isDiaCategory { final name = _selectedCategoryName.toLowerCase().trim(); return name == 'dia'; }
  bool get _isColoursCategory { final name = _selectedCategoryName.toLowerCase(); return name == 'colours' || name == 'colors' || name == 'colour' || name == 'color'; }
  bool get _isAccessoriesCategory { final name = _selectedCategoryName.toLowerCase().trim(); return name == 'accessories'; }

  void _showColorPreview(String valueName, String? photoUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(valueName, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (photoUrl != null && photoUrl.isNotEmpty)
                ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(ApiConstants.getImageUrl(photoUrl), width: 200, height: 200, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _largeColorCircle(valueName)))
              else _largeColorCircle(valueName),
            ],
          ),
          actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')) ],
        );
      },
    );
  }

  Widget _largeColorCircle(String value) {
    final color = _resolveColor(value) ?? const Color(0xFFBDBDBD);
    return Container(width: 150, height: 150, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300, width: 2), boxShadow: [ BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)) ]));
  }

  Widget _colorCircle(String value) {
    final color = _resolveColor(value) ?? const Color(0xFFBDBDBD);
    return Container(width: 32, height: 32, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade100, width: 1.5), boxShadow: [ BoxShadow(color: color.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)) ]));
  }

  Color? _resolveColor(String name) {
    final lower = name.toLowerCase().trim();
    const colorMap = <String, Color>{
      'red': Color(0xFFE53935), 'blue': Color(0xFF1E88E5), 'green': Color(0xFF43A047),
      'yellow': Color(0xFFFDD835), 'orange': Color(0xFFFB8C00), 'black': Color(0xFF212121),
      'white': Color(0xFFFAFAFA), 'grey': Color(0xFF9E9E9E), 'pink': Color(0xFFEC407A),
      'purple': Color(0xFF7B1FA2), 'brown': Color(0xFF6D4C41), 'maroon': Color(0xFF800000),
      'teal': Color(0xFF008080), 'navy': Color(0xFF0A1747), 'gold': Color(0xFFFFD700),
    };
    final hexMatch = RegExp(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})').firstMatch(name);
    if (hexMatch != null) { try { String hex = hexMatch.group(1)!; if (hex.length == 3) hex = hex[0] * 2 + hex[1] * 2 + hex[2] * 2; return Color(int.parse('0xFF$hex')); } catch (_) {} }
    if (colorMap.containsKey(lower)) return colorMap[lower]!;
    final sortedKeys = colorMap.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sortedKeys) { if (lower.contains(key)) return colorMap[key]; }
    return null;
  }
}
