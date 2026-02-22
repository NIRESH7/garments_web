import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/mobile_api_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/theme/color_palette.dart';
import 'package:intl/intl.dart';
import '../../services/task_print_service.dart';
import 'package:url_launcher/url_launcher.dart';

class TaskDetailScreen extends StatefulWidget {
  final dynamic task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _api = MobileApiService();
  final _stt = stt.SpeechToText();
  bool _isListening = false;
  bool _isSaving = false;

  final _workerNameController = TextEditingController();
  final _replyController = TextEditingController();
  String _status = 'In Progress';
  final _printService = TaskPrintService();

  @override
  void initState() {
    super.initState();
    _status = widget.task['status'] ?? 'To Do';
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _stt.initialize();
      if (available) {
        setState(() => _isListening = true);
        _stt.listen(
          onResult: (val) {
            setState(() {
              _replyController.text = val.recognizedWords;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _stt.stop();
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

    final result = await _api.addTaskReply(widget.task['_id'], data);
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
            Text(
              task['title'] ?? '',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Instruction:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            Text(
              task['description'] ?? 'No instruction provided.',
              style: const TextStyle(fontSize: 16),
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
              ...(task['replies'] as List).map(
                (r) {
                  final String type = r['type'] ?? 'Progress';
                  final String label = type == 'Completion' ? '✅ COMPLETION' : (type == 'Client' ? '💬 CLIENT' : '⚙️ PROGRESS');
                  final String dateStr = r['submittedAt'] != null 
                    ? DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(r['submittedAt'].toString())) 
                    : 'N/A';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '• $label: ${r['workerName']} - ${r['replyText']} ($dateStr)',
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  );
                },
              ),
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
            suffixIcon: IconButton(
              icon: Icon(
                _isListening ? LucideIcons.mic : LucideIcons.micOff,
                color: _isListening ? Colors.red : primaryColor,
              ),
              onPressed: _listen,
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
