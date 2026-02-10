import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';

import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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

  List<String?> _selectedRacks = [null, null, null];
  List<String?> _selectedPallets = [null, null, null];

  Map<String, List<StickerRow>> _stickerData = {};

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

    setState(() {
      _isLoading = false;
      _lotNames = _getValues(categories, 'Lot Name');
      _dias = _getValues(categories, 'Dia');
      if (_dias.isEmpty) _dias = _getValues(categories, 'dia');
      _masterColours = _getValues(categories, 'Colours');
      if (_masterColours.isEmpty)
        _masterColours = _getValues(categories, 'Colour');
      _colours = List<String>.from(_masterColours);
      _rackNames = _getValues(categories, 'Rack Name');
      if (_rackNames.isEmpty) _rackNames = _getValues(categories, 'Rack');
      if (_rackNames.isEmpty) _rackNames = _getValues(categories, 'Racks');
      _palletNos = _getValues(categories, 'Pallet No');
      if (_palletNos.isEmpty) _palletNos = _getValues(categories, 'Pallet');
      if (_palletNos.isEmpty) _palletNos = _getValues(categories, 'Pallets');
      _parties = parties.map((m) => m['name'] as String).toList();
    });
  }

  List<String> _getValues(List<dynamic> categories, String name) {
    try {
      final cat = categories.firstWhere(
        (c) =>
            c['name'].toString().toLowerCase() == name.toString().toLowerCase(),
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
          _colours = fetchedColours;
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
              "racks": _selectedRacks.where((r) => r != null).toList(),
              "pallets": _selectedPallets.where((p) => p != null).toList(),
              "rows": e.value
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
    final hasValidDia = _rows.any((r) => r.dia != null && r.dia!.isNotEmpty);
    if (!hasValidDia) {
      _showError('Please select a DIA in the table first');
      return;
    }
    setState(() => _currentPage = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lot Inward Entry',
          style: TextStyle(fontWeight: FontWeight.bold),
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
      bottomNavigationBar: _isLoading ? const LinearProgressIndicator() : null,
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
                  child: DropdownButtonFormField<String>(
                    value: _parties.contains(_selectedParty)
                        ? _selectedParty
                        : null,
                    isExpanded: true,
                    items: _parties
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              p,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _onPartyChanged,
                    decoration: const InputDecoration(
                      labelText: "From Party",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                    validator: (v) => v == null ? 'Required' : null,
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 12,
        border: TableBorder.all(color: Colors.grey.shade300),
        columns: const [
          DataColumn(label: Text("DIA")),
          DataColumn(label: Text("ROLL")),
          DataColumn(label: Text("SETS")),
          DataColumn(label: Text("DELIV. WT")),
          DataColumn(label: Text("REC. ROLL")),
          DataColumn(label: Text("REC. WT")),
          DataColumn(label: Text("RATE")),
          DataColumn(label: Text("DIFF")),
          DataColumn(label: Text("LOSS %")),
          DataColumn(label: Text("")),
        ],
        rows: _rows.asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value;
          return DataRow(
            cells: [
              DataCell(
                _buildSmallDropdown(
                  row.dia,
                  _dias,
                  (v) => setState(() => row.dia = v),
                ),
              ),
              DataCell(
                _buildGridInput(row.rolls, (v) {
                  row.rolls = int.tryParse(v) ?? 0;
                  _updateRowMath(row);
                }),
              ),
              DataCell(
                _buildGridInput(row.sets, (v) {
                  row.sets = int.tryParse(v) ?? 0;
                }),
              ),
              DataCell(
                _buildGridInput(row.deliveredWeight, (v) {
                  row.deliveredWeight = double.tryParse(v) ?? 0;
                  _updateRowMath(row);
                }),
              ),
              DataCell(Text(row.recRoll.toString())),
              DataCell(
                _buildGridInput(row.recWeight, (v) {
                  row.recWeight = double.tryParse(v) ?? 0;
                  _updateRowMath(row);
                }),
              ),
              DataCell(
                _buildGridInput(row.rate, (v) {
                  row.rate = double.tryParse(v) ?? 0;
                }),
              ),
              DataCell(Text(row.difference.toStringAsFixed(2))),
              DataCell(Text("${row.lossPercent.toStringAsFixed(2)}%")),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: () => setState(() => _rows.removeAt(idx)),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStickerPage() {
    final enteredDias = _rows
        .where((r) => r.dia != null)
        .map((r) => r.dia!.trim())
        .toSet()
        .toList();
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
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _currentPage = 0),
            ),
            const Text(
              "Sticker & Storage Details",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          "Select DIA for Stickers",
          _selectedStickerDia,
          enteredDias,
          (v) => setState(() => _selectedStickerDia = v),
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
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text("Save Entry"),
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
                    _selectedRacks[i],
                    _rackNames,
                    (v) => setState(() => _selectedRacks[i] = v),
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
                    _selectedPallets[i],
                    _palletNos,
                    (v) => setState(() => _selectedPallets[i] = v),
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
    if (!_stickerData.containsKey(_selectedStickerDia!))
      _stickerData[_selectedStickerDia!] = [StickerRow()];
    final rows = _stickerData[_selectedStickerDia!]!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        border: TableBorder.all(color: Colors.grey.shade300),
        columns: [
          const DataColumn(label: Text("S.No")),
          const DataColumn(label: Text("Colour")),
          ...List.generate(
            sets,
            (i) => DataColumn(label: Text("Set-${i + 1}")),
          ),
          const DataColumn(label: Text("")),
        ],
        rows: rows.asMap().entries.map((e) {
          final idx = e.key;
          final r = e.value;
          return DataRow(
            cells: [
              DataCell(Text("${idx + 1}")),
              DataCell(
                _buildSmallDropdown(
                  r.colour,
                  _colours,
                  (v) => setState(() => r.colour = v),
                ),
              ),
              ...List.generate(sets, (i) {
                if (r.setWeights.length <= i) r.setWeights.add("");
                return DataCell(
                  SizedBox(
                    width: 60,
                    child: TextFormField(
                      initialValue: r.setWeights[i],
                      onChanged: (v) => r.setWeights[i] = v,
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                );
              }),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.green),
                  onPressed: () => setState(() => rows.add(StickerRow())),
                ),
              ),
            ],
          );
        }).toList(),
      ),
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
  ) => DropdownButtonFormField<String>(
    value: items.contains(val) ? val : null,
    items: items
        .map(
          (i) => DropdownMenuItem(
            value: i,
            child: Text(i, style: const TextStyle(fontSize: 13)),
          ),
        )
        .toList(),
    onChanged: chg,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.all(8),
    ),
  );
  Widget _buildSmallDropdown(
    String? val,
    List<String> items,
    Function(String?) chg, {
    String hint = "-",
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: items.contains(val) ? val : null,
        items: items
            .map(
              (i) => DropdownMenuItem(
                value: i,
                child: Text(i, style: const TextStyle(fontSize: 11)),
              ),
            )
            .toList(),
        onChanged: chg,
        isExpanded: true,
        hint: Text(hint, style: const TextStyle(fontSize: 11)),
      ),
    ),
  );
  Widget _buildGridInput(num val, Function(String) chg) => TextFormField(
    initialValue: val == 0 ? "" : val.toString(),
    keyboardType: TextInputType.number,
    decoration: const InputDecoration(border: InputBorder.none, hintText: "0"),
    onChanged: chg,
  );
  Widget _buildGridHeader() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        "DIA-wise Entry",
        style: TextStyle(fontWeight: FontWeight.bold),
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
        icon: const Icon(Icons.add),
        label: const Text("Add Row"),
      ),
    ],
  );
  Widget _buildNavigationButtons() => Column(
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
          child: const Text("Next Page (Storage Details)"),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        height: 45,
        child: ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text("Save Entry"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    ],
  );

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
