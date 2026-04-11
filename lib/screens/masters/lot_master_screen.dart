import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/layout_constants.dart';
import '../../widgets/custom_dropdown_field.dart';
import '../../widgets/responsive_wrapper.dart';

class LotMasterScreen extends StatefulWidget {
  const LotMasterScreen({super.key});

  @override
  State<LotMasterScreen> createState() => _LotMasterScreenState();
}

class _LotMasterScreenState extends State<LotMasterScreen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();

  final _lotNumberController = TextEditingController();
  final _remarksController = TextEditingController();
  String? _partyName, _process;

  List<String> _parties = [], _processes = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    try {
      final parties = await _api.getParties();
      final categories = await _api.getCategories();

      final List<String> extractedProcesses = [];
      final processMatches = categories.where((c) {
        final String catName = (c['name'] ?? '').toString().trim().toLowerCase();
        return catName == 'process';
      });

      for (var cat in processMatches) {
        final dynamic rawValues = cat['values'];
        if (rawValues is List) {
          for (var v in rawValues) {
            if (v is Map) { extractedProcesses.add((v['name'] ?? '').toString()); }
            else if (v != null) { extractedProcesses.add(v.toString()); }
          }
        }
      }

      setState(() {
        _parties = parties.map((m) => m['name'] as String).toList();
        _processes = extractedProcesses.where((s) => s.isNotEmpty).toSet().toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      _formKey.currentState!.save();
      final lotData = {
        'lotNumber': _lotNumberController.text.trim(),
        'partyName': _partyName!,
        'process': _process!,
        'remarks': _remarksController.text.trim(),
      };

      try {
        final success = await _api.createLot(lotData);
        if (success) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lot identification successfully registered'), backgroundColor: ColorPalette.success));
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registry allocation failed'), backgroundColor: ColorPalette.error));
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registry error: $e'), backgroundColor: ColorPalette.error));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = LayoutConstants.isMobile(context);

    return Scaffold(
      backgroundColor: ColorPalette.background,
      appBar: AppBar(
        title: Text(
          'Lot Registration',
          style: TextStyle(fontWeight: FontWeight.w800, color: ColorPalette.textPrimary, fontSize: isMobile ? 18 : 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ColorPalette.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveWrapper(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: ColorPalette.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(LucideIcons.binary, size: 20, color: ColorPalette.primary),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'LOT SPECIFICATIONS',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: ColorPalette.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Form Card
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: ColorPalette.softShadow,
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            if (!isMobile) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildLotField()),
                                  const SizedBox(width: 24),
                                  Expanded(child: _buildPartyDropdown()),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildProcessDropdown()),
                                  const SizedBox(width: 24),
                                  const Spacer(),
                                ],
                              ),
                            ] else ...[
                              _buildLotField(),
                              const SizedBox(height: 24),
                              _buildPartyDropdown(),
                              const SizedBox(height: 24),
                              _buildProcessDropdown(),
                            ],
                            const SizedBox(height: 24),
                            _buildRemarksField(),
                            const SizedBox(height: 48),
                            SizedBox(
                              width: double.infinity,
                              child: _buildSubmitButton(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Info Tip
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: ColorPalette.primary.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ColorPalette.primary.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.info, size: 18, color: ColorPalette.primary),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Note: Secondary parameters (Dia & Colour) are automatically associated during inward transactions.',
                                style: TextStyle(fontSize: 13, color: ColorPalette.textSecondary, height: 1.5, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLotField() {
    return TextFormField(
      controller: _lotNumberController,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      decoration: const InputDecoration(
        labelText: 'Lot Identifier',
        hintText: 'Reference number/name',
        prefixIcon: Icon(LucideIcons.hash, size: 18),
      ),
      validator: (val) => val!.isEmpty ? 'Identifier required' : null,
    );
  }

  Widget _buildPartyDropdown() {
    return CustomDropdownField(
      label: 'Associated Entity',
      items: _parties,
      value: _partyName,
      onChanged: (val) => setState(() => _partyName = val),
      validator: (val) => val == null || val.isEmpty ? 'Entity selection required' : null,
      hint: 'Select party',
    );
  }

  Widget _buildProcessDropdown() {
    return CustomDropdownField(
      label: 'Assigned Process Type',
      items: _processes,
      value: _process,
      onChanged: (val) => setState(() => _process = val),
      validator: (val) => val == null || val.isEmpty ? 'Process context required' : null,
      hint: 'Select process',
    );
  }

  Widget _buildRemarksField() {
    return TextFormField(
      controller: _remarksController,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      decoration: const InputDecoration(
        labelText: 'Technical Remarks',
        hintText: 'Optional documentation details',
        prefixIcon: Icon(LucideIcons.fileText, size: 18),
      ),
      maxLines: 3,
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _save,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        backgroundColor: ColorPalette.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: _isSaving
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text('FINALIZE REGISTRATION', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
    );
  }
}
