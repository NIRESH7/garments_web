import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/api_constants.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../widgets/custom_dropdown_field.dart';
import 'package:garments/dialogs/signature_pad_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:garments/widgets/app_drawer.dart';

class LotInwardScreen extends StatefulWidget {
  const LotInwardScreen({super.key});

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
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _inTime = DateFormat('hh:mm a').format(DateTime.now());
    _loadMasterData();
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
            if (v['image'] != null && v['image'].toString().isNotEmpty) {
              String imgPath = v['image'].toString();
              // If it's a relative path (uploads/...), prepend base URL
              if (!imgPath.startsWith('http') && !imgPath.startsWith('/')) {
                imgPath = '${ApiConstants.serverUrl}/$imgPath';
              }
              // If it starts with uploads/, it likely needs base URL without extra slash if base has it, but usually safe to join.
              // Actually, best to check ApiConstants.

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

  Future<void> _onLotNameChanged(String? val) async {
    setState(() {
      _selectedLotName = val;
      _stickerData.clear(); // Ensure fresh start for storage details
      _completedStickerDias.clear();
    });

    if (val != null) {
      final group = await _api.getItemGroupByName(val);
      setState(() {
        if (group != null) {
          // Include all master colours + any specific lot colours
          _colours = List<String>.from({
            ..._masterColours,
            ...List<String>.from(group['colours'] ?? []),
          });

          // Carry over GSM and Rate
          _gsmController.text = (group['gsm'] ?? '').toString();

          // Only set rate if it's currently 0 or empty, allowing Party rate to take precedence if already set
          if (_rateController.text.isEmpty ||
              _rateController.text == "0.0" ||
              _rateController.text == "0") {
            _rateController.text = (group['rate'] ?? '').toString();
          }
        } else {
          _colours = List<String>.from(_masterColours);
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

      row.recRoll = row.rolls;
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
      String msg = "*Lot Inward Entry*\n";
      msg += "Date: ${data['inwardDate']}\n";
      msg += "Lot: ${data['lotName']} / ${data['lotNo']}\n";
      msg += "Party: ${data['fromParty']}\n";
      msg += "Quality: ${data['qualityStatus']}\n";
      if (data['complaintText'] != null &&
          data['complaintText'].toString().isNotEmpty) {
        msg += "Complaint: ${data['complaintText']}\n";
      }

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
          "Total Rec. Wt (Page 1): ${recWt.toStringAsFixed(3)} Kg\n"
          "Sum of Storage (Page 2): ${storageTotal.toStringAsFixed(3)} Kg\n\n"
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

    final success = await _api.saveInward(inwardData);

    setState(() {
      _isLoading = false;
      _isSaving = false;
      if (success) {
        // No-op for now unless we need to track local save state
      }
    });

    if (!mounted) return;

    if (success) {
      // Directly ask to share after success instead of showing sticker dialog automatically
      _askToShare(inwardData);
    } else {
      _showError("Failed to Save. Check if all required fields are filled.");
    }
  }

  void _showPrintStickerDialog(Map<String, dynamic> inwardData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Saved Successfully"),
        content: const Text(
          "Do you want to print stickers for the received rolls?",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Ask for WhatsApp share after declining print
              _askToShare(inwardData);
            },
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _printStickers(inwardData);
            },
            child: const Text("Print Stickers"),
          ),
        ],
      ),
    );
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
                  child: SizedBox(
                    width: double.infinity,
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
                        Navigator.pop(ctx); // Close the modal after "printing"
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
                        backgroundColor: const Color(0xFF0EA5E9),
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

  void _navigateToStickerPage() {
    final diasWithRolls = _getDiasWithRolls().toList();

    if (diasWithRolls.isEmpty) {
      _showError('Please enter at least one DIA with ROLLS first');
      return;
    }

    final pendingDias = diasWithRolls
        .where((d) => !_completedStickerDias.contains(d))
        .toList();

    // If no pending, allow navigating to the first one for editing
    final nextDia = pendingDias.isNotEmpty
        ? pendingDias.first
        : diasWithRolls.first;

    setState(() {
      _selectedStickerDia = nextDia;
      _stickerData.putIfAbsent(nextDia, () => StickerDiaData());
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
                ? 'Lot Inward Entry'
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
            child: _buildTableInput(row.rolls, (v) {
              row.rolls = int.tryParse(v) ?? 0;
              row.sets = (row.rolls / 11).round();
              _updateRowMath(row);
            }, key: ValueKey('rolls_${row.rolls}')),
          ),
          // SETS
          _buildTableCell(
            width: 80,
            child: _buildTableInput(row.sets, (v) {
              row.sets = int.tryParse(v) ?? 0;
              _updateRowMath(row);
            }, key: ValueKey('sets_${row.sets}')),
          ),
          // DELIV. WT
          _buildTableCell(
            width: 100,
            child: _buildTableInput(row.deliveredWeight, (v) {
              row.deliveredWeight = double.tryParse(v) ?? 0;
              _updateRowMath(row);
            }),
          ),
          // REC. ROLL
          _buildTableCell(
            width: 100,
            child: Text(
              '${row.recRoll}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          // REC. WT
          _buildTableCell(
            width: 100,
            child: _buildTableInput(row.recWeight, (v) {
              row.recWeight = double.tryParse(v) ?? 0;
              _updateRowMath(row);
            }),
          ),
          // RATE
          _buildTableCell(
            width: 80,
            child: _buildTableInput(row.rate, (v) {
              row.rate = double.tryParse(v) ?? 0;
            }),
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
                    onPressed: () => setState(() => _rows.removeAt(idx)),
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
      height: 48,
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

  Widget _buildTableInput(num val, Function(String) chg, {Key? key}) {
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
        initialValue: val == 0 ? '' : val.toString(),
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
                    backgroundColor: const Color(0xFF0EA5E9),
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
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSmallDropdown(
                              r.colour,
                              _colours,
                              (v) => setState(() => r.colour = v),
                              hint: "Colour",
                              itemImages: _colourImages,
                            ),
                          ),
                          if (r.colour != null &&
                              _colourImages.containsKey(r.colour))
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => Dialog(
                                      child: Image.network(
                                        _colourImages[r.colour]!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    image: DecorationImage(
                                      image: NetworkImage(
                                        _colourImages[r.colour]!,
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    ...List.generate(sets, (i) {
                      if (r.setWeights.length <= i) r.setWeights.add('');
                      return _buildGridCell(
                        "",
                        100,
                        child: _buildTableInputText(
                          r.setWeights[i],
                          (v) => setState(() => r.setWeights[i] = v),
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
                  foregroundColor: const Color(0xFF0EA5E9),
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

  Widget _buildTableInputText(String val, Function(String) chg) {
    return TextFormField(
      initialValue: val,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
      ],
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        hintText: '-',
        border: InputBorder.none,
        isDense: true,
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
            ),
            _buildSigBox(
              "Authorized",
              _authorizedSignature,
              (f) => setState(() => _authorizedSignature = f),
            ),
            _buildSigBox(
              "MD",
              _mdSignature,
              (f) => setState(() => _mdSignature = f),
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

  Widget _buildSigBox(String label, XFile? file, Function(XFile?) onPick) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _openSignaturePad(onPick),
          child: Container(
            width: 90,
            height: 50,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
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
          setState(() => _rows.add(InwardRow()..rate = defaultRate));
        },
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          "Add Row",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        style: TextButton.styleFrom(foregroundColor: const Color(0xFF0EA5E9)),
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
              backgroundColor: const Color(0xFF0EA5E9),
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
              _isSaving ? "Saving..." : "Save Entry",
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
        for (var sRow in diaData.rows) {
          totalRecWeight += sRow.totalWeight;
        }
        mainRow.recWeight = totalRecWeight;
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
        // Ensure the sticker data structure exists for the new DIA
        if (!_stickerData.containsKey(_selectedStickerDia)) {
          _stickerData[_selectedStickerDia!] = StickerDiaData();
        }
        // Stay on sticker page (assuming logic elsewhere renders sticker page based on some state,
        // usually _currentPage needs to be 1 for sticker page if checking screens, but based on code flow it seems we are already there.
        // If `_buildStickerPage` is shown when `_currentPage == 1`.
        // The previous code set `_currentPage = 0`, so I should only do that if NO remaining.
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
  String? dia;
  int rolls = 0;
  int sets = 0;
  double deliveredWeight = 0;
  int recRoll = 0;
  double recWeight = 0;
  double rate = 0;
  double difference = 0;
  double lossPercent = 0;

  // New Getter for Value
  double get value => rate * recWeight;
}

class StickerRow {
  String? colour;
  List<String> setWeights = [];

  double get totalWeight {
    final sum = setWeights.fold(0.0, (sum, w) {
      final val = double.tryParse(w.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      return sum + val;
    });
    return double.parse(sum.toStringAsFixed(3));
  }
}

class StickerDiaData {
  List<String?> racks = [];
  List<String?> pallets = [];
  List<StickerRow> rows = [StickerRow()];
}
