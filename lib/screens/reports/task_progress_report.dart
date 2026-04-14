import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../services/mobile_api_service.dart';
import '../../utils/print_utils.dart';

class TaskProgressReportScreen extends StatefulWidget {
  const TaskProgressReportScreen({super.key});

  @override
  State<TaskProgressReportScreen> createState() =>
      _TaskProgressReportScreenState();
}

class _TaskProgressReportScreenState extends State<TaskProgressReportScreen> {
  final _api = MobileApiService();
  bool _isLoading = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<dynamic> _tasks = [];
  String _targetDept = 'All';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await _api.getTasks();
      setState(() {
        _tasks = tasks.where((t) {
          final dateStr = t['createdAt']?.toString();
          if (dateStr == null) return false;
          final date = DateTime.parse(dateStr);
          final inRange =
              date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
              date.isBefore(_endDate.add(const Duration(days: 1)));
          final taskDept = t['assignedTo']?.toString() ?? 'Unknown';
          final inDept = _targetDept == 'All' || taskDept == _targetDept;
          return inRange && inDept;
        }).toList();
        _tasks.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.arrowLeft, size: 20, color: Color(0xFF1E293B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                Text(
                  'TASK ANALYTICS',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: const Color(0xFF1E293B),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                _buildActionIcons(),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          
          // Filters
          _buildFilterSection(),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _tasks.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      return _buildTaskEntry(_tasks[index], index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      margin: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('DEPARTMENT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _targetDept,
                      isDense: true,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                      items: ['All', 'Tailoring', 'Packing', 'Cutting']
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (val) {
                        setState(() => _targetDept = val!);
                        _fetchData();
                      },
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 32, width: 1, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 20)),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    setState(() => _startDate = d);
                    _fetchData();
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('FROM', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(LucideIcons.calendar, size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd MMM yyyy').format(_startDate),
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(height: 32, width: 1, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 20)),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    setState(() => _endDate = d);
                    _fetchData();
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('TO', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(LucideIcons.calendar, size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd MMM yyyy').format(_endDate),
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTaskEntry(dynamic task, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title']?.toString().toUpperCase() ?? 'UNTITLED TASK',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.clock, size: 11, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(DateTime.parse(task['createdAt'])),
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 12),
                      const Icon(LucideIcons.user, size: 11, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        task['assignedTo'] ?? 'All',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildStatusChip(task['status'] ?? 'To Do'),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 12),
                Text('DESCRIPTION', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 6),
                Text(
                  task['description'] ?? 'No details provided.',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.5),
                ),
                if (task['replies'] != null && (task['replies'] as List).isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('DIAGNOSTIC HISTORY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB))),
                  const SizedBox(height: 12),
                  for (var reply in task['replies']) _buildReplyLog(reply),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 30).ms).slideX(begin: 0.02);
  }

  Widget _buildReplyLog(dynamic reply) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.messageSquare, size: 12, color: Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      reply['workerName']?.toString().toUpperCase() ?? 'SYSTEM',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                    ),
                    Text(
                      reply['submittedAt'] != null 
                        ? DateFormat('dd MMM HH:mm').format(DateTime.parse(reply['submittedAt']))
                        : 'N/A',
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply['replyText'] ?? '',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = const Color(0xFF64748B);
    if (status == 'Completed') color = const Color(0xFF10B981);
    if (status == 'In Progress') color = const Color(0xFFF59E0B);
    if (status == 'To Do') color = const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.clipboardList, size: 48, color: const Color(0xFF94A3B8).withOpacity(0.3)),
          const SizedBox(height: 12),
          Text('No operational tasks identified', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
  Widget _buildActionIcons() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(LucideIcons.printer, size: 18, color: Color(0xFF64748B)),
          onPressed: () async => Printing.layoutPdf(
            onLayout: (format) async => (await _generatePDF()).save(),
          ),
        ),
        IconButton(
          icon: const Icon(LucideIcons.refreshCw, size: 18, color: Color(0xFF64748B)),
          onPressed: _fetchData,
        ),
      ],
    );
  }

  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();
    final dataSubset = _tasks.take(500).toList();
    final bold = pw.Font.helveticaBold();
    final normal = pw.Font.helvetica();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => PrintUtils.buildCompanyHeader(bold, normal),
      build: (pw.Context context) => [
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('DEPARTMENTAL TASK PROGRESS REPORT', style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColors.blueGrey800)),
            pw.Text('Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}', style: pw.TextStyle(font: normal, fontSize: 8)),
          ],
        ),
        pw.SizedBox(height: 15),
        pw.TableHelper.fromTextArray(
          headers: ['DATE', 'DEPARTMENT', 'TASK DESCRIPTION', 'STATUS', 'REPLY'],
          headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellStyle: pw.TextStyle(font: normal, fontSize: 7),
          data: dataSubset.map((i) => [
             DateFormat('dd MMM yy HH:mm').format(DateTime.parse(i['createdAt'].toString())),
             (i['assignedTo']?.toString().toUpperCase() ?? 'UNKNOWN'),
             i['text']?.toString() ?? 'N/A',
             (i['isSolved'] == true ? 'SOLVED' : 'PENDING'),
             i['replyText']?.toString() ?? '-',
          ]).toList(),
        ),
      ],
    ));
    return pdf;
  }
}
