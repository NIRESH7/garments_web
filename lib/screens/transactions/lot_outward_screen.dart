import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../dialogs/signature_pad_dialog.dart';
import '../../core/storage/storage_service.dart';
import '../../widgets/custom_dropdown_field.dart';
import '../../core/constants/api_constants.dart';

class LotOutwardScreen extends StatefulWidget {
  const LotOutwardScreen({super.key});

  @override
  State<LotOutwardScreen> createState() => _LotOutwardScreenState();
}

class _LotOutwardScreenState extends State<LotOutwardScreen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();

  DateTime _outwardDateTime = DateTime.now();
  String _dcNumber = 'Loading...';
  String? _selectedLotName;
  String? _selectedDia;
  String? _selectedLotNo;
  String? _selectedParty;

  String? _process;
  String? _address;

  final _vehicleController = TextEditingController();
  final String _inTime = DateFormat('hh:mm a').format(DateTime.now());
  String? _outTime;

  List<String> _lotNames = [];
  List<String> _dias = [];
  List<String> _lotNos = [];
  List<String> _parties = [];

  List<Map<String, dynamic>> _availableSets = [];
  final List<Map<String, dynamic>> _selectedSets = [];

  List<String> _allColours = [];
  List<String> _currentLotColours = [];
  Map<String, String> _colourImages = {};

  bool _isLoading = true;
  bool _isSaved = false;
  bool _isSaving = false;

  XFile? _lotInchargeSignature;
  XFile? _authorizedSignature;
  String? _userRole;
  bool _isScanned = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadInitialData();
  }

  Future<void> _loadUserRole() async {
    final role = await StorageService().getRole();
    setState(() => _userRole = role);
  }

  Future<void> _loadInitialData() async {
    final categories = await _api.getCategories();
    final parties = await _api.getParties();
    final dc = await _api.generateDcNumber();

    setState(() {
      _lotNames = _getValues(categories, 'Lot Name');
      _dias = _getValues(categories, 'dia');
      _allColours = _getValues(categories, 'Colours');
      _parties = parties.map((m) => m['name'] as String).toList();
      _dcNumber = dc ?? 'ERR-GEN';
      _isLoading = false;
    });
  }

  List<String> _getValues(List<dynamic> categories, String name) {
    try {
      final List<String> result = [];
      final matches = categories.where((c) {
        final catName = (c['name'] ?? '').toString().trim().toLowerCase();
        return catName == name.trim().toLowerCase();
      });

      for (var cat in matches) {
        final dynamic rawValues = cat['values'];
        if (rawValues is List) {
          for (var v in rawValues) {
            String? val;
            if (v is Map) {
              val = (v['name'] ?? v['value'] ?? '').toString();
              if (v['photo'] != null && v['photo'].toString().isNotEmpty) {
                String imgPath = v['photo'].toString();
                if (!imgPath.startsWith('http')) {
                  if (imgPath.startsWith('/uploads')) {
                    imgPath = '${ApiConstants.serverUrl}$imgPath';
                  } else if (imgPath.startsWith('uploads')) {
                    imgPath = '${ApiConstants.serverUrl}/$imgPath';
                  }
                }
                _colourImages[val] = imgPath;
              }
            } else if (v != null) {
              val = v.toString();
            }
            if (val != null && val.isNotEmpty && !result.contains(val)) {
              result.add(val);
            }
          }
        }
      }
      return result;
    } catch (e) {
      return [];
    }
  }

  Future<void> _onLotNameChanged(String? val) async {
    setState(() {
      _selectedLotName = val;
      _selectedLotNo = null;
      _availableSets = [];
      _selectedSets.clear();
    });
    if (val != null && _selectedDia != null) {
      await _fetchFifoRecommendation();
    }
  }

  Future<void> _onDiaChanged(String? val) async {
    setState(() {
      _selectedDia = val;
      _selectedLotNo = null;
      _lotNos = [];
      _availableSets = [];
      _selectedSets.clear();
    });
    if (val != null) {
      final lots = await _api.getLotsFifo(dia: val);
      setState(() => _lotNos = lots);

      if (_selectedLotName != null) {
        await _fetchFifoRecommendation();
      }
    }
  }

  Future<void> _fetchFifoRecommendation() async {
    if (_selectedLotName == null || _selectedDia == null) return;

    try {
      final rec = await _api.getFifoRecommendation(
        _selectedLotName!,
        _selectedDia!,
      );
      if (rec != null) {
        final recLotNo = rec['lotNo'].toString();
        // If the lot is not in current list, add it
        if (!_lotNos.contains(recLotNo)) {
          setState(() => _lotNos.add(recLotNo));
        }
        await _onLotNoChanged(recLotNo);
      }
    } catch (e) {
      debugPrint('FIFO Error: $e');
    }
  }

  Future<void> _onLotNoChanged(String? val) async {
    setState(() {
      _selectedLotNo = val;
      _currentLotColours = []; // Clear current lot colours
      _availableSets = [];
      _selectedSets.clear();
    });
    if (val != null) {
      // Load lot colours
      final colours = await _api.getColoursByLot(val);
      setState(() => _currentLotColours = colours);

      // Load available sets
      if (_selectedDia != null) {
        final sets = await _api.getBalancedSets(val, _selectedDia!);
        setState(() => _availableSets = sets);
      }
    }
  }

  Future<void> _onPartyChanged(String? val) async {
    setState(() {
      _selectedParty = val;
      _process = null;
      _address = null;
    });
    if (val != null) {
      final details = await _api.getPartyDetails(val);
      if (details != null) {
        setState(() {
          _process = details['process'];
          _address = details['address'];
        });
      }
    }
  }

  Future<void> _scanSticker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scan Inward Sticker',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String code = barcodes.first.displayValue ?? '';
                    if (code.isNotEmpty) {
                      Navigator.pop(ctx, code);
                    }
                  }
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Align the QR code within the frame to scan',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      _processScannedCode(result);
    }
  }

  void _processScannedCode(String code) {
    try {
      final lines = code.split('\n');
      String? lotNo, lotName, dia, colour, setNo, weight;

      for (var line in lines) {
        final clean = line.trim();
        if (clean.startsWith('LOT:'))
          lotNo = clean.replaceFirst('LOT:', '').trim();
        else if (clean.startsWith('NAME:'))
          lotName = clean.replaceFirst('NAME:', '').trim();
        else if (clean.startsWith('DIA:'))
          dia = clean.replaceFirst('DIA:', '').trim();
        else if (clean.startsWith('COL:'))
          colour = clean.replaceFirst('COL:', '').trim();
        else if (clean.startsWith('SET:'))
          setNo = clean.replaceFirst('SET:', '').trim();
        else if (clean.startsWith('WT:'))
          weight = clean.replaceFirst('WT:', '').replaceAll('kg', '').trim();
      }

      if (lotNo == null || dia == null || setNo == null) {
        _showError(
          'Invalid QR Code format. Please scan a valid Inward Sticker.',
        );
        return;
      }

      _autoFillFromScan(lotNo, lotName, dia, colour, setNo, weight);
    } catch (e) {
      _showError('Failed to parse scan: $e');
    }
  }

  Future<void> _autoFillFromScan(
    String lotNo,
    String? lotName,
    String dia,
    String? colour,
    String setNo,
    String? weight,
  ) async {
    // 1. Check if DIA exists
    if (!_dias.contains(dia)) {
      _showError('DIA $dia not found in master list');
      return;
    }

    // 2. Set DIA and Load Lots
    await _onDiaChanged(dia);

    // 3. Set Lot Name if provided
    if (lotName != null && _lotNames.contains(lotName)) {
      setState(() => _selectedLotName = lotName);
    }

    // 4. Check if Lot No exists for this DIA
    if (!_lotNos.contains(lotNo)) {
      _showError('Lot No $lotNo is not available for DIA $dia');
      return;
    }

    // 5. Select Lot No and Load Balanced Sets
    await _onLotNoChanged(lotNo);

    // 6. Check if Set No is in available stock
    final bool setAvailable = _availableSets.any(
      (s) => s['set_no'].toString() == setNo,
    );

    if (setAvailable) {
      // Check if already selected
      final isAlreadySelected = _selectedSets.any(
        (s) => s['set_no'].toString() == setNo,
      );
      if (isAlreadySelected) {
        _showError('Set $setNo is already selected');
        return;
      }

      _toggleSetSelection(setNo, true);
      setState(() => _isScanned = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully scanned and added Set $setNo ($colour)'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _showError(
        'Set $setNo is not available in stock or has already been issued',
      );
    }
  }

  Future<void> _openSignaturePad(Function(XFile?) onPick) async {
    final XFile? result = await showDialog(
      context: context,
      builder: (context) => const SignaturePadDialog(),
    );
    if (result != null) {
      onPick(result);
    }
  }

  Widget _buildSigBox(
    String label,
    XFile? file,
    Function(XFile?) onPick, {
    List<String> allowedRoles = const [],
  }) {
    final bool canSign =
        _userRole != null &&
        (allowedRoles.isEmpty ||
            allowedRoles.contains(_userRole) ||
            _userRole == 'admin');

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (canSign) {
              _openSignaturePad(onPick);
            } else {
              _showError('Only ${allowedRoles.join(' or ')} can sign here.');
            }
          },
          child: Container(
            width: 120,
            height: 70,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: canSign ? Colors.white : Colors.grey.shade50,
            ),
            child: file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: kIsWeb
                        ? Image.network(file.path, fit: BoxFit.contain)
                        : Image.file(File(file.path), fit: BoxFit.contain),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit, color: Colors.grey, size: 24),
                      Text(
                        "Sign Here",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _toggleSetSelection(String setNo, bool selected) {
    setState(() {
      if (selected) {
        // Find existing stock entries for this set
        final setStock = _availableSets
            .where((s) => s['set_no'].toString() == setNo)
            .toList();

        final List<Map<String, dynamic>> colours = [];
        double setTotalWeight = 0;

        // Requirement: "if 10 colour available automatically fill 10 colours"
        // Use Master List (_allColours) + Lot Specific (_currentLotColours)
        final combinedColours = {
          ..._allColours,
          ..._currentLotColours,
        }.toList();

        for (var lotCol in combinedColours) {
          // Check if we have stock for this color in this set
          final stockItem = setStock.firstWhere(
            (s) =>
                s['colour'].toString().trim().toLowerCase() ==
                lotCol.trim().toLowerCase(),
            orElse: () => {},
          );

          final w = (stockItem['weight'] as num?)?.toDouble() ?? 0.0;
          setTotalWeight += w;

          colours.add({
            'colour': lotCol,
            'weight': w,
            'roll_weight': w,
            'no_of_rolls': w > 0 ? 1 : 0,
          });
        }

        // If for some reason _currentLotColours is empty, fall back to stock entries
        if (colours.isEmpty) {
          for (var entry in setStock) {
            final w = (entry['weight'] as num?)?.toDouble() ?? 0.0;
            setTotalWeight += w;
            colours.add({
              'colour': entry['colour'] ?? 'N/A',
              'weight': w,
              'roll_weight': w,
              'no_of_rolls': 1,
            });
          }
        }

        _selectedSets.add({
          'set_no': setNo,
          'total_weight': setTotalWeight,
          'colours': colours,
          'rack_name': setStock.isNotEmpty
              ? (setStock.first['rack_name'] ?? 'Not Assigned')
              : 'Not Assigned',
          'pallet_number': setStock.isNotEmpty
              ? (setStock.first['pallet_number'] ?? 'Not Assigned')
              : 'Not Assigned',
        });
      } else {
        _selectedSets.removeWhere((s) => s['set_no'].toString() == setNo);
      }
    });
  }

  void _removeSet(int index) {
    setState(() {
      _selectedSets.removeAt(index);
    });
  }

  // Summary calculation functions
  Map<String, double> _getColourTotals() {
    final Map<String, double> totals = {};
    for (var set in _selectedSets) {
      final colours = set['colours'] as List;
      for (var col in colours) {
        final name = col['colour'].toString().trim().isEmpty
            ? 'N/A'
            : col['colour'].toString();
        totals[name] = (totals[name] ?? 0) + (col['weight'] as double);
      }
    }
    return totals;
  }

  double _getTotalWeight() {
    return _selectedSets.fold(
      0.0,
      (sum, set) => sum + (set['total_weight'] as double),
    );
  }

  double _getTotalRollWeight() {
    double total = 0;
    for (var set in _selectedSets) {
      final colours = set['colours'] as List;
      for (var col in colours) {
        total += (col['roll_weight'] as double);
      }
    }
    return total;
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _outwardDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_outwardDateTime),
      );
      if (time != null) {
        setState(() {
          _outwardDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _save() async {
    if (_selectedLotName == null) {
      _showError('Please select Lot Name');
      return;
    }
    if (_selectedDia == null) {
      _showError('Please select DIA');
      return;
    }
    if (_selectedLotNo == null) {
      _showError('Please select Lot No (FIFO)');
      return;
    }
    if (_selectedParty == null) {
      _showError('Please select Party Name');
      return;
    }
    if (_selectedSets.isEmpty) {
      _showError('Please select at least one set');
      return;
    }
    if (_getTotalWeight() <= 0) {
      _showError('Total weight must be greater than 0');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isScanned && kReleaseMode) {
      // Allow bypass in debug if needed, but strict for user
      _showError('Please scan the inward sticker to identify the roll');
      return;
    }

    if (_lotInchargeSignature == null || _authorizedSignature == null) {
      _showError(
        'Mandatory: Both Lot Incharge and Authorized signatures required',
      );
      return;
    }

    setState(() {
      _outTime = DateFormat('hh:mm a').format(DateTime.now());
      _isSaving = true;
    });

    final outwardData = {
      'dc_number': _dcNumber,
      'dateTime': _outwardDateTime.toIso8601String(),
      'lotName': _selectedLotName,
      'lotNo': _selectedLotNo,
      'dia': _selectedDia,
      'partyName': _selectedParty,
      'process': _process,
      'address': _address,
      'vehicleNo': _vehicleController.text,
      'inTime': _inTime,
      'outTime': _outTime,
      'items': _selectedSets
          .map(
            (set) => {
              'set_no': set['set_no'],
              'total_weight': set['total_weight'],
              'colours': (set['colours'] as List)
                  .map(
                    (col) => {
                      'colour': col['colour'],
                      'weight': col['weight'],
                      'roll_weight': col['roll_weight'],
                      'no_of_rolls': col['no_of_rolls'],
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      'lotInchargeSignature': _lotInchargeSignature,
      'authorizedSignature': _authorizedSignature,
      'lotInchargeSignTime': DateTime.now().toIso8601String(),
      'authorizedSignTime': DateTime.now().toIso8601String(),
    };

    try {
      final success = await _api.saveOutward(outwardData);
      if (success) {
        setState(() => _isSaved = true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Outward Registered: $_dcNumber')),
        );

        // Prompt for sticker printing
        _showPrintStickerDialog();
      } else {
        _showError('Failed to save to backend');
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSummarySection() {
    final colourTotals = _getColourTotals();
    final totalWeight = _getTotalWeight();
    final totalRollWeight = _getTotalRollWeight();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OUTWARD SUMMARY',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...colourTotals.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '${e.value.toStringAsFixed(2)} kg',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  'Overall Weight',
                  '${totalWeight.toStringAsFixed(2)} kg',
                  isMain: true,
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  'Total Roll Wt',
                  '${totalRollWeight.toStringAsFixed(2)} kg',
                ),
                const SizedBox(height: 4),
                _buildSummaryRow('Total Sets', '${_selectedSets.length}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isMain = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isMain ? FontWeight.bold : FontWeight.normal,
            fontSize: isMain ? 15 : 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isMain ? 16 : 14,
            color: isMain ? ColorPalette.primary : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "MANDATORY SIGNATURES",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSigBox(
              "Lot Incharge",
              _lotInchargeSignature,
              (f) => setState(() => _lotInchargeSignature = f),
              allowedRoles: ['lot_inward', 'admin'],
            ),
            _buildSigBox(
              "Authorized",
              _authorizedSignature,
              (f) => setState(() => _authorizedSignature = f),
              allowedRoles: ['authorized', 'admin'],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedSetsList() {
    if (_selectedSets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECTED SET DETAILS (EDITABLE)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ..._selectedSets.asMap().entries.map((setEntry) {
          final setIndex = setEntry.key;
          final set = setEntry.value;
          final List colours = set['colours'];

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  color: ColorPalette.primary.withOpacity(0.05),
                  child: Row(
                    children: [
                      Text(
                        'SET NO: ${set['set_no']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ColorPalette.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'RACK: ${set['rack_name']}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'PALLET: ${set['pallet_number']}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          LucideIcons.trash2,
                          color: Colors.red,
                          size: 18,
                        ),
                        onPressed: () => _removeSet(setIndex),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.5), // Colour
                      1: FlexColumnWidth(1.5), // Weight
                      2: FlexColumnWidth(1.2), // Rolls
                      3: FlexColumnWidth(1.5), // Roll Wt
                    },
                    children: [
                      const TableRow(
                        children: [
                          _TableHeader('COLOUR'),
                          _TableHeader('WT (kg)'),
                          _TableHeader('ROLLS'),
                          _TableHeader('ROLL WT'),
                        ],
                      ),
                      ...colours.map((col) {
                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 2,
                              ),
                              child: Row(
                                children: [
                                  if (_colourImages.containsKey(col['colour']))
                                    Container(
                                      width: 20,
                                      height: 20,
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            _colourImages[col['colour']]!,
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      col['colour'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildTableInput(col['weight'].toString(), (v) {
                              setState(() {
                                double val = double.tryParse(v) ?? 0.0;
                                col['weight'] = val;
                                col['roll_weight'] = val; // Same Weight Sync
                                set['total_weight'] = colours.fold(
                                  0.0,
                                  (sum, c) => sum + (c['weight'] as double),
                                );
                              });
                            }),
                            _buildTableInput(
                              col['no_of_rolls'].toString(),
                              (v) => setState(
                                () => col['no_of_rolls'] = int.tryParse(v) ?? 1,
                              ),
                            ),
                            _buildTableInput(
                              col['roll_weight'].toString(),
                              (v) => setState(
                                () => col['roll_weight'] =
                                    double.tryParse(v) ?? 0.0,
                              ),
                              key: ValueKey(
                                'rollwt_${col['colour']}_${col['roll_weight']}',
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTableInput(
    String value,
    Function(String) onChanged, {
    Key? key,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.all(2.0),
      child: TextFormField(
        initialValue: value == '0.0' || value == '0' ? '' : value,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }

  void _showPrintStickerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Success'),
        content: const Text('Outward saved successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'OUTWARD',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.scan),
            tooltip: 'Scan Inward Sticker',
            onPressed: _isSaved ? null : _scanSticker,
          ),
          IconButton(
            icon: const Icon(LucideIcons.mic),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice input (Tamil/English)...')),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDCSection(),
              const SizedBox(height: 16),
              _buildMainForm(),
              const SizedBox(height: 24),
              _buildSetSelectionSection(),
              const SizedBox(height: 24),
              _buildSelectedSetsList(),
              const SizedBox(height: 24),
              if (_selectedSets.isNotEmpty) _buildSummarySection(),
              const SizedBox(height: 24),
              if (_selectedSets.isNotEmpty) _buildSignatureSection(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_isSaved || _isSaving) ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.checkCircle),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : (_isSaved ? 'Dispatch Confirmed' : 'Save Outward'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSaved
                        ? Colors.grey
                        : ColorPalette.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDCSection() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: ColorPalette.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          'DC NO: $_dcNumber',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: ColorPalette.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildMainForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    'LOT NAME',
                    _lotNames,
                    _selectedLotName,
                    _onLotNameChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _isSaved ? null : _selectDateTime,
                    child: _buildReadOnlyField(
                      'DATE & TIME',
                      DateFormat('dd-MM-yyyy hh:mm a').format(_outwardDateTime),
                      icon: LucideIcons.calendar,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    'DIA',
                    _dias,
                    _selectedDia,
                    _onDiaChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    'LOT NO (FIFO)',
                    _lotNos,
                    _selectedLotNo,
                    _onLotNoChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              'PARTY NAME',
              _parties,
              _selectedParty,
              _onPartyChanged,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildReadOnlyField('PROCESS', _process ?? '-'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildReadOnlyField(
                    'ADDRESS',
                    _address ?? '-',
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vehicleController,
                    decoration: const InputDecoration(
                      labelText: 'VEHICLE NO',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(LucideIcons.truck, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildReadOnlyField('IN TIME', _inTime)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetSelectionSection() {
    if (_availableSets.isEmpty && _selectedLotNo != null) {
      return Card(
        color: Colors.orange.shade50,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '⚠️ No sets available for this Lot Number. Please ensure you completed the "Sticker & Storage Details" (Next Page) during Inward Entry.',
            style: TextStyle(color: Colors.orange, fontSize: 13),
          ),
        ),
      );
    }
    if (_availableSets.isEmpty) return const SizedBox.shrink();

    // Group available sets by unique set number to satisfy client req "Show only Set 1, 2, 3..."
    final uniqueSetNos = <int>{};
    for (var s in _availableSets) {
      uniqueSetNos.add(int.tryParse(s['set_no'].toString()) ?? 0);
    }
    final sortedSetNos = uniqueSetNos.toList()
      ..remove(0)
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECT SET NO (UNIQUE)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: sortedSetNos.map((setNo) {
            final isSelected = _selectedSets.any(
              (sel) => sel['set_no'].toString() == setNo.toString(),
            );

            return ChoiceChip(
              label: Text('Set $setNo', style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (selected) {
                _toggleSetSelection(setNo.toString(), selected);
              },
              selectedColor: ColorPalette.primary.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? ColorPalette.primary : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String? value,
    Function(String?) onChanged,
  ) {
    return CustomDropdownField(
      label: label,
      items: items,
      value: (value != null && items.contains(value)) ? value : null,
      onChanged: _isSaved ? (v) {} : onChanged,
    );
  }

  Widget _buildReadOnlyField(
    String label,
    String value, {
    IconData? icon,
    int maxLines = 1,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      ),
      child: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        overflow: TextOverflow.ellipsis,
        maxLines: maxLines,
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String title;
  const _TableHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey.shade700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
