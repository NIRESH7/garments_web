import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/layout_constants.dart';
import '../../widgets/responsive_wrapper.dart';
import '../../widgets/modern_data_table.dart';

class CategoriesMasterScreen extends StatefulWidget {
  const CategoriesMasterScreen({super.key});

  @override
  State<CategoriesMasterScreen> createState() => _CategoriesMasterScreenState();
}

class _CategoriesMasterScreenState extends State<CategoriesMasterScreen> {
  final _api = MobileApiService();
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _list = [];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  List<Map<String, dynamic>> get _filteredList {
    if (_searchQuery.isEmpty) return _list;
    return _list.where((item) {
      final name = item['name']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery);
    }).toList();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getCategories();
      setState(() {
        _list = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: ColorPalette.error),
        );
      }
    }
  }

  Future<void> _add() async {
    if (_controller.text.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final success = await _api.createCategory(_controller.text.trim());
      if (success) {
        _controller.clear();
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category Documented Successfully'), backgroundColor: ColorPalette.success),
        );
      } else {
        throw Exception('Failed to finalize registry entry');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registry Error: $e'), backgroundColor: ColorPalette.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final success = await _api.deleteCategory(item['_id']);
    if (success) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry removed from registry')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove entry'), backgroundColor: ColorPalette.error),
      );
    }
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
              'CATEGORIES MASTER',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                color: ColorPalette.textPrimary,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'REGISTRY DATA MANAGEMENT',
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
            onPressed: _load,
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
                        key: ValueKey(_filteredList.length),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ColorPalette.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ModernDataTable(
                          columns: const ['name'],
                          rows: _filteredList,
                          onDelete: _delete,
                          emptyMessage: _searchQuery.isEmpty 
                              ? 'No classifications found in registry'
                              : 'No matches found for "$_searchQuery"',
                        ),
                      ),
                    ),
            ],
          ),
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
          '(${_filteredList.length} ENTRIES)',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textMuted),
        ),
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
          hintText: 'Search registry...',
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

  Widget _buildRegistrationModule(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: !isMobile
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _buildTextField()),
                      Gaps.w24,
                      SizedBox(width: 180, child: _buildSubmitButton()),
                    ],
                  )
                : Column(
                    children: [
                      _buildTextField(),
                      Gaps.h16,
                      _buildSubmitButton(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATEGORY NAME',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        TextField(
          controller: _controller,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: ColorPalette.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter classification name...',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: ColorPalette.textMuted.withOpacity(0.6)),
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

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _add,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorPalette.textPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: _isSaving
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(
                'SAVE ENTRY',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
              ),
      ),
    );
  }
}
