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
import 'package:google_fonts/google_fonts.dart';

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

  void _recalculateSetTotalWeight(Map<String, dynamic> set) {
    final colours = (set['colours'] as List?) ?? [];
    double total = 0;
    for (var col in colours) {
      if (col['isChecked'] == true) {
        total += (col['roll_weight'] as num?)?.toDouble() ?? 0.0;
      }
    }
    setState(() {
      set['total_weight'] = total;
    });
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
            .replaceAll('à®ªà¯ à®³à¯ à®³à®¿', '.');

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
      _lotNos = [];
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
      _currentLotColours = [];
      _availableSets = [];
      _selectedSets.clear();
    });
    if (val != null) {
      final colours = await _api.getColoursByLot(val);
      setState(() => _currentLotColours = colours);

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

      final violation = await _api.checkFifoViolation(
        _selectedLotNo!,
        _selectedDia!,
        setNo,
      );

      if (violation != null && violation['violation'] == true) {
        if (!mounted) return;
        final msg = violation['message'] ?? 'This Set is available in a previous lot.';
        final warnKey = 'set|${_selectedLotNo}|${_selectedDia}|$setNo';
        if (_lastFifoWarnKey != warnKey) {
          _lastFifoWarnKey = warnKey;
          _showError(msg);
        }
        return;
      }

      if (!mounted) return;
      if (_selectedSets.any((s) => _isSetMatch(s['set_no'].toString(), setNo))) return;

      setState(() {
        final setStock = _availableSets
            .where((s) => _isSetMatch(s['set_no'].toString(), setNo))
            .toList();

        final List<Map<String, dynamic>> colours = [];
        double setTotalWeight = 0;

        final lotColours = _currentLotColours.isNotEmpty
            ? _currentLotColours
            : setStock.map((s) => s['colour']?.toString() ?? 'N/A').toSet().toList();

        for (var lotCol in lotColours) {
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
            'isChecked': w > 0,
          });
        }

        _selectedSets.add({
          'set_no': setNo,
          'total_weight': setTotalWeight,
          'colours': colours,
          'rack_name': setStock.isNotEmpty ? (setStock.first['rack_name'] ?? 'Not Assigned') : 'Not Assigned',
          'pallet_number': setStock.isNotEmpty ? (setStock.first['pallet_number'] ?? 'Not Assigned') : 'Not Assigned',
        });
        _activeSetIndex = _selectedSets.length - 1;
      });
    } else {
      setState(() {
        _selectedSets.removeWhere((s) => s['set_no'].toString() == setNo);
        if (_activeSetIndex >= _selectedSets.length) {
          _activeSetIndex = _selectedSets.isEmpty ? 0 : _selectedSets.length - 1;
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

  Map<String, double> _getColourTotals() {
    final Map<String, double> totals = {};
    for (var set in _selectedSets) {
      final colours = set['colours'] as List;
      for (var col in colours) {
        if (col['isChecked'] == true) {
          final name = col['colour'].toString().trim().isEmpty ? 'N/A' : col['colour'].toString();
          totals[name] = (totals[name] ?? 0) + (col['weight'] as double);
        }
      }
    }
    return totals;
  }

  double _calculateMeters(double weight, double gsm, double dia) {
    if (weight <= 0 || gsm <= 0 || dia <= 0) return 0.0;
    try {
      return (weight * 1000.0) / (gsm * (dia * 2.0 / 39.37));
    } catch (e) {
      return 0.0;
    }
  }

  double _getTotalMeters() {
    double total = 0.0;
    final colours = _getSelectedSetColourOrder();
    for (final colour in colours) {
      final rowRollWeight = _getColourRollWeightTotal(colour);
      if (rowRollWeight <= 0) continue;
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
      total += double.parse(meters.toStringAsFixed(1));
    }
    return total;
  }

  double _getTotalWeight() {
    return _selectedSets.fold(0.0, (sum, set) => sum + (set['total_weight'] as double));
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val.trim()) ?? 0.0;
    return 0.0;
  }

  double _getMeterDia(Map<String, dynamic> col) {
    final cd = _toDouble(col['cutting_dia']);
    return cd > 0 ? cd : _toDouble(col['dia']);
  }

  int _getTotalRolls() {
    int total = 0;
    for (var set in _selectedSets) {
      final colours = set['colours'] as List;
      for (var col in colours) {
        if (col['isChecked'] == true) {
          total += (col['no_of_rolls'] as num?)?.toInt() ?? 0;
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
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_outwardDateTime));
      if (time != null) {
        setState(() => _outwardDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
      }
    }
  }

  Future<void> _save() async {
    if (_selectedLotNo == null || _selectedParty == null || _selectedSets.isEmpty) {
      _showError('Mandatory: Lot No, Party Name, and Sets are required');
      return;
    }

    bool inchargeSigned = _lotInchargeSignature != null || _editInchargeSigUrl != null;
    bool authSigned = _authorizedSignature != null || _editAuthorizedSigUrl != null;
    if (!inchargeSigned || !authSigned) {
      _showError('Mandatory: Both signatures required');
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
      'items': _selectedSets.map((set) {
        final checked = (set['colours'] as List).where((col) => col['isChecked'] == true).map((col) => {
          'colour': col['colour'],
          'weight': col['weight'],
          'roll_weight': col['roll_weight'],
          'no_of_rolls': col['no_of_rolls'],
          'gsm': col['gsm'],
          'dia': col['dia'],
          'cutting_dia': col['cutting_dia'],
        }).toList();
        return {
          'set_no': set['set_no'],
          'total_weight': set['total_weight'],
          'rack_name': set['rack_name'],
          'pallet_number': set['pallet_number'],
          'colours': checked,
        };
      }).where((set) => (set['colours'] as List).isNotEmpty).toList(),
      'lotInchargeSignature': _lotInchargeSignature,
      'authorizedSignature': _authorizedSignature,
    };

    try {
      final success = _isEditMode ? await _api.updateOutward(widget.editOutward!['_id'], outwardData) : await _api.saveOutward(outwardData);
      if (success) {
        setState(() => _isSaved = true);
        if (_isEditMode) Navigator.pop(context); else _showPrintStickerDialog();
      } else {
        _showError('Failed to save dispatch');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Widget _buildErrorText(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showPrintStickerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('SUCCESS', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Outward registered successfully.', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: ColorPalette.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'EDIT OUTWARD' : 'OUTWARD DISPATCH',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1, color: ColorPalette.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: ColorPalette.textPrimary), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings2, size: 20, color: ColorPalette.textMuted),
            onPressed: _openInputControlSheet,
          ),
          IconButton(
            icon: Icon(_isManual ? LucideIcons.scanLine : LucideIcons.mousePointer2, size: 20, color: ColorPalette.textMuted),
            onPressed: () => setState(() {
              _isManual = !_isManual;
              if (!_isManual) {
                _scannerController ??= MobileScannerController();
                _scannerController?.start();
              } else {
                _scannerController?.stop();
              }
            }),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DELIVERY CHALLAN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 1)),
                      Text(_dcNumber, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 32, color: ColorPalette.primary)),
                    ],
                  ),
                  if (!_isManual) const Icon(LucideIcons.scan, size: 32, color: ColorPalette.primary),
                ],
              ),
              const SizedBox(height: 48),
              if (_isManual) _buildMainForm() else _buildScanSection(),
              const SizedBox(height: 48),
              _buildSetSelectionSection(),
              const SizedBox(height: 48),
              _buildSelectedSetsList(),
              if (_selectedSets.isNotEmpty) ...[
                const SizedBox(height: 64),
                _buildSummarySection(),
                const SizedBox(height: 64),
                _buildSignatureSection(),
              ],
              const SizedBox(height: 80),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: (_isSaved || _isSaving) ? null : _save,
                  icon: _isSaving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(LucideIcons.checkCircle, size: 18),
                  label: Text(_isSaving ? 'SAVING...' : (_isSaved ? 'DISPATCH CONFIRMED' : 'SAVE DISPATCH'), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.5)),
                  style: ElevatedButton.styleFrom(backgroundColor: _isSaved ? Colors.grey : ColorPalette.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormSectionHeader('BASIC DETAILS'),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(child: _buildDropdown('LOT NAME', _lotNames, _selectedLotName, _onLotNameChanged)),
            const SizedBox(width: 24),
            Expanded(child: InkWell(onTap: _isSaved ? null : _selectDateTime, child: _buildReadOnlyField('DATE & TIME', DateFormat('dd-MM-yyyy hh:mm a').format(_outwardDateTime), icon: LucideIcons.calendar))),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildDropdown('DIA', _dias, _selectedDia, _onDiaChanged)),
            const SizedBox(width: 24),
            Expanded(child: _buildDropdown('LOT NO (FIFO)', _lotNos, _selectedLotNo, _onLotNoChanged)),
          ],
        ),
        const SizedBox(height: 48),
        _buildFormSectionHeader('PARTY INFORMATION'),
        const SizedBox(height: 32),
        _buildDropdown('PARTY NAME', _parties, _selectedParty, _onPartyChanged),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildReadOnlyField('PROCESS', _process ?? 'NOT SPECIFIED')),
            const SizedBox(width: 24),
            Expanded(child: _buildReadOnlyField('ADDRESS', _address ?? 'NOT SPECIFIED', maxLines: 1)),
          ],
        ),
      ],
    );
  }

  Widget _buildFormSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: ColorPalette.textPrimary, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(height: 1, width: 32, color: ColorPalette.primary),
      ],
    );
  }

  Widget _buildSetSelectionSection() {
    if (_availableSets.isEmpty && _selectedLotNo != null) return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)), child: Row(children: [const Icon(LucideIcons.info, color: ColorPalette.primary, size: 16), const SizedBox(width: 12), Expanded(child: Text('NO SETS AVAILABLE FOR THIS LOT.', style: GoogleFonts.inter(color: ColorPalette.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)))]));
    if (_availableSets.isEmpty) return const SizedBox.shrink();
    final uniqueSetNos = _availableSets.map((s) => s['set_no']?.toString().trim() ?? '').where((s) => s.isNotEmpty).toSet().toList()..sort((a,b) => int.parse(a).compareTo(int.parse(b)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildFormSectionHeader('AVAILABLE SETS'),
      const SizedBox(height: 24),
      Wrap(spacing: 8, runSpacing: 8, children: uniqueSetNos.map((setNo) {
        final isSelected = _selectedSets.any((sel) => sel['set_no'].toString() == setNo);
        return InkWell(onTap: () => _toggleSetSelection(setNo, !isSelected), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: isSelected ? ColorPalette.primary : Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: isSelected ? ColorPalette.primary : ColorPalette.border.withOpacity(0.3))), child: Text('SET $setNo', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : ColorPalette.textPrimary))));
      }).toList()),
    ]);
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged) {
    return CustomDropdownField(label: label, items: items, value: (value != null && items.contains(value)) ? value : null, onChanged: _isSaved ? (v) {} : onChanged);
  }

  Widget _buildReadOnlyField(String label, String value, {IconData? icon, int maxLines = 1}) {
    return InputDecorator(decoration: InputDecoration(labelText: label, labelStyle: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textMuted), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: ColorPalette.border.withOpacity(0.3))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: ColorPalette.border.withOpacity(0.3))), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), prefixIcon: icon != null ? Icon(icon, size: 16, color: ColorPalette.textMuted) : null), child: Text(value.toUpperCase(), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: ColorPalette.textPrimary), overflow: TextOverflow.ellipsis, maxLines: maxLines));
  }

  Widget _buildSelectedSetsList() {
    if (_selectedSets.isEmpty) return const SizedBox.shrink();
    final activeSet = _selectedSets[_activeSetIndex];
    final colours = _getSelectedSetColourOrder();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildFormSectionHeader('INVENTORY COMPOSITION'),
      const SizedBox(height: 24),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _selectedSets.asMap().entries.map((entry) {
        final isSelected = entry.key == _activeSetIndex;
        return Padding(padding: const EdgeInsets.only(right: 8), child: InkWell(onTap: () => setState(() => _activeSetIndex = entry.key), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: isSelected ? const Color(0xFFF8FAFC) : Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: isSelected ? ColorPalette.primary : ColorPalette.border.withOpacity(0.3))), child: Text('SET ${entry.value['set_no']}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: isSelected ? ColorPalette.primary : ColorPalette.textPrimary)))));
      }).toList())),
      const SizedBox(height: 32),
      Container(decoration: BoxDecoration(color: Colors.white, border: Border.all(color: ColorPalette.border.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)), clipBehavior: Clip.antiAlias, child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), color: const Color(0xFFF8FAFC), child: Row(children: [_buildGridHeaderCell('COLOUR', flex: 3), ..._selectedSets.map((set) => _buildGridHeaderCell('SET ${set['set_no']}', flex: 2, align: TextAlign.right)), _buildGridHeaderCell('ROLLS', flex: 1, align: TextAlign.right), _buildGridHeaderCell('ROLL WT', flex: 1, align: TextAlign.right), _buildGridHeaderCell('METER', flex: 1, align: TextAlign.right)])),
        ...colours.map((col) => _buildGridRow(col, activeSet)),
      ])),
    ]);
  }

  Widget _buildGridHeaderCell(String label, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(flex: flex, child: Text(label, textAlign: align, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 1)));
  }

  Widget _buildGridRow(String col, Map<String, dynamic> activeSet) {
    final rowWeight = _getColourRollWeightTotal(col);
    final rowRolls = _getColourRollTotal(col);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), decoration: BoxDecoration(border: Border(top: BorderSide(color: ColorPalette.border.withOpacity(0.1)))), child: Row(children: [
      Expanded(flex: 3, child: Row(children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: _getColourValue(col), shape: BoxShape.circle)), const SizedBox(width: 12), Text(col.toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: ColorPalette.textPrimary))])),
      ..._selectedSets.map((set) {
        final entry = _findSetColourEntry(set, col);
        final value = (entry?['roll_weight'] as num?)?.toDouble() ?? 0.0;
        final controller = entry?['controller'] as TextEditingController?;
        return Expanded(flex: 2, child: Padding(padding: const EdgeInsets.only(left: 12), child: _buildCompactWeightInput(value, controller: controller, onChanged: (v) => setState(() {
          final p = double.tryParse(v) ?? 0.0;
          final t = _ensureSetColourEntry(set, col);
          t['weight'] = t['roll_weight'] = p; t['isChecked'] = p > 0;
          _recalculateSetTotalWeight(set);
        }))));
      }),
      Expanded(flex: 1, child: Text(rowRolls.toString(), textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ColorPalette.textPrimary))),
      Expanded(flex: 1, child: Text(_formatGridNumber(rowWeight), textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: ColorPalette.primary))),
      Expanded(flex: 1, child: Text(_calculateRowMeters(col, rowWeight).toStringAsFixed(1), textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ColorPalette.textMuted))),
    ]));
  }

  double _calculateRowMeters(String col, double rowWeight) {
    if (rowWeight <= 0) return 0.0;
    double gsm = 0.0, dia = 0.0;
    for (var s in _selectedSets) {
      final ent = _findSetColourEntry(s, col);
      if (ent != null) { gsm = _toDouble(ent['gsm']); dia = _getMeterDia(ent); if (gsm > 0 && dia > 0) break; }
    }
    return _calculateMeters(rowWeight, gsm, dia);
  }

  Widget _buildCompactWeightInput(double value, {TextEditingController? controller, required Function(String) onChanged}) {
    return SizedBox(height: 32, child: TextFormField(controller: controller, onChanged: onChanged, textAlign: TextAlign.right, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: ColorPalette.textPrimary), decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), fillColor: const Color(0xFFF8FAFC), filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: BorderSide.none), hintText: '0.0', hintStyle: GoogleFonts.inter(color: ColorPalette.border, fontSize: 11))));
  }

  Color _getColourValue(String name) {
    final n = name.toLowerCase();
    if (n.contains('red')) return Colors.red; if (n.contains('blue')) return Colors.blue; if (n.contains('green')) return Colors.green;
    if (n.contains('yellow')) return Colors.yellow; if (n.contains('black')) return Colors.black;
    return Colors.grey.shade400;
  }

  Widget _buildSummarySection() {
    final totals = _getColourTotals(), weight = _getTotalWeight(), rolls = _getTotalRolls();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildFormSectionHeader('DISPATCH SUMMARY'),
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(4)), child: Column(children: [
        ...totals.entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Text(e.key.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: ColorPalette.textMuted)), const Spacer(), Text('${e.value.toStringAsFixed(2)} KG', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: ColorPalette.textPrimary))]))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Divider(height: 1, color: ColorPalette.border.withOpacity(0.2))),
        _buildSummaryRow('TOTAL WEIGHT', '${weight.toStringAsFixed(2)} KG', isMain: true),
        const SizedBox(height: 12),
        _buildSummaryRow('TOTAL ROLLS', rolls.toString()),
        const SizedBox(height: 8),
        _buildSummaryRow('TOTAL METERS', '${_getTotalMeters().toStringAsFixed(1)} M'),
      ])),
    ]);
  }

  Widget _buildSummaryRow(String label, String value, {bool isMain = false}) {
    return Row(children: [Text(label, style: GoogleFonts.inter(fontSize: isMain ? 12 : 10, fontWeight: isMain ? FontWeight.w900 : FontWeight.w700, color: isMain ? ColorPalette.textPrimary : ColorPalette.textMuted, letterSpacing: 1)), const Spacer(), Text(value, style: GoogleFonts.inter(fontSize: isMain ? 20 : 14, fontWeight: FontWeight.w900, color: isMain ? ColorPalette.primary : ColorPalette.textPrimary))]);
  }

  Widget _buildSignatureSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildFormSectionHeader('AUTHORIZATION'),
      const SizedBox(height: 32),
      Row(children: [
        _buildFlatSigBox("LOT INCHARGE", _lotInchargeSignature, (f) => setState(() => _lotInchargeSignature = f), ['lot_inward', 'admin']),
        const SizedBox(width: 64),
        _buildFlatSigBox("AUTHORIZED", _authorizedSignature, (f) => setState(() => _authorizedSignature = f), ['authorized', 'admin']),
      ]),
    ]);
  }

  Widget _buildFlatSigBox(String label, XFile? file, Function(XFile?) onPick, List<String> roles) {
    final bool canSign = _userRole != null && (roles.contains(_userRole) || _userRole == 'admin');
    final isEditIncharge = label == "LOT INCHARGE" && _editInchargeSigUrl != null;
    final isEditAuth = label == "AUTHORIZED" && _editAuthorizedSigUrl != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 1)),
      const SizedBox(height: 16),
      GestureDetector(onTap: canSign ? () => _openSignaturePad(onPick) : () => _showError('ACCESS DENIED'), child: Container(height: 120, width: 240, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: ColorPalette.border.withOpacity(0.2))), child: file != null ? Image.network(file.path, fit: BoxFit.contain) : (isEditIncharge || isEditAuth) ? Image.network(ApiConstants.getImageUrl(isEditIncharge ? _editInchargeSigUrl! : _editAuthorizedSigUrl!), fit: BoxFit.contain) : Center(child: Text("SIGN HERE", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: ColorPalette.border))))),
    ]);
  }

  Widget _buildScanSection() {
    return Container(height: 400, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)), clipBehavior: Clip.antiAlias, child: MobileScanner(onDetect: (capture) {
      for (final barcode in capture.barcodes) { if (barcode.rawValue != null) { _handleScannedCode(barcode.rawValue!); break; } }
    }));
  }

  void _handleScannedCode(String code) {
    String? getValue(String key) {
      final keyPattern = '$key:';
      if (!code.contains(keyPattern)) return null;
      final start = code.indexOf(keyPattern) + keyPattern.length;
      final keys = ['LOT:', 'NAME:', 'DIA:', 'COL:', 'SET:', 'WT:', 'DT:'];
      int end = code.length;
      for (var k in keys) { if (k != keyPattern && code.contains(k, start)) { final pos = code.indexOf(k, start); if (pos < end) end = pos; } }
      return code.substring(start, end).trim();
    }
    String? scannedLotNo = getValue('LOT') ?? (code.contains(':') ? null : code.trim());
    String? scannedLotName = getValue('NAME'), scannedDia = getValue('DIA'), scannedSetNo = getValue('SET') ?? getValue('Set No'), scannedColour = getValue('COL');
    if (scannedSetNo != null && scannedSetNo.startsWith('#')) scannedSetNo = scannedSetNo.substring(1);
    if (scannedLotNo == null || scannedLotNo.isEmpty) { _showError('Invalid QR Code'); return; }
    setState(() { _isManual = true; if (scannedDia != null) _selectedDia = scannedDia; if (scannedLotName != null) _selectedLotName = scannedLotName; });
    if (scannedDia != null && scannedDia != _selectedDia) { _onDiaChanged(scannedDia).then((_) => _processScannedLot(scannedLotNo, scannedSetNo, scannedColour, scannedLotName)); }
    else { _processScannedLot(scannedLotNo, scannedSetNo, scannedColour, scannedLotName); }
  }

  void _processScannedLot(String lotNo, String? setNo, String? col, String? name) {
    if (!_lotNos.contains(lotNo)) { _showError('Lot No "$lotNo" not found'); return; }
    setState(() => _selectedLotNo = lotNo);
    _onLotNoChanged(lotNo).then((_) {
      if (!mounted) return;
      if (setNo != null) { Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) { _toggleSetSelection(setNo, true); if (col != null) { setState(() { final activeSet = _selectedSets.firstWhere((s) => s['set_no'].toString() == setNo, orElse: () => {}); if (activeSet.isNotEmpty) { final colours = activeSet['colours'] as List; for (var c in colours) { if (c['colour'] == col) c['isChecked'] = true; } } }); } }
      }); }
    });
  }

  Map<String, dynamic>? _findSetColourEntry(Map<String, dynamic> set, String colour) {
    final setColours = set['colours'] as List? ?? [];
    for (final col in setColours) { if (col['colour']?.toString().trim().toLowerCase() == colour.trim().toLowerCase()) return col; }
    return null;
  }

  Map<String, dynamic> _ensureSetColourEntry(Map<String, dynamic> set, String colour) {
    final ent = _findSetColourEntry(set, colour);
    if (ent != null) { ent['controller'] ??= TextEditingController(text: (ent['roll_weight'] as num?)?.toString() ?? ''); return ent; }
    final newEntry = <String, dynamic>{'colour': colour, 'weight': 0.0, 'roll_weight': 0.0, 'no_of_rolls': 0, 'isChecked': false, 'controller': TextEditingController()};
    (set['colours'] as List).add(newEntry); return newEntry;
  }

  List<String> _getSelectedSetColourOrder() {
    final ordered = <String>[], seen = <String>{};
    void add(dynamic v) { final c = v?.toString().trim() ?? ''; if (c.isNotEmpty && !seen.contains(c)) { seen.add(c); ordered.add(c); } }
    for (final c in _currentLotColours) add(c);
    for (final s in _selectedSets) { for (final c in (s['colours'] as List)) add(c['colour']); }
    return ordered;
  }

  int _getColourRollTotal(String colour) {
    int total = 0;
    for (final set in _selectedSets) { final col = _findSetColourEntry(set, colour); total += (col?['no_of_rolls'] as num?)?.toInt() ?? 0; }
    return total;
  }

  double _getColourRollWeightTotal(String colour) {
    double total = 0.0;
    for (final set in _selectedSets) { final col = _findSetColourEntry(set, colour); total += (col?['roll_weight'] as num?)?.toDouble() ?? 0.0; }
    return total;
  }

  String _formatGridNumber(double value) {
    if (value == value.truncateToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  void _openInputControlSheet() {
    showModalBottomSheet(context: context, showDragHandle: true, builder: (sheetContext) {
      return StatefulBuilder(builder: (ctx, modalSetState) {
        void sync(VoidCallback fn) { setState(fn); modalSetState(() {}); }
        return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Input Controls', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => sync(() => _enableVoiceInput = !_enableVoiceInput), icon: Icon(_enableVoiceInput ? Icons.mic : Icons.mic_off, size: 16), label: Text(_enableVoiceInput ? 'Voice ON' : 'Voice OFF'), style: OutlinedButton.styleFrom(backgroundColor: _enableVoiceInput ? Colors.blue.shade50 : null))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: () => sync(() => _enableWeightInput = !_enableWeightInput), icon: Icon(_enableWeightInput ? Icons.monitor_weight_outlined : Icons.monitor_weight, size: 16), label: Text(_enableWeightInput ? 'Weight ON' : 'Weight OFF'), style: OutlinedButton.styleFrom(backgroundColor: _enableWeightInput ? Colors.green.shade50 : null))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _enableWeightInput ? () async { await _setCurrentAsTare(); if (mounted) modalSetState(() {}); } : null, icon: const Icon(Icons.tune, size: 16), label: const Text('Set Tare'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: _tareOffset > 0 ? () => sync(() => _tareOffset = 0) : null, icon: const Icon(Icons.restore, size: 16), label: const Text('Clear Tare'))),
          ]),
          const SizedBox(height: 10),
          Text('Current Tare: ${_tareOffset.toStringAsFixed(3)} Kg', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
        ])));
      });
    });
  }

  Future<void> _setCurrentAsTare() async {
    try { final raw = await _scaleService.captureWeight(); if (!mounted) return; setState(() => _tareOffset = raw); }
    catch (e) { _showError('Failed to set tare'); }
  }
}
