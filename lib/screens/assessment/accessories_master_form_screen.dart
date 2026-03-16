import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../services/mobile_api_service.dart';
import '../../services/scale_service.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/custom_dropdown_field.dart';

class AccessoriesMasterFormScreen extends StatefulWidget {
  final Map<String, dynamic>? editEntry;
  const AccessoriesMasterFormScreen({super.key, this.editEntry});

  @override
  State<AccessoriesMasterFormScreen> createState() => _AccessoriesMasterFormScreenState();
}

class _AccessoriesMasterFormScreenState extends State<AccessoriesMasterFormScreen> {
  final _api = MobileApiService();
  final _scaleService = ScaleService.instance;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isListening = false;
  bool _voiceMode = false;
  bool _scaleMode = false;

  // Master lists for dropdowns
  List<String> _groupList = [];
  List<String> _accessoryList = [];
  List<String> _itemList = [];
  List<String> _sizeList = [];
  List<String> _supplierList = [];

  // Section 1: Accessories Group Setup Rows
  List<GroupSetupRow> _groupRows = [];

  // Section 2: Accessories Assign for Item Rows
  List<AssignmentRow> _assignRows = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadDropdowns();
    if (widget.editEntry != null) {
      _populateData();
    } else {
      _addGroupRow();
      _addAssignRow();
    }
  }

  Future<void> _initSpeech() async {
    await _speech.initialize();
  }

  Future<void> _loadDropdowns() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _api.getCategories();
      setState(() {
        _groupList = _getValues(categories, ['Accessories Group', 'Accessory Group']);
        _accessoryList = _getValues(categories, ['Accessories', 'Accessory']);
        _itemList = _getValues(categories, ['Item Name', 'Item']);
        _sizeList = _getValues(categories, ['Size', 'Sizes']);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<String> _getValues(List<dynamic> categories, List<String> names) {
    final lowerNames = names.map((n) => n.toLowerCase().trim()).toList();
    final cat = categories.firstWhere(
      (c) {
        final serverName = (c['name'] as String? ?? '').toLowerCase().trim();
        return lowerNames.contains(serverName);
      },
      orElse: () => null,
    );
    if (cat == null) return [];
    return (cat['values'] as List).map((v) {
      if (v is Map) return v['name'].toString();
      return v.toString();
    }).toList();
  }

  void _populateData() {
    final data = widget.editEntry!;
    if (data['groupSetup'] != null) {
      _groupRows = (data['groupSetup'] as List).map((e) => GroupSetupRow.fromMap(e)).toList();
    }
    if (data['itemAssignment'] != null) {
      _assignRows = (data['itemAssignment'] as List).map((e) => AssignmentRow.fromMap(e)).toList();
    }
  }

  void _addGroupRow() {
    setState(() {
      _groupRows.add(GroupSetupRow(date: DateTime.now()));
    });
  }

  void _addAssignRow() {
    setState(() {
      _assignRows.add(AssignmentRow());
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final data = {
      'groupSetup': _groupRows.map((e) => e.toMap()).toList(),
      'itemAssignment': _assignRows.map((e) => e.toMap()).toList(),
    };

    try {
      bool success;
      if (widget.editEntry != null) {
        success = await _api.updateAccessoriesMaster(widget.editEntry!['_id'], data);
      } else {
        success = await _api.createAccessoriesMaster(data);
      }

      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editEntry != null ? 'Edit Accessories Master' : 'Accessories Master'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              _voiceMode ? Icons.mic : (_scaleMode ? Icons.scale : Icons.more_vert),
              color: _voiceMode ? Colors.orange : (_scaleMode ? Colors.blue.shade300 : null),
            ),
            onSelected: (val) {
              setState(() {
                if (val == 'voice') {
                  _voiceMode = !_voiceMode;
                  if (_voiceMode) _scaleMode = false;
                } else if (val == 'scale') {
                  _scaleMode = !_scaleMode;
                  if (_scaleMode) _voiceMode = false;
                }
              });
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'voice',
                child: Row(
                  children: [
                    Icon(Icons.mic, color: _voiceMode ? Colors.orange : Colors.grey),
                    const SizedBox(width: 8),
                    Text('Voice Mode', style: TextStyle(fontWeight: _voiceMode ? FontWeight.bold : null)),
                    const Spacer(),
                    if (_voiceMode) const Icon(Icons.check, size: 16, color: Colors.orange),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'scale',
                child: Row(
                  children: [
                    Icon(Icons.scale, color: _scaleMode ? Colors.blue : Colors.grey),
                    const SizedBox(width: 8),
                    Text('Scale Mode', style: TextStyle(fontWeight: _scaleMode ? FontWeight.bold : null)),
                    const Spacer(),
                    if (_scaleMode) const Icon(Icons.check, size: 16, color: Colors.blue),
                  ],
                ),
              ),
            ],
          ),
          if (_isSaving)
            const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white))
          else
            IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    // REMOVED Section label
                    ..._groupRows.asMap().entries.map((entry) => _buildGroupRow(entry.key, entry.value)),
                          Center(
                            child: TextButton.icon(
                              onPressed: _addGroupRow,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Add Group Row', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(foregroundColor: ColorPalette.primary),
                            ),
                          ),
                              const SizedBox(height: 16),
                        // REMOVED Section label
                        ..._assignRows.asMap().entries.map((entry) => _buildAssignRow(entry.key, entry.value)),
                          Center(
                            child: TextButton.icon(
                              onPressed: _addAssignRow,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Add Assign Row', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(foregroundColor: ColorPalette.primary),
                            ),
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }



  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: ColorPalette.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorPalette.primary.withOpacity(0.1)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: ColorPalette.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildGroupRow(int index, GroupSetupRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Date: ${DateFormat('dd-MM-yyyy').format(row.date)}', style: TextStyle(color: Colors.grey.shade600)),
                ),
                IconButton(
                  onPressed: () => setState(() => _groupRows.removeAt(index)),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            CustomDropdownField(
              label: 'Accessories Group',
              value: row.group,
              items: _groupList,
              onChanged: (val) {
                setState(() {
                  row.group = val;
                  if (val?.toLowerCase() == 'elastic') {
                    row.showColors = true;
                  } else {
                    row.showColors = false;
                  }
                });
              },
            ),
            CustomDropdownField(
              label: 'Accessories',
              value: row.accessory,
              items: _accessoryList,
              onChanged: (val) => setState(() => row.accessory = val),
            ),
            const SizedBox(height: 8),
            _buildRowTextFields(row),
            if (row.showColors) ...[
              const SizedBox(height: 8),
              _buildColorSelection(row),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRowTextFields(GroupSetupRow row) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _miniTextField('HSN Code', row.hsnController)),
            const SizedBox(width: 8),
            Expanded(child: _miniTextField('Unit', row.unitController)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _miniTextField('Tax', row.taxController)),
            const SizedBox(width: 8),
            Expanded(child: _miniTextField('Rate', row.rateController, keyboardType: TextInputType.number)),
          ],
        ),
        CustomDropdownField(
          label: 'Used In',
          value: row.usedIn,
          items: const ['stiching', 'cutting', 'othetrs'],
          onChanged: (val) => setState(() => row.usedIn = val),
        ),
        Row(
          children: [
            Expanded(child: _miniTextField('Max Stock', row.maxStockController, keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: _miniTextField('Min Stock', row.minStockController, keyboardType: TextInputType.number)),
          ],
        ),
        _miniTextField('Party / Supplier', row.supplierController),
        _miniTextField('Product Specification', row.specController),
      ],
    );
  }

  Widget _buildColorSelection(GroupSetupRow row) {
    final List<Color> availableColors = [Colors.black, Colors.white, Colors.red, Colors.blue, Colors.green, Colors.yellow];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Colors (for Elastic)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          children: availableColors.map((color) {
            final colorHex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
            final isSelected = row.colors.contains(colorHex);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    row.colors.remove(colorHex);
                  } else {
                    row.colors.add(colorHex);
                  }
                });
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAssignRow(int index, AssignmentRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Assignment #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => setState(() => _assignRows.removeAt(index)),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            CustomDropdownField(
              label: 'Item Name',
              value: row.itemName,
              items: _itemList,
              onChanged: (val) => setState(() => row.itemName = val),
            ),
            CustomDropdownField(
              label: 'Accessories Group',
              value: row.group,
              items: _groupList,
              onChanged: (val) => setState(() => row.group = val),
            ),
            CustomDropdownField(
              label: 'Accessories Name',
              value: row.accessoryName,
              items: _accessoryList,
              onChanged: (val) => setState(() => row.accessoryName = val),
            ),
            CustomDropdownField(
              label: 'Size',
              value: row.size,
              items: _sizeList,
              onChanged: (val) => setState(() => row.size = val),
            ),
            _miniTextField('Quantity per piece', row.qtyPerPieceController, keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            _buildSizeGrid(row),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeGrid(AssignmentRow row) {
    final sizes = ['75', '80', '85', '90', '95', '100', '105', '110'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Size-wise Quantities',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: sizes.map((size) {
              return Container(
                width: 70, // Shrinked width
                margin: const EdgeInsets.only(right: 8, bottom: 8),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: ColorPalette.primary.withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: Center(
                        child: Text(
                          size,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: ColorPalette.primary, fontSize: 12),
                        ),
                      ),
                    ),
                    TextField(
                      controller: row.sizeControllers[size],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                      onTap: () {
                        if (_voiceMode) {
                          _startVoiceInputForSize(row, size);
                        } else if (_scaleMode) {
                          _captureScaleWeightForSize(row, size);
                        }
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                          borderSide: BorderSide(color: ColorPalette.primary),
                        ),
                        // REMOVED Suffix Icons inside the box as per feedback
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _miniTextField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _startVoiceInputForSize(AssignmentRow row, String size) async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }

    setState(() => _isListening = true);
    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final words = result.recognizedWords;
          final val = RegExp(r'\d+\.?\d*').firstMatch(words)?.group(0);
          if (val != null) {
            setState(() {
              row.sizeControllers[size]?.text = val;
              _isListening = false;
            });
          }
        }
      },
    );
  }

  Future<void> _captureScaleWeightForSize(AssignmentRow row, String size) async {
    try {
      final weight = await _scaleService.captureWeight();
      setState(() {
        row.sizeControllers[size]?.text = weight.toStringAsFixed(3);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scale Error: $e')));
    }
  }
}

class GroupSetupRow {
  DateTime date;
  String? group;
  String? accessory;
  String? usedIn;
  bool showColors = false;
  List<String> colors = [];

  final hsnController = TextEditingController();
  final unitController = TextEditingController();
  final taxController = TextEditingController();
  final rateController = TextEditingController();
  final maxStockController = TextEditingController();
  final minStockController = TextEditingController();
  final supplierController = TextEditingController();
  final specController = TextEditingController();

  GroupSetupRow({required this.date});

  static GroupSetupRow fromMap(Map<String, dynamic> map) {
    final row = GroupSetupRow(date: DateTime.parse(map['date']));
    row.group = map['group'];
    row.accessory = map['accessory'];
    row.usedIn = map['usedIn'];
    row.colors = List<String>.from(map['colors'] ?? []);
    row.hsnController.text = map['hsnCode'] ?? '';
    row.unitController.text = map['unit'] ?? '';
    row.taxController.text = map['tax'] ?? '';
    row.rateController.text = (map['rate'] ?? '').toString();
    row.maxStockController.text = (map['maxStock'] ?? '').toString();
    row.minStockController.text = (map['minStock'] ?? '').toString();
    row.supplierController.text = map['supplier'] ?? '';
    row.specController.text = map['productSpec'] ?? '';
    row.showColors = row.group?.toLowerCase() == 'elastic';
    return row;
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'group': group,
      'accessory': accessory,
      'hsnCode': hsnController.text,
      'unit': unitController.text,
      'tax': taxController.text,
      'rate': double.tryParse(rateController.text) ?? 0,
      'usedIn': usedIn,
      'maxStock': double.tryParse(maxStockController.text) ?? 0,
      'minStock': double.tryParse(minStockController.text) ?? 0,
      'supplier': supplierController.text,
      'productSpec': specController.text,
      'colors': colors,
    };
  }
}

class AssignmentRow {
  String? itemName;
  String? group;
  String? accessoryName;
  String? size;
  final qtyPerPieceController = TextEditingController();
  final Map<String, TextEditingController> sizeControllers = {
    '75': TextEditingController(),
    '80': TextEditingController(),
    '85': TextEditingController(),
    '90': TextEditingController(),
    '95': TextEditingController(),
    '100': TextEditingController(),
    '105': TextEditingController(),
    '110': TextEditingController(),
  };

  AssignmentRow();

  static AssignmentRow fromMap(Map<String, dynamic> map) {
    final row = AssignmentRow();
    row.itemName = map['itemName'];
    row.group = map['group'];
    row.accessoryName = map['accessoryName'];
    row.size = map['size'];
    row.qtyPerPieceController.text = (map['qtyPerPiece'] ?? '').toString();
    final sizeData = map['sizeWiseQuantities'] as Map? ?? {};
    sizeData.forEach((key, value) {
      if (row.sizeControllers.containsKey(key)) {
        row.sizeControllers[key]?.text = (value ?? '').toString();
      }
    });
    return row;
  }

  Map<String, dynamic> toMap() {
    final sizeWise = {};
    sizeControllers.forEach((key, controller) {
      sizeWise[key] = double.tryParse(controller.text) ?? 0;
    });
    return {
      'itemName': itemName,
      'group': group,
      'accessoryName': accessoryName,
      'size': size,
      'qtyPerPiece': double.tryParse(qtyPerPieceController.text) ?? 0,
      'sizeWiseQuantities': sizeWise,
    };
  }
}
