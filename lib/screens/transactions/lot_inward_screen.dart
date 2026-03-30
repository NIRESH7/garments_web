import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../services/mobile_api_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../services/scale_service.dart';
import '../../core/theme/color_palette.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../widgets/custom_dropdown_field.dart';
import 'package:garments/dialogs/signature_pad_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:garments/widgets/app_drawer.dart';
import '../../core/storage/storage_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class LotInwardScreen extends StatefulWidget {
  final Map<String, dynamic>? editInward;
  const LotInwardScreen({super.key, this.editInward});

  @override
  State<LotInwardScreen> createState() => _LotInwardScreenState();
}

class _LotInwardScreenState extends State<LotInwardScreen> {
  final _api = MobileApiService();
  final _scaleService = ScaleService.instance;
  final _formKey = GlobalKey<FormState>();

  DateTime _inwardDate = DateTime.now();
  late String _inTime;
  String? _outTime;

  String? _selectedLotName;
  final _lotNumberController = TextEditingController();
  final _inwardNoController = TextEditingController();
  String? _selectedParty;
  String _process = "";
  final _vehicleController = TextEditingController();
  final _dcController = TextEditingController();
  final _rateController = TextEditingController();
  final _gsmController = TextEditingController();

  List<InwardRow> _rows = [InwardRow()];
  int _currentPage = 0;
  String? _selectedStickerDia;
  // Balance Image removed as per user request
  // XFile? _balanceImage;

  // Quality & Complaint
  String _qualityStatus = "OK"; // OK, Not OK
  XFile? _qualityImage;
  final _complaintController = TextEditingController();
  XFile? _complaintImage;
  XFile? _lotInchargeSignature;
  XFile? _authorizedSignature;
  XFile? _mdSignature;

  // GSM, Shade, Washing Checks
  String _gsmStatus = "OK";
  XFile? _gsmImage;
  String _shadeStatus = "OK";
  XFile? _shadeImage;
  String _washingStatus = "OK";
  XFile? _washingImage;

  /// Per–DIA storage & sticker details
  Map<String, StickerDiaData> _stickerData = {};
  Map<String, String> _colourGsmMap = {}; // Maps Colour Name -> GSM
  Map<String, String> _colourImages = {}; // Maps Colour Name -> Image URL/Path
  Map<String, String> _diaCuttingMap = {}; // Maps DIA -> Cutting DIA
  Map<String, String> _diaKnittingMap = {}; // Maps DIA -> Knitting DIA

  /// DIAs for which storage details have been completed
  final Set<String> _completedStickerDias = {};

  List<String> _dias = [];
  List<String> _colours = [];
  List<String> _masterColours = [];
  List<String> _lotNames = [];
  List<String> _parties = [];
  List<String> _rackNames = [];
  List<String> _palletNos = [];
  // Colours mapped from Item Group Master for the selected lot
  List<String> _lotMappedColours = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _userRole;
  final Map<String, String> _lastStickerGsmMap = {};
  String _selectedVoiceLocale = 'en_US'; // 'en_US' or 'ta_IN'

  // Voice input
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String? _listeningForRowId; // which row is currently being listened to
  int? _listeningForStickerRowIdx; // index in diaData.rows
  int? _listeningForSetIdx; // set index
  bool _enableVoiceInput = false;
  bool _enableWeightInput = true;
  double _tareOffset = 0.0;
  bool _useSetBasedEntry = true;
  ScrollController _hScrollController = ScrollController();
  double _hScrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _hScrollController.addListener(() {
      if (mounted) {
        setState(() => _hScrollOffset = _hScrollController.offset);
      }
    });
    _inTime = DateFormat('hh:mm a').format(DateTime.now());
    _loadUserRole();
    _loadMasterData();
    _initSpeech();
    _loadWeightSettings();

    if (widget.editInward != null) {
      _populateEditData();
    }

    // Add listener for Lot Number to check for existing lot
    _lotNumberController.addListener(() {
      // Debounce could be added here if needed, but for now direct call on loose focus or simple delay if typing fast?
      // Actually, let's just call it. Backend calls are cheap enough or user pauses.
      // Better: only call if length > 0.
      if (_lotNumberController.text.isNotEmpty && _selectedLotName != null) {
        // To avoid too many calls, maybe we can rely on focus node or just simple debouncing?
        // For simplicity now, let's call it.
        _checkExistingLot();
      }
    });
  }

  @override
  void dispose() {
    for (var r in _rows) {
      r.dispose();
    }
    // Dispose sticker data
    _stickerData.forEach((dia, data) {
      data.dispose();
    });
    _hScrollController.dispose();

    _inwardNoController.dispose();
    _lotNumberController.dispose();
    _rateController.dispose();
    _gsmController.dispose();
    _vehicleController.dispose();
    _dcController.dispose();
    _complaintController.dispose();
    super.dispose();
  }

  Future<void> _loadWeightSettings() async {
    final settings = await _scaleService.loadSettings();
    setState(() => _enableWeightInput = settings.enabled);
  }

  Future<void> _loadUserRole() async {
    final role = await StorageService().getRole();
    setState(() => _userRole = role);
    print('DEBUG: User Role loaded: $_userRole');
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

  /// Starts voice recognition and writes the recognized number into row.recWtController
  void _startVoiceInputForRow(InwardRow row) async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    // Check microphone permission explicitly
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
    setState(() {
      _isListening = true;
      _listeningForRowId = row.id;
    });
    _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords
            .toLowerCase()
            .replaceAll(',', '.')
            .replaceAll('point', '.')
            .replaceAll('dot', '.')
            .replaceAll('decimal', '.')
            .replaceAll('புள்ளி', '.'); // Tamil for point

        final regExp = RegExp(r'\d+\.?\d*');
        final match = regExp.firstMatch(words);

        if (match != null) {
          final value = match.group(0)!;
          setState(() {
            row.recWtController.text = value;
            row.recWeight = double.tryParse(value) ?? 0;
            _updateRowMath(row);
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

  void _startVoiceInputForSetWeight(
    StickerRow row,
    int rowIdx,
    int setIdx,
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

    setState(() {
      _isListening = true;
      _listeningForStickerRowIdx = rowIdx;
      _listeningForSetIdx = setIdx;
      _listeningForRowId = null; // Clear main row listening if any
    });

    _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords
            .toLowerCase()
            .replaceAll(',', '.')
            .replaceAll('point', '.')
            .replaceAll('dot', '.')
            .replaceAll('decimal', '.')
            .replaceAll('புள்ளி', '.'); // Tamil for point

        final regExp = RegExp(r'\d+\.?\d*');
        final match = regExp.firstMatch(words);

        if (match != null) {
          final value = match.group(0)!;
          setState(() {
            if (row.controllers.length > setIdx) {
              row.controllers[setIdx].text = value;
              row.setWeights[setIdx] = value;
            }
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

  Future<void> _captureScaleWeightForRow(InwardRow row) async {
    try {
      final weight = await _captureNetScaleWeight();
      if (!mounted) return;
      setState(() {
        row.recWtController.text = weight.toStringAsFixed(2);
        row.recWeight = weight;
        _updateRowMath(row);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Machine weight captured: ${weight.toStringAsFixed(2)} Kg',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Machine read failed: $e')));
    }
  }

  Future<void> _captureScaleWeightForSet(StickerRow row, int setIdx) async {
    try {
      final weight = await _captureNetScaleWeight();
      if (!mounted) return;
      setState(() {
        if (row.controllers.length > setIdx) {
          row.controllers[setIdx].text = weight.toStringAsFixed(3);
        }
        if (row.setWeights.length > setIdx) {
          row.setWeights[setIdx] = weight.toStringAsFixed(3);
        }
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Set weight captured: ${weight.toStringAsFixed(3)} Kg'),
      //   ),
      // );
      
      // Auto-focus move logic 
      if (setIdx < row.focusNodes.length - 1) {
        row.focusNodes[setIdx + 1].requestFocus();
      } else {
        // Next Row
        final dia = _selectedStickerDia;
        if (dia != null && _stickerData.containsKey(dia)) {
          final rows = _stickerData[dia]!.rows;
          final currentIdx = rows.indexOf(row);
          if (currentIdx != -1 && currentIdx < rows.length - 1) {
            final nextRow = rows[currentIdx + 1];
            if (nextRow.focusNodes.isNotEmpty) {
              nextRow.focusNodes[0].requestFocus();
            }
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Machine read failed: $e')));
    }
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to set tare: $e')));
    }
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoading = true);
    print('DEBUG: Starting _loadMasterData');
    try {
      final categories = await _api.getCategories();
      final parties = await _api.getParties();
      final inwardNo = await _api.generateInwardNumber();

      print('DEBUG: Categories received: ${categories.length}');

      setState(() {
        _isLoading = false;
        _lotNames = _getValues(categories, ['Lot Name', 'lot name']);
        _dias = _getValues(categories, ['Dia', 'dia']);
        _masterColours = _getValues(categories, [
          'Colours',
          'Colour',
          'colour',
          'color',
        ]);
        _colours = List<String>.from(_masterColours);
        _rackNames = _getValues(categories, ['Rack Name', 'Rack', 'Racks']);
        _palletNos = _getValues(categories, ['Pallet No', 'Pallet', 'Pallets']);
        _parties = parties.map((m) => m['name'] as String).toList();
        if (inwardNo != null) {
          _inwardNoController.text = inwardNo;
        }

        print(
          'DEBUG: Final counts - Racks: ${_rackNames.length}, Pallets: ${_palletNos.length}',
        );

        // UI Feedback for debugging
        if (categories.isNotEmpty && _rackNames.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'DEBUG: No Racks found. Categories: ${categories.length}',
                  ),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          });
        }
      });
    } catch (e) {
      print('DEBUG: Error in _loadMasterData: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  void _populateEditData() {
    final data = widget.editInward!;
    _inwardNoController.text = data['inwardNo'] ?? '';
    _selectedLotName = data['lotName'];
    _lotNumberController.text = data['lotNo'] ?? '';
    _selectedParty = data['fromParty'];
    _process = data['process'] ?? '';
    _rateController.text = (data['rate'] ?? '').toString();
    _gsmController.text = (data['gsm'] ?? '').toString();
    _vehicleController.text = data['vehicleNo'] ?? '';
    _dcController.text = data['partyDcNo'] ?? '';
    _qualityStatus = data['qualityStatus'] ?? 'OK';
    _gsmStatus = data['gsmStatus'] ?? 'OK';
    _shadeStatus = data['shadeStatus'] ?? 'OK';
    _washingStatus = data['washingStatus'] ?? 'OK';
    _complaintController.text = data['complaintText'] ?? '';

    // diaEntries
    if (data['diaEntries'] != null) {
      _rows = (data['diaEntries'] as List).map((e) {
        final row = InwardRow();
        row.dia = e['dia'];
        row.rolls = (e['roll'] ?? 0) is int
            ? e['roll']
            : (e['roll'] as num).toInt();
        row.sets = (e['sets'] ?? 0) is int
            ? e['sets']
            : (e['sets'] as num).toInt();
        row.deliveredWeight = (e['delivWt'] ?? 0).toDouble();
        row.recRoll = (e['recRoll'] ?? 0) is int
            ? e['recRoll']
            : (e['recRoll'] as num).toInt();
        row.recWeight = (e['recWt'] ?? 0).toDouble();
        row.rate = (e['rate'] ?? 0).toDouble();
        row.syncControllersFromValues();
        _updateRowMath(row);
        return row;
      }).toList();
    }

    // storageDetails
    if (data['storageDetails'] != null) {
      for (var storage in data['storageDetails']) {
        final dia = storage['dia'];
        if (dia != null) {
          final diaData = StickerDiaData();
          diaData.racks = List<String?>.from(storage['racks'] ?? []);
          diaData.pallets = List<String?>.from(storage['pallets'] ?? []);
          diaData.cuttingDia = storage['cuttingDia']?.toString();
          diaData.cuttingDiaController = TextEditingController(text: diaData.cuttingDia);
          if (storage['rows'] != null) {
            diaData.rows = (storage['rows'] as List).map((r) {
              final sRow = StickerRow();
              sRow.colour = r['colour'];
              sRow.rollNo = r['rollNo'] ?? '';
              sRow.gsm = r['gsm']?.toString();
              sRow.setWeights = List<String>.from(r['setWeights'] ?? []);
              final labels = List<String>.from(r['setLabels'] ?? []);
              sRow.setLabels = List<String>.generate(
                sRow.setWeights.length,
                (i) => i < labels.length && labels[i].trim().isNotEmpty
                    ? labels[i].trim()
                    : (i + 1).toString(),
              );
              // Initialize controllers
              sRow.rollNoController = TextEditingController(text: sRow.rollNo);
              if (sRow.gsm != null) {
                sRow.gsmController = TextEditingController(text: sRow.gsm);
              }
              return sRow;
            }).toList();
          }
          _stickerData[dia] = diaData;
          _completedStickerDias.add(dia);
        }
      }
    }
    // inwardDate
    if (data['inwardDate'] != null) {
      try {
        _inwardDate = DateTime.parse(data['inwardDate']);
      } catch (e) {
        print('Error parsing inwardDate: $e');
      }
    }
  }

  List<String> _getValues(List<dynamic> categories, dynamic nameOrNames) {
    try {
      final List<String> names = nameOrNames is List<String>
          ? nameOrNames
          : [nameOrNames.toString()];

      final List<String> result = [];

      // Improved: Find ALL matching categories (e.g. if both 'Rack' and 'Rack Name' exist)
      final matches = categories.where((c) {
        final String catName = (c['name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        return names.any((n) => catName == n.trim().toLowerCase());
      });

      if (matches.isEmpty) {
        final available = categories
            .map((c) => c['name']?.toString() ?? 'null')
            .toList();
        print('DEBUG: No match for $names. Available: $available');
        return [];
      }

      for (var cat in matches) {
        final dynamic rawValues = cat['values'];
        if (rawValues == null || rawValues is! List) continue;

        for (var v in rawValues) {
          String? valStr;
          if (v is Map) {
            valStr = (v['name'] ?? v['value'] ?? '').toString();
            if (v['gsm'] != null && v['gsm'].toString().isNotEmpty) {
              _colourGsmMap[valStr] = v['gsm'].toString();
            }
            if (v['photo'] != null && v['photo'].toString().isNotEmpty) {
              String imgPath = v['photo'].toString();
              // Normalize image path: if it's a server path (starts with uploads or /uploads), prepend server URL
              if (!imgPath.startsWith('http')) {
                imgPath = ApiConstants.getImageUrl(imgPath);
              }
              _colourImages[valStr] = imgPath;
              print('DEBUG: Image found for $valStr: $imgPath');
            }

            // Extract DIA specific fields if category is Dia
            if (cat['name']?.toString().toLowerCase().contains('dia') ?? false) {
              if (v['knittingDia'] != null) {
                _diaKnittingMap[valStr] = v['knittingDia'].toString();
              }
              if (v['cuttingDia'] != null) {
                _diaCuttingMap[valStr] = v['cuttingDia'].toString();
              }
            }
          } else if (v != null) {
            valStr = v.toString();
          }

          if (valStr != null && valStr.isNotEmpty && !result.contains(valStr)) {
            result.add(valStr);
          }
        }
      }

      return result;
    } catch (e) {
      print('DEBUG: Error extraction for $nameOrNames: $e');
      return [];
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _onPartyChanged(String? val) async {
    setState(() {
      _selectedParty = val;
    });
    if (val != null) {
      final details = await _api.getPartyDetails(val);
      if (details != null) {
        final double partyRate = (details['rate'] is num)
            ? (details['rate'] as num).toDouble()
            : 0.0;
        setState(() {
          _process = details['process'] ?? "N/A";
          _rateController.text = partyRate.toString();
          for (var row in _rows) {
            row.rate = partyRate;
          }
        });
      }
    }
  }

  Future<void> _checkExistingLot() async {
    final name = _selectedLotName;
    final no = _lotNumberController.text.trim();

    if (name != null && name.isNotEmpty && no.isNotEmpty) {
      // Don't clear rows immediately, wait for API response
      // But if we are fundamentally changing lot, we might want to?
      // User case: "First time receive 5 colors... After 2 days same lot... DIA details automatic ah varum"
      // This implies we should PRE-FILL the rows with the DIAs from the previous lot.

      try {
        final details = await _api.getLotDetails(name, no);
        if (details.isNotEmpty) {
          setState(() {
            _rows.clear();
            for (var d in details) {
              final row = InwardRow();
              final dia = d['dia'] as String;
              row.dia = dia;
              // Don't set current rec/rolls, only previous
              row.prevRecRolls = (d['existingRecRolls'] as num).toInt();
              row.prevRecWt = (d['existingRecWt'] as num).toDouble();
              _rows.add(row);

              // Pre-fill GSM for this DIA if we found it
              if (d['gsm'] != null && d['gsm'].toString().isNotEmpty) {
                final gsmVal = d['gsm'].toString();
                // Store in map under a special 'default' key only if no colour-specific entries exist yet
                final diaData = _stickerData.putIfAbsent(
                  dia,
                  () => StickerDiaData(),
                );
                if (diaData.rows.isNotEmpty) {
                  for (var sRow in diaData.rows) {
                    // Only set if no colour-specific GSM already tracked
                    if (sRow.colour != null &&
                        !_lastStickerGsmMap.containsKey(sRow.colour)) {
                      sRow.gsm = gsmVal;
                      sRow.gsmController ??= TextEditingController();
                      sRow.gsmController?.text = gsmVal;
                    }
                  }
                }
              }
            }
            if (_rows.isEmpty) {
              _rows.add(InwardRow());
            }
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Found existing lot details. Rows auto-populated.',
                ),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        print('Error fetching lot details: $e');
      }
    }
  }

  Future<void> _onLotNameChanged(String? val) async {
    setState(() {
      _selectedLotName = val;
      _stickerData.clear();
      _completedStickerDias.clear();
      _lotMappedColours = [];
      _lastStickerGsmMap.clear(); // Clear session GSMs for new lot
    });

    if (val != null) {
      _checkExistingLot();

      final group = await _api.getItemGroupByName(val);
      setState(() {
        if (group != null) {
          final groupColours = List<String>.from(group['colours'] ?? []);
          _lotMappedColours = groupColours;

          // Merge: all master colours + any group-specific colours
          _colours = List<String>.from({..._masterColours, ...groupColours});

          _gsmController.text = (group['gsm'] ?? '').toString();

          if (_rateController.text.isEmpty ||
              _rateController.text == "0.0" ||
              _rateController.text == "0") {
            _rateController.text = (group['rate'] ?? '').toString();
          }
        } else {
          _colours = List<String>.from(_masterColours);
          _lotMappedColours = [];
        }
      });
    }
  }

  void _updateRowMath(InwardRow row) {
    setState(() {
      // Auto-Calculate Sets: rolls / 11, rounded to nearest integer
      // Auto-Calculate Sets logic removed as per new requirement (Sets drives Rolls now)
      // if (row.rolls > 0) {
      //   row.sets = (row.rolls / 11).round();
      // }

      // Auto-Fill Received Weight Logic Removed
      // if (row.recWeight == 0 && row.deliveredWeight > 0) {
      //   row.recWeight = row.deliveredWeight;
      // }

      // row.recRoll = row.rolls; // Removed: recRoll should only be updated from storage details
      row.difference = double.parse(
        (row.deliveredWeight - row.recWeight).toStringAsFixed(3),
      );
      if (row.deliveredWeight != 0) {
        row.lossPercent = (row.difference / row.deliveredWeight) * 100;
      } else {
        row.lossPercent = 0;
      }
    });
  }

  Future<void> _pickImage(Function(XFile?) onPicked) async {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) setState(() => onPicked(image));
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.pop(ctx);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                );
                if (image != null) setState(() => onPicked(image));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLargeImage(XFile file) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Image.file(File(file.path)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _inwardDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _inwardDate) {
      setState(() {
        _inwardDate = picked;
      });
    }
  }

  Future<void> _shareToWhatsApp(Map<String, dynamic> data) async {
    try {
      final sb = StringBuffer();
      sb.writeln("*LOT INWARD DETAILS*");
      sb.writeln("");

      sb.writeln("Inward No: ${data['inwardNo'] ?? 'N/A'}");
      sb.writeln("Date: ${data['inwardDate']}");
      sb.writeln("Party: ${data['fromParty'] ?? 'N/A'}");
      sb.writeln(
        "Lot: ${data['lotName'] ?? 'N/A'} / ${data['lotNo'] ?? 'N/A'}",
      );
      sb.writeln("");

      sb.writeln("GSM Check: ${data['gsmStatus'] ?? 'OK'}");
      sb.writeln("Shade Matching: ${data['shadeStatus'] ?? 'OK'}");
      sb.writeln("Washing Check: ${data['washingStatus'] ?? 'OK'}");
      sb.writeln("");

      final entries = data['diaEntries'] as List<dynamic>? ?? [];
      for (var entry in entries) {
        final dia = entry['dia']?.toString();
        final recRoll = entry['recRoll'] ?? 0;
        final recWt = entry['recWt'] ?? 0.0;

        if (dia != null) sb.writeln("DIA: $dia");
        sb.writeln("Rolls: $recRoll");
        sb.writeln("Received Weight: ${FormatUtils.formatWeight(recWt)} Kg");
        sb.writeln("");
      }

      int totalRolls = 0;
      double totalWeight = 0.0;
      for (var entry in entries) {
        totalRolls += (entry['recRoll'] as num?)?.toInt() ?? 0;
        totalWeight += (entry['recWt'] as num?)?.toDouble() ?? 0.0;
      }

      sb.writeln("-----------------------");
      sb.writeln("TOTAL SUMMARY");
      sb.writeln("Total Rolls: $totalRolls");
      sb.writeln("Total Weight: ${FormatUtils.formatWeight(totalWeight)} Kg");
      sb.writeln("-----------------------");
      sb.writeln("");

      sb.writeln("Signatures:");
      sb.writeln(
        "Lot Incharge: ${data['lotInchargeSignature'] != null ? 'OK' : 'Missing'}",
      );
      sb.writeln(
        "Authorized: ${data['authorizedSignature'] != null ? 'OK' : 'Missing'}",
      );
      sb.writeln("MD: ${data['mdSignature'] != null ? 'OK' : 'Missing'}");

      final msg = sb.toString();
      final whatsappUrl = "whatsapp://send?text=${Uri.encodeComponent(msg)}";
      final url = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        final webUrl = Uri.parse(
          "https://wa.me/?text=${Uri.encodeComponent(msg)}",
        );
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        } else {
          _showError(
            "Could not launch WhatsApp. Please ensure it is installed.",
          );
        }
      }
    } catch (e) {
      _showError("Error preparing WhatsApp message: $e");
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // --- WEIGHT CALCULATIONS CHECK ---
    for (var r in _rows) {
      if (r.dia == null || r.dia!.trim().isEmpty) continue;
      // Skip rows with no entering data
      if (r.recRoll == 0 && r.recWeight == 0) continue;

      final dia = r.dia!.trim();
      final recWt = r.recWeight;

      final storage = _stickerData[dia];
      if (storage == null) {
        _showError(
          "Storage details missing for DIA $dia. Please enter weights in Storage Details page.",
        );
        return;
      }

      final storageTotal = storage.rows.fold(
        0.0,
        (sum, row) => sum + row.totalWeight,
      );

      // Using small epsilon for double comparison (3 decimal places precision)
      if ((storageTotal - recWt).abs() > 0.0001) {
        _showError(
          "Weight Mismatch for DIA $dia!\n\n"
          "Total Rec. Wt (Page 1): ${FormatUtils.formatWeight(recWt)} Kg\n"
          "Sum of Storage (Page 2): ${FormatUtils.formatWeight(storageTotal)} Kg\n\n"
          "Please correct the weights to match exactly.",
        );
        return;
      }
    }

    setState(() {
      _outTime = DateFormat('hh:mm a').format(DateTime.now());
      _isLoading = true;
      _isSaving = true;
    });

    final inwardData = {
      "inwardDate": DateFormat('yyyy-MM-dd').format(_inwardDate),
      "inTime": _inTime,
      "outTime": _outTime,
      "inwardNo": _inwardNoController.text.trim().isEmpty
          ? null
          : _inwardNoController.text.trim(),
      "lotName": _selectedLotName,
      "lotNo": _lotNumberController.text,
      "fromParty": _selectedParty,
      "process": _process,
      "rate": double.tryParse(_rateController.text) ?? 0,
      "gsm": _gsmController.text,
      "vehicleNo": _vehicleController.text,
      "partyDcNo": _dcController.text,
      "diaEntries": _rows
          .where((r) => r.dia != null)
          .map(
            (r) => {
              "dia": r.dia ?? "",
              "roll": r.rolls,
              "sets": _useSetBasedEntry ? r.sets : 0,
              "delivWt": r.deliveredWeight,
              "recRoll": r.recRoll,
              "recWt": r.recWeight,
              "rate": r.rate,
            },
          )
          .toList(),
      "storageDetails": _stickerData.entries
          .map(
            (e) => {
              "dia": e.key,
              "cuttingDia": e.value.cuttingDia,
              "racks": e.value.racks,
              "pallets": e.value.pallets,
              "rows": e.value.rows
                  .where((r) => r.colour != null)
                  .map(
                    (r) => {
                      "colour": r.colour,
                      "rollNo": r.rollNo,
                      "gsm": r.gsm,
                      "setWeights": r.setWeights,
                      "setLabels": _normalizedSetLabels(r),
                      "totalWeight": r.totalWeight,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };

    // Upload Images First (Legacy for non-signature images)
    // Note: Signature images are now handled via Multipart in saveInward
    String? qualityImgPath;
    String? complaintImgPath;

    // Non-signature uploads still use old method (might fail on Web, needs future refactor)
    if (_qualityImage != null) {
      qualityImgPath = await _api.uploadFile(_qualityImage!.path);
      if (qualityImgPath == null || qualityImgPath.trim().isEmpty) {
        _showError('Quality image upload failed. Please retry.');
        setState(() {
          _isLoading = false;
          _isSaving = false;
        });
        return;
      }
    }
    if (_complaintImage != null) {
      complaintImgPath = await _api.uploadFile(_complaintImage!.path);
      if (complaintImgPath == null || complaintImgPath.trim().isEmpty) {
        _showError('Complaint image upload failed. Please retry.');
        setState(() {
          _isLoading = false;
          _isSaving = false;
        });
        return;
      }
    }

    // GSM, Shade, Washing Images
    String? gsmImgPath;
    String? shadeImgPath;
    String? washingImgPath;

    if (_gsmImage != null) {
      gsmImgPath = await _api.uploadFile(_gsmImage!.path);
      if (gsmImgPath == null || gsmImgPath.trim().isEmpty) {
        _showError('GSM image upload failed. Please retry.');
        setState(() {
          _isLoading = false;
          _isSaving = false;
        });
        return;
      }
    }
    if (_shadeImage != null) {
      shadeImgPath = await _api.uploadFile(_shadeImage!.path);
      if (shadeImgPath == null || shadeImgPath.trim().isEmpty) {
        _showError('Shade image upload failed. Please retry.');
        setState(() {
          _isLoading = false;
          _isSaving = false;
        });
        return;
      }
    }
    if (_washingImage != null) {
      washingImgPath = await _api.uploadFile(_washingImage!.path);
      if (washingImgPath == null || washingImgPath.trim().isEmpty) {
        _showError('Washing image upload failed. Please retry.');
        setState(() {
          _isLoading = false;
          _isSaving = false;
        });
        return;
      }
    }

    inwardData["qualityStatus"] = _qualityStatus;
    inwardData["qualityImage"] = qualityImgPath;
    inwardData["gsmStatus"] = _gsmStatus;
    inwardData["gsmImage"] = gsmImgPath;
    inwardData["shadeStatus"] = _shadeStatus;
    inwardData["shadeImage"] = shadeImgPath;
    inwardData["washingStatus"] = _washingStatus;
    inwardData["washingImage"] = washingImgPath;
    inwardData["complaintText"] = _complaintController.text;
    inwardData["complaintImage"] = complaintImgPath;

    // Pass XFile objects directly for signatures to use Multipart upload
    inwardData["lotInchargeSignature"] = _lotInchargeSignature;
    inwardData["authorizedSignature"] = _authorizedSignature;
    inwardData["mdSignature"] = _mdSignature;

    final success = widget.editInward != null
        ? await _api.updateInward(widget.editInward!['_id'], inwardData)
        : await _api.saveInward(inwardData);

    setState(() {
      _isLoading = false;
      _isSaving = false;
    });

    if (!mounted) return;

    if (success) {
      // Directly ask to share after success instead of showing sticker dialog automatically
      _askToShare(inwardData);
    } else {
      _showError("Failed to Save. Check if all required fields are filled.");
    }
  }

  void _askToShare(Map<String, dynamic> inwardData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Share Details?"),
        content: const Text("Do you want to share details on WhatsApp?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Close screen
            },
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _shareToWhatsApp(inwardData);
              Navigator.pop(context); // Close screen
            },
            child: const Text("Share"),
          ),
        ],
      ),
    );
  }

  String _resolveSetLabel(StickerRow row, int index) {
    if (index >= 0 && index < row.setLabels.length) {
      final label = row.setLabels[index].trim();
      if (label.isNotEmpty) return label;
    }
    return (index + 1).toString();
  }

  List<String> _normalizedSetLabels(StickerRow row) {
    final labels = List<String>.generate(
      row.setWeights.length,
      (i) => _resolveSetLabel(row, i),
    );
    row.setLabels = labels;
    return labels;
  }

  List<String> _resolveDiaSetLabels(StickerDiaData data, int sets) {
    if (!_useSetBasedEntry) {
      return List<String>.filled(sets, 'Weight');
    }

    List<String>? source;
    for (final row in data.rows) {
      if (row.setLabels.isNotEmpty) {
        source = row.setLabels;
        break;
      }
    }

    return List<String>.generate(sets, (i) {
      final label = (source != null && i < source.length)
          ? source[i].trim()
          : '';
      return label.isNotEmpty ? label : 'Set-${i + 1}';
    });
  }

  int _parseSetLabelNumber(String label) {
    final match = RegExp(r'\d+').firstMatch(label);
    return int.tryParse(match?.group(0) ?? '') ?? 0;
  }

  String _nextNoSetLabel(StickerDiaData data) {
    int maxVal = 0;
    for (final row in data.rows) {
      for (final label in row.setLabels) {
        final parsed = _parseSetLabelNumber(label);
        if (parsed > maxVal) maxVal = parsed;
      }
    }
    return 'S-${maxVal + 1}';
  }

  int _setSortKey(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return int.tryParse(match?.group(0) ?? '') ?? 1 << 30;
  }

  void _printStickers(Map<String, dynamic>? inwardData) {
    // Flatten sticker data
    final List<Map<String, dynamic>> stickers = [];

    _stickerData.forEach((dia, data) {
      for (var row in data.rows) {
        if (row.colour != null && row.colour!.isNotEmpty) {
          for (int i = 0; i < row.setWeights.length; i++) {
            final weight = row.setWeights[i];
            if (weight.trim().isNotEmpty) {
              final setNo = _resolveSetLabel(row, i);
              stickers.add({
                'lotNo': _lotNumberController.text,
                'lotName': _selectedLotName ?? '',
                'dia': dia,
                'colour': row.colour!,
                'weight': weight,
                'date': DateFormat('dd-MM-yyyy').format(_inwardDate),
                'setNo': setNo,
              });
            }
          }
        }
      }
    });

    if (stickers.isEmpty) {
      _showError("No sticker data found.");
      if (inwardData != null) _askToShare(inwardData);
      return;
    }

    // Filter state variables for the modal
    String? _modalFilterDia;
    String? _modalFilterColour;
    String? _modalFilterSet;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          // Available filter options
          final allSets =
              stickers.map((e) => e['setNo'].toString()).toSet().toList()
                ..sort((a, b) {
                  final keyA = _setSortKey(a);
                  final keyB = _setSortKey(b);
                  if (keyA != keyB) return keyA.compareTo(keyB);
                  return a.compareTo(b);
                });
          final allColours =
              stickers.map((e) => e['colour'].toString()).toSet().toList()
                ..sort();
          final allDias =
              stickers.map((e) => e['dia'].toString()).toSet().toList()..sort();

          // Note: To keep filter state persistent within the dialog session,
          // we should ideally move these to a separate stateful component or use a nested state.
          // For simplicity here, we'll keep it within the builder but realize it resets on setState of the DIALOG.
          // Wait, StatefulBuilder's setModalState will only rebuild its children.
          // To track these correctly, we use static-like variables or closure variables OUTSIDE the builder if we want persistence.
          // Let's use local variables outside the builder but inside _printStickers if we need it.
          // Actually, let's just use local vars inside _printStickers scope.

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sticker Previews',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (inwardData != null) _askToShare(inwardData);
                        },
                      ),
                    ],
                  ),
                ),
                // --- FILTER SECTION ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildModalFilter(
                              "DIA",
                              _modalFilterDia,
                              allDias,
                              (v) => setModalState(() => _modalFilterDia = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildModalFilter(
                              "Colour",
                              _modalFilterColour,
                              allColours,
                              (v) =>
                                  setModalState(() => _modalFilterColour = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildModalFilter(
                              "Set No",
                              _modalFilterSet,
                              allSets,
                              (v) => setModalState(() => _modalFilterSet = v),
                            ),
                          ),
                        ],
                      ),
                      if (_modalFilterDia != null ||
                          _modalFilterColour != null ||
                          _modalFilterSet != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              setModalState(() {
                                _modalFilterDia = null;
                                _modalFilterColour = null;
                                _modalFilterSet = null;
                              });
                            },
                            child: const Text(
                              "Clear Filters",
                              style: TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      // Apply filters
                      final filteredStickers = stickers.where((s) {
                        if (_modalFilterDia != null &&
                            s['dia'] != _modalFilterDia) {
                          return false;
                        }
                        if (_modalFilterColour != null &&
                            s['colour'] != _modalFilterColour) {
                          return false;
                        }
                        if (_modalFilterSet != null &&
                            s['setNo'].toString() != _modalFilterSet) {
                          return false;
                        }
                        return true;
                      }).toList();

                      if (filteredStickers.isEmpty) {
                        return const Center(
                          child: Text("No stickers match the filters"),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredStickers.length,
                        itemBuilder: (context, idx) {
                          final item = filteredStickers[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 2),
                              color: Colors.white,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStickerRow('LOT NO', item['lotNo']),
                                _buildStickerRow('Lot Name', item['lotName']),
                                _buildStickerRow('Dia', item['dia']),
                                _buildStickerRow('Colour', item['colour']),
                                _buildStickerRow(
                                  'Set No',
                                  item['setNo'].toString(),
                                ),
                                _buildStickerRow(
                                  'Roll Wt',
                                  '${item['weight']} kg',
                                ),
                                _buildStickerRow('Date', item['date']),
                                const SizedBox(height: 12),
                                Center(
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.black,
                                          ),
                                        ),
                                        child: QrImageView(
                                          data:
                                              'LOT: ${item['lotNo']}\nNAME: ${item['lotName']}\nDIA: ${item['dia']}\nCOL: ${item['colour']}\nSET: ${item['setNo']}\nWT: ${item['weight']}kg\nDT: ${item['date']}',
                                          version: QrVersions.auto,
                                          size: 80.0,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'SCAN FOR AUTH',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Apply filter to final print list
                              final filteredToPrint = stickers.where((s) {
                                if (_modalFilterDia != null &&
                                    s['dia'] != _modalFilterDia) {
                                  return false;
                                }
                                if (_modalFilterColour != null &&
                                    s['colour'] != _modalFilterColour) {
                                  return false;
                                }
                                if (_modalFilterSet != null &&
                                    s['setNo'].toString() != _modalFilterSet) {
                                  return false;
                                }
                                return true;
                              }).toList();

                              if (filteredToPrint.isEmpty) {
                                _showError("No stickers to print");
                                return;
                              }

                              Navigator.pop(ctx); // Close the modal
                              _printStickersCustom(filteredToPrint);
                              if (inwardData != null) _askToShare(inwardData);
                            },
                            icon: const Icon(Icons.print),
                            label: const Text(
                              'Print Now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final filteredToShare = stickers.where((s) {
                                if (_modalFilterDia != null &&
                                    s['dia'] != _modalFilterDia) {
                                  return false;
                                }
                                if (_modalFilterColour != null &&
                                    s['colour'] != _modalFilterColour) {
                                  return false;
                                }
                                if (_modalFilterSet != null &&
                                    s['setNo'].toString() != _modalFilterSet) {
                                  return false;
                                }
                                return true;
                              }).toList();

                              if (filteredToShare.isEmpty) {
                                _showError("No stickers to share");
                                return;
                              }

                              _showShareOptions(context, filteredToShare);
                            },
                            icon: const Icon(Icons.share),
                            label: const Text(
                              'Share',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStickerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100, // Increased width for bold label
            child: Text(
              '$label :',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ), // Increased from 14
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ), // Slightly reduced from 16
            ),
          ),
        ],
      ),
    );
  }

  void _showShareOptions(
    BuildContext context,
    List<Map<String, dynamic>> stickers,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Share Stickers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Share as PDF Document'),
              subtitle: const Text('Best for high-quality printing'),
              onTap: () {
                Navigator.pop(ctx);
                _shareStickers(stickers, format: 'pdf');
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.blue),
              title: const Text('Share as Image (PNG)'),
              subtitle: const Text('Best for quick viewing'),
              onTap: () {
                Navigator.pop(ctx);
                _shareStickers(stickers, format: 'image');
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.green),
              title: const Text('Share to WhatsApp'),
              subtitle: const Text('Quick share via WhatsApp'),
              onTap: () {
                Navigator.pop(ctx);
                _shareStickers(stickers, format: 'whatsapp');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildSingleSticker(Map<String, dynamic> item) {
    return pw.Container(
      width: double.infinity,
      height: double.infinity,
      padding: const pw.EdgeInsets.all(2),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfRow('LOT', item['lotNo']?.toString() ?? '', fontSize: 9),
              _buildPdfRow(
                'Name',
                item['lotName']?.toString() ?? '',
                fontSize: 9,
              ),
              _buildPdfRow('Dia', item['dia']?.toString() ?? '', fontSize: 9),
              _buildPdfRow(
                'Col',
                item['colour']?.toString() ?? '',
                fontSize: 9,
              ),
              _buildPdfRow('Set', item['setNo']?.toString() ?? '', fontSize: 9),
              _buildPdfRow(
                'Wt',
                '${item['weight']} kg',
                fontSize: 9,
                isBoldValue: true,
              ),
              _buildPdfRow('Dt', item['date']?.toString() ?? '', fontSize: 8),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(
                  width: 32,
                  height: 32,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data:
                        'LOT: ${item['lotNo']}\nNAME: ${item['lotName']}\nDIA: ${item['dia']}\nCOL: ${item['colour']}\nSET: ${item['setNo']}\nWT: ${item['weight']}kg\nDT: ${item['date']}',
                  ),
                ),
                pw.SizedBox(height: 0.5),
                pw.Text(
                  'SCAN FOR AUTH',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 2),
        ],
      ),
    );
  }

  Future<void> _shareStickers(
    List<Map<String, dynamic>> stickerList, {
    required String format,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final pdf = pw.Document();

      for (int i = 0; i < stickerList.length; i += 2) {
        final item1 = stickerList[i];
        final item2 = (i + 1 < stickerList.length) ? stickerList[i + 1] : null;

        final isSingle = item2 == null;
        final pageFormat = isSingle
            ? PdfPageFormat(50 * PdfPageFormat.mm, 50 * PdfPageFormat.mm)
            : PdfPageFormat(100 * PdfPageFormat.mm, 50 * PdfPageFormat.mm);

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: const pw.EdgeInsets.all(
              2,
            ), // Minimal margin for small sticker
            build: (pw.Context context) {
              if (isSingle) {
                return _buildSingleSticker(item1);
              } else {
                return pw.Row(
                  children: [
                    pw.Expanded(child: _buildSingleSticker(item1)),
                    pw.SizedBox(width: 2),
                    pw.Expanded(child: _buildSingleSticker(item2)),
                  ],
                );
              }
            },
          ),
        );
      }

      final pdfBytes = await pdf.save();
      final directory = await getTemporaryDirectory();

      if (format == 'pdf' || format == 'whatsapp') {
        final filePath =
            '${directory.path}/stickers_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Inward Stickers - ${_selectedLotName ?? 'Details'}',
          subject: 'Sticker Labels PDF',
        );
      } else if (format == 'image') {
        final List<XFile> imagesToShare = [];

        int pageIndex = 0;
        // Rasterize the PDF pages to PNG
        await for (var page in Printing.raster(pdfBytes, dpi: 300)) {
          final imageBytes = await page.toPng();
          final imgPath =
              '${directory.path}/stickers_page_${pageIndex}_${DateTime.now().millisecondsSinceEpoch}.png';
          final imgFile = File(imgPath);
          await imgFile.writeAsBytes(imageBytes);
          imagesToShare.add(XFile(imgPath));
          pageIndex++;

          // If many pages, maybe limit to avoid overwhelming share sheet?
          // For now, let's share all as images.
        }

        if (imagesToShare.isNotEmpty) {
          await Share.shareXFiles(
            imagesToShare,
            text: 'Inward Stickers - ${_selectedLotName ?? 'Images'}',
          );
        }
      }
    } catch (e) {
      debugPrint("Error sharing stickers: $e");
      _showError("Failed to generate stickers for sharing: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _printStickersCustom(
    List<Map<String, dynamic>> stickerList,
  ) async {
    final pdf = pw.Document();

    for (int i = 0; i < stickerList.length; i += 2) {
      final item1 = stickerList[i];
      final item2 = (i + 1 < stickerList.length) ? stickerList[i + 1] : null;

      final isSingle = item2 == null;
      final pageFormat = isSingle
          ? PdfPageFormat(50 * PdfPageFormat.mm, 50 * PdfPageFormat.mm)
          : PdfPageFormat(100 * PdfPageFormat.mm, 50 * PdfPageFormat.mm);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(2),
          build: (pw.Context context) {
            if (isSingle) {
              return _buildSingleSticker(item1);
            } else {
              return pw.Row(
                children: [
                  pw.Expanded(child: _buildSingleSticker(item1)),
                  pw.SizedBox(width: 2),
                  pw.Expanded(child: _buildSingleSticker(item2)),
                ],
              );
            }
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildPdfRow(
    String label,
    String value, {
    double fontSize = 9,
    bool isBoldValue = true,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 45,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: fontSize,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: pw.FontWeight.bold, // Always bold
              ),
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToStickerPage() {
    final diasWithRolls = _getDiasWithRolls().toList();

    if (diasWithRolls.isEmpty) {
      _showError('Please enter at least one DIA with ROLLS first');
      return;
    }

    final pendingDias = diasWithRolls
        .where((d) => !_completedStickerDias.contains(d))
        .toList();

    final nextDia = pendingDias.isNotEmpty
        ? pendingDias.first
        : diasWithRolls.first;

    setState(() {
      _selectedStickerDia = nextDia;
      _initializeStickerRows(nextDia);
      _currentPage = 1;
    });
  }

  void _initializeStickerRows(String dia) {
    final diaData = _stickerData.putIfAbsent(dia, () => StickerDiaData());

    // Pre-fill Cutting DIA from master if not already set
    if (diaData.cuttingDia == null || diaData.cuttingDia!.trim().isEmpty) {
      final masterCutting = _diaCuttingMap[dia.trim()];
      if (masterCutting != null && masterCutting.isNotEmpty) {
        diaData.cuttingDia = masterCutting;
      }
    }
    diaData.cuttingDiaController ??= TextEditingController(text: diaData.cuttingDia);

    if (diaData.rows.isEmpty && _lotMappedColours.isNotEmpty) {
      // First time: create all rows from mapped colours
      int noSetCounter = 1;
      diaData.rows = _lotMappedColours.map((c) {
        final row = StickerRow()..colour = c;
        if (!_useSetBasedEntry) {
          row.setLabels = ['S-$noSetCounter'];
          noSetCounter += 1;
        }
        final gsmToUse = _lastStickerGsmMap[c];
        if (gsmToUse != null) {
          row.gsm = gsmToUse;
          row.gsmController = TextEditingController(text: gsmToUse);
        }
        return row;
      }).toList();
    } else {
      // Rows already exist — refresh empty GSM fields from the map
      for (var row in diaData.rows) {
        final colour = row.colour;
        if (colour != null && colour.isNotEmpty) {
          final gsmToUse = _lastStickerGsmMap[colour];
          if (gsmToUse != null && (row.gsm == null || row.gsm!.isEmpty)) {
            row.gsm = gsmToUse;
            row.gsmController ??= TextEditingController();
            row.gsmController!.text = gsmToUse;
          }
        }
      }
    }
  }

  /// All DIAs from the main grid that have rolls entered
  Set<String> _getDiasWithRolls() {
    return _rows
        .where(
          (r) =>
              r.dia != null &&
              r.dia!.trim().isNotEmpty &&
              r.rolls > 0, // rolls imply this DIA is active
        )
        .map((r) => r.dia!.trim())
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentPage != 0) {
          setState(() => _currentPage = 0);
        }
      },
      child: Scaffold(
        drawer: _currentPage == 0 ? const AppDrawer() : null,
        appBar: AppBar(
          leading: _currentPage == 0
              ? null // Use default hamburger
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (_currentPage != 0) {
                      setState(() => _currentPage = 0);
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
          title: Text(
            _currentPage == 0
                ? (widget.editInward != null
                      ? 'Edit Lot Inward'
                      : 'Lot Inward Entry')
                : 'Sticker & Storage Details',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Input Controls',
              onPressed: _openInputControlSheet,
            ),
            // Tare Button
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                avatar: Icon(
                  Icons.scale_outlined,
                  size: 16,
                  color: _tareOffset > 0 ? Colors.green : Colors.grey,
                ),
                label: Text(
                  _tareOffset > 0
                      ? "TARE: ${_tareOffset.toStringAsFixed(2)}"
                      : "TARE",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _tareOffset > 0
                        ? Colors.green.shade900
                        : Colors.grey.shade700,
                  ),
                ),
                backgroundColor:
                    _tareOffset > 0 ? Colors.green.shade50 : Colors.grey.shade50,
                onPressed: _enableWeightInput ? _setCurrentAsTare : null,
              ),
            ),
            // Language Toggle for Voice Input
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                avatar: Icon(
                  Icons.language,
                  size: 16,
                  color: _selectedVoiceLocale == 'ta_IN'
                      ? Colors.orange
                      : Colors.blue,
                ),
                label: Text(
                  _selectedVoiceLocale == 'ta_IN' ? "தமிழ் (TA)" : "English (EN)",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _selectedVoiceLocale == 'ta_IN'
                        ? Colors.orange.shade900
                        : Colors.blue.shade900,
                  ),
                ),
                backgroundColor: _selectedVoiceLocale == 'ta_IN'
                    ? Colors.orange.shade50
                    : Colors.blue.shade50,
                onPressed: () {
                  setState(() {
                    _selectedVoiceLocale =
                        (_selectedVoiceLocale == 'en_US') ? 'ta_IN' : 'en_US';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Voice Language: ${_selectedVoiceLocale == 'ta_IN' ? 'Tamil' : 'English'}",
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: _currentPage == 0
                      ? _buildMainPage()
                      : _buildStickerPage(),
                ),
              ),
        bottomNavigationBar: _isLoading
            ? const LinearProgressIndicator()
            : null,
      ),
    );
  }

  Widget _buildMainPage() {
    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        // _buildImageSection("Balance/Challan Image", _balanceImage, (f) => _balanceImage = f),
        // const SizedBox(height: 16),
        _buildQualitySection(),
        const SizedBox(height: 16),
        _buildCheckSection(
          title: "GSM Check",
          status: _gsmStatus,
          image: _gsmImage,
          onStatusChanged: (v) => setState(() => _gsmStatus = v),
          onImagePicked: (f) => _gsmImage = f,
        ),
        const SizedBox(height: 16),
        _buildCheckSection(
          title: "Shade Matching",
          status: _shadeStatus,
          image: _shadeImage,
          onStatusChanged: (v) => setState(() => _shadeStatus = v),
          onImagePicked: (f) => _shadeImage = f,
        ),
        const SizedBox(height: 16),
        _buildCheckSection(
          title: "Washing Check",
          status: _washingStatus,
          image: _washingImage,
          onStatusChanged: (v) => setState(() => _washingStatus = v),
          onImagePicked: (f) => _washingImage = f,
        ),
        const SizedBox(height: 16),
        _buildComplaintSection(),
        const SizedBox(height: 16),
        _buildGridHeader(),
        _buildDataTable(),
        const SizedBox(height: 24),
        _buildSignatureSection(),
        const SizedBox(height: 24),
        _buildNavigationButtons(),
      ],
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
                            onPressed: () {
                              sync(() {
                                _enableWeightInput = !_enableWeightInput;
                              });
                              _scaleService.updateSettings(
                                enabled: _enableWeightInput,
                              );
                            },
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
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => sync(
                          () => _useSetBasedEntry = !_useSetBasedEntry,
                        ),
                        icon: Icon(
                          _useSetBasedEntry
                              ? Icons.grid_on
                              : Icons.grid_off,
                          size: 16,
                        ),
                        label: Text(
                          _useSetBasedEntry
                              ? 'Set-wise Entry'
                              : 'No-Set Entry',
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _useSetBasedEntry
                              ? null
                              : Colors.orange.shade50,
                        ),
                      ),
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

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _inwardNoController,
                    decoration: const InputDecoration(
                      labelText: "Inward No",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Inward Date",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(8),
                        suffixIcon: Icon(Icons.calendar_today, size: 20),
                      ),
                      child: Text(
                        DateFormat('dd-MM-yyyy').format(_inwardDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildReadOnly("In Time", _inTime)),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildReadOnly("Out Time", _outTime ?? "--:--"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    "Lot Name",
                    _selectedLotName,
                    _lotNames,
                    _onLotNameChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _lotNumberController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: "Lot No",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomDropdownField(
                    label: "From Party",
                    value: _parties.contains(_selectedParty)
                        ? _selectedParty
                        : null,
                    items: _parties,
                    onChanged: _onPartyChanged,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildReadOnly("Process", _process)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _gsmController,
                    decoration: const InputDecoration(
                      labelText: "GSM",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _rateController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: "Rate",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final r = double.tryParse(v) ?? 0;
                      setState(() {
                        for (var row in _rows) {
                          row.rate = r;
                        }
                      });
                    },
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField("Vehicle No", _vehicleController),
                ),
                const SizedBox(width: 8),
                Expanded(child: _buildTextField("Party DC No", _dcController)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Table Header
              _buildTableHeader(),
              // Table Rows
              ..._rows.asMap().entries.map((entry) {
                final idx = entry.key;
                final row = entry.value;
                return _buildDataRow(idx, row);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildColumnHeader('#', 40),
          _buildColumnHeader('DIA', 100),
          _buildColumnHeader('ROLL', 80),
          if (_useSetBasedEntry) _buildColumnHeader('SETS', 80),
          _buildColumnHeader('DELIV. WT', 100),
          _buildColumnHeader('REC. ROLL', 100),
          _buildColumnHeader('REC. WT', 100),
          _buildColumnHeader('RATE', 80),
          _buildColumnHeader('DIFF', 80),
          _buildColumnHeader('LOSS %', 80),
          _buildColumnHeader('VALUE', 100),
          _buildColumnHeader('ACTION', 60, isLast: true),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(String label, double width, {bool isLast = false}) {
    return Container(
      width: width,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          right: isLast
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDataRow(int idx, InwardRow row) {
    final bool isLastRow = idx == _rows.length - 1;
    final Color rowBgColor = idx % 2 != 0
        ? Colors.blue.shade50.withOpacity(0.2)
        : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: rowBgColor,
        border: Border(
          bottom: BorderSide(
            color: isLastRow ? Colors.transparent : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // #
          _buildTableCell(
            width: 40,
            child: Text(
              '${idx + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          // DIA
          _buildTableCell(
            width: 100,
            child: _buildSmallDropdown(
              row.dia,
              _dias,
              (v) => setState(() => row.dia = v),
              hint: "-",
            ),
          ),
          // ROLL
          _buildTableCell(
            width: 80,
            child: _buildTableInput(row.rollsController, (v) {
              row.rolls = int.tryParse(v) ?? 0;
              if (_useSetBasedEntry) {
                // Auto-Calculate Sets: rolls / 11, rounded
                row.sets = (row.rolls / 11).round();
                row.setsController.text = row.sets == 0
                    ? ''
                    : row.sets.toString();
              } else {
                row.sets = 0;
                row.setsController.text = '';
                row.recRoll = row.rolls;
              }
              _updateRowMath(row);
            }, key: ValueKey('rolls_${row.id}')),
          ),
          // SETS
          if (_useSetBasedEntry)
            _buildTableCell(
              width: 80,
              child: _buildTableInput(row.setsController, (v) {
                row.sets = int.tryParse(v) ?? 0;
                _updateRowMath(row);
              }, key: ValueKey('sets_${row.id}')),
            ),
          // DELIV. WT
          _buildTableCell(
            width: 100,
            child: _buildTableInput(row.delivWtController, (v) {
              row.deliveredWeight = double.tryParse(v) ?? 0;
              _updateRowMath(row);
            }, key: ValueKey('deliv_${row.id}')),
          ),
          // REC. ROLL
          _buildTableCell(
            width: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${row.recRoll}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
                if (row.prevRecRolls > 0)
                  Text(
                    '(Prev: ${row.prevRecRolls})',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          // REC. WT
          _buildTableCell(
            width: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTableInput(
                        row.recWtController,
                        (v) {
                          row.recWeight = double.tryParse(v) ?? 0;
                          _updateRowMath(row);
                        },
                        key: ValueKey('rec_${row.id}'),
                        onTap:
                            _enableWeightInput
                                ? () => _captureScaleWeightForRow(row)
                                : null,
                      ),
                    ),
                    if (_enableVoiceInput) ...[
                      GestureDetector(
                        onTap: () => _startVoiceInputForRow(row),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color:
                                (_isListening && _listeningForRowId == row.id)
                                ? Colors.red.shade100
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            (_isListening && _listeningForRowId == row.id)
                                ? Icons.mic
                                : Icons.mic_none,
                            size: 16,
                            color:
                                (_isListening && _listeningForRowId == row.id)
                                ? Colors.red
                                : Colors.blue.shade400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (_enableWeightInput && false) // Hide redundant icon when cell tap is enabled
                      GestureDetector(
                        onTap: () => _captureScaleWeightForRow(row),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.monitor_weight_outlined,
                            size: 16,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
                if (row.prevRecWt > 0)
                  Text(
                    '(Prev: ${row.prevRecWt.toStringAsFixed(1)})',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          // RATE
          _buildTableCell(
            width: 80,
            child: _buildTableInput(row.rateController, (v) {
              row.rate = double.tryParse(v) ?? 0;
            }, key: ValueKey('rate_${row.id}')),
          ),
          // DIFF
          _buildTableCell(
            width: 80,
            child: Text(
              row.difference.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: row.difference != 0
                    ? Colors.orange.shade800
                    : const Color(0xFF64748B),
              ),
            ),
          ),
          // LOSS %
          _buildTableCell(
            width: 80,
            child: Text(
              '${row.lossPercent.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: row.lossPercent > 0
                    ? Colors.red.shade800
                    : Colors.green.shade800,
              ),
            ),
          ),
          // VALUE
          _buildTableCell(
            width: 100,
            child: Text(
              row.value.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
          ),
          // ACTION
          _buildTableCell(
            width: 60,
            isLast: true,
            child: _rows.length > 1
                ? IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onPressed: () {
                      row.dispose();
                      setState(() => _rows.removeAt(idx));
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell({
    required double width,
    required Widget child,
    bool isLast = false,
  }) {
    return Container(
      width: width,
      height: 60,
      decoration: BoxDecoration(
        border: Border(
          right: isLast
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: child,
    );
  }

  Widget _buildTableInput(
    TextEditingController ctrl,
    Function(String) chg, {
    Key? key,
    VoidCallback? onTap,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextFormField(
        controller: ctrl,
        onTap: onTap,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
        ],
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF334155),
        ),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          hintText: '0',
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: chg,
      ),
    );
  }

  Widget _buildStickerPage() {
    final enteredDias = _getDiasWithRolls().toList();
    InwardRow? selectedRow;
    final diaData = _selectedStickerDia != null ? _stickerData[_selectedStickerDia!] : null;
    if (_selectedStickerDia != null) {
      for (final r in _rows) {
        if (r.dia?.trim() == _selectedStickerDia?.trim()) {
          selectedRow = r;
          break;
        }
      }
    }
    int setsCount = 0;
    if (_selectedStickerDia != null) {
      if (diaData != null && diaData.setsOverride != null) {
        setsCount = diaData.setsOverride!;
      } else if (_useSetBasedEntry) {
        for (var r in _rows) {
          if (r.dia?.trim() == _selectedStickerDia?.trim()) {
            setsCount += r.sets;
          }
        }
      } else {
        setsCount = 1;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          "Select DIA for Stickers",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        _buildSmallDropdown(
          _selectedStickerDia,
          enteredDias,
          (v) => setState(() {
            _selectedStickerDia = v;
            if (v != null) {
              _initializeStickerRows(v);
            }
          }),
        ),
          if (_selectedStickerDia != null) ...[
            const SizedBox(height: 12),
            Builder(builder: (context) {
              if (diaData == null) return const SizedBox.shrink();
            final isMissing = diaData.cuttingDia == null || diaData.cuttingDia!.trim().isEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Cuttable Dia",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: diaData.cuttingDiaController,
                  decoration: InputDecoration(
                    hintText: isMissing ? "you not add details in this dia no cuttable dia added" : "Enter Cuttable Dia",
                    hintStyle: isMissing ? const TextStyle(color: Colors.red, fontSize: 13) : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  onChanged: (v) {
                    setState(() {
                      diaData.cuttingDia = v;
                    });
                  },
                ),
              ],
            );
          }),
          const SizedBox(height: 16),
          if (selectedRow != null && diaData != null)
            Row(
              children: [
                Text(
                  'Delivery Roll: ${selectedRow.rolls}   '
                  'Delivery Wt: ${FormatUtils.formatWeight(selectedRow.deliveredWeight)} kg',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _removeSet(diaData),
                  icon: const Icon(Icons.remove_circle, color: Colors.red, size: 24),
                  tooltip: 'Remove Set',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _addSet(diaData),
                  icon: const Icon(Icons.add_circle, color: Colors.blue, size: 24),
                  tooltip: 'Add Set',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          if (setsCount > 0)
            _buildDynamicSetTable(setsCount, key: ValueKey(_selectedStickerDia))
          else if (_useSetBasedEntry)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "No sets calculated. Please enter ROLLS on the first page for this DIA.",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => _printStickers(null),
                  icon: const Icon(Icons.visibility),
                  label: const Text(
                    "Preview Stickers",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _saveStorageForCurrentDia,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    "Save Entry",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E).withOpacity(0.7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  void _onReorderRows(StickerDiaData diaData, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final r = diaData.rows.removeAt(oldIndex);
      diaData.rows.insert(newIndex, r);
    });
  }

  void _addSet(StickerDiaData diaData) {
    setState(() {
      int currentSets = diaData.setsOverride ?? _getSetsForDia(_selectedStickerDia!);
      diaData.setsOverride = currentSets + 1;
    });
  }

  void _removeSet(StickerDiaData diaData) {
    int currentSets = diaData.setsOverride ?? _getSetsForDia(_selectedStickerDia!);
    if (currentSets <= 1) return;
    setState(() {
      diaData.setsOverride = currentSets - 1;
      // Cleanup data
      if (diaData.racks.length > diaData.setsOverride!) diaData.racks.removeLast();
      if (diaData.pallets.length > diaData.setsOverride!) diaData.pallets.removeLast();
      for (var row in diaData.rows) {
        if (row.setWeights.length > diaData.setsOverride!) row.setWeights.removeLast();
        if (row.setLabels.length > diaData.setsOverride!) row.setLabels.removeLast();
        if (row.controllers.length > diaData.setsOverride!) {
          row.controllers.last.dispose();
          row.controllers.removeLast();
        }
        if (row.focusNodes.length > diaData.setsOverride!) {
          row.focusNodes.last.dispose();
          row.focusNodes.removeLast();
        }
      }
    });
  }

  int _getSetsForDia(String dia) {
    if (!_useSetBasedEntry) return 1;
    final diaData = _stickerData[dia];
    if (diaData != null && diaData.setsOverride != null) {
      return diaData.setsOverride!;
    }
    int totalSets = 0;
    for (var r in _rows) {
      if (r.dia?.trim() == dia) {
        totalSets += r.sets;
      }
    }
    return totalSets;
  }

  Widget _buildDynamicSetTable(int sets, {Key? key}) {
    final dia = _selectedStickerDia!;
    final diaData = _stickerData[dia] ?? StickerDiaData();
    final rows = diaData.rows;
    final setHeaders = _resolveDiaSetLabels(diaData, sets);

    // Responsive Widths
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Fixed parts (Left columns: Drag, Colour)
    final dWidth = isMobile ? 30.0 : 40.0;
    final cWidth = isMobile ? 95.0 : 120.0;
    final fixedPartWidth = dWidth + cWidth;

    // Scrollable identifiers (Moveable columns: S.NO, GSM)
    final sWidth = isMobile ? 35.0 : 50.0;
    final gWidth = isMobile ? 55.0 : 80.0;

    // Scrollable parts (Weights, Roll No, Total)
    final cellWidth = isMobile ? 85.0 : 125.0;
    final rollWidth = isMobile ? 65.0 : 100.0;
    final totWidth = isMobile ? 85.0 : 125.0;

    final totalTableWidth = fixedPartWidth + sWidth + gWidth + (sets * cellWidth) + rollWidth + totWidth;

    // Ensure rack and pallet lists are sized correctly
    while (diaData.racks.length < sets) diaData.racks.add(null);
    while (diaData.pallets.length < sets) diaData.pallets.add(null);

    // Calculate set-wise totals
    final List<double> setTotals = List.filled(sets, 0.0);
    double grandTotal = 0.0;
    int totalRolls = 0;
    for (var r in rows) {
      for (int i = 0; i < sets; i++) {
        if (r.setWeights.length > i) {
          final val = double.tryParse(r.setWeights[i].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
          setTotals[i] += val;
        }
      }
      grandTotal += r.totalWeight;
      totalRolls += int.tryParse(r.rollNo) ?? 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _hScrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER SECTION (Combined)
              Stack(
                children: [
                  // Scrollable Header Content
                  Padding(
                    padding: EdgeInsets.only(left: fixedPartWidth),
                    child: Column(
                      children: [
                        // Header Row 1: Rack Name
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0).withOpacity(0.3),
                            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: Row(
                            children: [
                              _buildGridCell("", sWidth),
                              _buildGridCell("", gWidth),
                              ...List.generate(
                                sets,
                                (i) => _buildGridCell(
                                  "",
                                  cellWidth,
                                  child: _buildSmallDropdown(
                                    diaData.racks[i],
                                    _rackNames,
                                    (v) => setState(() => diaData.racks[i] = v),
                                    hint: "Rack",
                                  ),
                                ),
                              ),
                              _buildGridCell("", rollWidth),
                              _buildGridCell("", totWidth),
                            ],
                          ),
                        ),
                        // Header Row 2: Pallet No
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0).withOpacity(0.3),
                            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: Row(
                            children: [
                              _buildGridCell("", sWidth),
                              _buildGridCell("", gWidth),
                              ...List.generate(
                                sets,
                                (i) => _buildGridCell(
                                  "",
                                  cellWidth,
                                  child: _buildSmallDropdown(
                                    diaData.pallets[i],
                                    _palletNos,
                                    (v) => setState(() => diaData.pallets[i] = v),
                                    hint: "Pallet",
                                  ),
                                ),
                              ),
                              _buildGridCell("", rollWidth),
                              _buildGridCell("", totWidth),
                            ],
                          ),
                        ),
                        // Header Row 3: Labels
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0).withOpacity(0.5),
                            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: Row(
                            children: [
                              _buildGridCell("S.NO", sWidth, isMobile: isMobile),
                              _buildGridCell("GSM", gWidth, isMobile: isMobile),
                              ...List.generate(
                                sets,
                                (i) => _buildGridCell(
                                  "",
                                  cellWidth,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        setHeaders[i],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 10 : 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              _buildGridCell(
                                "",
                                rollWidth,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Roll No",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: isMobile ? 10 : 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildGridCell(
                                "TOTAL",
                                totWidth,
                                isMobile: isMobile,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sticky Fixed Header Part
                  Transform.translate(
                    offset: Offset(_hScrollOffset, 0),
                    child: Container(
                      width: fixedPartWidth,
                      color: Colors.white,
                      child: Column(
                        children: [
                          _buildHeaderCell("", fixedPartWidth),
                          _buildHeaderCell("", fixedPartWidth),
                          Container(
                            height: 65,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0).withOpacity(0.5),
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade300),
                                right: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildGridCell("", dWidth),
                                _buildGridCell("Colour", cWidth, isMobile: isMobile),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // BODY SECTION (Reorderable Rows)
              SizedBox(
                width: totalTableWidth,
                child: ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (oldIdx, newIdx) => _onReorderRows(diaData, oldIdx, newIdx),
                  buildDefaultDragHandles: false,
                  children: rows.map((r) {
                    final idx = rows.indexOf(r);
                    r.gsmController ??= TextEditingController(text: r.gsm);
                    return Container(
                      key: ObjectKey(r),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Stack(
                        children: [
                          // All cells (Scrollable part offset by fixed width)
                          Padding(
                            padding: EdgeInsets.only(left: fixedPartWidth),
                            child: Row(
                              children: [
                                _buildGridCell('${idx + 1}', sWidth, isMobile: isMobile),
                                _buildGridCell(
                                  "",
                                  gWidth,
                                  child: _buildTableInputText(
                                    r.gsmController!,
                                    (v) {
                                      r.gsm = v;
                                      final colour = r.colour;
                                      if (v.isNotEmpty && colour != null && colour.isNotEmpty) {
                                        _lastStickerGsmMap[colour] = v;
                                      }
                                      setState(() {});
                                    },
                                    isMobile: isMobile,
                                  ),
                                ),
                                ...List.generate(sets, (i) {
                                  if (r.setWeights.length <= i) r.setWeights.add('');
                                  if (r.setLabels.length <= i) {
                                    r.setLabels.add(_useSetBasedEntry ? setHeaders[i] : _nextNoSetLabel(diaData));
                                  }
                                  if (r.controllers.length <= i) {
                                    r.controllers.add(TextEditingController(text: r.setWeights[i]));
                                  }
                                  if (r.focusNodes.length <= i) {
                                    r.focusNodes.add(FocusNode());
                                  }
                                  return _buildGridCell(
                                    "",
                                    cellWidth,
                                    child: _buildTableInputText(
                                      r.controllers[i],
                                      (v) {
                                        setState(() {
                                          r.setWeights[i] = v;
                                          int count = r.setWeights.where((w) => w.trim().isNotEmpty).length;
                                          if (count > 0) {
                                            r.rollNo = count.toString();
                                            r.rollNoController.text = r.rollNo;
                                          } else {
                                            r.rollNo = "";
                                            r.rollNoController.text = "";
                                          }
                                        });
                                      },
                                      onMicTap: _enableVoiceInput ? () => _startVoiceInputForSetWeight(r, idx, i) : null,
                                      onWeightTap: _enableWeightInput ? () => _captureScaleWeightForSet(r, i) : null,
                                      isListening: _isListening && _listeningForStickerRowIdx == idx && _listeningForSetIdx == i,
                                      focusNode: r.focusNodes.length > i ? r.focusNodes[i] : null,
                                      isMobile: isMobile,
                                    ),
                                  );
                                }),
                                // Roll No Input
                                _buildGridCell(
                                  "",
                                  rollWidth,
                                  child: _buildTableInputText(
                                    r.rollNoController,
                                    (v) {
                                      r.rollNo = v;
                                    },
                                    isMobile: isMobile,
                                  ),
                                ),
                                // Row Total
                                _buildGridCell(
                                  r.totalWeight.toStringAsFixed(3),
                                  totWidth,
                                  alignment: Alignment.center,
                                  isMobile: isMobile,
                                  child: Text(
                                    r.totalWeight.toStringAsFixed(3),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isMobile ? 10 : 12,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Sticky Fixed Column Part
                          Transform.translate(
                            offset: Offset(_hScrollOffset, 0),
                            child: Container(
                              width: fixedPartWidth,
                              color: Colors.white.withOpacity(0.9), // Slightly opaque for drag clarity
                              child: Row(
                                children: [
                                  _buildGridCell(
                                    "",
                                    dWidth,
                                    child: ReorderableDragStartListener(
                                      index: idx,
                                      child: Icon(
                                        Icons.drag_handle,
                                        color: Colors.grey,
                                        size: isMobile ? 16 : 20,
                                      ),
                                    ),
                                  ),
                                  _buildGridCell(
                                    "",
                                    cWidth,
                                    child: _buildSmallDropdown(
                                      r.colour,
                                      _colours,
                                      (v) => setState(() => r.colour = v),
                                      hint: "Colour",
                                      itemImages: _colourImages,
                                      onDoubleTap: r.colour != null ? () => _showColorPreview(r.colour!, _colourImages[r.colour!]) : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              // FOOTER SECTION
              Stack(
                children: [
                  // Scrollable Footer Content
                  Padding(
                    padding: EdgeInsets.only(left: fixedPartWidth),
                    child: Container(
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                      ),
                      child: Row(
                        children: [
                          _buildGridCell("", sWidth),
                          _buildGridCell("", gWidth),
                          ...List.generate(
                            sets,
                            (i) => _buildGridCell(
                              FormatUtils.formatWeight(setTotals[i]),
                              cellWidth,
                              alignment: Alignment.center,
                              isMobile: isMobile,
                            ),
                          ),
                          _buildGridCell(
                            totalRolls.toString(),
                            rollWidth,
                            alignment: Alignment.center,
                            isMobile: isMobile,
                            child: Text(
                              totalRolls.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 11 : 13,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          _buildGridCell(
                            FormatUtils.formatWeight(grandTotal),
                            totWidth,
                            alignment: Alignment.center,
                            isMobile: isMobile,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Sticky Footer Label
                  Transform.translate(
                    offset: Offset(_hScrollOffset, 0),
                    child: Container(
                      height: 50,
                      width: fixedPartWidth,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300),
                          right: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "SET TOTAL",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                          fontSize: isMobile ? 11 : 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Add row button
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                final row = StickerRow();
                row.setWeights = List<String>.filled(sets, '', growable: true);
                row.setLabels = _useSetBasedEntry
                    ? List<String>.from(setHeaders)
                    : [_nextNoSetLabel(diaData)];
                diaData.rows.add(row);
              });
            },
            icon: const Icon(Icons.add_circle_outline, size: 20),
            label: const Text("Add New Set Entry"),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String label, double width, {bool isMobile = false}) {
    return Container(
      width: width,
      height: 65,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0).withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 12),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isMobile ? 10 : 12,
          color: const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildGridCell(
    String label,
    double width, {
    Widget? child,
    Alignment alignment = Alignment.center,
    double? padding,
    bool isMobile = false,
  }) {
    return Container(
      width: width,
      height: 65, // Increased from 50 to allow wrapping
      padding: EdgeInsets.symmetric(horizontal: padding ?? (isMobile ? 2 : 4)),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      alignment: alignment,
      child: child ??
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 10 : 12,
              color: const Color(0xFF475569),
            ),
          ),
    );
  }

  Widget _buildTableInputText(
    TextEditingController controller,
    Function(String) chg, {
    VoidCallback? onMicTap,
    VoidCallback? onWeightTap,
    bool isListening = false,
    FocusNode? focusNode,
    bool isMobile = false,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      onTap: (_enableWeightInput && onWeightTap != null) ? onWeightTap : null,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
      ],
      style: TextStyle(
        fontSize: isMobile ? 10 : 12,
        fontWeight: FontWeight.bold,
      ), // Reduced from 13
      textAlign: TextAlign.center,
      maxLines: isMobile ? 1 : 2, // Allow wrapping
      minLines: 1,
      decoration: InputDecoration(
        hintText: '-',
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero, // Maximize space
        suffixIcon: (onMicTap != null || onWeightTap != null)
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onMicTap != null)
                    IconButton(
                      icon: Icon(
                        Icons.mic,
                        size: 16,
                        color: isListening ? Colors.red : Colors.blue,
                      ),
                      onPressed: onMicTap,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                    ),
                  if (onWeightTap != null && !_enableWeightInput)
                    IconButton(
                      icon: Icon(
                        Icons.monitor_weight_outlined,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      onPressed: onWeightTap,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                    ),
                ],
              )
            : null,
      ),
      onChanged: chg,
    );
  }

  Widget _buildSignatureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Signatures (E-Signature)",
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
            _buildSigBox(
              "MD",
              _mdSignature,
              (f) => setState(() => _mdSignature = f),
              allowedRoles: ['md', 'admin'],
            ),
          ],
        ),
      ],
    );
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

  Widget _buildModalFilter(
    String label,
    String? val,
    List<String> items,
    Function(String?) chg,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: val,
              isExpanded: true,
              hint: Text(
                "All",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              items: items
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: const TextStyle(fontSize: 12)),
                    ),
                  )
                  .toList(),
              onChanged: chg,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSigBox(
    String label,
    XFile? file,
    Function(XFile?) onPick, {
    List<String> allowedRoles = const [],
  }) {
    final bool canSign = _userRole != null && allowedRoles.contains(_userRole);

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
            width: 90,
            height: 50,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              color: canSign ? null : Colors.grey.shade100,
            ),
            child: file != null
                ? (kIsWeb
                      ? Image.network(file.path, fit: BoxFit.contain)
                      : Image.file(File(file.path), fit: BoxFit.contain))
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit, color: Colors.grey, size: 20),
                      Text(
                        "Sign",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
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
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnly(String label, String val) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.all(8),
    ),
    child: Text(
      val,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
    ),
  );
  Widget _buildTextField(String label, TextEditingController c) =>
      TextFormField(
        controller: c,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.all(8),
        ),
      );
  Widget _buildDropdown(
    String label,
    String? val,
    List<String> items,
    Function(String?) chg,
  ) => CustomDropdownField(
    label: label,
    value: val,
    items: items,
    onChanged: chg,
    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
  );

  Widget _buildSmallDropdown(
    String? val,
    List<String> items,
    Function(String?) chg, {
    String hint = "-",
    Map<String, String>? itemImages,
    VoidCallback? onDoubleTap,
  }) => CustomDropdownField(
    label: "", // No label for small dropdown in grid
    value: val,
    items: items,
    onChanged: chg,
    hint: hint,
    itemImages: itemImages,
    onDoubleTap: onDoubleTap,
    resolveColor: _resolveColor,
  );
  Widget _buildGridHeader() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        "DIA-wise Entry",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF475569),
        ),
      ),
      TextButton.icon(
        onPressed: () async {
          double defaultRate = 0;
          if (_selectedParty != null) {
            final details = await _api.getPartyDetails(_selectedParty!);
            if (details != null) {
              defaultRate = (details['rate'] is num)
                  ? (details['rate'] as num).toDouble()
                  : 0.0;
            }
          }
          final newRow = InwardRow()..rate = defaultRate;
          newRow.syncControllersFromValues();
          setState(() => _rows.add(newRow));
        },
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          "Add Row",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).primaryColor,
        ),
      ),
    ],
  );
  Widget _buildNavigationButtons() {
    final diasWithRolls = _getDiasWithRolls();
    final pending = diasWithRolls
        .where((d) => !_completedStickerDias.contains(d))
        .toList();
    final allDone = diasWithRolls.isNotEmpty && pending.isEmpty;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _navigateToStickerPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              "Next Page (Storage Details)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: (allDone && !_isSaving) ? _save : null,
            icon: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save, size: 24),
            label: Text(
              _isSaving
                  ? "Saving..."
                  : (widget.editInward != null ? "Update Entry" : "Save Entry"),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: allDone
                  ? const Color(0xFF22C55E)
                  : Colors.grey.shade300,
              foregroundColor: allDone ? Colors.white : Colors.grey,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        if (!allDone && diasWithRolls.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "Missing storage for: ${pending.join(', ')}",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  /// Save storage details for the currently selected DIA and return to main page.
  void _saveStorageForCurrentDia() {
    if (_selectedStickerDia == null) {
      _showError('Please select a DIA for stickers');
      return;
    }

    final dia = _selectedStickerDia!.trim();

    // Recalculate sets count for this DIA from the main grid
    int setsCount = 0;
    if (_useSetBasedEntry) {
      for (var r in _rows) {
        if (r.dia?.trim() == dia) {
          setsCount += r.sets;
        }
      }

      if (setsCount <= 0) {
        _showError(
          'No sets calculated. Please enter ROLLS/SETS on the first page for this DIA.',
        );
        return;
      }
    } else {
      setsCount = 1;
    }

    final diaData = _stickerData[dia] ?? StickerDiaData();

    final hasRackOrPallet =
        diaData.racks.any((r) => r != null && r.isNotEmpty) ||
        diaData.pallets.any((p) => p != null && p.isNotEmpty);

    if (!hasRackOrPallet) {
      _showError('Please select at least one Rack or Pallet.');
      return;
    }

    // At least one colour row with any set weight entered
    final hasAnyRow = diaData.rows.any(
      (r) => r.colour != null && r.setWeights.any((w) => w.trim().isNotEmpty),
    );

    if (!hasAnyRow) {
      _showError('Please enter at least one sticker row for this DIA.');
      return;
    }

    setState(() {
      _stickerData[dia] = diaData;
      _completedStickerDias.add(dia);

      // Update the main row's received weight based on sticker entries
      try {
        final mainRow = _rows.firstWhere((r) => r.dia == dia);
        double totalRecWeight = 0;
        int totalRecRolls = 0;
        for (var sRow in diaData.rows) {
          totalRecWeight += sRow.totalWeight;
          totalRecRolls += int.tryParse(sRow.rollNo) ?? 0;
        }
        mainRow.recWeight = totalRecWeight;
        mainRow.recRoll =
            _useSetBasedEntry ? totalRecRolls : mainRow.rolls;
        // Also update other math like difference and loss%
        _updateRowMath(mainRow);
      } catch (e) {
        print('Error updating main row for dia $dia: $e');
      }

      // Check if another DIA is available for stickers
      final allDias = _getDiasWithRolls();
      final remaining = allDias
          .where((d) => !_completedStickerDias.contains(d))
          .toList();

      if (remaining.isNotEmpty) {
        // Move to next DIA
        _selectedStickerDia = remaining.first;
        _initializeStickerRows(_selectedStickerDia!);
      } else {
        _selectedStickerDia = null;
        _currentPage = 0; // Back to main page only if all done
      }
    });
  }

  Widget _buildImageSection(String label, XFile? file, Function(XFile?) onSet) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _pickImage(onSet),
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: Text(file == null ? "Add Image" : "Change"),
                ),
              ],
            ),
            if (file != null)
              GestureDetector(
                onTap: () => _showLargeImage(file),
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(File(file.path)),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.zoom_in, color: Colors.white70, size: 30),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckSection({
    required String title,
    required String status,
    required XFile? image,
    required Function(String) onStatusChanged,
    required Function(XFile?) onImagePicked,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: RadioListTile(
                    title: const Text("OK", style: TextStyle(fontSize: 12)),
                    value: "OK",
                    groupValue: status,
                    onChanged: (v) => onStatusChanged(v.toString()),
                  ),
                ),
                Expanded(
                  child: RadioListTile(
                    title: const Text("Not OK", style: TextStyle(fontSize: 12)),
                    value: "Not OK",
                    groupValue: status,
                    onChanged: (v) => onStatusChanged(v.toString()),
                  ),
                ),
              ],
            ),
            _buildImageSection(
              "${title.split(' ')[0]} Image",
              image,
              onImagePicked,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualitySection() {
    return _buildCheckSection(
      title: "Quality Check",
      status: _qualityStatus,
      image: _qualityImage,
      onStatusChanged: (v) => setState(() => _qualityStatus = v),
      onImagePicked: (f) => _qualityImage = f,
    );
  }

  Widget _buildComplaintSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Complaint (if any)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _complaintController,
              decoration: const InputDecoration(
                labelText: "Complaint Remarks",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            _buildImageSection(
              "Complaint Image",
              _complaintImage,
              (f) => _complaintImage = f,
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPreview(String valueName, String? photoUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(valueName, textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (photoUrl != null && photoUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ApiConstants.getImageUrl(photoUrl),
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _largeColorCircle(valueName),
                  ),
                )
              else
                _largeColorCircle(valueName),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _largeColorCircle(String value) {
    final color = _resolveColor(value) ?? const Color(0xFFBDBDBD);
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }

  Color? _resolveColor(String name) {
    final lower = name.toLowerCase().trim();
    const colorMap = <String, Color>{
      'red': Color(0xFFE53935),
      'dark red': Color(0xFFB71C1C),
      'light red': Color(0xFFEF9A9A),
      'blue': Color(0xFF1E88E5),
      'dark blue': Color(0xFF0D47A1),
      'light blue': Color(0xFF90CAF9),
      'sky blue': Color(0xFFA3C1E0),
      'royal blue': Color(0xFF4D63C3),
      'navy blue': Color(0xFF0A1747),
      'navy': Color(0xFF0A1747),
      'green': Color(0xFF43A047),
      'dark green': Color(0xFF1B5E20),
      'light green': Color(0xFFA5D6A7),
      'olive green': Color(0xFF6B8E23),
      'forest green': Color(0xFF228B22),
      'yellow': Color(0xFFFDD835),
      'golden yellow': Color(0xFFF9A825),
      'orange': Color(0xFFFB8C00),
      'dark orange': Color(0xFFE65100),
      'black': Color(0xFF212121),
      'jet black': Color(0xFF0A0A0A),
      'white': Color(0xFFFAFAFA),
      'off white': Color(0xFFF5F0E8),
      'cream': Color(0xFFFFF8E1),
      'ivory': Color(0xFFFFFFF0),
      'grey': Color(0xFF9E9E9E),
      'gray': Color(0xFF9E9E9E),
      'dark grey': Color(0xFF424242),
      'light grey': Color(0xFFE0E0E0),
      'charcoal': Color(0xFF36454F),
      'pink': Color(0xFFEC407A),
      'hot pink': Color(0xFFFF1493),
      'dusty rose': Color(0xFFDCAE96),
      'baby pink': Color(0xFFF8BBD0),
      'magenta': Color(0xFFD500F9),
      'purple': Color(0xFF7B1FA2),
      'violet': Color(0xFF7C21A6),
      'lavender': Color(0xFFCE93D8),
      'brown': Color(0xFF6D4C41),
      'chocolate brown': Color(0xFF5D3A1A),
      'dark brown': Color(0xFF3E2723),
      'tan': Color(0xFFD2B48C),
      'beige': Color(0xFFF5F5DC),
      'khaki': Color(0xFFC3B091),
      'maroon': Color(0xFF800000),
      'burgundy': Color(0xFF800020),
      'wine': Color(0xFF722F37),
      'teal': Color(0xFF008080),
      'turquoise': Color(0xFF40E0D0),
      'aqua': Color(0xFF00FFFF),
      'cyan': Color(0xFF00BCD4),
      'coral': Color(0xFFFF7F50),
      'salmon': Color(0xFFFA8072),
      'peach': Color(0xFFFFDAB9),
      'rust': Color(0xFFB7410E),
      'copper': Color(0xFFB87333),
      'gold': Color(0xFFFFD700),
      'silver': Color(0xFFC0C0C0),
      'indigo': Color(0xFF3F51B5),
      'mint': Color(0xFF98FF98),
      'sage': Color(0xFFBCB88A),
      'olive': Color(0xFF808000),
      'mustard': Color(0xFFFFDB58),
      'lemon': Color(0xFFFFF44F),
      'plum': Color(0xFF8E4585),
    };

    // Check for hex code in the name (e.g. "My Color #FF00FF")
    final hexMatch = RegExp(
      r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})',
    ).firstMatch(name);
    if (hexMatch != null) {
      try {
        String hex = hexMatch.group(1)!;
        if (hex.length == 3) {
          // Convert 3-digit hex to 6-digit
          hex = hex[0] * 2 + hex[1] * 2 + hex[2] * 2;
        }
        return Color(int.parse('0xFF$hex'));
      } catch (_) {}
    }

    // Direct match
    if (colorMap.containsKey(lower)) return colorMap[lower]!;

    // Partial match — check if any key is contained in the color name
    // Sort keys by length descending to match more specific colors first (e.g. "Dark Blue" before "Blue")
    final sortedKeys = colorMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final key in sortedKeys) {
      if (lower.contains(key)) return colorMap[key];
    }

    // Default null for unknown colors
    return null;
  }
}

class InwardRow {
  final String id =
      DateTime.now().millisecondsSinceEpoch.toString() +
      Random().nextInt(1000).toString();
  String? dia;
  int rolls = 0;
  int sets = 0;
  double deliveredWeight = 0;
  int recRoll = 0;
  double recWeight = 0;
  double rate = 0;
  double difference = 0;
  double lossPercent = 0;

  // Previous totals for recurring lots
  double prevRecWt = 0;
  int prevRecRolls = 0;

  // Text Controllers for stable focus and live updates
  late TextEditingController rollsController;
  late TextEditingController setsController;
  late TextEditingController delivWtController;
  late TextEditingController recWtController;
  late TextEditingController rateController;

  InwardRow() {
    rollsController = TextEditingController();
    setsController = TextEditingController();
    delivWtController = TextEditingController();
    recWtController = TextEditingController();
    rateController = TextEditingController();
  }

  void syncControllersFromValues() {
    rollsController.text = rolls == 0 ? '' : rolls.toString();
    setsController.text = sets == 0 ? '' : sets.toString();
    delivWtController.text = deliveredWeight == 0
        ? ''
        : deliveredWeight.toString();
    recWtController.text = recWeight == 0 ? '' : recWeight.toString();
    rateController.text = rate == 0 ? '' : rate.toString();
  }

  void dispose() {
    rollsController.dispose();
    setsController.dispose();
    delivWtController.dispose();
    recWtController.dispose();
    rateController.dispose();
  }

  // New Getter for Value
  double get value => rate * recWeight;
}

class StickerRow {
  String? colour;
  String? gsm;
  String rollNo = "";
  List<String> setWeights = [];
  List<String> setLabels = [];
  List<TextEditingController> controllers = [];
  List<FocusNode> focusNodes = [];
  TextEditingController? gsmController;
  late TextEditingController rollNoController;

  StickerRow() {
    rollNoController = TextEditingController();
  }

  double get totalWeight {
    final sum = setWeights.fold(0.0, (sum, w) {
      final val = double.tryParse(w.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      return sum + val;
    });
    return double.parse(sum.toStringAsFixed(3));
  }

  void dispose() {
    for (var c in controllers) {
      c.dispose();
    }
    for (var f in focusNodes) {
      f.dispose();
    }
    gsmController?.dispose();
    rollNoController.dispose();
  }
}

class StickerDiaData {
  List<String?> racks = [];
  List<String?> pallets = [];
  List<StickerRow> rows = []; // Start empty so it can be auto-filled correctly
  String? cuttingDia;
  TextEditingController? cuttingDiaController;
  int? setsOverride;

  void dispose() {
    cuttingDiaController?.dispose();
    for (var row in rows) {
      row.dispose();
    }
  }
}
