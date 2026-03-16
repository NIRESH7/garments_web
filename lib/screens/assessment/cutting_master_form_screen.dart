import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/api_constants.dart';
import '../../widgets/custom_dropdown_field.dart';
import '../../services/lot_allocation_print_service.dart';

class CuttingMasterFormScreen extends StatefulWidget {
  final String? entryId;
  const CuttingMasterFormScreen({super.key, this.entryId});

  @override
  State<CuttingMasterFormScreen> createState() => _CuttingMasterFormScreenState();
}

class _CuttingMasterFormScreenState extends State<CuttingMasterFormScreen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();
  late AudioRecorder _recorder;
  late stt.SpeechToText _speechToText;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isRecording = false;
  String? _recordingPath;

  // ─── Section 1: Item Details ───
  String? _itemName;
  String? _size;
  XFile? _itemImageFile;
  String? _itemImageUrl;
  final _dozenWeightController = TextEditingController();
  final _wastePctController = TextEditingController(); // used for auto-calc
  final _layPcsController = TextEditingController();

  // ─── Section 2: Lot Details ───
  String? _lotName;
  String? _knittingDia;
  String? _knittingDiaSpecific;
  String? _cuttingDia; // auto-filled
  final _efficiencyController = TextEditingController();
  final _lotWastePctController = TextEditingController(); // auto-filled
  final _foldingController = TextEditingController();
  final _layLengthController = TextEditingController();

  // ─── Section 3: Pattern Details ───
  List<PatternRowData> _patterns = [];

  // ─── Section 4: CAD File ───
  PlatformFile? _cadFile;
  String? _cadFileUrl;

  // ─── Section 5: Instructions ───
  XFile? _instructionAudioFile;
  String? _instructionAudioUrl;
  final _instructionTextController = TextEditingController();
  PlatformFile? _instructionDocFile;
  String? _instructionDocUrl;
  bool _isListening = false;
  bool _isSpeechInitialized = false;


  // Dropdown lists
  List<String> _itemList = [];
  List<String> _sizeList = [];
  List<String> _lotList = [];
  List<Map<String, dynamic>> _diaObjects = []; 
  List<String> _diaNames = [];
  List<String> _partyList = [];

  final _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _speechToText = stt.SpeechToText();
    _loadDropdowns();
    if (widget.entryId != null) {
      _loadEntryDetails();
    } else {
      _addPatternRow();
    }

    _wastePctController.addListener(_updateEfficiencyPctSection1);
    _efficiencyController.addListener(_updateWastePctSection2);
  }

  @override
  void dispose() {
    _recorder.dispose();
    _dozenWeightController.dispose();
    _wastePctController.removeListener(_updateEfficiencyPctSection1);
    _wastePctController.dispose();
    _layPcsController.dispose();
    _efficiencyController.removeListener(_updateWastePctSection2);
    _efficiencyController.dispose();
    _lotWastePctController.dispose();
    _foldingController.dispose();
    _layLengthController.dispose();
    _instructionTextController.dispose();
    _audioPlayer.dispose();
    for (var p in _patterns) {
      p.frontController.dispose();
      p.backController.dispose();
      p.finishingController.dispose();
    }
    super.dispose();
  }

  void _updateEfficiencyPctSection1() {
    setState(() {}); // trigger rebuild to show 100 - waste
  }

  void _updateWastePctSection2() {
    final eff = double.tryParse(_efficiencyController.text) ?? 0;
    _lotWastePctController.text = (100 - eff).toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _loadDropdowns() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _api.getCategories();
      final lots = await _api.getLots();
      final parties = await _api.getParties();

      for (var cat in categories) {
        final name = (cat['name'] ?? '').toString().toLowerCase().trim();
        final rawVals = cat['values'] as List? ?? [];
        final vals = rawVals.map((v) => v is Map ? v : {'name': v.toString()}).toList();

        if (name == 'item name' || name == 'item') {
          _itemList = vals.map((v) => v['name'].toString()).toList();
        } else if (name == 'size') {
          _sizeList = vals.map((v) => v['name'].toString()).toList();
        } else if (name == 'dia') {
          _diaObjects = vals.cast<Map<String, dynamic>>();
          _diaNames = _diaObjects.map((v) => v['name'].toString()).toList();
        } else if (name == 'party name') {
          final catParties = vals.map((v) => v['name'].toString()).toList();
          _partyList.addAll(catParties);
        }
      }

      _lotList = lots.map((l) => l['lotNumber'].toString()).toList();
      _partyList.addAll(parties.map((p) => p['name'].toString()).toList());
      _partyList = _partyList.toSet().toList(); // unique

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEntryDetails() async {
    final data = await _api.getCuttingMasterById(widget.entryId!);
    if (data != null) {
      setState(() {
        _itemName = data['itemName'];
        _size = data['size'];
        _itemImageUrl = data['itemImage'];
        _dozenWeightController.text = (data['dozenWeight'] ?? 0).toString();
        _wastePctController.text = (100 - (data['efficiencyPct'] ?? 100)).toString();
        _layPcsController.text = (data['layPcs'] ?? 0).toString();

        _lotName = data['lotName'];
        _itemName = data['diaName'] ?? data['knittingDia']; 
        _knittingDiaSpecific = data['knittingDia'];
        _knittingDia = data['knittingDia']; 
        _cuttingDia = data['cuttingDia'];
        _efficiencyController.text = (data['efficiency'] ?? 0).toString();
        _lotWastePctController.text = (data['wastePercentage'] ?? 0).toString();
        _foldingController.text = (data['folding'] ?? 0).toString();
        _layLengthController.text = (data['layLengthMeter'] ?? 0).toString();

        final pats = data['patternDetails'] as List? ?? [];
        _patterns = pats.map((p) => PatternRowData(
          partyName: p['partyName'],
          imageUrl: p['patternImage'],
          frontController: TextEditingController(text: (p['frontMeasurement'] ?? '').toString()),
          backController: TextEditingController(text: (p['backMeasurement'] ?? '').toString()),
          finishingController: TextEditingController(text: (p['finishingMeasurement'] ?? '').toString()),
        )).toList();

        _cadFileUrl = data['cadFile'];
        _instructionAudioUrl = data['instructionAudio'];
        _instructionTextController.text = data['instructionText'] ?? '';
        _instructionDocUrl = data['instructionDoc'];
      });
    }
  }

  void _addPatternRow() {
    setState(() {
      _patterns.add(PatternRowData(
        frontController: TextEditingController(),
        backController: TextEditingController(),
        finishingController: TextEditingController(),
      ));
    });
  }

  Future<void> _pickImage(bool isItem, {int? patternIndex}) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() {
        if (isItem) {
          _itemImageFile = img;
        } else if (patternIndex != null) {
          _patterns[patternIndex].imageFile = img;
        }
      });
    }
  }

  Future<void> _pickFile(bool isCad) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        if (isCad) {
          _cadFile = result.files.first;
        } else {
          _instructionDocFile = result.files.first;
        }
      });
    }
  }

  Future<void> _playAudio(String? url, XFile? local) async {
    if (local != null) {
      await _audioPlayer.play(DeviceFileSource(local.path));
    } else if (url != null && url.isNotEmpty) {
      await _audioPlayer.play(UrlSource(ApiConstants.getImageUrl(url)));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> data = {
        'itemName': _itemName,
        'size': _size,
        'dozenWeight': _dozenWeightController.text,
        'layPcs': _layPcsController.text,
        'lotName': _lotName,
        'diaName': _itemName,
        'knittingDia': _knittingDiaSpecific ?? '',
        'cuttingDia': _cuttingDia,
        'efficiency': _efficiencyController.text,
        'wastePercentage': _lotWastePctController.text,
        'folding': _foldingController.text,
        'layLengthMeter': _layLengthController.text,
        'instructionText': _instructionTextController.text,
      };

      if (_itemImageFile != null) data['itemImage'] = _itemImageFile;
      if (_cadFile?.path != null) data['cadFile'] = XFile(_cadFile!.path!);
      if (_instructionAudioFile != null) data['instructionAudio'] = _instructionAudioFile;
      if (_instructionDocFile?.path != null) data['instructionDoc'] = XFile(_instructionDocFile!.path!);

      final List<Map<String, String>> patternRows = [];
      for (int i = 0; i < _patterns.length; i++) {
        final p = _patterns[i];
        patternRows.add({
          'partyName': p.partyName ?? '',
          'frontMeasurement': p.frontController.text,
          'backMeasurement': p.backController.text,
          'finishingMeasurement': p.finishingController.text,
          'patternImage': p.imageUrl ?? '',
        });
        if (p.imageFile != null) {
          data['patternImage_$i'] = p.imageFile;
        }
      }
      data['patternDetails'] = patternRows;

      final resultData = widget.entryId == null
          ? await _api.createCuttingMaster(data)
          : await _api.updateCuttingMaster(widget.entryId!, data);

      if (mounted && resultData != null) {
        _showSuccessDialog(resultData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessDialog(Map<String, dynamic> entry) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 16),
            Text('Saved Successfully'),
          ],
        ),
        content: const Text('Cutting master entry has been saved. What would you like to do next?', textAlign: TextAlign.center),
        actions: [
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton(Icons.share, 'Share', Colors.green, () => _shareEntry(entry)),
                  _actionButton(Icons.print, 'Print', Colors.purple, () => _printEntry(entry)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context, true); // Go back to list
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to List'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  void _shareEntry(Map<String, dynamic> entry) {
    final summary = "Cutting Master: ${entry['itemName']}\nLot: ${entry['lotName']}\nSize: ${entry['size']}\nInstructions: ${entry['instructionText'] ?? 'N/A'}";
    Share.share(summary);
  }

  void _printEntry(Map<String, dynamic> entry) {
    final printService = LotAllocationPrintService();
    printService.printCuttingMasterDetail(entry);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final waste1 = double.tryParse(_wastePctController.text) ?? 0;
    final eff1 = (100 - waste1).toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entryId == null ? 'New Cutting Master' : 'Edit Cutting Master'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildSection(
                title: 'Item Details',
                icon: Icons.info_outline,
                children: [
                  CustomDropdownField(
                    label: 'Item Name',
                    items: _itemList,
                    value: _itemName,
                    onChanged: (v) => setState(() => _itemName = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  CustomDropdownField(
                    label: 'Size',
                    items: _sizeList,
                    value: _size,
                    onChanged: (v) => setState(() => _size = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildImagePreview('Item Image', _itemImageFile, _itemImageUrl, () => _pickImage(true)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dozenWeightController,
                    decoration: const InputDecoration(labelText: 'Dozen Weight', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _wastePctController,
                    decoration: const InputDecoration(labelText: 'Waste Percentage (%)', border: OutlineInputBorder(), hintText: 'Enter waste to calc efficiency'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Efficiency Percentage:', style: TextStyle(fontWeight: FontWeight.bold))),
                        Text('$eff1%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _layPcsController,
                    decoration: const InputDecoration(labelText: 'Lay Pieces', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Lot Details',
                icon: Icons.layers_outlined,
                children: [
                  CustomDropdownField(
                    label: 'Lot Name',
                    items: _lotList,
                    value: _lotName,
                    onChanged: (v) => setState(() => _lotName = v),
                  ),
                  const SizedBox(height: 16),
                  CustomDropdownField(
                    label: 'Dia',
                    items: _diaNames,
                    value: _knittingDia,
                    onChanged: (v) {
                      setState(() {
                        _itemName = v; // Using _itemName as the Dia Name anchor
                        _knittingDia = null;
                        _cuttingDia = null;
                        _knittingDiaSpecific = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_itemName != null)
                    CustomDropdownField(
                      label: 'Knitting Dia',
                      items: _diaObjects
                          .where((d) => d['name'] == _itemName)
                          .map((d) => d['knittingDia']?.toString() ?? '')
                          .where((s) => s.isNotEmpty)
                          .toList(),
                      value: _knittingDiaSpecific,
                      onChanged: (v) {
                        final diaObj = _diaObjects.firstWhere(
                          (d) => d['name'] == _itemName && d['knittingDia']?.toString() == v,
                          orElse: () => {},
                        );
                        setState(() {
                          _knittingDiaSpecific = v;
                          _knittingDia = v; // legacy field fallback
                          _cuttingDia = diaObj['cuttingDia']?.toString();
                        });
                      },
                    ),
                  if (_knittingDiaSpecific != null) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _cuttingDia,
                      key: Key('cutting_dia_$_cuttingDia'),
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Cutting Dia (Auto)', fillColor: Color(0xFFF5F5F5), filled: true, border: OutlineInputBorder()),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _foldingController,
                    decoration: const InputDecoration(labelText: 'Folding', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _layLengthController,
                    decoration: const InputDecoration(labelText: 'Lay Length in Meter', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Pattern Details',
                icon: Icons.design_services_outlined,
                children: [
                  ..._patterns.asMap().entries.map((entry) => _buildPatternRow(entry.key, entry.value)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addPatternRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Row'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'CAD File Upload',
                icon: Icons.upload_file_outlined,
                children: [
                  _buildFilePicker('CAD File', _cadFile, _cadFileUrl, () => _pickFile(true)),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Instructions',
                icon: Icons.record_voice_over_outlined,
                children: [
                   _buildInstructionRecordingSection(),
                  const SizedBox(height: 24),
                  _buildFilePicker('Instruction Document', _instructionDocFile, _instructionDocUrl, () => _pickFile(false)),
                ],
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Cutting Master', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = p.join(dir.path, 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await _recorder.start(const RecordConfig(), path: path);
        
        setState(() {
          _isRecording = true;
          _instructionAudioFile = null;
        });

        // Optional: Start speech to text
        await _startListening();
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      await _stopListening();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        setState(() {
          _instructionAudioFile = XFile(path);
        });
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _startListening() async {
    if (!_isSpeechInitialized) {
      _isSpeechInitialized = await _speechToText.initialize();
    }
    if (_isSpeechInitialized) {
      setState(() => _isListening = true);
      _speechToText.listen(
        onResult: (val) => setState(() {
          _instructionTextController.text = val.recognizedWords;
        }),
      );
    }
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  Widget _buildInstructionRecordingSection() {
    bool hasAudio = _instructionAudioFile != null || (_instructionAudioUrl != null && _instructionAudioUrl!.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Voice Instruction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ColorPalette.textPrimary)),
            if (hasAudio)
              IconButton(
                icon: const Icon(Icons.play_circle_fill, color: Colors.green, size: 32),
                onPressed: () => _playAudio(_instructionAudioUrl, _instructionAudioFile),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _isRecording ? Colors.red.shade200 : Colors.grey.shade200),
          ),
          child: Column(
            children: [
              if (_isRecording)
                const Column(
                  children: [
                    LinearProgressIndicator(color: Colors.red, backgroundColor: Colors.white),
                    SizedBox(height: 8),
                    Text('Recording...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: Container(
                  height: 60,
                  width: 60,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: _isRecording ? Colors.red : Colors.blue,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isRecording ? 'Tap to Stop' : (hasAudio ? 'Tap to Re-record' : 'Tap to Start Recording'),
                style: TextStyle(color: _isRecording ? Colors.red : Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _instructionTextController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Instruction Text (Auto-converted)',
            hintText: 'Voice will be converted to text here...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required List<Widget> children, IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: ColorPalette.softShadow),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: icon != null ? Icon(icon, color: Colors.blue) : null,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(String label, XFile? file, String? url, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColorPalette.textPrimary)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12), color: Colors.grey.shade50),
            child: file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb 
                        ? Image.network(file.path, fit: BoxFit.cover)
                        : Image.file(File(file.path), fit: BoxFit.cover),
                  )
                : (url != null && url.isNotEmpty)
                    ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(ApiConstants.getImageUrl(url), fit: BoxFit.cover))
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 40, color: Colors.grey), SizedBox(height: 8), Text('Tap to upload image', style: TextStyle(color: Colors.grey, fontSize: 12))]),
          ),
        ),
      ],
    );
  }

  Widget _buildPatternRow(int index, PatternRowData data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade100), borderRadius: BorderRadius.circular(12), color: Colors.grey.shade50.withOpacity(0.5)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pattern Detail Row ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20), onPressed: () => setState(() => _patterns.removeAt(index))),
            ],
          ),
          CustomDropdownField(
            label: 'Party Name',
            items: _partyList,
            value: data.partyName,
            onChanged: (v) => setState(() => data.partyName = v),
          ),
          const SizedBox(height: 12),
          _buildImagePreview('Pattern Image', data.imageFile, data.imageUrl, () => _pickImage(false, patternIndex: index)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextFormField(controller: data.frontController, decoration: const InputDecoration(labelText: 'Front (Mea)', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: data.backController, decoration: const InputDecoration(labelText: 'Back (Mea)', border: OutlineInputBorder()))),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(controller: data.finishingController, decoration: const InputDecoration(labelText: 'Finishing Measurement', border: OutlineInputBorder())),
        ],
      ),
    );
  }

  Widget _buildFilePicker(String label, PlatformFile? file, String? url, VoidCallback onTap) {
    String? name = file?.name ?? (url != null && url.isNotEmpty ? url.split('/').last : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ListTile(
          shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
          tileColor: Colors.grey.shade50,
          leading: const Icon(Icons.insert_drive_file_outlined, color: Colors.orange),
          title: Text(name ?? 'No file selected', style: TextStyle(color: name == null ? Colors.grey : Colors.black, fontSize: 13)),
          trailing: OutlinedButton(onPressed: onTap, style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Pick File', style: TextStyle(fontSize: 12))),
        ),
      ],
    );
  }
}

class PatternRowData {
  String? partyName;
  XFile? imageFile;
  String? imageUrl;
  final TextEditingController frontController;
  final TextEditingController backController;
  final TextEditingController finishingController;

  PatternRowData({
    this.partyName,
    this.imageFile,
    this.imageUrl,
    required this.frontController,
    required this.backController,
    required this.finishingController,
  });
}
