import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import '../../services/task_print_service.dart';
import '../../core/constants/api_constants.dart';

class TaskDetailScreen extends StatefulWidget {
  final dynamic task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _api = MobileApiService();
  final _printService = TaskPrintService();

  bool _isSaving = false;
  final _workerNameController = TextEditingController();
  final _replyController = TextEditingController();
  late String _status;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _status = widget.task != null ? (widget.task['status'] ?? 'In Progress') : 'In Progress';
  }

  @override
  void dispose() {
    _workerNameController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
        backgroundColor: error ? ColorPalette.error : ColorPalette.success,
        behavior: SnackBarBehavior.floating,
        width: 300,
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = image.name;
        });
      }
    } catch (e) {
      _showMsg('IMAGE PICK FAILED', error: true);
    }
  }

  Future<void> _submitReply() async {
    final worker = _workerNameController.text.trim();
    if (worker.isEmpty) {
      _showMsg('NAME REQUIRED', error: true);
      return;
    }

    setState(() => _isSaving = true);
    final data = {
      'workerName': worker,
      'replyText': _replyController.text.trim(),
      'status': _status,
      if (_selectedImageBytes != null) 'imageBase64': base64Encode(_selectedImageBytes!),
    };

    try {
      final result = await _api.addTaskReply(widget.task['_id'], data);
      if (result != null && mounted) {
        _showMsg('SYNCED');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showMsg('FAILED', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.task == null) {
      return const Scaffold(body: Center(child: Text('NULL_TASK')));
    }

    return Scaffold(
      backgroundColor: ColorPalette.background,
      body: Column(
        children: [
          _buildProfessionalHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPulseRow(),
                            const SizedBox(height: 24),
                            _buildInstructionModule(),
                            const SizedBox(height: 24),
                            _buildWorkflowRegistry(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      SizedBox(
                        width: 320,
                        child: _buildControlRegistry(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: ColorPalette.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.arrowLeft, size: 18)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MONITORING PROTOCOL', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: ColorPalette.textMuted, letterSpacing: 1.2)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(widget.task['title']?.toString().toUpperCase() ?? 'UNTITLED', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: ColorPalette.textPrimary)),
                      const SizedBox(width: 12),
                      _buildStatusToken(widget.task['status'] ?? 'PENDING'),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _headerButton(icon: LucideIcons.printer, label: 'EXPORT', onTap: () => _printService.printTaskDetails(widget.task)),
              const SizedBox(width: 8),
              _headerButton(icon: LucideIcons.share2, label: 'SHARE', isPrimary: true, onTap: () => _shareTask(widget.task)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerButton({required IconData icon, required String label, bool isPrimary = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? ColorPalette.primary : Colors.white,
          border: Border.all(color: isPrimary ? ColorPalette.primary : ColorPalette.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: isPrimary ? Colors.white : ColorPalette.textPrimary),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: isPrimary ? Colors.white : ColorPalette.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseRow() {
    String date = 'N/A';
    try {
      if (widget.task['createdAt'] != null) {
        date = DateFormat('MMM dd, yyyy').format(DateTime.parse(widget.task['createdAt'].toString()));
      }
    } catch (_) {}

    return Row(
      children: [
        _buildMetricToken('ASSIGNMENT', widget.task['assignedTo']?.toString() ?? 'SYSTEM', LucideIcons.user),
        const SizedBox(width: 12),
        _buildMetricToken('DATE', date, LucideIcons.calendar),
        const SizedBox(width: 12),
        _buildMetricToken('PRIORITY', (widget.task['priority'] ?? 'MEDIUM').toString().toUpperCase(), LucideIcons.zap, isUrgent: widget.task['priority'] == 'High'),
      ],
    );
  }

  Widget _buildMetricToken(String label, String value, IconData icon, {bool isUrgent = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: ColorPalette.border), borderRadius: BorderRadius.circular(4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 10, color: ColorPalette.textMuted),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: ColorPalette.textMuted, letterSpacing: 0.5)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: isUrgent ? ColorPalette.error : ColorPalette.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleHeading('OPERATIONAL SPECIFICATIONS'),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: ColorPalette.border), borderRadius: BorderRadius.circular(4)),
          child: Text(
            widget.task['description'] ?? 'NO WRITTEN LOG.',
            style: GoogleFonts.inter(fontSize: 14, height: 1.6, color: ColorPalette.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkflowRegistry() {
    final List logs = List.from(widget.task['replies'] ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleHeading('STATE HISTORY'),
        const SizedBox(height: 16),
        if (logs.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            width: double.infinity,
            decoration: BoxDecoration(border: Border.all(color: ColorPalette.border, style: BorderStyle.solid), borderRadius: BorderRadius.circular(4)),
            child: Center(child: Text('LOG EMPTY', style: GoogleFonts.inter(fontSize: 10, color: ColorPalette.textMuted))),
          )
        else
          ...logs.reversed.map((l) => _buildLogEntry(l)),
      ],
    );
  }

  Widget _buildLogEntry(dynamic l) {
    String time = 'Pending';
    try {
      if (l['submittedAt'] != null) {
        time = DateFormat('hh:mm a • MMM dd').format(DateTime.parse(l['submittedAt'].toString()));
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: ColorPalette.border), borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l['workerName']?.toString().toUpperCase() ?? 'ADMIN', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900)),
              Text(time.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, color: ColorPalette.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 8),
          Row(children: [_buildStatusToken(l['status'] ?? 'UPDATE')]),
          const SizedBox(height: 8),
          if (l['replyText'] != null && l['replyText'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l['replyText'], style: GoogleFonts.inter(fontSize: 12, color: ColorPalette.textSecondary)),
            ),
          if (l['imageUrl'] != null || l['imageBase64'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(border: Border.all(color: ColorPalette.border)),
                child: l['imageUrl'] != null 
                  ? Image.network('${ApiConstants.baseUrl}${l['imageUrl']}', fit: BoxFit.contain)
                  : Image.memory(base64Decode(l['imageBase64']), fit: BoxFit.contain),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlRegistry() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: ColorPalette.border), borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STATE SYNC', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: ColorPalette.textMuted, letterSpacing: 1)),
          const SizedBox(height: 24),
          _inputPanel('OPERATOR', 'ID...', _workerNameController, LucideIcons.user),
          const SizedBox(height: 16),
          _inputPanel('STATUS', 'Select...', null, LucideIcons.activity, isDropdown: true),
          const SizedBox(height: 16),
          _inputPanel('COMMENT', 'Add...', _replyController, LucideIcons.edit3, lines: 3),
          const SizedBox(height: 24),
          
          // Image Attachment Row
          Text('PROGRESS PROOF', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: ColorPalette.textMuted)),
          const SizedBox(height: 8),
          if (_selectedImageBytes != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: ColorPalette.border), borderRadius: BorderRadius.circular(4)),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.memory(_selectedImageBytes!, width: 40, height: 40, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_selectedImageName ?? 'Proof Image', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: ColorPalette.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(onPressed: () => setState(() { _selectedImageBytes = null; _selectedImageName = null; }), icon: const Icon(LucideIcons.x, size: 14, color: ColorPalette.error)),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(LucideIcons.camera, size: 14),
              label: Text('ATTACH IMAGE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                foregroundColor: ColorPalette.textSecondary,
                side: BorderSide(color: ColorPalette.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          const SizedBox(height: 24),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submitReply,
              style: ElevatedButton.styleFrom(backgroundColor: ColorPalette.primary, foregroundColor: Colors.white, elevation: 0),
              child: _isSaving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('SYNC STATE', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputPanel(String label, String hint, TextEditingController? ctrl, IconData icon, {int lines = 1, bool isDropdown = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: ColorPalette.textMuted)),
        const SizedBox(height: 6),
        if (isDropdown)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: ColorPalette.border), borderRadius: BorderRadius.circular(4)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: ['To Do', 'In Progress', 'Completed'].contains(_status) ? _status : 'To Do',
                items: ['To Do', 'In Progress', 'Completed'].map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800)))).toList(),
                onChanged: (v) => setState(() => _status = v!),
                isExpanded: true,
                icon: const Icon(LucideIcons.chevronDown, size: 12),
              ),
            ),
          )
        else
          TextFormField(
            controller: ctrl,
            maxLines: lines,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: 10, color: ColorPalette.textMuted),
              prefixIcon: Icon(icon, size: 12, color: ColorPalette.primary.withOpacity(0.5)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: ColorPalette.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: ColorPalette.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusToken(String status) {
    Color c = status.toUpperCase() == 'COMPLETED' ? ColorPalette.success : ColorPalette.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(2), border: Border.all(color: c.withOpacity(0.2))),
      child: Text(status.toUpperCase(), style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: c)),
    );
  }

  Widget _titleHeading(String text) {
    return Row(
      children: [
        Container(width: 2, height: 10, color: ColorPalette.primary),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: ColorPalette.textPrimary, letterSpacing: 1)),
      ],
    );
  }

  Future<void> _shareTask(dynamic task) async {
    final sb = StringBuffer();
    sb.writeln("*UPDATE: ${task['title']}*");
    sb.writeln("Status: ${task['status']}");
    final url = "https://wa.me/?text=${Uri.encodeComponent(sb.toString())}";
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
