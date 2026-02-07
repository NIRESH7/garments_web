import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/color_palette.dart';
import '../../services/api_service.dart';

// Implementation of Niresh (1).docx Requirements
// Integrated with FastAPI Backend.

class LotInwardScreen extends StatefulWidget {
  const LotInwardScreen({super.key});

  @override
  State<LotInwardScreen> createState() => _LotInwardScreenState();
}

class _LotInwardScreenState extends State<LotInwardScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  // --- 1. Header Logic ---
  final DateTime _inwardDate = DateTime.now(); 
  late String _inTime; 
  String? _outTime; 
  
  String? _selectedLotName;
  final _lotNumberController = TextEditingController();
  String? _selectedParty;
  String _process = ""; 
  final _vehicleController = TextEditingController();
  final _dcController = TextEditingController(); 

  // --- 2. Main Grid State ---
  List<InwardRow> _rows = [InwardRow()];

  // --- 3. Navigation & Sticker State ---
  int _currentPage = 0; 
  String? _selectedStickerDia; 
  
  // Storage per requirements: 3 dropdowns for Rack, 3 for Pallet
  List<String?> _selectedRacks = [null, null, null];
  List<String?> _selectedPallets = [null, null, null];
  
  Map<String, List<StickerRow>> _stickerData = {};

  // Master Data Mock/Load
  List<String> _dias = [];
  List<String> _colours = [];
  List<String> _lotNames = [];
  List<String> _parties = [];
  List<String> _rackNames = []; 
  List<String> _palletNos = [];
  
  bool _isSaved = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _inTime = DateFormat('hh:mm a').format(DateTime.now());
    _loadMasterData();
  }
  
  Future<void> _loadMasterData() async {
    setState(() => _isLoading = true);
    final data = await _api.getMasterData();
    setState(() {
      _isLoading = false;
      if (data.isNotEmpty) {
        _lotNames = data['lots'] ?? [];
        _parties = data['parties'] ?? [];
        _dias = data['dias'] ?? [];
        _colours = data['colours'] ?? [];
        _rackNames = data['racks'] ?? [];
        _palletNos = data['pallets'] ?? [];
      } else {
        // Fallback for demo if API fails/empty
        _lotNames = ['Lot Alpha', 'Lot Beta'];
        _parties = ['Client A', 'Client B'];
        _dias = ['30', '32', '34', '36'];
        _colours = ['Red', 'Blue', 'Black'];
        _rackNames = ['R-1', 'R-2', 'R-3'];
        _palletNos = ['P-1', 'P-2', 'P-3'];
      }
    });
  }

  void _onPartyChanged(String? val) {
    setState(() {
      _selectedParty = val;
      _process = "Auto-fetched Process"; 
    });
  }

  Future<void> _onLotNameChanged(String? val) async {
    setState(() {
      _selectedLotName = val;
      _colours = []; // Clear existing colours
    });
    
    if (val != null) {
      final fetchedColours = await _api.getColoursByLot(val);
      setState(() {
        _colours = fetchedColours;
      });
    } else {
       // Reset or keep empty
    }
  }

  // --- Calculations (Requirement Strict) ---
  void _updateRowMath(InwardRow row) {
    setState(() {
      // SET RULE: (ROLL / 11). If decimal >= .5, Round UP. If < .5, Round DOWN.
      if (row.rolls > 0) {
        row.sets = (row.rolls / 11).round();
      } else {
        row.sets = 0;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _outTime = DateFormat('hh:mm a').format(DateTime.now()); // Out Time on save
      _isLoading = true;
    });

    // Construct Payload
    final inwardData = {
      "inward_date": DateFormat('yyyy-MM-dd').format(_inwardDate),
      "in_time": _inTime,
      "out_time": _outTime,
      "lot_name": _selectedLotName,
      "lot_number": _lotNumberController.text,
      "party_name": _selectedParty,
      "process": _process,
      "vehicle_no": _vehicleController.text,
      "dc_number": _dcController.text,
      "sticker_dia": _selectedStickerDia,
      "racks": _selectedRacks,
      "pallets": _selectedPallets,
      "grid_rows": _rows.map((r) => {
        "dia": r.dia ?? "",
        "rolls": r.rolls,
        "sets": r.sets,
        "delivered_weight": r.deliveredWeight,
        "rec_roll": r.recRoll,
        "rec_weight": r.recWeight,
        "difference": r.difference,
        "loss_percent": r.lossPercent
      }).toList(),
      "sticker_rows": _selectedStickerDia != null && _stickerData.containsKey(_selectedStickerDia) 
        ? _stickerData[_selectedStickerDia]!.map((r) => {
            "colour": r.colour,
            "set_weights": r.setWeights
          }).toList() 
        : []
    };

    final success = await _api.saveInward(inwardData);

    setState(() {
      _isLoading = false;
      if (success) _isSaved = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? "Inward Saved to Backend!" : "Failed to Save (Ensure Backend is Running)"),
        backgroundColor: success ? Colors.green : Colors.red,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lot Inward Entry', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_currentPage == 0)
            IconButton(
              icon: const Icon(Icons.print),
              color: _isSaved ? Colors.blue : Colors.grey,
              onPressed: _isSaved ? () {} : null, 
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: _currentPage == 0 ? _buildMainPage() : _buildStickerPage(),
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
                Expanded(child: _buildReadOnly("Inward Date", DateFormat('dd-MM-yyyy').format(_inwardDate))),
                const SizedBox(width: 8),
                Expanded(child: _buildReadOnly("In Time", _inTime)),
                const SizedBox(width: 8),
                Expanded(child: _buildReadOnly("Out Time", _outTime ?? "--:--")),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDropdown("Lot Name", _selectedLotName, _lotNames, _onLotNameChanged)),
                const SizedBox(width: 8),
                Expanded(child: _buildTextField("Lot No", _lotNumberController)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDropdown("From Party", _selectedParty, _parties, _onPartyChanged)),
                const SizedBox(width: 8),
                Expanded(child: _buildReadOnly("Process", _process)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTextField("Vehicle No", _vehicleController)),
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
          DataColumn(label: Text("DIFF")),
          DataColumn(label: Text("LOSS %")),
          DataColumn(label: Text("")),
        ],
        rows: _rows.asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value;
          return DataRow(cells: [
            DataCell(_buildSmallDropdown(row.dia, _dias, (v) => setState(() => row.dia = v))),
            DataCell(_buildGridInput(row.rolls, (v) {
              row.rolls = int.tryParse(v) ?? 0;
              _updateRowMath(row);
            })),
            DataCell(Text(row.sets.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(_buildGridInput(row.deliveredWeight, (v) {
              row.deliveredWeight = double.tryParse(v) ?? 0;
              _updateRowMath(row);
            })),
            DataCell(Text(row.recRoll.toString())),
            DataCell(_buildGridInput(row.recWeight, (v) {
               row.recWeight = double.tryParse(v) ?? 0;
               _updateRowMath(row);
            })),
            DataCell(Text(row.difference.toStringAsFixed(2))),
            DataCell(Text("${row.lossPercent.toStringAsFixed(2)}%")),
            DataCell(IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setState(() => _rows.removeAt(idx)))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildStickerPage() {
    final enteredDias = _rows.where((r) => r.dia != null).map((r) => r.dia!).toSet().toList();
    int setsCount = 0;
    if (_selectedStickerDia != null) {
      final found = _rows.where((r) => r.dia == _selectedStickerDia);
      if (found.isNotEmpty) setsCount = found.first.sets;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _currentPage = 0)),
            const Text("Sticker & Storage Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        _buildDropdown("Select DIA for Stickers", _selectedStickerDia, enteredDias, (v) => setState(() => _selectedStickerDia = v)),
        const SizedBox(height: 16),
        if (_selectedStickerDia != null) ...[
          _buildStorageDropdowns(),
          const SizedBox(height: 16),
          _buildDynamicSetTable(setsCount),
        ]
      ],
    );
  }

  Widget _buildStorageDropdowns() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text("Rack & Pallet (Select 3 each)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(3, (i) => Expanded(
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _buildSmallDropdown(_selectedRacks[i], _rackNames, (v) => setState(() => _selectedRacks[i] = v))),
              )),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(3, (i) => Expanded(
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _buildSmallDropdown(_selectedPallets[i], _palletNos, (v) => setState(() => _selectedPallets[i] = v))),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicSetTable(int sets) {
    if (!_stickerData.containsKey(_selectedStickerDia!)) _stickerData[_selectedStickerDia!] = [StickerRow()];
    final rows = _stickerData[_selectedStickerDia!]!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        border: TableBorder.all(color: Colors.grey.shade300),
        columns: [
          const DataColumn(label: Text("S.No")),
          const DataColumn(label: Text("Colour")),
          ...List.generate(sets, (i) => DataColumn(label: Text("Set-${i+1}"))),
          const DataColumn(label: Text("")),
        ],
        rows: rows.asMap().entries.map((e) {
          final idx = e.key;
          final r = e.value;
          return DataRow(cells: [
            DataCell(Text("${idx + 1}")),
            DataCell(_buildSmallDropdown(r.colour, _colours, (v) => r.colour = v)),
            ...List.generate(sets, (i) {
              if (r.setWeights.length <= i) r.setWeights.add("");
              return DataCell(SizedBox(width: 60, child: TextFormField(
                initialValue: r.setWeights[i],
                onChanged: (v) => r.setWeights[i] = v,
                decoration: const InputDecoration(isDense: true),
              )));
            }),
             DataCell(IconButton(icon: const Icon(Icons.add, color: Colors.green), onPressed: () => setState(() => rows.add(StickerRow())))),
          ]);
        }).toList(),
      ),
    );
  }

  // --- UI Helpers ---
  Widget _buildReadOnly(String label, String val) => InputDecorator(decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(8)), child: Text(val, style: const TextStyle(fontWeight: FontWeight.bold)));
  Widget _buildTextField(String label, TextEditingController c) => TextFormField(controller: c, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
  Widget _buildDropdown(String label, String? val, List<String> items, Function(String?) chg) => DropdownButtonFormField<String>(value: items.contains(val) ? val : null, items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(), onChanged: chg, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
  Widget _buildSmallDropdown(String? val, List<String> items, Function(String?) chg) => DropdownButton<String>(value: items.contains(val) ? val : null, items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 12)))).toList(), onChanged: chg, underline: const SizedBox(), isExpanded: true, hint: const Text("-"));
  Widget _buildGridInput(num val, Function(String) chg) => TextFormField(initialValue: val == 0 ? "" : val.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, hintText: "0"), onChanged: chg);
  Widget _buildGridHeader() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("DIA-wise Entry", style: TextStyle(fontWeight: FontWeight.bold)), TextButton.icon(onPressed: () => setState(() => _rows.add(InwardRow())), icon: const Icon(Icons.add), label: const Text("Add Row"))]);
  Widget _buildNavigationButtons() => Column(children: [SizedBox(width: double.infinity, height: 45, child: ElevatedButton(onPressed: () => setState(() => _currentPage = 1), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), child: const Text("Next Page (Storage Details)"))), const SizedBox(height: 12), SizedBox(width: double.infinity, height: 45, child: ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text("Save Entry"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)))]);
}

class InwardRow {
  String? dia;
  int rolls = 0;
  int sets = 0;
  double deliveredWeight = 0;
  int recRoll = 0;
  double recWeight = 0;
  double difference = 0;
  double lossPercent = 0;
}

class StickerRow {
  String? colour;
  List<String> setWeights = [];
}