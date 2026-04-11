import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/layout/web_layout_wrapper.dart';
import '../../widgets/custom_dropdown_field.dart';
import '../../widgets/responsive_wrapper.dart';
import '../../widgets/modern_data_table.dart';
import 'party_history_screen.dart';

class PartyMasterScreen extends StatefulWidget {
  final Map<dynamic, dynamic>? editParty;
  const PartyMasterScreen({super.key, this.editParty});

  @override
  State<PartyMasterScreen> createState() => _PartyMasterScreenState();
}

class _PartyMasterScreenState extends State<PartyMasterScreen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _mobileController = TextEditingController();
  final _gstController = TextEditingController();
  final _rateController = TextEditingController();

  String? _selectedProcess;
  List<String> _processes = [];
  List<Map<String, dynamic>> _parties = [];
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
    if (widget.editParty != null) {
      _nameController.text = widget.editParty!['name'] ?? '';
      _addressController.text = widget.editParty!['address'] ?? '';
      _mobileController.text = widget.editParty!['mobileNumber'] ?? '';
      _selectedProcess = widget.editParty!['process'];
      _gstController.text = widget.editParty!['gstIn'] ?? '';
      _rateController.text = (widget.editParty!['rate'] ?? '').toString();
    }
  }

  List<Map<String, dynamic>> get _filteredParties {
    if (_searchQuery.isEmpty) return _parties;
    return _parties.where((item) {
      final name = item['name']?.toString().toLowerCase() ?? '';
      final process = item['process']?.toString().toLowerCase() ?? '';
      final mobile = item['mobileNumber']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery) || process.contains(_searchQuery) || mobile.contains(_searchQuery);
    }).toList();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _api.getCategories();
      final partiesData = await _api.getParties();
      
      final processCategory = categories.firstWhere(
        (c) => c['name'] == 'Process',
        orElse: () => {'values': []},
      );

      setState(() {
        _processes = (processCategory['values'] as List).map<String>((v) {
          if (v is Map) return v['name'].toString();
          return v.toString();
        }).toList();
        _parties = List<Map<String, dynamic>>.from(partiesData);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final partyData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'mobileNumber': _mobileController.text.trim(),
        'gstIn': _gstController.text.trim().toUpperCase(),
        'rate': double.tryParse(_rateController.text) ?? 0.0,
        'process': _selectedProcess ?? '',
      };

      try {
        bool success;
        if (widget.editParty != null) {
          success = await _api.updateParty(widget.editParty!['_id'], partyData);
        } else {
          success = await _api.createParty(partyData);
        }

        if (!mounted) return;

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.editParty != null ? 'Registry details updated' : 'Party successfully documented'),
              backgroundColor: ColorPalette.success,
            ),
          );
          if (widget.editParty != null) {
            Navigator.pop(context, true);
          } else {
            _nameController.clear(); _addressController.clear(); _mobileController.clear(); _gstController.clear(); _rateController.clear();
            setState(() => _selectedProcess = null);
            await _loadAllData();
          }
        }
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registry Error: $e'), backgroundColor: ColorPalette.error)); }
      finally { if (mounted) setState(() => _isSaving = false); }
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final success = await _api.deleteParty(item['_id']);
    if (success) { await _loadAllData(); }
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
              'PARTY MASTER',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                color: ColorPalette.textPrimary,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'REGISTRY & VENDOR MANAGEMENT',
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
                          key: ValueKey(_filteredParties.length),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ColorPalette.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ModernDataTable(
                            columns: const ['name', 'process', 'mobileNumber', 'rate'],
                            rows: _filteredParties,
                            onDelete: _delete,
                            emptyMessage: 'No registered entities found in registry',
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

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IDENTIFICATION NAME',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        TextFormField(
          controller: _nameController,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: ColorPalette.textPrimary),
          decoration: InputDecoration(
            hintText: 'Full name or Business entity...',
            hintStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted.withOpacity(0.6)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
          ),
          validator: (v) => v!.isEmpty ? 'Identity name is required' : null,
        ),
      ],
    );
  }

  Widget _buildAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PHYSICAL ADDRESS',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        TextFormField(
          controller: _addressController,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: ColorPalette.textPrimary),
          decoration: InputDecoration(
            hintText: 'Office / Unit location details...',
            hintStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted.withOpacity(0.6)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildMobileField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONTACT IDENTIFIER',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        TextFormField(
          controller: _mobileController,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: ColorPalette.textPrimary),
          decoration: InputDecoration(
            hintText: 'Primary mobile number...',
            hintStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted.withOpacity(0.6)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
          ),
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildProcessField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OPERATIONAL CONTEXT',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        CustomDropdownField(
          label: '',
          value: _selectedProcess,
          items: _processes,
          onChanged: (val) => setState(() => _selectedProcess = val),
          validator: (v) => v == null || v.isEmpty ? 'Process context required' : null,
          hint: 'Select assigned process',
        ),
      ],
    );
  }

  Widget _buildGstField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TAX IDENTITY (GST)',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        TextFormField(
          controller: _gstController,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: ColorPalette.textPrimary),
          decoration: InputDecoration(
            hintText: '15-digit GST identification...',
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

  Widget _buildRateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AGREED RATE',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2),
        ),
        Gaps.h8,
        TextFormField(
          controller: _rateController,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: ColorPalette.textPrimary),
          decoration: InputDecoration(
            hintText: 'Base service charge...',
            hintStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted.withOpacity(0.6)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
          ),
          keyboardType: TextInputType.number,
          validator: (v) => v!.isEmpty ? 'Base rate is required' : null,
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
                widget.editParty != null ? 'SAVE CHANGES' : 'SAVE ENTRY',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
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
          '(${_filteredParties.length} ENTRIES)',
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
                        _buildNameField(),
                        const SizedBox(height: 24),
                        _buildMobileField(),
                        const SizedBox(height: 24),
                        _buildRateField(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      children: [
                        _buildProcessField(),
                        const SizedBox(height: 24),
                        _buildGstField(),
                        const SizedBox(height: 24),
                        _buildAddressField(),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildNameField(), const SizedBox(height: 24),
                  _buildProcessField(), const SizedBox(height: 24),
                  _buildMobileField(), const SizedBox(height: 24),
                  _buildGstField(), const SizedBox(height: 24),
                  _buildRateField(), const SizedBox(height: 24),
                  _buildAddressField(),
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