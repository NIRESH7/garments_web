import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/app_drawer.dart';
import '../../core/storage/storage_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import './task_detail_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants/api_constants.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AdminTaskManagementScreen extends StatefulWidget {
  const AdminTaskManagementScreen({super.key});

  @override
  State<AdminTaskManagementScreen> createState() =>
      _AdminTaskManagementScreenState();
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
  bool _isLoading = false;
  bool _isSaving = false;
  String? _recordedPath;
  String _voiceLocale = 'en_US'; // 'en_US' or 'ta_IN'
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

  Future<void> _loadAssignOptions() async {
    final saved = await _storage.getAssignmentOptions();
    if (saved != null && saved.isNotEmpty) {
      setState(() => _assignOptions = saved);
      if (!_assignOptions.contains(_assignedTo)) {
        _assignedTo = _assignOptions.first;
      }
    }
  }

  Future<void> _showManageAssignmentsDialog() async {
    final newController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Manage Assignments'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newController,
                          decoration: const InputDecoration(
                            hintText: 'New Assignment Name',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.blue),
                        onPressed: () async {
                          final name = newController.text.trim();
                          if (name.isNotEmpty && !_assignOptions.contains(name)) {
                            setState(() {
                              _assignOptions.add(name);
                            });
                            setDialogState(() {});
                            newController.clear();
                            await _storage.saveAssignmentOptions(_assignOptions);
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _assignOptions.length,
                      itemBuilder: (context, idx) {
                        final opt = _assignOptions[idx];
                        // User wants delete option for EVERYTHING
                        return ListTile(
                          title: Text(opt),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              setState(() {
                                _assignOptions.removeAt(idx);
                                if (_assignedTo == opt) {
                                  _assignedTo = _assignOptions.isNotEmpty ? _assignOptions.first : 'All';
                                }
                                if (_assignOptions.isEmpty) {
                                  _assignOptions.add('All');
                                  _assignedTo = 'All';
                                }
                              });
                              setDialogState(() {});
                              await _storage.saveAssignmentOptions(_assignOptions);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
    setState(() {}); // Refresh main screen dropdown items
  }

  @override
  void dispose() {
    _stt.stop();
    _audioPlayer.dispose();
    _recorder.dispose();
    _tts.stop();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _initVoice() async {
    _speechReady = await _stt.initialize(
      onStatus: (status) {
        final listening = status.toLowerCase().contains('listening');
        if (mounted && _isListening != listening) {
          setState(() => _isListening = listening);
        }
      },
      onError: (error) {
        if (mounted) setState(() => _isListening = false);
        debugPrint('Speech error: ${error.errorMsg}');
      },
    );
  }

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  String _transcribeLang() => _voiceLocale.startsWith('ta') ? 'ta' : 'en';

  Future<void> _transcribeAndFillDescription(String audioPath) async {
    setState(() => _isTranscribing = true);
    try {
      final transcribed = await _api.transcribeAudioFile(
        audioPath,
        language: _transcribeLang(),
      );
      if (transcribed != null && transcribed.trim().isNotEmpty) {
        setState(() {
          _descController.text = transcribed.trim();
          _descController.selection = TextSelection.fromPosition(
            TextPosition(offset: _descController.text.length),
          );
        });
      } else {
        _showMsg(
          'Voice to text failed on server. Check live OPENAI_API_KEY and /api/ai/transcribe.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _showMsg('Microphone permission is required', error: true);
        return;
      }

      await _tts.stop();
      // Do not speak prompt here; it can conflict with iOS listen session.

      String path = '';
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        path =
            '${dir.path}/task_desc_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      await _recorder.start(const RecordConfig(), path: path);

      setState(() {
        _isRecording = true;
        _recordedPath = null;
      });

      // Do not start live STT while recording; rely on server transcription for final text.
    } catch (e) {
      debugPrint('Error starting record: $e');
      _showMsg('Failed to start recording', error: true);
    }
  }

  Future<void> _stopRecording() async {
    try {
      String? path;
      if (_isRecording) {
        path = await _recorder.stop();
      }
      if (_isListening) {
        await _listen(stopOnly: true);
      }

      setState(() {
        _isRecording = false;
        if (path != null && path.isNotEmpty) _recordedPath = path;
      });

      // Guaranteed fallback: transcribe recorded audio and auto-fill description.
      if (path != null && path.isNotEmpty) {
        await _transcribeAndFillDescription(path);
      }
    } catch (e) {
      debugPrint('Error stopping record: $e');
      _showMsg('Failed to stop voice recording', error: true);
    }
  }

  void _playLocalRecording() async {
    if (_recordedPath != null) {
      try {
        await _transcribeAndFillDescription(_recordedPath!);
        await _audioPlayer.play(DeviceFileSource(_recordedPath!));
      } catch (e) {
        _showMsg('Unable to play local recording', error: true);
      }
    }
  }

  void _playRemoteAudio(String url) async {
    try {
      final fullUrl = ApiConstants.getImageUrl(url);
      await _audioPlayer.play(UrlSource(fullUrl));
    } catch (e) {
      _showMsg('Unable to play voice description', error: true);
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final tasks = await _api.getTasks();
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  Future<void> _listen({bool startOnly = false, bool stopOnly = false}) async {
    try {
      if (stopOnly) {
        await _stt.stop();
        if (mounted) setState(() => _isListening = false);
        return;
      }

      if (!_speechReady) {
        _speechReady = await _stt.initialize();
      }
      if (!_speechReady) return;

      if (!_isListening) {
        await _stt.stop();
        setState(() => _isListening = true);
        await _stt.listen(
          localeId: _voiceLocale,
          partialResults: true,
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 4),
          cancelOnError: true,
          onResult: (val) {
            final recognized = val.recognizedWords.trim();
            if (recognized.isEmpty) return;
            setState(() {
              _descController.text = recognized;
              _descController.selection = TextSelection.fromPosition(
                TextPosition(offset: _descController.text.length),
              );
            });
          },
        );
        return;
      }

      if (!startOnly) {
        await _stt.stop();
        if (mounted) setState(() => _isListening = false);
      }
    } catch (e) {
      debugPrint('Speech listen failed: $e');
      if (mounted) setState(() => _isListening = false);
    }
  }

  Future<void> _createTask() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final data = {
      'title': _titleController.text,
      'description': _descController.text,
      'priority': _priority,
      'assignedTo': _assignedTo,
      'deadline': _deadline?.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (_recordedPath != null) {
      final voiceUrl = await _api.uploadAudio(_recordedPath!);
      if (voiceUrl != null) {
        data['voiceDescriptionUrl'] = voiceUrl;
      } else {
        _showMsg(
          'Voice upload failed; task will be saved without audio.',
          error: true,
        );
      }
    }

    final result = await _api.createTask(data);
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task Created Successfully')),
      );
      _titleController.clear();
      _descController.clear();
      setState(() => _recordedPath = null);
      _loadTasks();
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('TASK MANAGEMENT (ADMIN)')),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTaskForm(primaryColor),
                  const SizedBox(height: 30),
                  const Text(
                    'RECENT TASKS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  _buildTaskList(),
                ],
              ),
            ),
    );
  }

  Widget _buildTaskForm(Color primaryColor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_recordedPath != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.checkCircle,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Voice description recorded',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Task Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Task Description',
                border: const OutlineInputBorder(),
                suffixIcon: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Language toggle
                    GestureDetector(
                      onTap: () => setState(() {
                        _voiceLocale = _voiceLocale == 'en_US'
                            ? 'ta_IN'
                            : 'en_US';
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(right: 4, top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _voiceLocale == 'ta_IN'
                              ? Colors.orange.shade100
                              : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _voiceLocale == 'ta_IN' ? 'TA' : 'EN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _voiceLocale == 'ta_IN'
                                ? Colors.orange.shade900
                                : Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isTranscribing)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        if (_recordedPath != null)
                          IconButton(
                            icon: const Icon(
                              LucideIcons.playCircle,
                              color: Colors.green,
                            ),
                            onPressed: _playLocalRecording,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        IconButton(
                          icon: Icon(
                            (_isRecording || _isListening)
                                ? LucideIcons.stopCircle
                                : LucideIcons.mic,
                            color: (_isRecording || _isListening)
                                ? Colors.red
                                : primaryColor,
                          ),
                          onPressed: (_isRecording || _isListening)
                              ? _stopRecording
                              : _startRecording,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Low', 'Medium', 'High']
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (val) => setState(() => _priority = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _assignOptions.contains(_assignedTo) ? _assignedTo : _assignOptions.first,
                    decoration: const InputDecoration(
                      labelText: 'Assign To',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ..._assignOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))),
                      const DropdownMenuItem(
                        value: 'ADD_NEW',
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline, color: Colors.blue, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Add New Assignment',
                              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == 'ADD_NEW') {
                        _showManageAssignmentsDialog();
                      } else {
                        setState(() => _assignedTo = val!);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSaving ? null : _createTask,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'CREATE & ASSIGN TASK',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        final priorityColor = task['priority'] == 'High'
            ? Colors.red
            : (task['priority'] == 'Medium' ? Colors.orange : Colors.green);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              debugPrint('DEBUG: Tapped on task ${task['_id']}');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskDetailScreen(task: task),
                ),
              ).then((_) => _loadTasks());
            },
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: priorityColor,
                child: const Icon(
                  LucideIcons.listTodo,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                task['title'] ?? 'No Title',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Assigned: ${task['assignedTo']} | Status: ${task['status']}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (task['voiceDescriptionUrl'] != null &&
                      task['voiceDescriptionUrl'].toString().isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        LucideIcons.volume2,
                        color: Colors.blue,
                        size: 20,
                      ),
                      onPressed: () =>
                          _playRemoteAudio(task['voiceDescriptionUrl']),
                      tooltip: 'Listen to description',
                    ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.trash2,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Task'),
                          content: const Text(
                            'Are you sure you want to delete this task?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                final success = await _api.deleteTask(
                                  task['_id'],
                                );
                                if (success) {
                                  _loadTasks();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Task deleted successfully',
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to delete task'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    tooltip: 'Delete Task',
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
