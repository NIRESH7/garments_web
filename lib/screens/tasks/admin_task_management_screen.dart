import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/mobile_api_service.dart';
import '../../core/storage/storage_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import './task_detail_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants/api_constants.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/theme/color_palette.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/layout_constants.dart';

class AdminTaskManagementScreen extends StatefulWidget {
  const AdminTaskManagementScreen({super.key});

  @override
  State<AdminTaskManagementScreen> createState() => _AdminTaskManagementScreenState();
}

class _AdminTaskManagementScreenState extends State<AdminTaskManagementScreen> {
  final _api = MobileApiService();
  final _stt = stt.SpeechToText();
  final _audioPlayer = AudioPlayer();
  final _recorder = AudioRecorder();
  final _tts = FlutterTts();
  final _storage = StorageService();

  bool _isListening = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _recordedPath;
  String _voiceLocale = 'en_US'; 
  bool _speechReady = false;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _priority = 'Medium';
  String _assignedTo = 'All';
  List<String> _assignOptions = ['All', 'Tailoring', 'Packing', 'Cutting'];
  DateTime? _deadline;

  List<dynamic> _tasks = [];

  @override
  void initState() {
    super.initState();
    _initVoice();
    _loadAssignOptions();
    _loadTasks();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recorder.dispose();
    _tts.stop();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _initVoice() async {
    try {
      _speechReady = await _stt.initialize(
        onStatus: (status) {
          if (mounted) setState(() => _isListening = status.contains('listening'));
        },
        onError: (e) => debugPrint('STT Error: $e'),
      );
    } catch (e) {
      debugPrint('STT Init failed');
    }
  }

  Future<void> _loadAssignOptions() async {
    final saved = await _storage.getAssignmentOptions();
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _assignOptions = saved;
        if (!_assignOptions.contains(_assignedTo)) _assignedTo = _assignOptions.first;
      });
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await _api.getTasks();
      if (mounted) {
        setState(() {
          _tasks = tasks ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMsg('Please enter a task title', error: true);
      return;
    }

    setState(() => _isSaving = true);
    final data = {
      'title': title,
      'description': _descController.text.trim(),
      'priority': _priority,
      'assignedTo': _assignedTo,
      'deadline': _deadline?.toIso8601String(),
      'status': 'Pending',
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (_recordedPath != null) {
      final voiceUrl = await _api.uploadAudio(_recordedPath!);
      if (voiceUrl != null) data['voiceDescriptionUrl'] = voiceUrl;
    }

    try {
      final result = await _api.createTask(data);
      if (result != null) {
        _showMsg('Task Created & Assigned Successfully');
        _titleController.clear();
        _descController.clear();
        setState(() => _recordedPath = null);
        _loadTasks();
      }
    } catch (e) {
      _showMsg('Failed to create task', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMsg(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? ColorPalette.error : ColorPalette.success));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: Padding(padding: EdgeInsets.all(100), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF475569))));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(),
                const SizedBox(height: 48),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 1000) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: _buildTaskFormUI()),
                          const SizedBox(width: 48),
                          Expanded(flex: 6, child: _buildTasksListUI()),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildTaskFormUI(),
                          const SizedBox(height: 64),
                          _buildTasksListUI(),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MISSION CONTROL',
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 2),
        ),
        const SizedBox(height: 4),
        Text(
          'Operational Workflows',
          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -0.5),
        ),
      ],
    );
  }

  Widget _buildTaskFormUI() {
    return _formContainer(
      title: 'NEW WORK ASSIGNMENT',
      children: [
        _buildIndustrialInput('TASK IDENTIFIER / TITLE', _titleController, LucideIcons.type),
        const SizedBox(height: 24),
        _buildIndustrialInput('DESCRIPTION & TECHNICAL SPECS', _descController, LucideIcons.alignLeft, maxLines: 4),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildIndustrialDropdown('PRIORITY', ['Low', 'Medium', 'High'], _priority, (v) => setState(() => _priority = v!)),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildIndustrialDropdown('ASSIGNMENT GROUP', _assignOptions, _assignedTo, (v) => setState(() => _assignedTo = v!)),
            ),
          ],
        ),
        const SizedBox(height: 32),
        if (_recordedPath != null)
          _voiceAttachmentIndicator(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _toggleRecording,
                icon: Icon(_isRecording ? LucideIcons.stopCircle : LucideIcons.mic, size: 16),
                label: Text(_isRecording ? 'STOP RECORDING' : 'ATTACH VOICE PROTOCOL', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  foregroundColor: _isRecording ? const Color(0xFFEF4444) : const Color(0xFF475569),
                  side: BorderSide(color: _isRecording ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 60,
              height: 60,
              child: OutlinedButton(
                onPressed: _showManageAssignmentsDialog,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Icon(LucideIcons.settings, size: 18, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _createTask,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF475569),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('DISPATCH WORKFLOW', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
          ),
        ),
      ],
    );
  }

  Widget _formContainer({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 12, color: const Color(0xFF475569)),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 32),
          ...children,
        ],
      ),
    );
  }

  Widget _buildIndustrialInput(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 14, color: const Color(0xFF475569)),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
      ],
    );
  }

  Widget _buildIndustrialDropdown(String label, List<String> items, String value, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)))).toList(),
              onChanged: onChanged,
              isExpanded: true,
              icon: const Icon(LucideIcons.chevronDown, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _voiceAttachmentIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.mic, size: 14, color: Color(0xFF059669)),
          const SizedBox(width: 12),
          Text('VOICE INSTRUCTION ATTACHED', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF059669), letterSpacing: 0.5)),
          const Spacer(),
          InkWell(onTap: () => setState(() => _recordedPath = null), child: const Icon(LucideIcons.x, size: 14, color: Color(0xFF059669))),
        ],
      ),
    );
  }

  Widget _buildTasksListUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ACTIVE FLOWS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Container(height: 2, width: 24, color: const Color(0xFF475569)),
              ],
            ),
            IconButton(onPressed: _loadTasks, icon: const Icon(LucideIcons.refreshCw, size: 16, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 32),
        if (_tasks.isEmpty)
          _buildEmptyState()
        else
          ..._tasks.map((task) => _buildTaskRegistryCard(task)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(64),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.layers, size: 32, color: const Color(0xFF94A3B8).withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('NO ACTIVE REGISTRIES', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildTaskRegistryCard(dynamic task) {
    final status = (task['status'] ?? 'Pending').toString().toUpperCase();
    final bool isCompleted = status == 'COMPLETED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TaskDetailScreen(task: task))).then((_) => _loadTasks()),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (task['title'] ?? 'UNTITLED').toString().toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('ASSIGNED:', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFF64748B))),
                        const SizedBox(width: 4),
                        Text(task['assignedTo']?.toString().toUpperCase() ?? 'N/A', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              _buildStatusBadge(status),
              const SizedBox(width: 16),
              if (task['voiceDescriptionUrl'] != null)
                IconButton(icon: const Icon(LucideIcons.volume2, size: 16, color: Color(0xFF475569)), onPressed: () => _playRemoteAudio(task['voiceDescriptionUrl'])),
              IconButton(icon: const Icon(LucideIcons.trash2, size: 16, color: Color(0xFFCBD5E1)), onPressed: () => _confirmDelete(task)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    bool isDone = status == 'COMPLETED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
        border: Border.all(color: isDone ? const Color(0xFFD1FAE5) : const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(status, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: isDone ? const Color(0xFF059669) : const Color(0xFF64748B))),
    );
  }

  void _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        if (path != null) _recordedPath = path;
      });
      if (path != null) _transcribe(path);
    } else {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/task_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _transcribe(String path) async {
    setState(() => _isTranscribing = true);
    try {
      final result = await _api.transcribeAudioFile(path);
      if (mounted && result != null && result.trim().isNotEmpty) {
        setState(() => _descController.text = result);
      }
    } catch (_) {}
    finally { if (mounted) setState(() => _isTranscribing = false); }
  }

  void _playRemoteAudio(String url) async {
    await _audioPlayer.play(UrlSource(ApiConstants.getImageUrl(url)));
  }

  Future<void> _showManageAssignmentsDialog() async {
    final tc = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('MANAGE ASSIGNMENTS', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: _buildTextInput('New name...', controller: tc)),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(LucideIcons.plus, color: ColorPalette.primary), onPressed: () async {
            final n = tc.text.trim();
            if (n.isNotEmpty && !_assignOptions.contains(n)) {
              setState(() => _assignOptions.add(n));
              tc.clear();
              await _storage.saveAssignmentOptions(_assignOptions);
              Navigator.pop(ctx);
            }
          })
        ]),
        const SizedBox(height: 24),
        ..._assignOptions.map((opt) => ListTile(title: Text(opt), trailing: IconButton(icon: const Icon(LucideIcons.trash2, size: 16), onPressed: () async {
          setState(() {
            _assignOptions.remove(opt);
            if (_assignOptions.isEmpty) _assignOptions.add('All');
          });
          await _storage.saveAssignmentOptions(_assignOptions);
          Navigator.pop(ctx);
        }))),
      ])),
    ));
    setState(() {});
  }

  void _confirmDelete(dynamic task) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text('DELETE TASK', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      content: const Text('Are you sure you want to remove this workflow step?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
        TextButton(onPressed: () async {
          Navigator.pop(c);
          if (await _api.deleteTask(task['_id'])) _loadTasks();
        }, child: const Text('DELETE', style: TextStyle(color: ColorPalette.error))),
      ],
    ));
  }

  Widget _buildTextInput(String hint, {required TextEditingController controller}) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      ),
    );
  }
}
