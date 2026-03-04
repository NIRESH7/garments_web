import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/mobile_api_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/theme/color_palette.dart';
import 'package:intl/intl.dart';
import '../../services/task_print_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/api_constants.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class TaskDetailScreen extends StatefulWidget {
  final dynamic task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _api = MobileApiService();
  final _stt = stt.SpeechToText();
  final _recorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final _tts = FlutterTts();

  bool _isListening = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isSaving = false;
  String? _recordedPath;
  String _voiceLocale = 'en_US'; // 'en_US' or 'ta_IN'
  bool _speechReady = false;

  final _workerNameController = TextEditingController();
  final _replyController = TextEditingController();
  String _status = 'In Progress';
  final _printService = TaskPrintService();

  @override
  void initState() {
    super.initState();
    _initVoice();
    _status = widget.task['status'] ?? 'To Do';
  }

  @override
  void dispose() {
    _stt.stop();
    _recorder.dispose();
    _audioPlayer.dispose();
    _tts.stop();
    _workerNameController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _initVoice() async {
    _speechReady = await _stt.initialize();
  }

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  String _transcribeLang() => _voiceLocale.startsWith('ta') ? 'ta' : 'en';

  Future<void> _transcribeAndFillReply(String audioPath) async {
    setState(() => _isTranscribing = true);
    try {
      final transcribed = await _api.transcribeAudioFile(
        audioPath,
        language: _transcribeLang(),
      );
      if (transcribed != null && transcribed.trim().isNotEmpty) {
        setState(() {
          _replyController.text = transcribed.trim();
          _replyController.selection = TextSelection.fromPosition(
            TextPosition(offset: _replyController.text.length),
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
            '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      await _recorder.start(const RecordConfig(), path: path);
      setState(() {
        _isRecording = true;
        _recordedPath = null;
      });

      // Do not start live STT while recording; rely on server transcription for final text.
    } catch (e) {
      debugPrint('Error starting record: $e');
      _showMsg('Failed to start voice recording', error: true);
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

      // Guaranteed fallback: transcribe recorded audio and auto-fill progress details.
      if (path != null && path.isNotEmpty) {
        await _transcribeAndFillReply(path);
      }
    } catch (e) {
      debugPrint('Error stopping record: $e');
      _showMsg('Failed to stop voice recording', error: true);
    }
  }

  void _playLocalRecording() async {
    if (_recordedPath != null) {
      try {
        await _transcribeAndFillReply(_recordedPath!);
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
      _showMsg('Unable to play voice audio', error: true);
    }
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
          onResult: (val) {
            final recognized = val.recognizedWords.trim();
            if (recognized.isEmpty) return;
            setState(() {
              _replyController.text = recognized;
              _replyController.selection = TextSelection.fromPosition(
                TextPosition(offset: _replyController.text.length),
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

  Future<void> _submitReply() async {
    if (_workerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Submission failed: Worker Name is mandatory!'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final data = {
      'workerName': _workerNameController.text,
      'replyText': _replyController.text,
      'status': _status,
    };

    final result = await _api.addTaskReply(
      widget.task['_id'],
      data,
      voicePath: _recordedPath,
    );
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status & Reply Submitted Successfully')),
      );
      Navigator.pop(context);
    }
    setState(() => _isSaving = false);
  }

  Future<void> _shareTask(dynamic task) async {
    final String title = task['title'] ?? 'No Title';
    final String description =
        task['description'] ?? 'No description provided.';
    final String priority = task['priority'] ?? 'N/A';
    final String status = task['status'] ?? 'N/A';
    final String createdAt = task['createdAt'] != null
        ? DateFormat(
            'dd-MM-yyyy hh:mm a',
          ).format(DateTime.parse(task['createdAt'].toString()))
        : 'N/A';

    final sb = StringBuffer();
    sb.writeln("*TASK ASSIGNMENT*");
    sb.writeln("");
    sb.writeln("*Title:* $title");
    sb.writeln("*Date:* $createdAt");
    sb.writeln("*Priority:* $priority");
    sb.writeln("*Status:* $status");
    sb.writeln("");
    sb.writeln("*Instruction:*");
    sb.writeln(description);

    if (task['replies'] != null && (task['replies'] as List).isNotEmpty) {
      sb.writeln("");
      sb.writeln("*Progress History:*");
      for (var reply in task['replies']) {
        sb.writeln(
          "• ${reply['workerName']}: ${reply['replyText']} (${reply['status']})",
        );
      }
    }

    final message = sb.toString();
    final whatsappUrl = "whatsapp://send?text=${Uri.encodeComponent(message)}";
    final webUrl = "https://wa.me/?text=${Uri.encodeComponent(message)}";

    try {
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(
          Uri.parse(whatsappUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback to web URL which opens Safari on simulator
        await launchUrl(
          Uri.parse(webUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp or Safari.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final task = widget.task;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TASK DETAILS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printService.printTaskDetails(task),
            tooltip: 'Print Task',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareTask(task),
            tooltip: 'Share via WhatsApp',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(task, primaryColor),
            const SizedBox(height: 24),
            const Text(
              'SUBMIT PROGRESS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            _buildReplyForm(primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(dynamic task, Color primaryColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task['title'] ?? '',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Instruction:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        if ((task['description'] != null &&
                                task['description'].toString().isNotEmpty) ||
                            (task['voiceDescriptionUrl'] != null &&
                                task['voiceDescriptionUrl']
                                    .toString()
                                    .isNotEmpty))
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: InkWell(
                              onTap: () {
                                final voiceUrl = task['voiceDescriptionUrl'];
                                if (voiceUrl != null &&
                                    voiceUrl.toString().isNotEmpty) {
                                  _playRemoteAudio(voiceUrl.toString());
                                } else {
                                  final desc =
                                      task['description']?.toString() ?? '';
                                  if (desc.isNotEmpty) _tts.speak(desc);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  LucideIcons.volume2,
                                  color: Colors.blue,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task['description'] ?? 'No instruction provided.',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                if ((task['description'] != null &&
                        task['description'].toString().isNotEmpty) ||
                    (task['voiceDescriptionUrl'] != null &&
                        task['voiceDescriptionUrl'].toString().isNotEmpty))
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          LucideIcons.volume2,
                          color: Colors.blue,
                        ),
                        tooltip: 'Listen to instruction',
                        onPressed: () {
                          final voiceUrl = task['voiceDescriptionUrl'];
                          if (voiceUrl != null &&
                              voiceUrl.toString().isNotEmpty) {
                            _playRemoteAudio(voiceUrl.toString());
                          } else {
                            // Fallback: TTS reads the description aloud
                            final desc = task['description']?.toString() ?? '';
                            if (desc.isNotEmpty) _tts.speak(desc);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                _buildChip('Priority: ${task['priority']}', Colors.orange),
                const SizedBox(width: 8),
                _buildChip('Status: ${task['status']}', Colors.blue),
              ],
            ),
            if (task['createdAt'] != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    LucideIcons.calendar,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Created: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(task['createdAt'].toString()))}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            if (task['replies'] != null &&
                (task['replies'] as List).isNotEmpty) ...[
              const Divider(height: 40),
              const Text(
                'History:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...(task['replies'] as List).map((r) {
                final String type = r['type'] ?? 'Progress';
                final String label = type == 'Completion'
                    ? '✅ COMPLETION'
                    : (type == 'Client' ? '💬 CLIENT' : '⚙️ PROGRESS');
                final String dateStr = r['submittedAt'] != null
                    ? DateFormat(
                        'dd-MM-yyyy hh:mm a',
                      ).format(DateTime.parse(r['submittedAt'].toString()))
                    : 'N/A';
                final String? voiceUrl = r['voiceReplyUrl'];

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '• $label: ${r['workerName']} - ${r['replyText']} ($dateStr)',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // Always show speaker for any reply that has text or voice
                      IconButton(
                        icon: const Icon(
                          LucideIcons.volume2,
                          size: 18,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          if (voiceUrl != null && voiceUrl.isNotEmpty) {
                            _playRemoteAudio(voiceUrl);
                          } else {
                            // TTS fallback — read the reply text aloud
                            final replyText = r['replyText']?.toString() ?? '';
                            final workerName =
                                r['workerName']?.toString() ?? '';
                            if (replyText.isNotEmpty) {
                              _tts.speak('$workerName said: $replyText');
                            }
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Listen to reply',
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildReplyForm(Color primaryColor) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _status,
          decoration: const InputDecoration(
            labelText: 'Update Status',
            border: OutlineInputBorder(),
          ),
          items: [
            'To Do',
            'In Progress',
            'Completed',
          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (val) => setState(() => _status = val!),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _workerNameController,
          decoration: const InputDecoration(
            labelText: 'Your Name (Mandatory)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(LucideIcons.user),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _replyController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Progress Details',
            border: const OutlineInputBorder(),
            suffixIcon: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _voiceLocale = _voiceLocale == 'en_US' ? 'ta_IN' : 'en_US';
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
                        _isRecording ? LucideIcons.stopCircle : LucideIcons.mic,
                        color: _isRecording ? Colors.red : primaryColor,
                      ),
                      onPressed: _isRecording
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

        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isSaving ? null : _submitReply,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: ColorPalette.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isSaving
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  'SUBMIT REPORT',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
