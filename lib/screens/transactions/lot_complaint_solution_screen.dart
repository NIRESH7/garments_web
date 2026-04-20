import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class LotComplaintSolutionScreen extends StatefulWidget {
  const LotComplaintSolutionScreen({super.key});

  @override
  State<LotComplaintSolutionScreen> createState() =>
      _LotComplaintSolutionScreenState();
}

class _LotComplaintSolutionScreenState
    extends State<LotComplaintSolutionScreen> {
  final _api = MobileApiService();

  List<Map<String, dynamic>> _complaintLots = [];
  String? _selectedLotNo;
  Map<String, dynamic>? _foundInward;
  bool _isLoading = false;
  bool _isSaving = false;

  // Solution Fields
  final _replyController = TextEditingController();
  final _arrestLotController = TextEditingController();
  DateTime? _findDate;
  DateTime? _completionDate;
  String? _resolution; // ACCEPT / RETURN
  bool _isCleared = false;

  @override
  void initState() {
    super.initState();
    _fetchComplaintLots();
  }

  Future<void> _fetchComplaintLots() async {
    setState(() => _isLoading = true);
    try {
      final inwards = await _api.getInwards();
      setState(() {
        _complaintLots = inwards
            .where((i) =>
                i['complaintText'] != null &&
                i['complaintText'].toString().trim().isNotEmpty)
            .cast<Map<String, dynamic>>()
            .toList();
      });
    } catch (e) {
      debugPrint('Error fetching complaint lots: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchLot(String? lotNo) async {
    if (lotNo == null || lotNo.isEmpty) return;

    setState(() {
      _isLoading = true;
      _foundInward = null;
    });

    try {
      final match = _complaintLots.firstWhere(
        (i) => i['lotNo'].toString().toLowerCase() == lotNo.toLowerCase(),
      );

      setState(() {
        _foundInward = match;
        // Populate fields
        _replyController.text = match['complaintReply'] ?? '';
        _arrestLotController.text = match['complaintArrestLotNo'] ?? '';
        _resolution = match['complaintResolution'];
        _isCleared = match['isComplaintCleared'] ?? false;

        if (match['complaintFindDate'] != null) {
          _findDate = DateTime.parse(match['complaintFindDate']);
        } else {
          _findDate = DateTime.now();
        }
        
        if (match['complaintCompletionDate'] != null) {
          _completionDate = DateTime.parse(match['complaintCompletionDate']);
        } else {
          _completionDate = DateTime.now();
        }
      });
        } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_foundInward == null) return;

    setState(() => _isSaving = true);

    final data = {
      'complaintReply': _replyController.text,
      'complaintResolution': _resolution,
      'complaintFindDate': _findDate?.toIso8601String(),
      'complaintCompletionDate': _completionDate?.toIso8601String(),
      'complaintArrestLotNo': _arrestLotController.text,
      'isComplaintCleared': _isCleared,
    };

    try {
      final success = await _api.updateComplaintSolution(
        _foundInward!['_id'],
        data,
      );
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint solution saved successfully'),
          ),
        );
        setState(() {
          _foundInward = null;
          _selectedLotNo = null;
          _replyController.clear();
          _arrestLotController.clear();
          _resolution = null;
          _isCleared = false;
          _findDate = null;
          _completionDate = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save solution')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('COMPLAINT RESOLUTION PROTOCOL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchCard(),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            if (_foundInward != null) ...[
              const SizedBox(height: 16),
              _buildLotInfoCard(),
              const SizedBox(height: 16),
              _buildComplaintCard(),
              const SizedBox(height: 16),
              _buildSolutionForm(),
              const SizedBox(height: 24),
              _buildSaveButton(),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SELECT LOT FOR RESOLUTION', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 1)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedLotNo,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              prefixIcon: const Icon(LucideIcons.search, size: 14),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
            items: _complaintLots.map((lot) {
              return DropdownMenuItem<String>(
                value: lot['lotNo'].toString(),
                child: Text('LOT: ${lot['lotNo']} - ${lot['lotName']}'),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedLotNo = val);
              if (val != null) _searchLot(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLotInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.info, color: Color(0xFF2563EB), size: 16),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LOT: ${_foundInward!['lotNo']} — ${_foundInward!['lotName']}'.toUpperCase(),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF1E40AF), letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text('SENDER GROUP: ${_foundInward!['fromParty']}'.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF60A5FA))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintCard() {
    final complaint = _foundInward!['complaintText'] ?? 'No original complaint text recorded.';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORIGINAL DISCREPANCY RECORD',
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 10, color: const Color(0xFFEF4444), letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Text(
            complaint,
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569), height: 1.6, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TECHNICAL RESOLUTION PROTOCOL',
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 10, color: const Color(0xFF0F172A), letterSpacing: 1),
          ),
          const SizedBox(height: 24),
          _buildIndustrialField('Identification Date', _findDate, (d) => setState(() => _findDate = d)),
          const SizedBox(height: 20),
          _buildIndustrialInput('Solution / Response Log', _replyController, maxLines: 3),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildIndustrialDropdown('Resolution Status', ['ACCEPT', 'RETURN'], _resolution, (v) => setState(() => _resolution = v)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildIndustrialField('Closure Date', _completionDate, (d) => setState(() => _completionDate = d)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildIndustrialInput('Quarantine / Arrest Lot ID', _arrestLotController),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isCleared ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _isCleared ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PROTOCOLE STATUS: ${_isCleared ? "RESOLVED" : "PENDING"}'.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: _isCleared ? const Color(0xFF16A34A) : const Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Text('Mark this complaint as legally cleared from the system.', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
                Switch(
                  value: _isCleared,
                  onChanged: (v) => setState(() => _isCleared = v),
                  activeColor: const Color(0xFF16A34A),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndustrialInput(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
      ],
    );
  }

  Widget _buildIndustrialField(String label, DateTime? value, Function(DateTime) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Text(
                  value != null ? DateFormat('dd-MM-yyyy').format(value) : 'SELECT DATE',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: value == null ? const Color(0xFF94A3B8) : const Color(0xFF0F172A)),
                ),
                const Spacer(),
                const Icon(LucideIcons.calendar, size: 14, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIndustrialDropdown(String label, List<String> items, String? value, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              icon: const Icon(LucideIcons.chevronDown, size: 14),
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _save,
        icon: _isSaving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(LucideIcons.checkCircle, size: 16),
        label: Text('AUTHORIZE & CLOSE PROTOCOL', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}
