import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:record/record.dart' as record;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../core/constants/api_constants.dart';
import '../../widgets/custom_dropdown_field.dart';

class CuttingMasterFormScreen extends StatefulWidget {
  final String? entryId;
  const CuttingMasterFormScreen({super.key, this.entryId});

  @override
  State<CuttingMasterFormScreen> createState() => _CuttingMasterFormScreenState();
}

class _CuttingMasterFormScreenState extends State<CuttingMasterFormScreen> {
  final _api = MobileApiService();
  final _formKey = GlobalKey<FormState>();

  late record.AudioRecorder _recorder;
  late stt.SpeechToText _speechToText;
  bool _isRecording = false;
  bool _isSpeechInitialized = false;

  bool _isLoading = false;
  bool _isSaving = false;

  // Tab 1: Identity
  String? _itemName;
  String? _size;
  XFile? _itemImageFile;
  String? _itemImageUrl;
  
  // Tab 2: Production Data
  final _dozenWeightController = TextEditingController();
  final _wastePctController = TextEditingController(); 
  final _layPcsController = TextEditingController();
  final _timeToCompleteController = TextEditingController();
  final _meterPerDozenController = TextEditingController();
  final _efficiencyController = TextEditingController();
  final _foldingController = TextEditingController();
  final _layLengthController = TextEditingController();

  // Lot Details (In Identity or Production depending on density)
  String? _lotName;
  String? _selectedDiaName;
  String? _knittingDiaSpecific;
  String? _cuttingDia;

  // Tab 3: Patterns & Instructions
  List<PatternRowData> _patterns = [];
  final _instructionTextController = TextEditingController();
  PlatformFile? _cadFile;
  String? _cadFileUrl;
  XFile? _instructionAudioFile;
  String? _instructionAudioUrl;
  PlatformFile? _instructionDocFile;
  String? _instructionDocUrl;

  // Dropdown lists
  List<String> _itemList = [];
  List<String> _sizeList = [];
  List<String> _lotList = [];
  List<Map<String, dynamic>> _diaObjects = []; 
  List<String> _diaNames = [];
  List<String> _partNameList = [];

  @override
  void initState() {
    super.initState();
    _recorder = record.AudioRecorder();
    _speechToText = stt.SpeechToText();
    _loadDropdowns();
    if (widget.entryId != null) {
      _loadEntryDetails();
    } else {
      _addPatternRow();
    }

    _efficiencyController.addListener(_updateWasteFromEfficiency);
    _wastePctController.addListener(_updateEfficiencyFromWaste);
  }

  bool _isCalculating = false;

  void _updateWasteFromEfficiency() {
    if (_isCalculating) return;
    _isCalculating = true;
    try {
      final eff = double.tryParse(_efficiencyController.text) ?? 0;
      final wasteVal = (100 - eff).toStringAsFixed(2);
      if (_wastePctController.text != wasteVal) {
        _wastePctController.text = wasteVal;
      }
    } finally {
      _isCalculating = false;
    }
  }

  void _updateEfficiencyFromWaste() {
    if (_isCalculating) return;
    _isCalculating = true;
    try {
      final waste = double.tryParse(_wastePctController.text) ?? 0;
      final effVal = (100 - waste).toStringAsFixed(2);
      if (_efficiencyController.text != effVal) {
        _efficiencyController.text = effVal;
      }
    } finally {
      _isCalculating = false;
    }
  }

  @override
  void dispose() {
    _dozenWeightController.dispose();
    _recorder.dispose();
    _wastePctController.removeListener(_updateEfficiencyFromWaste);
    _wastePctController.dispose();
    _layPcsController.dispose();
    _timeToCompleteController.dispose();
    _meterPerDozenController.dispose();
    _efficiencyController.removeListener(_updateWasteFromEfficiency);
    _efficiencyController.dispose();
    _foldingController.dispose();
    _layLengthController.dispose();
    _instructionTextController.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _api.getCategories();
      final lots = await _api.getLots();
      debugPrint('LOAD_DROPDOWNS: Categories count: ${categories.length}');
      debugPrint('LOAD_DROPDOWNS: Lots count: ${lots.length}');
      if (lots.isNotEmpty) debugPrint('LOAD_DROPDOWNS: First lot sample: ${lots.first}');

      if (!mounted) return;

      for (var cat in categories) {
        final name = (cat['name'] ?? '').toString().toLowerCase().trim();
        final rawVals = cat['values'] as List? ?? [];
        final vals = rawVals.map((v) => v is Map ? v : {'name': v.toString()}).toList();

        if (name == 'item name' || name == 'item' || name == 'item_name') {
          _itemList = vals.map((v) => v['name'].toString()).toList();
        } else if (name == 'size') {
          _sizeList = vals.map((v) => v['name'].toString()).toList();
        } else if (name == 'dia') {
          _diaObjects = vals.cast<Map<String, dynamic>>();
          _diaNames = _diaObjects.map((v) => v['name'].toString()).toList();
        } else if (name == 'part name') {
          // STRICT: Only Part names here
          _partNameList = vals.map((v) => v['name'].toString()).toList();
        } else if (name == 'lot name' || name == 'lot') {
          final registryLots = vals.map((v) => v['name'].toString()).toList();
          _lotList.addAll(registryLots);
        }
      }
      
      final masterLots = lots.map((l) => l['lotNumber'].toString()).toList();
      _lotList.addAll(masterLots);
      _lotList = _lotList.toSet().toList(); // Deduplicate

      debugPrint('LOAD_DROPDOWNS: Final Item List: ${_itemList.length}');
      debugPrint('LOAD_DROPDOWNS: Final Lot List: ${_lotList.length}');
      
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEntryDetails() async {
    final data = await _api.getCuttingMasterById(widget.entryId!);
    if (data != null && mounted) {
      setState(() {
        _itemName = data['itemName'];
        _size = data['size'];
        _itemImageUrl = data['itemImage'];
        _dozenWeightController.text = (data['dozenWeight'] ?? '').toString();
        _layPcsController.text = (data['layPcs'] ?? '').toString();
        _lotName = data['lotName'];
        _selectedDiaName = data['diaName']; 
        _knittingDiaSpecific = data['knittingDia']?.toString();
        _cuttingDia = data['cuttingDia']?.toString();
        _efficiencyController.text = (data['efficiency'] ?? '').toString();
        _wastePctController.text = (data['wastePercentage'] ?? '').toString();
        _foldingController.text = (data['folding'] ?? '').toString();
        _layLengthController.text = (data['layLengthMeter'] ?? '').toString();
        _timeToCompleteController.text = data['timeToComplete'] ?? '';
        _meterPerDozenController.text = (data['meterPerDozen'] ?? '').toString();

        _instructionTextController.text = data['instructionText'] ?? '';
        _cadFileUrl = data['cadFile'];
        _instructionAudioUrl = data['instructionAudio'];
        _instructionDocUrl = data['instructionDoc'];

        final pats = data['patternDetails'] as List? ?? [];
        _patterns = pats.map((p) => PatternRowData(
          partName: p['partyName'],
          imageUrl: p['patternImage'],
          ctrlMeasurement: TextEditingController(text: (p['patternMeasurement'] ?? '').toString()),
          ctrlFinishing: TextEditingController(text: (p['finishingMeasurement'] ?? '').toString()),
          ctrlPunches: TextEditingController(text: (p['noOfPunches'] ?? '').toString()),
        )).toList();
      });
    }
  }

  void _addPatternRow() {
    setState(() {
      _patterns.add(PatternRowData(
        ctrlMeasurement: TextEditingController(),
        ctrlFinishing: TextEditingController(),
        ctrlPunches: TextEditingController(),
      ));
    });
  }

  Future<void> _pickImage(bool isItem, {int? patternIndex}) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() {
        if (isItem) _itemImageFile = img;
        else if (patternIndex != null) _patterns[patternIndex].imageFile = img;
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
        'diaName': _selectedDiaName,
        'knittingDia': _knittingDiaSpecific ?? '',
        'cuttingDia': _cuttingDia,
        'efficiency': _efficiencyController.text,
        'wastePercentage': _wastePctController.text,
        'folding': _foldingController.text,
        'layLengthMeter': _layLengthController.text,
        'timeToComplete': _timeToCompleteController.text,
        'meterPerDozen': _meterPerDozenController.text,
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
          'partyName': p.partName ?? '',
          'patternMeasurement': p.ctrlMeasurement.text,
          'finishingMeasurement': p.ctrlFinishing.text,
          'noOfPunches': p.ctrlPunches.text,
          'patternImage': p.imageUrl ?? '',
        });
        if (p.imageFile != null) data['patternImage_$i'] = p.imageFile;
      }
      data['patternDetails'] = patternRows;

      final resultData = widget.entryId == null
          ? await _api.createCuttingMaster(data)
          : await _api.updateCuttingMaster(widget.entryId!, data);

      if (mounted && resultData != null) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cutting Master Synchronized'), backgroundColor: ColorPalette.success));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft, color: Color(0xFF0F172A), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('NEW CUTTING MASTER', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          centerTitle: false,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Center(
                child: TextButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.check, size: 14, color: Colors.white),
                  label: Text('SAVE RECORD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1, color: Colors.white)),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF475569),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            labelColor: const Color(0xFF0F172A),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF0F172A),
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
            tabs: const [
              Tab(text: 'IDENTITY'),
              Tab(text: 'PRODUCTION'),
              Tab(text: 'MEDIA'),
            ],
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Form(
              key: _formKey,
              child: TabBarView(
                children: [
                   _buildContentWrapper(_buildIdentityTab()),
                   _buildContentWrapper(_buildProductionTab()),
                   _buildContentWrapper(_buildMediaTab()),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildContentWrapper(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850),
          child: child,
        ),
      ),
    );
  }

  Widget _buildIdentityTab() {
    return Column(
      children: [
        _formCard(
          title: 'Item Details',
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: CustomDropdownField(
                    label: 'Item',
                    items: _itemList,
                    value: _itemName,
                    onChanged: (v) => setState(() => _itemName = v),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: CustomDropdownField(
                    label: 'Size',
                    items: _sizeList,
                    value: _size,
                    onChanged: (v) => setState(() => _size = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildImagePicker('Item Image', _itemImageFile, _itemImageUrl, () => _pickImage(true)),
          ],
        ),
        const SizedBox(height: 24),
        _formCard(
          title: 'Lot Details',
          children: [
            Row(
              children: [
                Expanded(
                  child: CustomDropdownField(
                    label: 'Lot Name',
                    items: _lotList,
                    value: _lotName,
                    onChanged: (v) => setState(() => _lotName = v),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomDropdownField(
                    label: 'Dia',
                    items: _diaNames,
                    value: _selectedDiaName,
                    onChanged: (v) {
                      setState(() {
                        _selectedDiaName = v;
                        final diaObj = _diaObjects.firstWhere((d) => d['name'] == v, orElse: () => {});
                        _knittingDiaSpecific = diaObj['knittingDia']?.toString();
                        _cuttingDia = diaObj['cuttingDia']?.toString();
                      });
                    },
                  ),
                ),
              ],
            ),
            if (_selectedDiaName != null) ...[
              const SizedBox(height: 24),
              CustomDropdownField(
                label: 'Knitting Dia',
                items: _diaObjects
                    .where((d) => d['name'] == _selectedDiaName)
                    .map((d) => d['knittingDia']?.toString() ?? '')
                    .where((s) => s.isNotEmpty)
                    .toList(),
                value: _knittingDiaSpecific,
                onChanged: (v) {
                   final diaObj = _diaObjects.firstWhere(
                    (d) => d['name'] == _selectedDiaName && d['knittingDia']?.toString() == v,
                    orElse: () => {},
                  );
                  setState(() {
                    _knittingDiaSpecific = v;
                    _cuttingDia = diaObj['cuttingDia']?.toString();
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildReadOnlyDisplay('Cutting Dia (Auto)', _cuttingDia ?? 'N/A'),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildProductionTab() {
    return Column(
      children: [
        _formCard(
          title: 'Weight & Productivity',
          children: [
            Row(
              children: [
                Expanded(child: _buildTextField('Costing Weight', _dozenWeightController, LucideIcons.scale)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField('Folding Weight', _foldingController, LucideIcons.archive)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildTextField('Efficiency (%)', _efficiencyController, LucideIcons.zap)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField('Waste (%)', _wastePctController, LucideIcons.trash2)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        _formCard(
          title: 'Lay & Layout',
          children: [
            Row(
              children: [
                Expanded(child: _buildTextField('Lay Length (M)', _layLengthController, LucideIcons.moveHorizontal)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField('Lay Pcs', _layPcsController, LucideIcons.layers)),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField('Time to Complete', _timeToCompleteController, LucideIcons.clock),
            const SizedBox(height: 20),
            _buildTextField('Meter per Dozen', _meterPerDozenController, LucideIcons.trendingUp),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaTab() {
    return Column(
      children: [
        _formCard(
          title: 'Pattern Details',
          children: [
            ..._patterns.asMap().entries.map((entry) => _buildPatternRow(entry.key, entry.value)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _addPatternRow,
              icon: const Icon(LucideIcons.plus, size: 14),
              label: Text('Add Pattern Detail', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _formCard(
          title: 'Files & Instruction Assets',
          children: [
            _buildFilePicker('CAD/CAM DESIGN FILE', _cadFile, _cadFileUrl, () => _pickFile(true)),
            const SizedBox(height: 32),
            _buildVoiceInstructionSection(),
            const SizedBox(height: 32),
            _buildInstructionTextSection(),
            const SizedBox(height: 32),
            _buildFilePicker('INSTRUCTION DOCUMENT', _instructionDocFile, _instructionDocUrl, () => _pickFile(false)),
          ],
        ),
      ],
    );
  }

  Widget _buildVoiceInstructionSection() {
    bool hasAudio = _instructionAudioFile != null || (_instructionAudioUrl != null && _instructionAudioUrl!.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VOICE INSTRUCTION',
          style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _isRecording ? ColorPalette.error.withOpacity(0.5) : ColorPalette.border),
          ),
          child: Column(
            children: [
              if (hasAudio) ...[
                Row(
                  children: [
                    Icon(LucideIcons.volume2, size: 16, color: ColorPalette.success),
                    const SizedBox(width: 12),
                    Expanded(child: Text('VOICE RECORDING READY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: ColorPalette.success))),
                    TextButton.icon(
                      onPressed: () => _playAudio(_instructionAudioUrl, _instructionAudioFile),
                      icon: const Icon(LucideIcons.play, size: 12),
                      label: Text('PLAYBACK', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _recordingButton(),
                  const SizedBox(width: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isRecording ? 'RECORDING IN PROGRESS...' : 'START VOICE INSTRUCTION',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: _isRecording ? ColorPalette.error : ColorPalette.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isRecording ? 'Tap the stop icon to finish' : 'Tap mic to record audio guidance',
                        style: GoogleFonts.inter(fontSize: 10, color: ColorPalette.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _recordingButton() {
    return InkWell(
      onTap: _isRecording ? _stopRecording : _startRecording,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _isRecording ? ColorPalette.error.withOpacity(0.1) : ColorPalette.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isRecording ? LucideIcons.square : LucideIcons.mic,
          color: _isRecording ? ColorPalette.error : ColorPalette.primary,
          size: 20,
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
     try {
       if (await _recorder.hasPermission()) {
         setState(() => _isRecording = true);
         // In web, path can be null for record to handle internal stream or we can provide a dummy
         await _recorder.start(const record.RecordConfig(), path: ''); 
         _startListening();
       }
     } catch (e) {
       debugPrint('RECORD_ERROR: $e');
     }
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      if (path != null) {
        _instructionAudioFile = XFile(path);
      }
    });
    _speechToText.stop();
  }

  Future<void> _startListening() async {
    if (!_isSpeechInitialized) {
      _isSpeechInitialized = await _speechToText.initialize();
    }
    if (_isSpeechInitialized) {
      _speechToText.listen(onResult: (result) {
        setState(() {
          _instructionTextController.text = result.recognizedWords;
        });
      });
    }
  }

  Future<void> _playAudio(String? url, XFile? file) async {
    final player = audioplayers.AudioPlayer();
    if (file != null) {
      await player.play(audioplayers.DeviceFileSource(file.path));
    } else if (url != null && url.isNotEmpty) {
      await player.play(audioplayers.UrlSource(ApiConstants.getImageUrl(url)));
    }
  }

  Widget _buildInstructionTextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INSTRUCTION TEXT / VOICE TRANSCRIPTION',
          style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _instructionTextController,
          maxLines: 4,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ColorPalette.textPrimary),
          decoration: InputDecoration(
            hintText: 'Type instructions or use voice-to-text...',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: ColorPalette.border)),
          ),
        ),
      ],
    );
  }

  Widget _buildFilePicker(String label, PlatformFile? file, String? url, VoidCallback onTap) {
    String? name = file?.name ?? (url != null && url.isNotEmpty ? url.split('/').last : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: ColorPalette.border),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.fileText, size: 20, color: ColorPalette.primary.withOpacity(0.5)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name ?? 'NO FILE SELECTED',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: name == null ? ColorPalette.textMuted : ColorPalette.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  backgroundColor: ColorPalette.primary.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: Text('PICK FILE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: ColorPalette.primary)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 12, color: ColorPalette.primary),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: ColorPalette.textPrimary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ColorPalette.textPrimary),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 14, color: ColorPalette.primary.withOpacity(0.5)),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: ColorPalette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: ColorPalette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: ColorPalette.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyDisplay(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ColorPalette.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ColorPalette.textMuted)),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: ColorPalette.primary)),
        ],
      ),
    );
  }

  Widget _buildImagePicker(String label, XFile? file, String? url, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: ColorPalette.border, style: BorderStyle.solid),
            ),
            clipBehavior: Clip.antiAlias,
            child: file != null 
              ? Image.network(file.path, fit: BoxFit.contain)
              : (url != null && url.isNotEmpty)
                ? Image.network(ApiConstants.getImageUrl(url), fit: BoxFit.contain)
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.uploadCloud, color: ColorPalette.primary.withOpacity(0.3), size: 40),
                        const SizedBox(height: 16),
                        Text(
                          'SELECT ASSET FILENAME',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: ColorPalette.primary, letterSpacing: 1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Maximum file size: 10MB',
                          style: GoogleFonts.inter(fontSize: 8, color: ColorPalette.textMuted),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatternRow(int index, PatternRowData data) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMicroImage(data.imageFile, data.imageUrl, () => _pickImage(false, patternIndex: index)),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CustomDropdownField(
                            label: 'PART IDENTIFIER', 
                            items: _partNameList, 
                            value: data.partName, 
                            onChanged: (v) => setState(() => data.partName = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => setState(() => _patterns.removeAt(index)), 
                          icon: const Icon(LucideIcons.minusCircle, color: ColorPalette.error, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField('DIMENSION / MEASUREMENT', data.ctrlMeasurement, LucideIcons.ruler),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('FINISHING MEASUREMENT', data.ctrlFinishing, LucideIcons.checkCircle2)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField('PUNCHES', data.ctrlPunches, LucideIcons.hash)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(height: 1, color: ColorPalette.border),
        ],
      ),
    );
  }

  Widget _buildMicroImage(XFile? file, String? url, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: ColorPalette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: file != null 
          ? Image.network(file.path, fit: BoxFit.cover)
          : (url != null && url.isNotEmpty)
            ? Image.network(ApiConstants.getImageUrl(url), fit: BoxFit.cover)
            : Icon(LucideIcons.image, color: ColorPalette.primary.withOpacity(0.2), size: 24),
      ),
    );
  }
}

class PatternRowData {
  String? partName;
  XFile? imageFile;
  String? imageUrl;
  final TextEditingController ctrlMeasurement;
  final TextEditingController ctrlFinishing;
  final TextEditingController ctrlPunches;

  PatternRowData({
    this.partName,
    this.imageFile,
    this.imageUrl,
    required this.ctrlMeasurement,
    required this.ctrlFinishing,
    required this.ctrlPunches,
  });
}
