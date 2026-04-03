import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../dialogs/signature_pad_dialog.dart';
import '../../core/storage/storage_service.dart';
import '../../widgets/custom_dropdown_field.dart';
import '../../core/constants/api_constants.dart';
import '../../services/scale_service.dart';

class LotOutwardScreen extends StatefulWidget {
  final Map<String, dynamic>? editOutward;
  final Map<String, dynamic>? initialOutwardData;
  const LotOutwardScreen({
    super.key,
    this.editOutward,
    this.initialOutwardData,
  });

  @override
  State<LotOutwardScreen> createState() => _LotOutwardScreenState();
}

class _LotOutwardScreenState extends State<LotOutwardScreen> {
  final _api = MobileApiService();
  final _scaleService = ScaleService.instance;
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

  List<String> _currentLotColours = [];
  Map<String, String> _colourImages = {};

  bool _isLoading = true;
  bool _isSaved = false;
  bool _isSaving = false;

  XFile? _lotInchargeSignature;
  XFile? _authorizedSignature;
  String? _userRole;
  int _activeSetIndex = 0;

  // Scan / Manual Toggle
  bool _isManual = true;
  MobileScannerController? _scannerController;
  bool _isEditMode = false;
  String? _editInchargeSigUrl;
  String? _editAuthorizedSigUrl;
  bool _enableVoiceInput = false;
  bool _enableWeightInput = true;
  double _tareOffset = 0.0;
  String? _fifoRecommendedLotNo;
  String? _lastFifoWarnKey;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _selectedVoiceLocale = 'en_US';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _initSpeech();
    if (widget.editOutward != null) {
      _isEditMode = true;
      _loadEditData();
    } else if (widget.initialOutwardData != null) {
      _loadInitialFromData();
    } else {
      _loadInitialData();
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _speech.stop();
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final role = await StorageService().getRole();
    setState(() => _userRole = role);
  }

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (mounted) setState(() {});
  }

  void _startVoiceInputForSetWeight(
    Map<String, dynamic> set,
    String colour,
  ) async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showError('Microphone permission is required for voice input.');
        return;
      }
    }

    if (!_speech.isAvailable) {
      _showError('Voice recognition not available on this device.');
      return;
    }

    setState(() => _isListening = true);

    _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords
            .toLowerCase()
            .replaceAll(',', '.')
            .replaceAll('point', '.')
            .replaceAll('dot', '.')
            .replaceAll('decimal', '.')
            .replaceAll('à®ªà¯à®³à¯à®³à®¿', '.');

        final regExp = RegExp(r'\d+\.?\d*');
        final match = regExp.firstMatch(words);
        if (match != null) {
          final value = match.group(0)!;
          setState(() {
            final parsed = double.tryParse(value) ?? 0.0;
            final target = _ensureSetColourEntry(set, colour);
            target['weight'] = parsed;
            target['roll_weight'] = parsed;
            target['isChecked'] = parsed > 0;
            final controller =
                target['controller'] as TextEditingController?;
            if (controller != null) {
              controller.text =
                  parsed == 0 ? '' : _formatGridNumber(parsed);
            }
            _recalculateSetTotalWeight(set);
          });
        }

        if (result.finalResult) {
          setState(() => _isListening = false);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: _selectedVoiceLocale,
    );
  }

  Future<void> _loadInitialData() async {
    final categories = await _api.getCategories();
    final parties = await _api.getParties();
    final dc = await _api.generateDcNumber();

    setState(() {
      _lotNames = _getValues(categories, 'Lot Name');
      _dias = _getValues(categories, 'dia');
      _parties = parties.map((m) => m['name'] as String).toList();
      _dcNumber = dc ?? 'ERR-GEN';
      _isLoading = false;
    });
  }

  Future<void> _loadEditData() async {
    final categories = await _api.getCategories();
    final parties = await _api.getParties();
    final item = widget.editOutward!;

    setState(() {
      _lotNames = _getValues(categories, 'Lot Name');
      _dias = _getValues(categories, 'dia');
      _parties = parties.map((m) => m['name'] as String).toList();

      _dcNumber = item['dcNo'] ?? '';
      _selectedLotName = item['lotName'];
      _selectedDia = item['dia'];
      _selectedLotNo = item['lotNo'];
      _selectedParty = item['partyName'];
      _process = item['process'];
      _address = item['address'];
      _vehicleController.text = item['vehicleNo'] ?? '';
      _outwardDateTime = DateTime.parse(item['dateTime']);

      _editInchargeSigUrl = item['lotInchargeSignature'];
      _editAuthorizedSigUrl = item['authorizedSignature'];

      // Populate selected sets
      if (item['items'] != null) {
        for (var it in item['items']) {
          _selectedSets.add({
            'set_no': it['set_no'],
            'total_weight': (it['total_weight'] as num).toDouble(),
            'rack_name': it['rack_name'] ?? 'Not Assigned',
            'pallet_number': it['pallet_number'] ?? 'Not Assigned',
            'colours': (it['colours'] as List)
                .map(
                  (c) => {
                    'colour': c['colour'],
                    'weight': (c['weight'] as num).toDouble(),
                    'roll_weight': (c['roll_weight'] as num).toDouble(),
                    'no_of_rolls': c['no_of_rolls'] ?? 0,
                    'isChecked': true,
                  },
                )
                .toList(),
          });
        }
      }

      _isLoading = false;
    });

    // Populate lot numbers and colours
    if (_selectedDia != null) {
      final lots = await _api.getLotsFifo(
        dia: _selectedDia!,
        lotName: _selectedLotName,
      );
      setState(() => _lotNos = lots);

      if (_selectedLotNo != null) {
        final colours = await _api.getColoursByLot(_selectedLotNo!);
        setState(() => _currentLotColours = colours);

        final sets = await _api.getBalancedSets(_selectedLotNo!, _selectedDia!);
        _availableSets = sets;
        await _mapMetadataToSelectedSets();
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _loadInitialFromData() async {
    final categories = await _api.getCategories();
    final parties = await _api.getParties();
    final dc = await _api.generateDcNumber();
    final data = widget.initialOutwardData!;

    setState(() {
      _lotNames = _getValues(categories, 'Lot Name');
      _dias = _getValues(categories, 'dia');
      _parties = parties.map((m) => m['name'] as String).toList();
      _dcNumber = dc ?? 'ERR-GEN';

      _selectedLotName = data['lotName'];
      _selectedDia = data['dia'];
      _selectedLotNo = data['lotNo'];
    });

    if (_selectedDia != null) {
      final lots = await _api.getLotsFifo(
        dia: _selectedDia!,
        lotName: _selectedLotName,
      );
      setState(() => _lotNos = lots);

      if (_selectedLotNo != null) {
        final colours = await _api.getColoursByLot(_selectedLotNo!);
        setState(() => _currentLotColours = colours);

        final sets = await _api.getBalancedSets(_selectedLotNo!, _selectedDia!);
        setState(() {
          _availableSets = sets;
          _isLoading = false;
        });

        // Auto-select sets passed in data
        final List<dynamic> targetSetNos = List<dynamic>.from(
          data['setNos'] ?? const [],
        );
        for (final sNo in targetSetNos) {
          final setNoText = sNo.toString().trim();
          if (setNoText.isEmpty) continue;
          await _toggleSetSelection(setNoText, true);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
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
                  imgPath = ApiConstants.getImageUrl(imgPath);
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
      _lotNos = []; // Clear lot numbers
      _availableSets = [];
      _selectedSets.clear();
    });

    if (val != null && _selectedDia != null) {
      final lots = await _api.getLotsFifo(
        dia: _selectedDia!,
        lotName: val,
      );
      setState(() => _lotNos = lots);
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
      final lots = await _api.getLotsFifo(
        dia: val,
        lotName: _selectedLotName,
      );
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
        final recLotNo = rec['lotNo'].toString().trim();
        _fifoRecommendedLotNo = recLotNo.isEmpty ? null : recLotNo;
        // If the lot is not in current list, add it
        if (recLotNo.isNotEmpty && !_lotNos.contains(recLotNo)) {
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
        final sets = await _api.getBalancedSets(
          val,
          _selectedDia!,
          excludeId: widget.editOutward?['_id'],
        );
        _availableSets = sets;
        await _mapMetadataToSelectedSets();
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _mapMetadataToSelectedSets() async {
    if (_availableSets.isEmpty && widget.editOutward != null) {
      // Re-fetch available sets with exclusion to ensure metadata is recovered during edit
      final sets = await _api.getBalancedSets(
        _selectedLotNo!,
        _selectedDia!,
        excludeId: widget.editOutward!['_id'],
      );
      _availableSets = sets;
    }

    for (var selSet in _selectedSets) {
      final selColours = selSet['colours'] as List;
      for (var selCol in selColours) {
        // Find matching colour in available sets using canonical match
        final match = _availableSets.firstWhere(
          (s) =>
              _isSetMatch(s['set_no'].toString(), selSet['set_no'].toString()) &&
              s['colour'].toString().trim().toLowerCase() ==
                  selCol['colour'].toString().trim().toLowerCase(),
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          selCol['gsm'] = _toDouble(match['gsm']);
          selCol['dia'] = _toDouble(match['dia']);
          selCol['cutting_dia'] = _toDouble(match['cutting_dia']);
        }
      }
    }
  }

  bool _isSetMatch(String s1, String s2) {
    if (s1.trim() == s2.trim()) return true;
    String clean(String s) {
      return s.toLowerCase().replaceAll('set', '').replaceAll('s-', '').replaceAll('-', '').trim();
    }
    final c1 = clean(s1);
    final c2 = clean(s2);
    if (c1 == c2) return true;
    // Handle leading zeros
    final int? n1 = int.tryParse(c1);
    final int? n2 = int.tryParse(c2);
    if (n1 != null && n2 != null) return n1 == n2;
    return false;
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
                : (label == "Lot Incharge" && _editInchargeSigUrl != null)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.network(
                      ApiConstants.getImageUrl(_editInchargeSigUrl),
                      fit: BoxFit.contain,
                    ),
                  )
                : (label == "Authorized" && _editAuthorizedSigUrl != null)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.network(
                      ApiConstants.getImageUrl(_editAuthorizedSigUrl),
                      fit: BoxFit.contain,
                    ),
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

  Future<void> _toggleSetSelection(String setNo, bool selected) async {
    if (selected) {
      if (_selectedLotNo == null || _selectedDia == null) return;

      final selectedLot = _selectedLotNo!.trim();
      final recLot = _fifoRecommendedLotNo?.trim() ?? '';
      if (recLot.isNotEmpty &&
          selectedLot.toLowerCase() != recLot.toLowerCase()) {
        final warnKey = 'lot|$selectedLot|${_selectedDia}|$recLot';
        if (_lastFifoWarnKey != warnKey) {
          _lastFifoWarnKey = warnKey;
          _showError('FIFO: Please outward Lot $recLot first');
        }
        return;
      }

      // FIFO VALIDATION
      final violation = await _api.checkFifoViolation(
        _selectedLotNo!,
        _selectedDia!,
        setNo,
      );

      if (violation != null && violation['violation'] == true) {
        if (!mounted) return;

        final msg =
            violation['message'] ??
            'This Dia, Set Number, Rack, and Pallet Number are already available in a previous lot.';

        final warnKey = 'set|${_selectedLotNo}|${_selectedDia}|$setNo';
        if (_lastFifoWarnKey != warnKey) {
          _lastFifoWarnKey = warnKey;
          _showError(msg);
        }
        return; // Prevent selection
      }

      if (!mounted) return;

      // Prevent duplicate selection
      if (_selectedSets.any((s) => _isSetMatch(s['set_no'].toString(), setNo))) return;

      setState(() {
        // Find existing stock entries for this set
        final setStock = _availableSets
            .where((s) => _isSetMatch(s['set_no'].toString(), setNo))
            .toList();

        final List<Map<String, dynamic>> colours = [];
        double setTotalWeight = 0;

        // Use ONLY Lot Specific Colours (_currentLotColours)
        final lotColours = _currentLotColours.isNotEmpty
            ? _currentLotColours
            : setStock
                  .map((s) => s['colour']?.toString() ?? 'N/A')
                  .toSet()
                  .toList();

        for (var lotCol in lotColours) {
          // Check if we have stock for this color in this set
          final stockItem = setStock.firstWhere(
            (s) =>
                _isSetMatch(s['set_no'].toString(), setNo.toString()) &&
                s['colour'].toString().trim().toLowerCase() ==
                    lotCol.toString().trim().toLowerCase(),
            orElse: () => {},
          );

          final w = (stockItem['weight'] as num?)?.toDouble() ?? 0.0;
          final r = (stockItem['rolls'] as num?)?.toInt() ?? (w > 0 ? 1 : 0);
          setTotalWeight += w;

          colours.add({
            'colour': lotCol,
            'weight': w,
            'roll_weight': w,
            'no_of_rolls': r,
            'gsm': _toDouble(stockItem['gsm']),
            'dia': _toDouble(stockItem['dia']),
            'cutting_dia': _toDouble(stockItem['cutting_dia']),
            'isChecked': w > 0, // Automatically check if weight is present
          });
        }

        // If for some reason colours list is still empty, fall back to stock entries
        if (colours.isEmpty) {
          for (var entry in setStock) {
            final w = (entry['weight'] as num?)?.toDouble() ?? 0.0;
            final r = (entry['rolls'] as num?)?.toInt() ?? 1;
            setTotalWeight += w;
            colours.add({
              'colour': entry['colour'] ?? 'N/A',
              'weight': w,
              'roll_weight': w,
              'no_of_rolls': r,
              'gsm': _toDouble(entry['gsm']),
              'dia': _toDouble(entry['dia']),
              'cutting_dia': _toDouble(entry['cutting_dia']),
              'isChecked': false,
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
        _activeSetIndex = _selectedSets.length - 1;
      });
    } else {
      setState(() {
        _selectedSets.removeWhere((s) => s['set_no'].toString() == setNo);
        if (_activeSetIndex >= _selectedSets.length) {
          _activeSetIndex = _selectedSets.isEmpty
              ? 0
              : _selectedSets.length - 1;
        }
      });
    }
  }

  void _removeSet(int index) {
    setState(() {
      _selectedSets.removeAt(index);
      if (_activeSetIndex >= _selectedSets.length) {
        _activeSetIndex = _selectedSets.isEmpty ? 0 : _selectedSets.length - 1;
      }
    });
  }

  // Summary calculation functions
  Map<String, double> _getColourTotals() {
    final Map<String, double> totals = {};
    for (var set in _selectedSets) {
      final colours = set['colours'] as List;
      for (var col in colours) {
        if (col['isChecked'] == true) { // Filter only checked colors
          final name = col['colour'].toString().trim().isEmpty
              ? 'N/A'
              : col['colour'].toString();
          totals[name] = (totals[name] ?? 0) + (col['weight'] as double);
        }
      }
    }
    return totals;
  }

  double _calculateMeters(double weight, double gsm, double dia) {
    if (weight <= 0 || gsm <= 0 || dia <= 0) {
      debugPrint('Meter Calculation Skipped: weight=$weight, gsm=$gsm, dia=$dia');
      return 0.0;
    }
    // Formula: (roll_wt * 1000) / (gsm * (cuttable_dia * 2 / 39.37))
    try {
      final double result = (weight * 1000.0) / (gsm * (dia * 2.0 / 39.37));
      return result;
    } catch (e) {
      debugPrint('Meter Calculation Error: $e');
      return 0.0;
    }
  }

  Map<String, double> _getColourMeterTotals() {
    final Map<String, double> totals = {};
    for (var set in _selectedSets) {
      final colours = set['colours'] as List;
      for (var col in colours) {
        if (col['isChecked'] == true) {
          final name = col['colour'].toString().trim().isEmpty
              ? 'N/A'
              : col['colour'].toString();
          final w = (col['weight'] as num?)?.toDouble() ?? 0.0;
          final g = (col['gsm'] as num?)?.toDouble() ?? 0.0;
          final d = (col['dia'] as num?)?.toDouble() ?? 0.0;
          final m = _calculateMeters(w, g, d);
          totals[name] = (totals[name] ?? 0.0) + m;
        }
      }
    }
    return totals;
  }

  double _getTotalMeters() {
    double total = 0.0;
    // Mirror exactly how the grid METER column is computed:
    // for each colour, sum roll_weight across ALL sets, then calculate meters once.
    final colours = _getSelectedSetColourOrder();
    for (final colour in colours) {
      final rowRollWeight = _getColourRollWeightTotal(colour);
      if (rowRollWeight <= 0) continue;
      // Get GSM and DIA (prefer cutting_dia) from the first set that has them
      double gsm = 0.0;
      double dia = 0.0;
      for (var s in _selectedSets) {
        final ent = _findSetColourEntry(s, colour);
        if (ent != null) {
          gsm = _toDouble(ent['gsm']);
          dia = _getMeterDia(ent);
          if (gsm > 0 && dia > 0) break;
        }
      }
      final meters = _calculateMeters(rowRollWeight, gsm, dia);
      // Round to 1 decimal to match displayed grid values before summing
      total += double.parse(meters.toStringAsFixed(1));
    }
    return total;
  }

  double _getTotalWeight() {
    return _selectedSets.fold(
      0.0,
      (sum, set) => sum + (set['total_weight'] as double),
    );
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final v = val.trim();
      if (v.isEmpty) return 0.0;
      return double.tryParse(v) ?? 0.0;
    }
    return 0.0;
  }

  double _getMeterDia(Map<String, dynamic> col) {
    final cd = _toDouble(col['cutting_dia']);
    if (cd > 0) return cd;
    return _toDouble(col['dia']);
  }

  double _getTotalRollWeight() {
    double total = 0;
    for (var set in _selectedSets) {
      final colours = set['colours'] as List;
      for (var col in colours) {
        if (col['isChecked'] == true) { // Filter only checked colors
          total += (col['roll_weight'] as double);
        }
      }
    }
    return total;
  }

  int _getTotalRolls() {
    int total = 0;
    for (var set in _selectedSets) {
      final colours = set['colours'] as List;
      for (var col in colours) {
        if (col['isChecked'] == true) {
          total += (col['rolls'] as num?)?.toInt() ?? 1;
        }
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

    // FIFO priority check (Lot Name + DIA)
    if (_selectedLotName != null && _selectedDia != null) {
      final rec = await _api.getFifoRecommendation(
        _selectedLotName!,
        _selectedDia!,
      );
      final fifoLotNo = rec?['lotNo']?.toString().trim();
      final selectedLot = _selectedLotNo?.trim() ?? '';
      if (fifoLotNo != null && fifoLotNo.isNotEmpty) {
        if (selectedLot.toLowerCase() != fifoLotNo.toLowerCase()) {
          _showError('FIFO: Please outward Lot $fifoLotNo first');
          return;
        }
      }
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

    // signature validation
    bool inchargeSigned =
        _lotInchargeSignature != null || _editInchargeSigUrl != null;
    bool authSigned =
        _authorizedSignature != null || _editAuthorizedSigUrl != null;

    if (!inchargeSigned || !authSigned) {
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
            (set) {
              final checkedColours = (set['colours'] as List)
                  .where((col) => col['isChecked'] == true)
                  .map(
                    (col) => {
                      'colour': col['colour'],
                      'weight': col['weight'],
                      'roll_weight': col['roll_weight'],
                      'no_of_rolls': col['no_of_rolls'],
                    },
                  )
                  .toList();
              return {
                'set_no': set['set_no'],
                'total_weight': set['total_weight'], // Already recalculated correctly
                'rack_name': set['rack_name'],
                'pallet_number': set['pallet_number'],
                'colours': checkedColours,
              };
            },
          )
          .where((set) => (set['colours'] as List).isNotEmpty) // Only save sets with at least one color checked
          .toList(),
      'lotInchargeSignature': _lotInchargeSignature,
      'authorizedSignature': _authorizedSignature,
      'lotInchargeSignTime': DateTime.now().toIso8601String(),
      'authorizedSignTime': DateTime.now().toIso8601String(),
    };

    try {
      bool success;
      if (_isEditMode) {
        success = await _api.updateOutward(
          widget.editOutward!['_id'],
          outwardData,
        );
      } else {
        success = await _api.saveOutward(outwardData);
      }

      if (success) {
        setState(() => _isSaved = true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Outward Updated: $_dcNumber'
                  : 'Outward Registered: $_dcNumber',
            ),
          ),
        );

        if (!_isEditMode) {
          _showPrintStickerDialog();
        } else {
          Navigator.pop(context);
        }
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
    final totalRolls = _getTotalRolls();

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
                _buildSummaryRow('Total Rolls', '$totalRolls'),
                const SizedBox(height: 4),
                _buildSummaryRow('Total Sets', '${_selectedSets.length}'),
                const SizedBox(height: 4),
                _buildSummaryRow(
                  'Total Meters',
                  '${_getTotalMeters().toStringAsFixed(1)} m',
                  isMain: true,
                ),
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
            color: isMain ? Theme.of(context).primaryColor : Colors.black87,
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

    // Ensure index is valid
    if (_activeSetIndex >= _selectedSets.length) {
      _activeSetIndex = 0;
    }

    final activeSet = _selectedSets[_activeSetIndex];
    final colours = _getSelectedSetColourOrder();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECT SET NO (UNIQUE)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _selectedSets.asMap().entries.map((entry) {
              final index = entry.key;
              final set = entry.value;
              final isSelected = index == _activeSetIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    'Set ${set['set_no']}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() => _activeSetIndex = index);
                    }
                  },
                  selectedColor: Colors.lightBlue.shade100,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.lightBlue
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'SELECTED SET DETAILS (EDITABLE)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            Text(
              'Active: Set ${activeSet['set_no']}',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 18),
              onPressed: () => _removeSet(_activeSetIndex),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: {
                0: const FixedColumnWidth(180),
                for (int i = 0; i < _selectedSets.length; i++)
                  i + 1: const FixedColumnWidth(150),
                _selectedSets.length + 1: const FixedColumnWidth(95),
                _selectedSets.length + 2: const FixedColumnWidth(100),
                _selectedSets.length + 3: const FixedColumnWidth(100),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.shade50.withOpacity(0.6),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  children: [
                    _buildGridHeaderCell('COLOUR'),
                    ..._selectedSets.map((set) {
                      return _buildGridHeaderCell(
                        'Set ${set['set_no']}\nRack: ${set['rack_name']}\nPallet: ${set['pallet_number']}',
                        alignStart: true,
                      );
                    }),
                    _buildGridHeaderCell('ROLLS'),
                    _buildGridHeaderCell('ROLL WT'),
                    _buildGridHeaderCell('METER'),
                  ],
                ),
                ...colours.map((col) {
                  final rowWeight = _getColourWeightTotal(col);
                  final rowRollWeight = _getColourRollWeightTotal(col);
                  final rowRolls = _getColourRollTotal(col);

                  return TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    children: [
                      _buildColourGridCell(col, activeSet),
                      ..._selectedSets.map((set) {
                        final entry = _findSetColourEntry(set, col);
                        final value =
                            (entry?['roll_weight'] as num?)?.toDouble() ?? 0.0;
                        final controller =
                            entry?['controller'] as TextEditingController?;

                        return _buildSetWeightInput(
                          value,
                          onChanged: (v) {
                            setState(() {
                              final parsed = double.tryParse(v) ?? 0.0;
                              final target = _ensureSetColourEntry(set, col);
                              target['weight'] = parsed;
                              target['roll_weight'] = parsed;
                              target['isChecked'] = parsed > 0;
                              (target['controller'] as TextEditingController?)
                                  ?.text = v;
                              _recalculateSetTotalWeight(set);
                            });
                          },
                          onMicTap: _enableVoiceInput
                              ? () => _startVoiceInputForSetWeight(set, col)
                              : null,
                          onWeightTap: _enableWeightInput
                              ? () => _captureScaleWeightForColour(set, col)
                              : null,
                          controller: controller,
                        );
                      }),
                      _buildGridValueCell(rowRolls.toString()),
                      _buildGridValueCell(_formatGridNumber(rowRollWeight)),
                      _buildGridValueCell(() {
                        // Get GSM and DIA for this color from the first set that has it
                        double gsm = 0.0;
                        double dia = 0.0;
                        for (var s in _selectedSets) {
                          final ent = _findSetColourEntry(s, col);
                          if (ent != null) {
                            gsm = _toDouble(ent['gsm']);
                            dia = _getMeterDia(ent);
                            if (gsm > 0 && dia > 0) break;
                          }
                        }
                        final meters = _calculateMeters(rowRollWeight, gsm, dia);
                        if (rowRollWeight > 0) {
                          if (gsm <= 0) return _buildErrorText("NO GSM");
                          if (dia <= 0) return _buildErrorText("NO DIA");
                        }
                        return meters.toStringAsFixed(1);
                      }()),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<String> _getSelectedSetColourOrder() {
    final ordered = <String>[];
    final seen = <String>{};

    void addColour(dynamic value) {
      final colour = value?.toString().trim() ?? '';
      if (colour.isNotEmpty && !seen.contains(colour)) {
        seen.add(colour);
        ordered.add(colour);
      }
    }

    for (final colour in _currentLotColours) {
      addColour(colour);
    }
    for (final set in _selectedSets) {
      final setColours = set['colours'] as List? ?? [];
      for (final col in setColours) {
        if (col is Map<String, dynamic>) {
          addColour(col['colour']);
        } else if (col is Map) {
          addColour(col['colour']);
        }
      }
    }
    return ordered;
  }

  Map<String, dynamic>? _findSetColourEntry(
    Map<String, dynamic> set,
    String colour,
  ) {
    final setColours = set['colours'] as List? ?? [];
    for (final col in setColours) {
      if (col is Map<String, dynamic>) {
        final name = col['colour']?.toString().trim().toLowerCase() ?? '';
        if (name == colour.trim().toLowerCase()) return col;
      } else if (col is Map) {
        final name = col['colour']?.toString().trim().toLowerCase() ?? '';
        if (name == colour.trim().toLowerCase()) {
          return Map<String, dynamic>.from(col);
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _ensureSetColourEntry(
    Map<String, dynamic> set,
    String colour,
  ) {
    final setColours = set['colours'] as List? ?? [];
    for (int i = 0; i < setColours.length; i++) {
      final col = setColours[i];
      if (col is Map<String, dynamic>) {
        final name = col['colour']?.toString().trim().toLowerCase() ?? '';
        if (name == colour.trim().toLowerCase()) {
          col['controller'] ??= TextEditingController(
            text: (col['roll_weight'] as num?)?.toString() ?? '',
          );
          return col;
        }
      } else if (col is Map) {
        final name = col['colour']?.toString().trim().toLowerCase() ?? '';
        if (name == colour.trim().toLowerCase()) {
          final fixed = Map<String, dynamic>.from(col);
          fixed['controller'] ??= TextEditingController(
            text: (fixed['roll_weight'] as num?)?.toString() ?? '',
          );
          setColours[i] = fixed;
          return fixed;
        }
      }
    }

    final newEntry = <String, dynamic>{
      'colour': colour,
      'weight': 0.0,
      'roll_weight': 0.0,
      'no_of_rolls': 0,
      'isChecked': false,
      'controller': TextEditingController(),
    };
    setColours.add(newEntry);
    set['colours'] = setColours;
    return newEntry;
  }

  void _recalculateSetTotalWeight(Map<String, dynamic> set) {
    final setColours = set['colours'] as List? ?? [];
    double total = 0.0;
    for (final col in setColours) {
      if (col['isChecked'] == true) { // Filter only checked colors
        if (col is Map<String, dynamic>) {
          total += (col['weight'] as num?)?.toDouble() ?? 0.0;
        } else if (col is Map) {
          total += (col['weight'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }
    set['total_weight'] = total;
  }

  int _getColourRollTotal(String colour) {
    int total = 0;
    for (final set in _selectedSets) {
      final col = _findSetColourEntry(set, colour);
      total += (col?['no_of_rolls'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  double _getColourWeightTotal(String colour) {
    double total = 0.0;
    for (final set in _selectedSets) {
      final col = _findSetColourEntry(set, colour);
      total += (col?['weight'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  double _getColourRollWeightTotal(String colour) {
    double total = 0.0;
    for (final set in _selectedSets) {
      final col = _findSetColourEntry(set, colour);
      total += (col?['roll_weight'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  String _formatGridNumber(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Future<double> _captureNetScaleWeight() async {
    final raw = await _scaleService.captureWeight();
    final net = raw - _tareOffset;
    return net <= 0 ? 0.0 : net;
  }

  Future<void> _setCurrentAsTare() async {
    try {
      final raw = await _scaleService.captureWeight();
      if (!mounted) return;
      setState(() => _tareOffset = raw);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tare set: ${_tareOffset.toStringAsFixed(3)} Kg (net = gross - tare)',
          ),
        ),
      );
    } catch (e) {
      _showError('Failed to set tare: $e');
    }
  }

  Future<void> _captureScaleWeightForColour(
    Map<String, dynamic> set,
    String colour,
  ) async {
    try {
      final net = await _captureNetScaleWeight();
      if (!mounted) return;
      setState(() {
        final target = _ensureSetColourEntry(set, colour);
        target['weight'] = net;
        target['roll_weight'] = net;
        target['isChecked'] = net > 0;
        _recalculateSetTotalWeight(set);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Captured: ${net.toStringAsFixed(3)} Kg')),
      );
    } catch (e) {
      _showError('Machine read failed: $e');
    }
  }

  Widget _buildGridHeaderCell(String label, {bool alignStart = false}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      alignment: alignStart ? Alignment.centerLeft : Alignment.center,
      child: Text(
        label,
        textAlign: alignStart ? TextAlign.left : TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildColourGridCell(String colour, Map<String, dynamic> activeSet) {
    final activeEntry = _findSetColourEntry(activeSet, colour);
    final checked = (activeEntry?['isChecked'] as bool?) ?? false;

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: checked,
              onChanged: (val) {
                setState(() {
                  final target = _ensureSetColourEntry(activeSet, colour);
                  target['isChecked'] = val ?? false;
                  _recalculateSetTotalWeight(activeSet); // Trigger recalculation
                });
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          if (_colourImages.containsKey(colour))
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
                image: DecorationImage(
                  image: NetworkImage(_colourImages[colour]!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Expanded(
            child: Text(
              colour,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetWeightInput(
    double value, {
    required Function(String) onChanged,
    VoidCallback? onMicTap,
    VoidCallback? onWeightTap,
    TextEditingController? controller,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null
            ? (value == 0 ? '' : _formatGridNumber(value))
            : null,
        onChanged: onChanged,
        onTap: (_enableWeightInput && onWeightTap != null) ? onWeightTap : null,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: (onMicTap != null || onWeightTap != null)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onMicTap != null)
                      IconButton(
                        icon: const Icon(Icons.mic, size: 14),
                        onPressed: onMicTap,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 14,
                      ),
                    if (onWeightTap != null && !_enableWeightInput)
                      IconButton(
                        icon: Icon(
                          Icons.monitor_weight_outlined,
                          size: 14,
                          color: Colors.green.shade700,
                        ),
                        onPressed: onWeightTap,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 14,
                      ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildGridValueCell(dynamic value) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: value is Widget
          ? value
          : Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
    );
  }

  void _openInputControlSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, modalSetState) {
            void sync(VoidCallback fn) {
              setState(fn);
              modalSetState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Input Controls',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => sync(
                              () => _enableVoiceInput = !_enableVoiceInput,
                            ),
                            icon: Icon(
                              _enableVoiceInput ? Icons.mic : Icons.mic_off,
                              size: 16,
                            ),
                            label: Text(
                              _enableVoiceInput ? 'Voice ON' : 'Voice OFF',
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _enableVoiceInput
                                  ? Colors.blue.shade50
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => sync(
                              () => _enableWeightInput = !_enableWeightInput,
                            ),
                            icon: Icon(
                              _enableWeightInput
                                  ? Icons.monitor_weight_outlined
                                  : Icons.monitor_weight,
                              size: 16,
                            ),
                            label: Text(
                              _enableWeightInput ? 'Weight ON' : 'Weight OFF',
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _enableWeightInput
                                  ? Colors.green.shade50
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _enableWeightInput
                                ? () async {
                                    await _setCurrentAsTare();
                                    if (mounted) modalSetState(() {});
                                  }
                                : null,
                            icon: const Icon(Icons.tune, size: 16),
                            label: const Text('Set Tare'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _tareOffset > 0
                                ? () => sync(() => _tareOffset = 0)
                                : null,
                            icon: const Icon(Icons.restore, size: 16),
                            label: const Text('Clear Tare'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Current Tare: ${_tareOffset.toStringAsFixed(3)} Kg',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
        title: Text(
          _isEditMode ? 'EDIT OUTWARD' : 'OUTWARD',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Input Controls',
            onPressed: _openInputControlSheet,
          ),
          IconButton(
            icon: Icon(
              _isManual ? LucideIcons.scanLine : LucideIcons.mousePointer2,
            ),
            tooltip: _isManual ? 'Switch to Scan' : 'Switch to Manual',
            onPressed: () {
              setState(() {
                _isManual = !_isManual;
                if (!_isManual) {
                  // Initialize scanner when switching to scan mode
                  _scannerController ??= MobileScannerController(
                    detectionSpeed: DetectionSpeed.noDuplicates,
                    facing: CameraFacing.back,
                    torchEnabled: false,
                  );
                  _scannerController?.start();
                } else {
                  // Stop scanner when switching to manual
                  _scannerController?.stop();
                }
              });
            },
          ),
          if (_enableVoiceInput)
            IconButton(
              icon: const Icon(LucideIcons.mic),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Voice input (Tamil/English)...'),
                  ),
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
              const SizedBox(height: 16),

              if (_isManual) _buildMainForm() else _buildScanSection(),
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
                        : (_isSaved
                              ? 'Dispatch Confirmed'
                              : (_isEditMode
                                    ? 'Update Outward'
                                    : 'Save Outward')),
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
            'âš ï¸ No sets available for this Lot Number. Please ensure you completed the "Sticker & Storage Details" (Next Page) during Inward Entry.',
            style: TextStyle(color: Colors.orange, fontSize: 13),
          ),
        ),
      );
    }
    if (_availableSets.isEmpty) return const SizedBox.shrink();

    // Group available sets by unique set id (supports both numeric and labels like S-4)
    final uniqueSetNos = <String>{};
    for (var s in _availableSets) {
      final setNo = s['set_no']?.toString().trim() ?? '';
      if (setNo.isNotEmpty) uniqueSetNos.add(setNo);
    }
    final sortedSetNos = uniqueSetNos.toList()
      ..sort((a, b) {
        int key(String value) {
          final match = RegExp(r'\d+').firstMatch(value);
          return int.tryParse(match?.group(0) ?? '') ?? 1 << 30;
        }

        final kA = key(a);
        final kB = key(b);
        if (kA != kB) return kA.compareTo(kB);
        return a.compareTo(b);
      });

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
              (sel) => sel['set_no'].toString() == setNo,
            );

            return ChoiceChip(
              label: Text('Set $setNo', style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (selected) {
                _toggleSetSelection(setNo, selected);
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

  Widget _buildScanSection() {
    return Column(
      children: [
        Container(
          height: 300,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final String? code = barcode.rawValue;
                  if (code != null && code.isNotEmpty) {
                    _handleScannedCode(code);
                    break; // Handle first valid code
                  }
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Point camera at a Lot QR/Barcode',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  void _handleScannedCode(String code) {
    debugPrint('Scanned Code: $code');

    // Parse data robustly (handles multi-line or flattened single-line strings)
    String? getValue(String key) {
      final keyPattern = '$key:';
      if (!code.contains(keyPattern)) return null;

      final start = code.indexOf(keyPattern) + keyPattern.length;
      // Find the next key to know where to stop
      final keys = ['LOT:', 'NAME:', 'DIA:', 'COL:', 'SET:', 'WT:', 'DT:'];
      int end = code.length;

      for (var k in keys) {
        if (k == keyPattern) continue;
        final nextKeyPos = code.indexOf(k, start);
        if (nextKeyPos != -1 && nextKeyPos < end) {
          end = nextKeyPos;
        }
      }
      return code.substring(start, end).trim();
    }

    String? scannedLotNo = getValue('LOT');
    String? scannedLotName = getValue('NAME');
    String? scannedDia = getValue('DIA');
    String? scannedSetNo = getValue('SET');
    // If 'SET' fails, try 'Set No' just in case of old formats
    scannedSetNo ??= getValue('Set No');
    // Clean set number from prefix like #
    if (scannedSetNo != null && scannedSetNo.startsWith('#')) {
      scannedSetNo = scannedSetNo.substring(1);
    }

    String? scannedColour = getValue('COL');

    // If no keys found, treat whole code as Lot No (Fallback)
    if (scannedLotNo == null && !code.contains(':')) {
      scannedLotNo = code.trim();
    }

    if (scannedLotNo == null || scannedLotNo.isEmpty) {
      _showError('Invalid QR Code: Could not find Lot Number');
      return;
    }

    // Auto-selection logic
    bool needsDiaChange = scannedDia != null && scannedDia != _selectedDia;

    setState(() {
      _isManual = true; // Switch to manual to show details
      if (scannedDia != null && _dias.contains(scannedDia)) {
        _selectedDia = scannedDia;
      }
      if (scannedLotName != null && _lotNames.contains(scannedLotName)) {
        _selectedLotName = scannedLotName;
      }
    });

    // If DIA changed, we need to refresh lot numbers first
    if (needsDiaChange) {
      _onDiaChanged(scannedDia).then((_) {
        _processScannedLot(
          scannedLotNo!,
          scannedSetNo,
          scannedColour,
          scannedLotName,
        );
      });
    } else {
      _processScannedLot(
        scannedLotNo,
        scannedSetNo,
        scannedColour,
        scannedLotName,
      );
    }
  }

  void _processScannedLot(
    String lotNo,
    String? setNo,
    String? scannedColour,
    String? lotName,
  ) {
    // Check if lot exists in current DIA's list
    if (!_lotNos.contains(lotNo)) {
      // If lot name was provided, maybe it's recommended?
      // But we strictly check the loaded _lotNos for safety.
      _showError('Lot No "$lotNo" not found for DIA $_selectedDia');
      return;
    }

    setState(() {
      _selectedLotNo = lotNo;
    });

    _onLotNoChanged(lotNo).then((_) {
      if (!mounted) return;
      // Auto-toggle set if provided
      if (setNo != null) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _toggleSetSelection(setNo, true);

            // After toggling, we can try to find the specific color from scan
            // and ensure it's checked (though our logic already checks all stock colors)
            if (scannedColour != null) {
              setState(() {
                final activeSet = _selectedSets.firstWhere(
                  (s) => s['set_no'].toString() == setNo,
                  orElse: () => {},
                );
                if (activeSet.isNotEmpty) {
                  final colours = activeSet['colours'] as List;
                  for (var col in colours) {
                    if (col['colour'] == scannedColour) {
                      col['isChecked'] = true;
                    }
                  }
                }
              });
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lot & Set Found: $lotNo, Set $setNo'),
                backgroundColor: Colors.green,
              ),
            );
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lot Found: $lotNo'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  Widget _buildErrorText(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.red.shade700,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
