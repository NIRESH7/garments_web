import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/app_drawer.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import './task_detail_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants/api_constants.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
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
  
  bool _isListening = false;
  bool _isRecording = false;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _recordedPath;
  String _voiceLocale = 'en_US'; // 'en_US' or 'ta_IN'

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _priority = 'Medium';
  String _assignedTo = 'All';
  DateTime? _deadline;

  List<dynamic> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recorder.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        await _tts.speak("Tell me, I am listening");
        String path = '';
        if (!kIsWeb) {
          final dir = await getTemporaryDirectory();
          path = '${dir.path}/task_desc_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }
        
        await _recorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _recordedPath = null;
        });
        
        // Also start speech to text
        _listen();
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      if (_isListening) _listen(); // stop STT
      
      setState(() {
        _isRecording = false;
        _recordedPath = path;
      });
    } catch (e) {
      debugPrint('Error stopping record: $e');
    }
  }

  void _playLocalRecording() async {
    if (_recordedPath != null) {
      await _audioPlayer.play(DeviceFileSource(_recordedPath!));
    }
  }

  void _playRemoteAudio(String url) async {
    final fullUrl = ApiConstants.getImageUrl(url);
    await _audioPlayer.play(UrlSource(fullUrl));
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final tasks = await _api.getTasks();
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _stt.initialize();
      if (available) {
        setState(() => _isListening = true);
        _stt.listen(
          onResult: (val) {
            setState(() {
              _descController.text = val.recognizedWords;
            });
          },
          localeId: _voiceLocale,
        );
      }
    } else {
      setState(() => _isListening = false);
      _stt.stop();
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
                    const Icon(LucideIcons.checkCircle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Voice description recorded',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
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
                        _voiceLocale = _voiceLocale == 'en_US' ? 'ta_IN' : 'en_US';
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(right: 4, top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _voiceLocale == 'ta_IN' ? Colors.orange.shade100 : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _voiceLocale == 'ta_IN' ? 'TA' : 'EN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _voiceLocale == 'ta_IN' ? Colors.orange.shade900 : Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_recordedPath != null)
                          IconButton(
                            icon: const Icon(LucideIcons.playCircle, color: Colors.green),
                            onPressed: _playLocalRecording,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        IconButton(
                          icon: Icon(
                            _isRecording ? LucideIcons.mic : LucideIcons.micOff,
                            color: _isRecording ? Colors.red : primaryColor,
                          ),
                          onPressed: _isRecording ? _stopRecording : _startRecording,
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
                    value: _assignedTo,
                    decoration: const InputDecoration(
                      labelText: 'Assign To',
                      border: OutlineInputBorder(),
                    ),
                    items: ['All', 'Tailoring', 'Packing', 'Cutting']
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (val) => setState(() => _assignedTo = val!),
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
                   if (task['voiceDescriptionUrl'] != null && task['voiceDescriptionUrl'].toString().isNotEmpty)
                    IconButton(
                      icon: const Icon(LucideIcons.volume2, color: Colors.blue, size: 20),
                      onPressed: () => _playRemoteAudio(task['voiceDescriptionUrl']),
                      tooltip: 'Listen to description',
                    ),
                  IconButton(
                    icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Task'),
                          content: const Text('Are you sure you want to delete this task?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                final success = await _api.deleteTask(task['_id']);
                                if (success) {
                                  _loadTasks();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Task deleted successfully')),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Failed to delete task'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
