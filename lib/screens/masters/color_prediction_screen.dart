import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/layout_constants.dart';
import '../../services/color_prediction_service.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/custom_dropdown_field.dart';
import '../../widgets/responsive_wrapper.dart';
import '../../widgets/modern_data_table.dart';

class ColorPredictionScreen extends StatefulWidget {
  const ColorPredictionScreen({super.key});

  @override
  State<ColorPredictionScreen> createState() => _ColorPredictionScreenState();
}

class _ColorPredictionScreenState extends State<ColorPredictionScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _dyePercentageController = TextEditingController(text: '2.0');
  final _gsmController = TextEditingController(text: '160');
  final _saltController = TextEditingController(text: '40');
  final _sodaAshController = TextEditingController(text: '10');
  final _aceticAcidController = TextEditingController(text: '0.5');
  final _dyeNamesController = TextEditingController();

  // Mode Selection
  String _fabricType = 'cotton';
  String _dyeType = 'reactive';
  bool _useAI = true;
  bool _isPredicting = false;
  bool _isAddingColour = false;
  
  ColorPredictionResult? _result;
  final _api = MobileApiService();

  List<Map<String, dynamic>> _registeredColors = [];
  bool _isLoadingRegistry = true;

  Color? _manualSelectedColor;
  final List<Color> _paletteColors = [
    Colors.red, Colors.pink, Colors.purple, Colors.deepPurple, Colors.indigo,
    Colors.blue, Colors.lightBlue, Colors.cyan, Colors.teal, Colors.green,
    Colors.lightGreen, Colors.lime, Colors.yellow, Colors.amber, Colors.orange,
    Colors.deepOrange, Colors.brown, Colors.grey, Colors.blueGrey, Colors.black,
  ];

  final _manualColorNameController = TextEditingController();
  final _manualColorCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _manualColorCodeController.addListener(_onColorCodeChanged);
    _loadRegistry();
  }

  void _onColorCodeChanged() {
    final text = _manualColorCodeController.text.trim();
    if (text.length == 7 && text.startsWith('#')) {
      try {
        final color = Color(int.parse(text.replaceAll('#', '0xFF')));
        setState(() => _manualSelectedColor = color);
      } catch (_) {}
    }
  }

  Future<void> _loadRegistry() async {
    setState(() => _isLoadingRegistry = true);
    try {
      final categories = await _api.getCategories();
      final coloursCat = categories.firstWhere(
        (c) => (c['name'] as String).toLowerCase() == 'colours',
        orElse: () => {'values': []},
      );
      final vals = coloursCat['values'] ?? [];
      setState(() {
        _registeredColors = (vals as List).map<Map<String, dynamic>>((v) {
          if (v is Map) return Map<String, dynamic>.from(v);
          return {'name': v.toString()};
        }).toList();
        _isLoadingRegistry = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingRegistry = false);
    }
  }

  @override
  void dispose() {
    _dyePercentageController.dispose();
    _gsmController.dispose();
    _saltController.dispose();
    _sodaAshController.dispose();
    _aceticAcidController.dispose();
    _dyeNamesController.dispose();
    _manualColorNameController.dispose();
    _manualColorCodeController.dispose();
    super.dispose();
  }

  void _predict() async {
    if (_useAI) { if (!_formKey.currentState!.validate()) return; }
    else {
      if (_manualColorCodeController.text.isEmpty || _manualColorNameController.text.isEmpty) {
        _showToast('Please specify color identity', Colors.orange);
        return;
      }
      final hex = _manualColorCodeController.text.trim();
      if (!RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').hasMatch(hex)) {
        _showToast('Invalid Hex Specification', Colors.red);
        return;
      }
    }

    setState(() => _isPredicting = true);
    if (_useAI) {
      final dyeNames = _dyeNamesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final result = await ColorPredictionService.predictWithAI(
        fabricType: _fabricType,
        fabricGSM: double.tryParse(_gsmController.text) ?? 160,
        dyeType: _dyeType,
        dyePercentage: double.tryParse(_dyePercentageController.text) ?? 2.0,
        dyeNames: dyeNames,
        saltPercentage: double.tryParse(_saltController.text) ?? 0,
        sodaAshPercentage: double.tryParse(_sodaAshController.text) ?? 0,
        aceticAcidPercentage: double.tryParse(_aceticAcidController.text) ?? 0,
      );
      setState(() { _result = result; _isPredicting = false; });
    } else {
      String name = _manualColorNameController.text.trim();
      String hex = _manualColorCodeController.text.trim();
      if (!hex.startsWith('#')) hex = '#$hex';
      final valueToSave = "$name (${hex.toUpperCase()})";
      await _addToColours(valueToSave);
      setState(() => _isPredicting = false);
      _reset();
    }
  }

  void _showToast(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, backgroundColor: bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  }

  Future<void> _addToColours(String colorName) async {
    setState(() => _isAddingColour = true);
    try {
      final categories = await _api.getCategories();
      var coloursCat = categories.firstWhere((c) => (c['name'] as String).toLowerCase() == 'colours', orElse: () => null);
      if (coloursCat == null) {
        await _api.createCategory('Colours');
        final updated = await _api.getCategories();
        coloursCat = updated.firstWhere((c) => (c['name'] as String).toLowerCase() == 'colours', orElse: () => null);
      }
      if (coloursCat == null) throw Exception('Colours registry unavailable');

      final success = await _api.addCategoryValue(coloursCat['_id'], colorName);
      if (success) {
        _showToast('"$colorName" documented in registry', ColorPalette.success);
        await _loadRegistry();
      }
    } catch (e) {
      if (mounted) _showToast('Registry error: $e', ColorPalette.error);
    } finally {
      if (mounted) setState(() => _isAddingColour = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final categories = await _api.getCategories();
    final coloursCat = categories.firstWhere((c) => (c['name'] as String).toLowerCase() == 'colours');
    final success = await _api.deleteCategoryValue(coloursCat['_id'], item['name'].toString());
    if (success) await _loadRegistry();
  }

  void _reset() {
    setState(() {
      _result = null; _dyeNamesController.clear(); _dyePercentageController.text = '2.0'; _gsmController.text = '160';
      _saltController.text = '40'; _sodaAshController.text = '10'; _aceticAcidController.text = '0.5';
      _fabricType = 'cotton'; _dyeType = 'reactive'; _manualSelectedColor = null; _manualColorNameController.clear(); _manualColorCodeController.clear();
    });
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
              'CHROMATICS AGENT',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                color: ColorPalette.textPrimary,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'AI PREDICTION & COLOR REGISTRY',
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
          if (_result != null) IconButton(icon: const Icon(LucideIcons.rotateCcw, size: 16), onPressed: _reset, color: ColorPalette.textMuted),
          IconButton(onPressed: _loadRegistry, icon: const Icon(LucideIcons.refreshCw, size: 16, color: ColorPalette.textMuted)),
          Gaps.w16,
        ],
      ),
      body: ResponsiveWrapper(
        maxWidth: 1200,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildModeSelector(isMobile),
              Gaps.h32,
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _useAI ? _buildAIForm(isMobile) : _buildManualInterface(isMobile),
              ),
              Gaps.h32,
              if (_result != null) ...[
                _buildResultDisplay(isMobile),
                Gaps.h32,
              ],
              _buildDatabaseHeader(),
              Gaps.h16,
              _isLoadingRegistry 
                ? const Center(child: Padding(padding: EdgeInsets.all(64.0), child: CircularProgressIndicator()))
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ColorPalette.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ModernDataTable(
                      key: ValueKey(_registeredColors.length),
                      columns: const ['name'],
                      rows: _registeredColors,
                      onDelete: _delete,
                      emptyMessage: 'No registered colors documented',
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), 
        borderRadius: BorderRadius.circular(8), 
        border: Border.all(color: ColorPalette.border)
      ),
      child: Row(
        children: [
          _buildModeButton(LucideIcons.filePlus, 'Direct Registry', !_useAI),
          Gaps.w4,
          _buildModeButton(LucideIcons.sparkles, 'AI Agent Prediction', _useAI),
        ],
      ),
    );
  }

  Widget _buildModeButton(IconData icon, String label, bool active) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() { _useAI = label.contains('AI'); if (!_useAI) _result = null; }),
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent, 
            borderRadius: BorderRadius.circular(6), 
            border: Border.all(color: active ? ColorPalette.border : Colors.transparent),
            boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? ColorPalette.primary : ColorPalette.textMuted),
              Gaps.w12,
              Text(
                label.toUpperCase(), 
                style: GoogleFonts.inter(
                  fontSize: 10, 
                  fontWeight: FontWeight.w800, 
                  letterSpacing: 0.5,
                  color: active ? ColorPalette.textPrimary : ColorPalette.textMuted
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIForm(bool isMobile) {
    return Container(
      key: const ValueKey('ai_form'),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(8), 
        border: Border.all(color: ColorPalette.border),
      ),
      child: Column(children: [
        _buildModuleHeader('AI BEHAVIORAL MODELING', LucideIcons.bot, ColorPalette.primary),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(children: [
              if (!isMobile)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _buildFabricDropdown()),
                  Gaps.w24,
                  Expanded(child: _buildDyeDropdown()),
                ])
              else ...[ _buildFabricDropdown(), Gaps.h24, _buildDyeDropdown() ],
              Gaps.h24,
              if (!isMobile)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _buildModernInput(_gsmController, 'FABRIC DENSITY', LucideIcons.layers, 'GSM')),
                  Gaps.w24,
                  Expanded(child: _buildModernInput(_dyePercentageController, 'DYE CONCENTRATION', LucideIcons.percent, '%')),
                ])
              else ...[ _buildModernInput(_gsmController, 'FABRIC DENSITY', LucideIcons.layers, 'GSM'), Gaps.h24, _buildModernInput(_dyePercentageController, 'DYE CONCENTRATION', LucideIcons.percent, '%') ],
              Gaps.h24,
              _buildDyeNamesField(),
              Gaps.h32,
              _buildAuxiliaryChemistry(isMobile),
              Gaps.h32,
              SizedBox(width: double.infinity, child: _buildExecutionButton()),
            ]),
          ),
        ),
      ]),
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

  Widget _buildFabricDropdown() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('MATERIAL BASE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2)),
      Gaps.h8,
      CustomDropdownField(label: '', value: _fabricType, items: const ['cotton', 'polyester', 'blend'], onChanged: (v) => setState(() => _fabricType = v!)),
    ]);
  }

  Widget _buildDyeDropdown() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('DYE TECHNOLOGY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2)),
      Gaps.h8,
      CustomDropdownField(label: '', value: _dyeType, items: const ['reactive', 'disperse', 'vat'], onChanged: (v) => setState(() => _dyeType = v!)),
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
          suffixStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: ColorPalette.textMuted),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (v) => (v == null || v.isEmpty || double.tryParse(v) == null) ? 'Required' : null,
      ),
    ]);
  }

  Widget _buildDyeNamesField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('CHEMICAL DYE IDENTIFIERS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2)),
      Gaps.h8,
      TextFormField(
        controller: _dyeNamesController,
        maxLines: 2,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: ColorPalette.textPrimary),
        decoration: InputDecoration(
          hintText: 'e.g. Reactive Red, Blue 19...',
          hintStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted.withOpacity(0.5)),
          prefixIcon: const Icon(LucideIcons.beaker, size: 16, color: ColorPalette.textMuted),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
    ]);
  }

  Widget _buildAuxiliaryChemistry(bool isMobile) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(LucideIcons.flaskConical, size: 14, color: ColorPalette.textMuted),
        Gaps.w12,
        Text('AUXILIARY CHEMISTRY (G/L)', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1, color: ColorPalette.textMuted)),
      ]),
      Gaps.h20,
      if (!isMobile)
        Row(children: [
          Expanded(child: _buildChemInput(_saltController, 'SALT')),
          Gaps.w12,
          Expanded(child: _buildChemInput(_sodaAshController, 'SODA')),
          Gaps.w12,
          Expanded(child: _buildChemInput(_aceticAcidController, 'ACID')),
        ])
      else
        Column(children: [
          _buildChemInput(_saltController, 'SALT'), Gaps.h12,
          _buildChemInput(_sodaAshController, 'SODA'), Gaps.h12,
          _buildChemInput(_aceticAcidController, 'ACID'),
        ]),
    ]);
  }

  Widget _buildChemInput(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller, 
      textAlign: TextAlign.center, 
      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: ColorPalette.textPrimary), 
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: ColorPalette.textMuted), 
        filled: true, fillColor: ColorPalette.background.withOpacity(0.4),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.primary, width: 1)),
      )
    );
  }

  Widget _buildManualInterface(bool isMobile) {
    return Container(
      key: const ValueKey('manual_form'),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(8), 
        border: Border.all(color: ColorPalette.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildModuleHeader('DIRECT ENTRY REGISTRATION', LucideIcons.palette, ColorPalette.secondary),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!isMobile)
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(flex: 2, child: _buildManualNameField()),
                Gaps.w20,
                Expanded(flex: 1, child: _buildManualHexField()),
                Gaps.w20,
                _buildManualPreview(),
              ])
            else ...[
              _buildManualNameField(), Gaps.h20,
              Row(children: [Expanded(child: _buildManualHexField()), Gaps.w16, _buildManualPreview()]),
            ],
            Gaps.h32,
            Text('STANDARD PALETTE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1, color: ColorPalette.textMuted)),
            Gaps.h16,
            _buildPaletteGrid(),
            Gaps.h32,
            SizedBox(width: double.infinity, child: _buildExecutionButton()),
          ]),
        ),
      ]),
    );
  }

  Widget _buildManualNameField() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('COLOR IDENTITY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2)),
    Gaps.h8,
    TextFormField(
      controller: _manualColorNameController, 
      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ColorPalette.textPrimary),
      decoration: InputDecoration(
        prefixIcon: const Icon(LucideIcons.tag, size: 14, color: ColorPalette.textMuted),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
      )
    ),
  ]);
  
  Widget _buildManualHexField() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('HEX CODE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textSecondary, letterSpacing: 0.2)),
    Gaps.h8,
    TextFormField(
      controller: _manualColorCodeController, 
      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ColorPalette.textPrimary),
      decoration: InputDecoration(
        prefixIcon: const Icon(LucideIcons.hash, size: 14, color: ColorPalette.textMuted),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
      )
    ),
  ]);

  Widget _buildManualPreview() => Container(
    width: 54, height: 54, 
    decoration: BoxDecoration(
      color: _manualSelectedColor ?? Colors.grey.shade50, 
      borderRadius: BorderRadius.circular(4), 
      border: Border.all(color: ColorPalette.border)
    )
  );

  Widget _buildPaletteGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _paletteColors.map((color) {
        final active = _manualSelectedColor == color;
        return GestureDetector(
          onTap: () => setState(() { 
            _manualSelectedColor = color; 
            _manualColorCodeController.text = '#${color.value.toRadixString(16).substring(2).toUpperCase()}'; 
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color, 
              shape: BoxShape.circle, 
              border: Border.all(color: active ? ColorPalette.textPrimary : Colors.white, width: 2),
              boxShadow: active ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6)] : null
            ),
            child: active ? const Icon(LucideIcons.check, color: Colors.white, size: 12) : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExecutionButton() {
    return ElevatedButton(
      onPressed: _isPredicting ? null : _predict,
      style: ElevatedButton.styleFrom(
        backgroundColor: ColorPalette.textPrimary, 
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), 
        elevation: 0,
      ),
      child: _isPredicting
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(_useAI ? LucideIcons.zap : LucideIcons.plus, size: 16), 
              Gaps.w12,
              Text(_useAI ? 'COMPUTE PREDICTION' : 'DOCUMENT TO REGISTRY', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5))
            ]),
    );
  }

  Widget _buildResultDisplay(bool isMobile) {
    final result = _result!;
    final color = Color.fromARGB(255, result.red, result.green, result.blue);
    final isDark = color.computeLuminance() < 0.5;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorPalette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          height: 140,
          color: color,
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              result.colorName.toUpperCase(), 
              style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)
            ),
            Gaps.h4,
            Text(
              result.hexColor.toUpperCase(), 
              style: GoogleFonts.inter(color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)
            ),
          ])),
        ),
        _buildAnalysisReport(result, isMobile),
        _buildActionFooter(result),
      ]),
    );
  }

  Widget _buildAnalysisReport(ColorPredictionResult result, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Row(children: [
          Icon(LucideIcons.activity, size: 14, color: ColorPalette.textMuted),
          Gaps.w12,
          Text('PREDICTION TELEMETRY', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1, color: ColorPalette.textMuted))
        ]),
        Gaps.h24,
        Row(children: [
          Expanded(child: _buildMetrics('SHADE', result.shadeLevel.toUpperCase())),
          Expanded(child: _buildMetrics('TONE', result.tone.toUpperCase())),
          Expanded(child: _buildMetrics('RGB', result.rgb)),
          Expanded(child: _buildMetrics('CONFIDENCE', result.confidence.toUpperCase())),
        ]),
      ]),
    );
  }

  Widget _buildMetrics(String label, String value) {
    return Column(children: [
      Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5)),
      Gaps.h8,
      Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: ColorPalette.textPrimary)),
    ]);
  }

  Widget _buildActionFooter(ColorPredictionResult result) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () { Clipboard.setData(ClipboardData(text: result.toJson().toString())); _showToast('Payload copied', ColorPalette.secondary); }, 
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), side: const BorderSide(color: ColorPalette.border)), 
          child: Text('COPY ANALYTICS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: ColorPalette.textMuted))
        )),
        Gaps.w12,
        Expanded(child: ElevatedButton(
          onPressed: _isAddingColour ? null : () => _addToColours(result.colorName), 
          style: ElevatedButton.styleFrom(backgroundColor: ColorPalette.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), elevation: 0), 
          child: _isAddingColour ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('DOCUMENT TO REGISTRY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900))
        )),
      ]),
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
          '(${_registeredColors.length} ENTRIES)',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textMuted),
        ),
      ],
    );
  }
}
