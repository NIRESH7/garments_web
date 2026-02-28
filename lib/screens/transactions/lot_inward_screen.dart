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
  final _formKey = GlobalKey<FormState>();

  final DateTime _inwardDate = DateTime.now();
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

  // Voice input
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String? _listeningForRowId; // which row is currently being listened to
  int? _listeningForStickerRowIdx; // index in diaData.rows
  int? _listeningForSetIdx; // set index

  @override
  void initState() {
    super.initState();
    _inTime = DateFormat('hh:mm a').format(DateTime.now());
    _loadUserRole();
    _loadMasterData();
    _initSpeech();

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
    // Dispose sticker data controllers
    _stickerData.forEach((dia, data) {
      for (var row in data.rows) {
        row.dispose();
      }
    });

    _inwardNoController.dispose();
    _lotNumberController.dispose();
    _rateController.dispose();
    _gsmController.dispose();
    _vehicleController.dispose();
    _dcController.dispose();
    _complaintController.dispose();
    super.dispose();
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
            .replaceAll('decimal', '.');

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
      localeId: 'en_US',
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
            .replaceAll('decimal', '.');

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
      localeId: 'en_US',
    );
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
          if (storage['rows'] != null) {
            diaData.rows = (storage['rows'] as List).map((r) {
              final sRow = StickerRow();
              sRow.colour = r['colour'];
              sRow.setWeights = List<String>.from(r['setWeights'] ?? []);
              return sRow;
            }).toList();
          }
          _stickerData[dia] = diaData;
          _completedStickerDias.add(dia);
        }
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
              row.dia = d['dia'];
              // Don't set current rec/rolls, only previous
              row.prevRecRolls = (d['existingRecRolls'] as num).toInt();
              row.prevRecWt = (d['existingRecWt'] as num).toDouble();
              _rows.add(row);
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
              "sets": r.sets,
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
              "racks": e.value.racks,
              "pallets": e.value.pallets,
              "rows": e.value.rows
                  .where((r) => r.colour != null)
                  .map(
                    (r) => {
                      "colour": r.colour,
                      "setWeights": r.setWeights,
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
    if (_qualityImage != null)
      qualityImgPath = await _api.uploadFile(_qualityImage!.path);
    if (_complaintImage != null)
      complaintImgPath = await _api.uploadFile(_complaintImage!.path);

    // GSM, Shade, Washing Images
    String? gsmImgPath;
    String? shadeImgPath;
    String? washingImgPath;

    if (_gsmImage != null) gsmImgPath = await _api.uploadFile(_gsmImage!.path);
    if (_shadeImage != null)
      shadeImgPath = await _api.uploadFile(_shadeImage!.path);
    if (_washingImage != null)
      washingImgPath = await _api.uploadFile(_washingImage!.path);

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

  void _printStickers(Map<String, dynamic>? inwardData) {
    // Flatten sticker data
    final List<Map<String, dynamic>> stickers = [];

    _stickerData.forEach((dia, data) {
      for (var row in data.rows) {
        if (row.colour != null && row.colour!.isNotEmpty) {
          for (int i = 0; i < row.setWeights.length; i++) {
            final weight = row.setWeights[i];
            if (weight.trim().isNotEmpty) {
              stickers.add({
                'lotNo': _lotNumberController.text,
                'lotName': _selectedLotName ?? '',
                'dia': dia,
                'colour': row.colour!,
                'weight': weight,
                'date': DateFormat('dd-MM-yyyy').format(_inwardDate),
                'setNo': i + 1,
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
                ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
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
                                _buildStickerRow('Set No', '#${item['setNo']}'),
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
                                          fontSize: 8,
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
                              _showError(
                                "Printing not implemented yet for ${filteredToPrint.length} stickers",
                              );
                              Navigator.pop(
                                ctx,
                              ); // Close the modal after "printing"
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
            width: 80,
            child: Text(
              '$label :',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 14)),
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
              _buildPdfRow('Set', '#${item['setNo']}', fontSize: 9),
              _buildPdfRow(
                'Wt',
                '${item['weight']} kg',
                fontSize: 9,
                isBoldValue: true,
              ),
              _buildPdfRow('Dt', item['date']?.toString() ?? '', fontSize: 8),
            ],
          ),
          pw.Spacer(),
          pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(
                  width: 40,
                  height: 40,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data:
                        'LOT: ${item['lotNo']}\nNAME: ${item['lotName']}\nDIA: ${item['dia']}\nCOL: ${item['colour']}\nSET: ${item['setNo']}\nWT: ${item['weight']}kg\nDT: ${item['date']}',
                  ),
                ),
                pw.SizedBox(height: 0.5),
                pw.Text(
                  'SCAN',
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

  pw.Widget _buildPdfRow(
    String label,
    String value, {
    double fontSize = 9,
    bool isBoldValue = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 40, // Reduced width for small label
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
                fontWeight: isBoldValue
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
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
      _stickerData.putIfAbsent(nextDia, () {
        final diaData = StickerDiaData();
        // Auto-populate colour rows from Item Group Master mapping
        if (_lotMappedColours.isNotEmpty) {
          diaData.rows = _lotMappedColours
              .map((c) => StickerRow()..colour = c)
              .toList();
        }
        return diaData;
      });
      _currentPage = 1;
    });
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
                  child: _buildReadOnly(
                    "Inward Date",
                    DateFormat('dd-MM-yyyy').format(_inwardDate),
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
          _buildColumnHeader('SETS', 80),
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
              // Auto-Calculate Sets: rolls / 11, rounded
              row.sets = (row.rolls / 11).round();
              row.setsController.text = row.sets == 0
                  ? ''
                  : row.sets.toString();
              _updateRowMath(row);
            }, key: ValueKey('rolls_${row.id}')),
          ),
          // SETS
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
                      child: _buildTableInput(row.recWtController, (v) {
                        row.recWeight = double.tryParse(v) ?? 0;
                        _updateRowMath(row);
                      }, key: ValueKey('rec_${row.id}')),
                    ),
                    // Voice input button
                    GestureDetector(
                      onTap: () => _startVoiceInputForRow(row),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: (_isListening && _listeningForRowId == row.id)
                              ? Colors.red.shade100
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          (_isListening && _listeningForRowId == row.id)
                              ? Icons.mic
                              : Icons.mic_none,
                          size: 16,
                          color: (_isListening && _listeningForRowId == row.id)
                              ? Colors.red
                              : Colors.blue.shade400,
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
    int setsCount = 0;
    if (_selectedStickerDia != null) {
      for (var r in _rows) {
        if (r.dia?.trim() == _selectedStickerDia?.trim()) {
          setsCount += r.sets;
        }
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
              _stickerData.putIfAbsent(v, () => StickerDiaData());
            }
          }),
        ),
        if (_selectedStickerDia != null) ...[
          const SizedBox(height: 16),
          if (setsCount > 0)
            _buildDynamicSetTable(setsCount, key: ValueKey(_selectedStickerDia))
          else
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

  Widget _buildDynamicSetTable(int sets, {Key? key}) {
    final dia = _selectedStickerDia!;
    final diaData = _stickerData[dia] ?? StickerDiaData();
    final rows = diaData.rows;

    // Ensure rack and pallet lists are sized correctly
    while (diaData.racks.length < sets) diaData.racks.add(null);
    while (diaData.pallets.length < sets) diaData.pallets.add(null);

    return SingleChildScrollView(
      key: key,
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row 1: Rack Name
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0).withOpacity(0.3),
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  _buildGridCell(
                    "Rack Name",
                    170,
                    alignment: Alignment.centerLeft,
                    padding: 12,
                  ),
                  ...List.generate(
                    sets,
                    (i) => _buildGridCell(
                      "",
                      100,
                      child: _buildSmallDropdown(
                        diaData.racks[i],
                        _rackNames,
                        (v) => setState(() => diaData.racks[i] = v),
                        hint: "Rack",
                      ),
                    ),
                  ),
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
                  _buildGridCell(
                    "Pallet No",
                    170,
                    alignment: Alignment.centerLeft,
                    padding: 12,
                  ),
                  ...List.generate(
                    sets,
                    (i) => _buildGridCell(
                      "",
                      100,
                      child: _buildSmallDropdown(
                        diaData.pallets[i],
                        _palletNos,
                        (v) => setState(() => diaData.pallets[i] = v),
                        hint: "Pallet",
                      ),
                    ),
                  ),
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
                  _buildGridCell("S.NO", 50),
                  _buildGridCell("Colour", 120),
                  ...List.generate(
                    sets,
                    (i) => _buildGridCell("Set-${i + 1}", 100),
                  ),
                  _buildGridCell("TOTAL", 100),
                ],
              ),
            ),
            // Data Rows
            ...rows.asMap().entries.map((e) {
              final idx = e.key;
              final r = e.value;
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    _buildGridCell('${idx + 1}', 50),
                    _buildGridCell(
                      "",
                      120,
                      child: _buildSmallDropdown(
                        r.colour,
                        _colours,
                        (v) => setState(() => r.colour = v),
                        hint: "Colour",
                        itemImages: _colourImages,
                      ),
                    ),
                    ...List.generate(sets, (i) {
                      if (r.setWeights.length <= i) r.setWeights.add('');
                      if (r.controllers.length <= i) {
                        r.controllers.add(
                          TextEditingController(text: r.setWeights[i]),
                        );
                      }
                      return _buildGridCell(
                        "",
                        100,
                        child: _buildTableInputText(
                          r.controllers[i],
                          (v) => setState(() => r.setWeights[i] = v),
                          onMicTap: () =>
                              _startVoiceInputForSetWeight(r, idx, i),
                          isListening:
                              _isListening &&
                              _listeningForStickerRowIdx == idx &&
                              _listeningForSetIdx == i,
                        ),
                      );
                    }),
                    _buildGridCell(
                      r.totalWeight.toStringAsFixed(3),
                      100,
                      alignment: Alignment.center,
                    ),
                  ],
                ),
              );
            }),
            // Add row button
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    diaData.rows.add(StickerRow());
                  });
                },
                icon: const Icon(Icons.add, size: 20),
                label: const Text("Add Row"),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCell(
    String label,
    double width, {
    Widget? child,
    Alignment alignment = Alignment.center,
    double padding = 4,
  }) {
    return Container(
      width: width,
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: padding),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      alignment: alignment,
      child:
          child ??
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF475569),
            ),
          ),
    );
  }

  Widget _buildTableInputText(
    TextEditingController controller,
    Function(String) chg, {
    VoidCallback? onMicTap,
    bool isListening = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
      ],
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: '-',
        border: InputBorder.none,
        isDense: true,
        suffixIcon: onMicTap != null
            ? IconButton(
                icon: Icon(
                  Icons.mic,
                  size: 16,
                  color: isListening ? Colors.red : Colors.blue,
                ),
                onPressed: onMicTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 16,
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
  }) => CustomDropdownField(
    label: "", // No label for small dropdown in grid
    value: val,
    items: items,
    onChanged: chg,
    hint: hint,
    itemImages: itemImages,
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
          // Count non-empty weights as rolls
          totalRecRolls += sRow.setWeights
              .where((w) => w.trim().isNotEmpty)
              .length;
        }
        mainRow.recWeight = totalRecWeight;
        mainRow.recRoll = totalRecRolls;
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
        // Move to next DIA — auto-populate its colours if not yet done
        _selectedStickerDia = remaining.first;
        _stickerData.putIfAbsent(_selectedStickerDia!, () {
          final diaData = StickerDiaData();
          if (_lotMappedColours.isNotEmpty) {
            diaData.rows = _lotMappedColours
                .map((c) => StickerRow()..colour = c)
                .toList();
          }
          return diaData;
        });
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
  List<String> setWeights = [];
  List<TextEditingController> controllers = [];

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
  }
}

class StickerDiaData {
  List<String?> racks = [];
  List<String?> pallets = [];
  List<StickerRow> rows = [StickerRow()];
}
