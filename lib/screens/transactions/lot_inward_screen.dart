import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';

import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/custom_dropdown_field.dart';

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

  /// Per–DIA storage & sticker details
  Map<String, StickerDiaData> _stickerData = {};

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

  @override
  void initState() {
    super.initState();
    _inTime = DateFormat('hh:mm a').format(DateTime.now());
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoading = true);
    final categories = await _api.getCategories();
    final parties = await _api.getParties();
    final inwardNo = await _api.generateInwardNumber();

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
    });
  }

  List<String> _getValues(List<dynamic> categories, dynamic nameOrNames) {
    try {
      final List<String> names = nameOrNames is List<String>
          ? nameOrNames
          : [nameOrNames.toString()];
      final cat = categories.firstWhere(
        (c) => names.any(
          (n) => c['name'].toString().toLowerCase() == n.toLowerCase(),
        ),
      );
      return List<String>.from(cat['values'] ?? []);
    } catch (e) {
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
    });

    if (val != null) {
      final fetchedColours = await _api.getColoursByLot(val);
      setState(() {
        if (fetchedColours.isNotEmpty) {
          // Combine lot-specific colors with master colors
          final List<String> combined = List<String>.from(
            fetchedColours.map((c) => c.toString()),
          );
          for (var mc in _masterColours) {
            if (!combined.contains(mc)) {
              combined.add(mc);
            }
          }
          _colours = combined;
        } else {
          _colours = List<String>.from(_masterColours);
        }
      });
    }
  }

  void _updateRowMath(InwardRow row) {
    setState(() {
      // row.sets is no longer auto-calculated here if user overrides,
      // but we can set a default if it's 0. For now, let's leave it manual or loose coupling.
      if (row.rolls > 0 && row.sets == 0) {
        row.sets = (row.rolls / 11).ceil();
      }
      row.recRoll = row.rolls;
      row.difference = row.recWeight - row.deliveredWeight;
      if (row.deliveredWeight > 0) {
        // Loss is positive when we receive less than delivered
        row.lossPercent =
            ((row.deliveredWeight - row.recWeight) / row.deliveredWeight) * 100;
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

  Future<void> _pickColorFromImage(StickerRow row) async {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Detect Colour from Image',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: ColorPalette.primary,
              ),
              title: const Text('Pick from Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 50,
                  maxWidth: 800,
                );
                if (image != null) _detectAndSetColor(image, row);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: ColorPalette.primary,
              ),
              title: const Text('Take a Photo'),
              onTap: () async {
                Navigator.pop(ctx);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 50,
                  maxWidth: 800,
                );
                if (image != null) _detectAndSetColor(image, row);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _detectAndSetColor(XFile image, StickerRow row) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Detecting colour...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'AI is analyzing the image',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Read and encode image
      final bytes = await File(image.path).readAsBytes();
      final base64Str = base64Encode(bytes);

      // Call API with existing colors so AI prefers matching them
      final result = await _api.detectColorFromImage(
        base64Str,
        existingColors: _colours,
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      if (result != null && result['colorName'] != null) {
        final colorName = result['colorName'] as String;

        // Try to find exact match in existing list (case-insensitive)
        final matchedExisting = _colours.firstWhere(
          (c) => c.toLowerCase() == colorName.toLowerCase(),
          orElse: () => '',
        );

        final bool exists = matchedExisting.isNotEmpty;
        // Use the exact string from the list for dropdown matching
        final String finalColor = exists ? matchedExisting : colorName;

        if (!exists) {
          // Add to master colours via API
          try {
            final categories = await _api.getCategories();
            var coloursCat = categories.firstWhere(
              (c) => (c['name'] as String).toLowerCase() == 'colours',
              orElse: () => null,
            );

            if (coloursCat != null) {
              final categoryId = coloursCat['_id'] as String;
              await _api.addCategoryValue(categoryId, colorName);
            }
          } catch (_) {}

          // Update local list
          setState(() {
            _colours.add(colorName);
            _masterColours.add(colorName);
          });
        }

        // Set the colour on the row (using exact matched string)
        setState(() => row.colour = finalColor);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _hexToColor(
                      result['hexColor'] as String? ?? '#888888',
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    exists
                        ? 'Matched: $finalColor'
                        : 'New colour added: $finalColor',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: exists
                ? ColorPalette.primary
                : const Color(0xFF10B981),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        _showError('Could not detect colour. Try again with a clearer image.');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        _showError('Error detecting colour: ${e.toString()}');
      }
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
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
    String msg = "*Lot Inward Entry*\n";
    msg += "Date: ${data['inwardDate']}\n";
    msg += "Lot: ${data['lotName']} / ${data['lotNo']}\n";
    msg += "Party: ${data['fromParty']}\n";
    msg += "Quality: ${data['qualityStatus']}\n";
    if (data['complaintText'] != null && data['complaintText'].isNotEmpty) {
      msg += "Complaint: ${data['complaintText']}\n";
    }

    final url = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showError("Could not launch WhatsApp");
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _outTime = DateFormat('hh:mm a').format(DateTime.now());
      _isLoading = true;
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
      "vehicleNo": _vehicleController.text,
      "partyDcNo": _dcController.text,
      "diaEntries": _rows
          .where((r) => r.dia != null)
          .map(
            (r) => {
              "dia": r.dia ?? "",
              "roll": r.rolls,
              "set": r.sets,
              "delWt": r.deliveredWeight,
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
              "racks": e.value.racks.where((r) => r != null).toList(),
              "pallets": e.value.pallets.where((p) => p != null).toList(),
              "rows": e.value.rows
                  .where((r) => r.colour != null)
                  .map((r) => {"colour": r.colour, "setWeights": r.setWeights})
                  .toList(),
            },
          )
          .toList(),
    };

    // Upload Images First
    // Upload Images First
    // String? balanceImgPath;
    String? qualityImgPath;
    String? complaintImgPath;

    // if (_balanceImage != null) balanceImgPath = await _api.uploadFile(_balanceImage!.path);
    if (_qualityImage != null)
      qualityImgPath = await _api.uploadFile(_qualityImage!.path);
    if (_complaintImage != null)
      complaintImgPath = await _api.uploadFile(_complaintImage!.path);

    // inwardData["balanceImage"] = balanceImgPath;
    inwardData["qualityStatus"] = _qualityStatus;
    inwardData["qualityImage"] = qualityImgPath;
    inwardData["complaintText"] = _complaintController.text;
    inwardData["complaintImage"] = complaintImgPath;

    final success = await _api.saveInward(inwardData);

    setState(() {
      _isLoading = false;
      if (success) {
        // No-op for now unless we need to track local save state
      }
    });

    if (!mounted) return;

    if (success) {
      // Prompt to Share
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Saved Successfully"),
          content: const Text("Do you want to share details on WhatsApp?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _shareToWhatsApp(inwardData);
                Navigator.pop(context);
              },
              child: const Text("Share"),
            ),
          ],
        ),
      );
    } else {
      _showError("Failed to Save. Check if all required fields are filled.");
    }
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
        appBar: AppBar(
          leading: IconButton(
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
        _buildComplaintSection(),
        const SizedBox(height: 16),
        _buildGridHeader(),
        _buildDataTable(),
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
                    controller: _rateController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: "Rate",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                    keyboardType: TextInputType.number,
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
    return Column(
      children: _rows.asMap().entries.map((entry) {
        final idx = entry.key;
        final row = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with number and delete
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ColorPalette.primary.withOpacity(0.06),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: ColorPalette.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      row.dia != null ? 'DIA: ${row.dia}' : 'DIA Entry',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (_rows.length > 1)
                      InkWell(
                        onTap: () => setState(() => _rows.removeAt(idx)),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Row 1: DIA, Roll, Sets
                    Row(
                      children: [
                        Expanded(
                          child: _buildCardField(
                            'DIA',
                            child: _buildSmallDropdown(
                              row.dia,
                              _dias,
                              (v) => setState(() => row.dia = v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCardInput('Roll', row.rolls, (v) {
                            row.rolls = int.tryParse(v) ?? 0;
                            _updateRowMath(row);
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCardInput('Sets', row.sets, (v) {
                            row.sets = int.tryParse(v) ?? 0;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row 2: Deliv. Wt, Rec. Wt, Rate
                    Row(
                      children: [
                        Expanded(
                          child: _buildCardInput(
                            'Deliv. Wt',
                            row.deliveredWeight,
                            (v) {
                              row.deliveredWeight = double.tryParse(v) ?? 0;
                              _updateRowMath(row);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCardInput('Rec. Wt', row.recWeight, (v) {
                            row.recWeight = double.tryParse(v) ?? 0;
                            _updateRowMath(row);
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCardInput('Rate', row.rate, (v) {
                            row.rate = double.tryParse(v) ?? 0;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row 3: Calculated values as info chips
                    Row(
                      children: [
                        _buildInfoChip(
                          'Rec Roll',
                          '${row.recRoll}',
                          Colors.blue,
                        ),
                        const SizedBox(width: 6),
                        _buildInfoChip(
                          'Diff',
                          row.difference.toStringAsFixed(2),
                          row.difference != 0 ? Colors.orange : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        _buildInfoChip(
                          'Loss',
                          '${row.lossPercent.toStringAsFixed(1)}%',
                          row.lossPercent > 0 ? Colors.red : Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCardField(String label, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _buildCardInput(String label, num val, Function(String) chg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextFormField(
            initialValue: val == 0 ? '' : val.toString(),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: Colors.grey),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: chg,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
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
        const SizedBox(height: 4),
        _buildDropdown(
          "Select DIA for Stickers",
          _selectedStickerDia,
          enteredDias,
          (v) => setState(() {
            _selectedStickerDia = v;
            if (v != null) {
              _stickerData.putIfAbsent(v, () => StickerDiaData());
            }
          }),
        ),
        const SizedBox(height: 16),
        if (_selectedStickerDia != null) ...[
          _buildStorageDropdowns(),
          const SizedBox(height: 16),
          if (setsCount > 0)
            _buildDynamicSetTable(setsCount)
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
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 45,
          child: ElevatedButton.icon(
            onPressed: _saveStorageForCurrentDia,
            icon: const Icon(Icons.save),
            label: const Text("Save Storage for DIA"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStorageDropdowns() {
    if (_selectedStickerDia == null) return const SizedBox.shrink();
    final diaData =
        _stickerData[_selectedStickerDia!] ?? StickerDiaData(); // safety
    _stickerData[_selectedStickerDia!] = diaData;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Text(
            "Rack & Pallet (Required)",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: ColorPalette.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildSmallDropdown(
                    diaData.racks[i],
                    _rackNames,
                    (v) => setState(() => diaData.racks[i] = v),
                    hint: "Rack ${i + 1}",
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildSmallDropdown(
                    diaData.pallets[i],
                    _palletNos,
                    (v) => setState(() => diaData.pallets[i] = v),
                    hint: "Pallet ${i + 1}",
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicSetTable(int sets) {
    final dia = _selectedStickerDia!;
    final diaData =
        _stickerData[dia] ?? StickerDiaData(); // ensure entry exists
    if (!_stickerData.containsKey(dia)) {
      _stickerData[dia] = diaData;
    }
    final rows = diaData.rows;

    return Column(
      children: [
        ...rows.asMap().entries.map((e) {
          final idx = e.key;
          final r = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: ColorPalette.primary.withOpacity(0.06),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: ColorPalette.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Colour & Set Weights',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      if (rows.length > 1)
                        InkWell(
                          onTap: () => setState(() => rows.removeAt(idx)),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Colour selector with camera
                      Text(
                        'COLOUR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSmallDropdown(
                              r.colour,
                              _colours,
                              (v) => setState(() => r.colour = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _pickColorFromImage(r),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    ColorPalette.primary.withOpacity(0.15),
                                    ColorPalette.primary.withOpacity(0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: ColorPalette.primary.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.camera_alt,
                                    size: 16,
                                    color: ColorPalette.primary,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'AI',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: ColorPalette.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Set weights in grid
                      Text(
                        'SET WEIGHTS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(sets, (i) {
                          if (r.setWeights.length <= i) r.setWeights.add('');
                          return SizedBox(
                            width: (MediaQuery.of(context).size.width - 80) / 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Set ${i + 1}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: TextFormField(
                                    initialValue: r.setWeights[i],
                                    onChanged: (v) => r.setWeights[i] = v,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '0',
                                      hintStyle: TextStyle(color: Colors.grey),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        // Add row button
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: OutlinedButton.icon(
            onPressed: () => setState(() => rows.add(StickerRow())),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Add Colour Row'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ColorPalette.primary,
              side: BorderSide(color: ColorPalette.primary.withOpacity(0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
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
  }) => CustomDropdownField(
    label: "", // No label for small dropdown in grid
    value: val,
    items: items,
    onChanged: chg,
    hint: hint,
  );
  Widget _buildGridHeader() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        "DIA-wise Entry",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      OutlinedButton.icon(
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
        icon: const Icon(Icons.add_circle_outline, size: 18),
        label: const Text("Add DIA"),
        style: OutlinedButton.styleFrom(
          foregroundColor: ColorPalette.primary,
          side: BorderSide(color: ColorPalette.primary.withOpacity(0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          height: 45,
          child: ElevatedButton(
            onPressed: _navigateToStickerPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(
              pending.isEmpty
                  ? "Manage Storage Details"
                  : "Next: Storage for DIA ${pending.first}",
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 45,
          child: ElevatedButton.icon(
            onPressed: allDone ? _save : null,
            icon: const Icon(Icons.save),
            label: const Text("Save Entry"),
            style: ElevatedButton.styleFrom(
              backgroundColor: allDone ? Colors.green : Colors.grey.shade300,
              foregroundColor: allDone ? Colors.white : Colors.grey,
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
      _selectedStickerDia = null;
      _currentPage = 0; // back to main page
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

  Widget _buildQualitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Quality Check",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: RadioListTile(
                    title: const Text("OK", style: TextStyle(fontSize: 12)),
                    value: "OK",
                    groupValue: _qualityStatus,
                    onChanged: (v) =>
                        setState(() => _qualityStatus = v.toString()),
                  ),
                ),
                Expanded(
                  child: RadioListTile(
                    title: const Text("Not OK", style: TextStyle(fontSize: 12)),
                    value: "Not OK",
                    groupValue: _qualityStatus,
                    onChanged: (v) =>
                        setState(() => _qualityStatus = v.toString()),
                  ),
                ),
              ],
            ),
            _buildImageSection(
              "Quality Image",
              _qualityImage,
              (f) => _qualityImage = f,
            ),
          ],
        ),
      ),
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
}

class StickerRow {
  String? colour;
  List<String> setWeights = [];
}

class StickerDiaData {
  List<String?> racks = [null, null, null];
  List<String?> pallets = [null, null, null];
  List<StickerRow> rows = [StickerRow()];
}
