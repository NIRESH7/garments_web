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
              backgroundColor: const Color(0xFF10B981),
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
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registry Error: $e'), backgroundColor: const Color(0xFFEF4444))); }
      finally { if (mounted) setState(() => _isSaving = false); }
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final success = await _api.deleteParty(item['_id']);
    if (success) { await _loadAllData(); }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = LayoutConstants.isWeb(context);
    
    if (isWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFFDFDFD),
        body: WebLayoutWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWebHeader(),
              const SizedBox(height: 48),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Form Side
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: _buildRegistrationModule(false),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                    // Table Side
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDatabaseHeader(),
                          const SizedBox(height: 20),
                          Expanded(
                            child: _isLoading 
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                              : _buildDataTableContainer(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('PARTY MASTER', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF1F5F9), height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildRegistrationModule(true),
                    const SizedBox(height: 24),
                    _buildDatabaseHeader(),
                    const SizedBox(height: 12),
                    _buildDataTableContainer(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWebHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(LucideIcons.arrowLeft, size: 24, color: Color(0xFF1E293B)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Party Master',
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage registered parties, vendors, and shared resources',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        _buildSearchField(),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      width: 320,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(LucideIcons.search, size: 16, color: Color(0xFF94A3B8)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search entities...',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTableContainer() {
    return ModernDataTable(
      columns: const ['name', 'process', 'mobileNumber', 'rate'],
      rows: _filteredParties,
      onDelete: _delete,
      emptyMessage: 'No entities registered yet',
    );
  }

  Widget _buildRegistrationModule(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New Registration',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900, 
              fontSize: 20, 
              color: const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fill in the details to document a new party entry',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),
          _buildFieldLabel('IDENTITY NAME'),
          _buildTextField(_nameController, 'Full name or Business entity...', validator: (v) => v!.isEmpty ? 'Identity name is required' : null),
          const SizedBox(height: 24),
          _buildFieldLabel('OPERATIONAL CONTEXT'),
          CustomDropdownField(
            label: '',
            value: _selectedProcess,
            items: _processes,
            onChanged: (val) => setState(() => _selectedProcess = val),
            validator: (v) => v == null || v.isEmpty ? 'Process context required' : null,
            hint: 'Select assigned process',
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('CONTACT'),
                    _buildTextField(_mobileController, 'Mobile number...', keyboardType: TextInputType.phone),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('BASE RATE'),
                    _buildTextField(_rateController, 'Service charge...', keyboardType: TextInputType.number),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFieldLabel('TAX IDENTITY (GST)'),
          _buildTextField(_gstController, '15-digit GST identification...'),
          const SizedBox(height: 24),
          _buildFieldLabel('PHYSICAL ADDRESS'),
          _buildTextField(_addressController, 'Location details...', maxLines: 2),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      widget.editParty != null ? 'UPDATE REGISTRY' : 'DOCUMENT ENTRY',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF475569),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.normal),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E293B), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444))),
      ),
    );
  }

  Widget _buildDatabaseHeader() {
    return Row(
      children: [
        Text(
          'REGISTRY DATABASE',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1E293B),
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
          child: Text(
            '${_filteredParties.length} entries',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }
}