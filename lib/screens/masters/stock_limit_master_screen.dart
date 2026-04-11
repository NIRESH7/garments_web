import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/layout_constants.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/custom_dropdown_field.dart';
import '../../widgets/responsive_wrapper.dart';
import '../../widgets/modern_data_table.dart';


class StockLimitMasterScreen extends StatefulWidget {
  const StockLimitMasterScreen({super.key});

  @override
  State<StockLimitMasterScreen> createState() => _StockLimitMasterScreenState();
}

class _StockLimitMasterScreenState extends State<StockLimitMasterScreen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();

  String? _selectedLotName;
  String? _selectedDia;
  final _minWeightController = TextEditingController();
  final _maxWeightController = TextEditingController();
  final _manualAdjustmentController = TextEditingController();

  List<String> _lotNames = [];
  List<String> _dias = [];
  List<Map<String, dynamic>> _currentLimits = [];
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
  }

  List<Map<String, dynamic>> get _filteredLimits {
    if (_searchQuery.isEmpty) return _currentLimits;
    return _currentLimits.where((item) {
      final lot = item['lotName']?.toString().toLowerCase() ?? '';
      final dia = item['dia']?.toString().toLowerCase() ?? '';
      return lot.contains(_searchQuery) || dia.contains(_searchQuery);
    }).toList();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _api.getCategories();
      final limitsData = await _api.getStockLimits();

      setState(() {
        _lotNames = _getValues(categories, 'Lot Name');
        _dias = _getValues(categories, 'dia');
        _currentLimits = (limitsData as List).map<Map<String, dynamic>>((v) => Map<String, dynamic>.from(v)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _getValues(List<dynamic> categories, String name) {
    try {
      final match = categories.firstWhere(
        (c) => (c['name'] ?? '').toString().toLowerCase() == name.toLowerCase(),
        orElse: () => null,
      );
      if (match == null) return [];
      final vals = match['values'] as List;
      return vals.map((v) => v['name'].toString()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final success = await _api.saveStockLimit({
        'lotName': _selectedLotName,
        'dia': _selectedDia,
        'minWeight': double.tryParse(_minWeightController.text) ?? 0,
        'maxWeight': double.tryParse(_maxWeightController.text) ?? 0,
        'manualAdjustment': double.tryParse(_manualAdjustmentController.text) ?? 0,
      });

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inventory thresholds finalized'), backgroundColor: ColorPalette.success),
        );
        _minWeightController.clear(); _maxWeightController.clear(); _manualAdjustmentController.clear();
        setState(() { _selectedLotName = null; _selectedDia = null; });
        await _loadAllData();
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registry Error: $e'), backgroundColor: ColorPalette.error)); }
    finally { if (mounted) setState(() => _isSaving = false); }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    // API might not have deleteStockLimit for specific ID, checking typical pattern
    final success = await _api.deleteStockLimit(item['_id']);
    if (success) await _loadAllData();
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
              'STOCK LIMIT MASTER',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                color: ColorPalette.textPrimary,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'INVENTORY THRESHOLDS & MONITORING',
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
          if (!isMobile)
            Container(
              width: 280,
              height: 38,
              margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Search lots or diameters...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted.withOpacity(0.5)),
                  prefixIcon: const Icon(LucideIcons.search, size: 14, color: ColorPalette.textMuted),
                  filled: true,
                  fillColor: ColorPalette.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
                ),
              ),
            ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Form Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ColorPalette.border),
                      ),
                      child: Column(
                        children: [
                          _buildModuleHeader('THRESHOLD CONFIGURATION', LucideIcons.shieldCheck, ColorPalette.warning),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  if (!isMobile) ...[
                                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Expanded(child: _buildLotDropdown()),
                                      Gaps.w24,
                                      Expanded(child: _buildDiaDropdown()),
                                    ]),
                                    Gaps.h24,
                                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Expanded(child: _buildModernInput(_minWeightController, 'SAFETY MINIMUM (KG)', LucideIcons.arrowDownToLine, 'Min')),
                                      Gaps.w20,
                                      Expanded(child: _buildModernInput(_maxWeightController, 'CAPACITY MAXIMUM (KG)', LucideIcons.arrowUpToLine, 'Max')),
                                      Gaps.w20,
                                      Expanded(child: _buildModernInput(_manualAdjustmentController, 'STOCK CALIBRATION', LucideIcons.plusCircle, '±Kg')),
                                    ]),
                                  ] else ...[
                                    _buildLotDropdown(), Gaps.h24,
                                    _buildDiaDropdown(), Gaps.h24,
                                    _buildModernInput(_minWeightController, 'SAFETY MINIMUM (KG)', LucideIcons.arrowDownToLine, 'Min'), Gaps.h24,
                                    _buildModernInput(_maxWeightController, 'CAPACITY MAXIMUM (KG)', LucideIcons.arrowUpToLine, 'Max'), Gaps.h24,
                                    _buildModernInput(_manualAdjustmentController, 'STOCK CALIBRATION', LucideIcons.plusCircle, '±Kg'),
                                  ],
                                  Gaps.h32,
                                  SizedBox(width: double.infinity, child: _buildSubmitButton()),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gaps.h32,
                    
                    _buildDatabaseHeader(),
                    Gaps.h16,
                    
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ColorPalette.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ModernDataTable(
                        key: ValueKey(_filteredLimits.length),
                        columns: const ['lotName', 'dia', 'minWeight', 'maxWeight'],
                        rows: _filteredLimits,
                        onDelete: _delete,
                        emptyMessage: 'No monitoring thresholds documented',
                      ),
                    ),
                    Gaps.h48,
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModuleHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: ColorPalette.background.withOpacity(0.3),
        border: const Border(bottom: BorderSide(color: ColorPalette.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          Gaps.w12,
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: ColorPalette.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildLotDropdown() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('BATCH CLASSIFICATION', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2)),
      Gaps.h8,
      CustomDropdownField(label: '', value: _selectedLotName, items: _lotNames, onChanged: (v) => setState(() => _selectedLotName = v), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
    ]);
  }

  Widget _buildDiaDropdown() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('DIAMETER CONTEXT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2)),
      Gaps.h8,
      CustomDropdownField(label: '', value: _selectedDia, items: _dias, onChanged: (v) => setState(() => _selectedDia = v), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
    ]);
  }

  Widget _buildModernInput(TextEditingController controller, String label, IconData icon, String suffix) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2)),
      Gaps.h8,
      TextFormField(
        controller: controller,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: ColorPalette.textPrimary),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 14, color: ColorPalette.textMuted),
          suffixText: suffix, 
          suffixStyle: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: ColorPalette.textMuted),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (v) => (label.contains('CALIBRATION')) ? null : (v == null || v.isEmpty ? 'Required' : null),
      ),
    ]);
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: ColorPalette.textPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 0,
      ),
      child: _isSaving
          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.save, size: 16),
                Gaps.w12,
                Text(
                  'FINALIZE THRESHOLDS',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
                ),
              ],
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
          '(${_filteredLimits.length} ENTRIES)',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textMuted),
        ),
      ],
    );
  }
}

