import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/color_palette.dart';
import '../../services/color_prediction_service.dart';
import '../../services/mobile_api_service.dart';

import '../../widgets/custom_dropdown_field.dart';

class ColorPredictionScreen extends StatefulWidget {
  const ColorPredictionScreen({super.key});

  @override
  State<ColorPredictionScreen> createState() => _ColorPredictionScreenState();
}

class _ColorPredictionScreenState extends State<ColorPredictionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _dyePercentageController = TextEditingController(text: '2.0');
  final _gsmController = TextEditingController(text: '160');
  final _saltController = TextEditingController(text: '40');
  final _sodaAshController = TextEditingController(text: '10');
  final _aceticAcidController = TextEditingController(text: '0.5');
  final _dyeNamesController = TextEditingController();

  // Dropdown values
  String _fabricType = 'cotton';
  String _dyeType = 'reactive';

  // Result
  ColorPredictionResult? _result;
  bool _isPredicting = false;
  bool _useAI = true; // Default to AI prediction
  bool _isAddingColour = false;
  final _api = MobileApiService();

  late AnimationController _pulseController;

  Color? _manualSelectedColor;
  final List<Color> _paletteColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
  ];

  final _manualColorNameController = TextEditingController();
  final _manualColorCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Listen to color code changes to update preview
    _manualColorCodeController.addListener(() {
      final text = _manualColorCodeController.text.trim();
      if (text.length == 7 && text.startsWith('#')) {
        try {
          final color = Color(int.parse(text.replaceAll('#', '0xFF')));
          setState(() {
            _manualSelectedColor = color;
          });
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
    if (_useAI) {
      if (!_formKey.currentState!.validate()) return;
    } else {
      if (_manualColorCodeController.text.isEmpty ||
          _manualColorNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter color name and code'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      // Validate Hex
      final hex = _manualColorCodeController.text.trim();
      if (!RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').hasMatch(hex)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invalid Hex Color Code'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }
    }

    if (_useAI) {
      setState(() => _isPredicting = true);
      final dyeNames = _dyeNamesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // AI-powered prediction via backend API
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

      setState(() {
        _result = result;
        _isPredicting = false;
      });
    } else {
      // Manual Color Selection - SAVE DIRECTLY
      setState(() => _isPredicting = true);

      String name = _manualColorNameController.text.trim();
      String hex = _manualColorCodeController.text.trim();
      if (!hex.startsWith('#')) hex = '#$hex';

      // Save as "Name (#HEX)" so it can be resolved in lists
      final valueToSave = "$name (${hex.toUpperCase()})";

      await _addToColours(valueToSave);
      setState(() => _isPredicting = false);
      _reset(); // Clear form after saving
    }
  }

  Future<void> _addToColours(String colorName) async {
    setState(() => _isAddingColour = true);
    try {
      // Get all categories
      final categories = await _api.getCategories();

      // Find the 'Colours' category (case-insensitive)
      var coloursCat = categories.firstWhere(
        (c) => (c['name'] as String).toLowerCase() == 'colours',
        orElse: () => null,
      );

      String categoryId;

      if (coloursCat == null) {
        // Create the Colours category if it doesn't exist
        await _api.createCategory('Colours');
        final updated = await _api.getCategories();
        coloursCat = updated.firstWhere(
          (c) => (c['name'] as String).toLowerCase() == 'colours',
          orElse: () => null,
        );
        if (coloursCat == null) {
          throw Exception('Failed to create Colours category');
        }
      }

      categoryId = coloursCat['_id'] as String;

      // Check if value already exists
      final existingValues = List<String>.from(coloursCat['values'] ?? []);
      if (existingValues
          .map((v) => v.toLowerCase())
          .contains(colorName.toLowerCase())) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$colorName" already exists in Colours'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      // Add the colour value
      final success = await _api.addCategoryValue(categoryId, colorName);

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('"$colorName" added to Colours!'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to add colour. Try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isAddingColour = false);
    }
  }

  void _reset() {
    setState(() {
      _result = null;
      _dyeNamesController.clear();
      _dyePercentageController.text = '2.0';
      _gsmController.text = '160';
      _saltController.text = '40';
      _sodaAshController.text = '10';
      _aceticAcidController.text = '0.5';
      _fabricType = 'cotton';
      _dyeType = 'reactive';
      _manualSelectedColor = null;
      _manualColorNameController.clear();
      _manualColorCodeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPalette.background,
      appBar: AppBar(
        title: const Text('Color Prediction'),
        backgroundColor: Colors.white,
        foregroundColor: ColorPalette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(LucideIcons.rotateCcw),
              onPressed: _reset,
              tooltip: 'Reset',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            _buildHeaderCard(),
            const SizedBox(height: 20),

            // AI Mode Toggle - Moved UP
            _buildModeToggle(),
            const SizedBox(height: 16),

            // Input Form or Palette
            _useAI ? _buildInputForm() : _buildManualPalette(),
            const SizedBox(height: 20),

            // Predict Button
            _buildPredictButton(),
            const SizedBox(height: 24),

            // Result Card
            if (_result != null) _buildResultCard(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildManualPalette() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ColorPalette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ColorPalette.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.palette,
                  size: 20,
                  color: ColorPalette.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Manual Color Input',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ColorPalette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Color Name Input
          TextFormField(
            controller: _manualColorNameController,
            decoration: InputDecoration(
              labelText: 'Color Name',
              hintText: 'e.g., Royal Blue',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(LucideIcons.tag),
            ),
          ),
          const SizedBox(height: 12),

          // Color Code Input
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _manualColorCodeController,
                  decoration: InputDecoration(
                    labelText: 'Hex Code',
                    hintText: '#0000FF',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(LucideIcons.hash),
                  ),
                  onChanged: (val) {
                    if (val.length >= 6) {
                      String hex = val;
                      if (!hex.startsWith('#')) hex = '#$hex';
                      try {
                        final color = Color(
                          int.parse(hex.replaceAll('#', '0xFF')),
                        );
                        setState(() => _manualSelectedColor = color);
                      } catch (_) {}
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _manualSelectedColor ?? Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: (_manualSelectedColor ?? Colors.black).withOpacity(
                        0.1,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text(
            'Quick Select Palette',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _paletteColors.length,
            itemBuilder: (context, index) {
              final color = _paletteColors[index];
              final isSelected = _manualSelectedColor == color;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _manualSelectedColor = color;
                    _manualColorCodeController.text =
                        '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                    // Optional: Clear or set a generic name? Keeping name as is allows user to name the color they picked.
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              LucideIcons.palette,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dye Color Agent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter dye recipe to predict garment color',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
  }

  Widget _buildInputForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Fabric & Dye Type row
          Row(
            children: [
              Expanded(child: _buildFabricTypeDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildDyeTypeDropdown()),
            ],
          ),
          const SizedBox(height: 12),

          // GSM & Dye %
          Row(
            children: [
              Expanded(
                child: _buildInputCard(
                  controller: _gsmController,
                  label: 'Fabric GSM',
                  icon: LucideIcons.layers,
                  suffix: 'gsm',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputCard(
                  controller: _dyePercentageController,
                  label: 'Dye %',
                  icon: LucideIcons.percent,
                  suffix: '%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dye Names (main input)
          _buildDyeNamesInput(),
          const SizedBox(height: 12),

          // Chemicals section
          _buildChemicalsSection(),
        ],
      ),
    );
  }

  Widget _buildFabricTypeDropdown() {
    return CustomDropdownField(
      label: 'Fabric',
      value: _fabricType,
      items: const ['cotton', 'polyester', 'blend'],
      onChanged: (v) => setState(() => _fabricType = v!),
    );
  }

  Widget _buildDyeTypeDropdown() {
    return CustomDropdownField(
      label: 'Dye Type',
      value: _dyeType,
      items: const ['reactive', 'disperse', 'vat'],
      onChanged: (v) => setState(() => _dyeType = v!),
    );
  }

  Widget _buildInputCard({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? suffix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ColorPalette.softShadow,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13),
          suffixText: suffix,
          suffixStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          border: InputBorder.none,
          icon: Icon(icon, size: 18, color: ColorPalette.primary),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Required';
          if (double.tryParse(v) == null) return 'Invalid';
          return null;
        },
      ),
    );
  }

  Widget _buildDyeNamesInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ColorPalette.softShadow,
        border: Border.all(
          color: _dyeNamesController.text.isEmpty
              ? Colors.transparent
              : ColorPalette.primary.withOpacity(0.3),
        ),
      ),
      child: TextFormField(
        controller: _dyeNamesController,
        maxLines: 2,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: 'Dye Names',
          hintText: 'e.g., Reactive Red, Blue 19',
          hintStyle: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade400,
            fontWeight: FontWeight.normal,
          ),
          labelStyle: const TextStyle(fontSize: 13),
          border: InputBorder.none,
          icon: const Icon(
            LucideIcons.pipette,
            size: 20,
            color: ColorPalette.primary,
          ),
          helperText: 'Comma separated dye names',
          helperStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty)
            return 'Enter at least one dye name';
          return null;
        },
      ),
    );
  }

  Widget _buildChemicalsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ColorPalette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.beaker,
                  size: 16,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Chemicals',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: ColorPalette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildChemicalField(
                  controller: _saltController,
                  label: 'Salt %',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChemicalField(
                  controller: _sodaAshController,
                  label: 'Soda Ash %',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChemicalField(
                  controller: _aceticAcidController,
                  label: 'Acetic Acid %',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChemicalField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ColorPalette.primary),
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ColorPalette.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _useAI = false;
                _result = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_useAI
                      ? ColorPalette.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: !_useAI
                      ? Border.all(color: ColorPalette.primary.withOpacity(0.3))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.cpu,
                      size: 16,
                      color: !_useAI
                          ? ColorPalette.primary
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Local',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: !_useAI
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: !_useAI
                            ? ColorPalette.primary
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _useAI = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _useAI
                      ? const Color(0xFF10B981).withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: _useAI
                      ? Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                        )
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.sparkles,
                      size: 16,
                      color: _useAI
                          ? const Color(0xFF10B981)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AI Agent',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _useAI
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _useAI
                            ? const Color(0xFF10B981)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isPredicting ? null : _predict,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 4,
          shadowColor: const Color(0xFF6366F1).withOpacity(0.4),
        ),
        child: _isPredicting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _useAI ? LucideIcons.sparkles : LucideIcons.save,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _useAI ? 'Predict Color' : 'Save Color',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _result!;
    final predictedColor = Color.fromARGB(
      255,
      result.red,
      result.green,
      result.blue,
    );

    // Determine if text should be light or dark based on background
    final luminance = predictedColor.computeLuminance();
    final textColor = luminance > 0.5 ? Colors.black87 : Colors.white;

    return Column(
      children: [
        // Large color preview
        Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: predictedColor.withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  height: 200,
                  width: double.infinity,
                  color: predictedColor,
                  child: Stack(
                    children: [
                      // Subtle pattern overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.05),
                                Colors.transparent,
                                Colors.black.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                      // Color name overlay
                      Positioned(
                        bottom: 16,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.colorName,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              result.hexColor,
                              style: TextStyle(
                                color: textColor.withOpacity(0.8),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Confidence badge
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Source badge (AI or Local)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: result.source == 'ai'
                                    ? const Color(0xFF10B981).withOpacity(0.8)
                                    : Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    result.source == 'ai'
                                        ? LucideIcons.sparkles
                                        : LucideIcons.cpu,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    result.source == 'ai'
                                        ? 'AI'
                                        : result.source == 'fallback'
                                        ? 'FALLBACK'
                                        : 'LOCAL',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    result.confidence == 'medium'
                                        ? LucideIcons.checkCircle
                                        : LucideIcons.alertCircle,
                                    size: 12,
                                    color: textColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    result.confidence.toUpperCase(),
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
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
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(begin: const Offset(0.95, 0.95)),

        const SizedBox(height: 16),

        // Details card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: ColorPalette.softShadow,
          ),
          child: Column(
            children: [
              _buildDetailRow(
                'Shade Level',
                result.shadeLevel.toUpperCase(),
                _getShadeIcon(result.shadeLevel),
                _getShadeColor(result.shadeLevel),
              ),
              const Divider(height: 24),
              _buildDetailRow(
                'Tone',
                result.tone.toUpperCase(),
                _getToneIcon(result.tone),
                _getToneColor(result.tone),
              ),
              const Divider(height: 24),
              _buildDetailRow(
                'RGB',
                result.rgb,
                LucideIcons.monitor,
                Colors.grey,
              ),
              const Divider(height: 24),
              _buildDetailRow(
                'HEX',
                result.hexColor,
                LucideIcons.hash,
                Colors.grey,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.info, size: 16, color: Colors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        result.note,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.05),

        const SizedBox(height: 16),

        // Copy JSON button
        OutlinedButton.icon(
          onPressed: () {
            final json = result.toJson().toString();
            Clipboard.setData(ClipboardData(text: json));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Color data copied to clipboard'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
          icon: const Icon(LucideIcons.copy, size: 16),
          label: const Text('Copy Result'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),

        const SizedBox(height: 10),

        // Add to Colours button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isAddingColour
                ? null
                : () => _addToColours(result.colorName),
            icon: _isAddingColour
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(LucideIcons.plusCircle, size: 18),
            label: Text(
              _isAddingColour
                  ? 'Adding...'
                  : 'Add "${result.colorName}" to Colours',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
              shadowColor: const Color(0xFF10B981).withOpacity(0.3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: ColorPalette.textPrimary,
          ),
        ),
      ],
    );
  }

  IconData _getShadeIcon(String shade) {
    switch (shade) {
      case 'light':
        return LucideIcons.sun;
      case 'dark':
        return LucideIcons.moon;
      default:
        return LucideIcons.sunMedium;
    }
  }

  Color _getShadeColor(String shade) {
    switch (shade) {
      case 'light':
        return Colors.amber;
      case 'dark':
        return Colors.indigo;
      default:
        return Colors.orange;
    }
  }

  IconData _getToneIcon(String tone) {
    switch (tone) {
      case 'warm':
        return LucideIcons.flame;
      case 'cool':
        return LucideIcons.snowflake;
      default:
        return LucideIcons.minus;
    }
  }

  Color _getToneColor(String tone) {
    switch (tone) {
      case 'warm':
        return Colors.deepOrange;
      case 'cool':
        return Colors.lightBlue;
      default:
        return Colors.grey;
    }
  }
}
