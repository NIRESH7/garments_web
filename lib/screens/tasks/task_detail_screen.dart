import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/mobile_api_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/theme/color_palette.dart';

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
        _stt.listen(onResult: (val) {
          setState(() {
            _replyController.text = val.recognizedWords;
          });
        });
      }
    } else {
      setState(() => _isListening = false);
      _stt.stop();
    }
  }

  Future<void> _submitReply() async {
    if (_workerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submission failed: Worker Name is mandatory!')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status & Reply Submitted Successfully')));
      Navigator.pop(context);
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final task = widget.task;

    return Scaffold(
      appBar: AppBar(title: const Text('TASK DETAILS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(task, primaryColor),
            const SizedBox(height: 24),
            const Text('SUBMIT PROGRESS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            Text(task['title'] ?? '', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 12),
            const Text('Instruction:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            Text(task['description'] ?? 'No instruction provided.', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildChip('Priority: ${task['priority']}', Colors.orange),
                const SizedBox(width: 8),
                _buildChip('Status: ${task['status']}', Colors.blue),
              ],
            ),
            if (task['replies'] != null && (task['replies'] as List).isNotEmpty) ...[
              const Divider(height: 40),
              const Text('History:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...(task['replies'] as List).map((r) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('• ${r['workerName']}: ${r['replyText']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
              )),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildReplyForm(Color primaryColor) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _status,
          decoration: const InputDecoration(labelText: 'Update Status', border: OutlineInputBorder()),
          items: ['To Do', 'In Progress', 'Completed'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
              icon: Icon(_isListening ? LucideIcons.mic : LucideIcons.micOff, color: _isListening ? Colors.red : primaryColor),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSaving 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('SUBMIT REPORT', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
