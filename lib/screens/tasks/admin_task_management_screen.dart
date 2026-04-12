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
    if (_isLoading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRODUCTION TASK ASSIGNMENT',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: ColorPalette.textPrimary,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create and monitor operational workflows for floor teams.',
              style: GoogleFonts.inter(fontSize: 13, color: ColorPalette.textMuted),
            ),
            const SizedBox(height: 48),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildTaskFormUI()),
                      const SizedBox(width: 48),
                      Expanded(flex: 3, child: _buildTasksListUI()),
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
    );
  }

  Widget _buildTaskFormUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('NEW ASSIGNMENT'),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorPalette.border.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _buildFieldLabel('TASK TITLE'),
              _buildTextInput('Enter task name...', controller: _titleController),
              const SizedBox(height: 24),
              _buildFieldLabel('DESCRIPTION & INSTRUCTIONS'),
              _buildTextInput('Describe the work details...', controller: _descController, maxLines: 4),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('PRIORITY'),
                        _buildDropdown(['Low', 'Medium', 'High'], _priority, (v) => setState(() => _priority = v!)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('ASSIGN TO'),
                        _buildDropdown(_assignOptions, _assignedTo, (v) => setState(() => _assignedTo = v!)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (_recordedPath != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: ColorPalette.success.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ColorPalette.success.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.mic, size: 16, color: ColorPalette.success),
                      const SizedBox(width: 12),
                      Text('VOICE INSTRUCTION ATTACHED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: ColorPalette.success)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 14),
                        onPressed: () => setState(() => _recordedPath = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _toggleRecording,
                      icon: Icon(_isRecording ? LucideIcons.stopCircle : LucideIcons.mic, size: 16),
                      label: Text(_isRecording ? 'STOP' : 'RECORD VOICE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        foregroundColor: _isRecording ? ColorPalette.error : ColorPalette.primary,
                        side: BorderSide(color: _isRecording ? ColorPalette.error : ColorPalette.primary.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _showManageAssignmentsDialog,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Icon(LucideIcons.users, size: 18),
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
                    backgroundColor: ColorPalette.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('CREATE & DISPATCH TASK', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 1.2)),
    );
  }

  Widget _buildTextInput(String hint, {required TextEditingController controller, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: ColorPalette.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: ColorPalette.border, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String value, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
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
    );
  }

  Widget _buildTasksListUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('ACTIVE FLOWS'),
        const SizedBox(height: 32),
        if (_tasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(64),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorPalette.border.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(LucideIcons.clipboardList, size: 48, color: ColorPalette.border.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text('NO ACTIVE TASKS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 1)),
              ],
            ),
          )
        else
          ..._tasks.map((task) => _buildTaskCard(task)),
      ],
    );
  }

  Widget _buildTaskCard(dynamic task) {
    final priority = (task['priority'] ?? 'Low').toString().toUpperCase();
    final status = (task['status'] ?? 'Pending').toString().toUpperCase();
    final bool isCompleted = status == 'COMPLETED';

    Color pColor = priority == 'HIGH' ? ColorPalette.error : (priority == 'MEDIUM' ? Colors.orange : ColorPalette.success);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorPalette.border.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TaskDetailScreen(task: task))).then((_) => _loadTasks()),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(width: 4, height: 48, decoration: BoxDecoration(color: pColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (task['title'] ?? 'UNTITLED').toString().toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isCompleted ? ColorPalette.textMuted : ColorPalette.textPrimary,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ASSIGNEE: ${task['assignedTo']?.toString().toUpperCase() ?? 'NONE'}',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: ColorPalette.textMuted, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              _buildStatusIndicator(status),
              const SizedBox(width: 24),
              if (task['voiceDescriptionUrl'] != null)
                IconButton(
                  icon: const Icon(LucideIcons.volume2, size: 18, color: ColorPalette.primary),
                  onPressed: () => _playRemoteAudio(task['voiceDescriptionUrl']),
                ),
              IconButton(
                icon: const Icon(LucideIcons.trash2, size: 18, color: ColorPalette.textMuted),
                onPressed: () => _confirmDelete(task),
              ),
              const Icon(LucideIcons.chevronRight, size: 16, color: ColorPalette.border),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color c = status == 'COMPLETED' ? ColorPalette.success : (status == 'PENDING' ? ColorPalette.textMuted : ColorPalette.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(4), border: Border.all(color: c.withOpacity(0.2))),
      child: Text(status, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: c, letterSpacing: 0.5)),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: ColorPalette.textPrimary, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(height: 2, width: 24, color: ColorPalette.primary),
      ],
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
}
