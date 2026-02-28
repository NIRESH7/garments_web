import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LotComplaintSolutionScreen extends StatefulWidget {
  const LotComplaintSolutionScreen({super.key});

  @override
  State<LotComplaintSolutionScreen> createState() =>
      _LotComplaintSolutionScreenState();
}

class _LotComplaintSolutionScreenState
    extends State<LotComplaintSolutionScreen> {
  final _api = MobileApiService();
  final _lotNoController = TextEditingController();

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

      if (match != null) {
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
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lot Number not found')));
      }
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
      appBar: AppBar(
        title: const Text('Complaint Solution Module'),
        backgroundColor: ColorPalette.primary,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedLotNo,
              decoration: const InputDecoration(
                labelText: 'Select Lot Number',
                prefixIcon: Icon(LucideIcons.search),
                border: OutlineInputBorder(),
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
      ),
    );
  }

  Widget _buildLotInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(LucideIcons.info, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lot: ${_foundInward!['lotNo']} - ${_foundInward!['lotName']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Party: ${_foundInward!['fromParty']}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintCard() {
    final complaint =
        _foundInward!['complaintText'] ??
        'No original complaint text recorded.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ORIGINAL COMPLAINT',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.red,
              ),
            ),
            const Divider(),
            Text(complaint),
          ],
        ),
      ),
    );
  }

  Widget _buildSolutionForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'COMPLAINT RESOLUTION',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildDatePicker(
              'Complaint Find Date',
              _findDate,
              (d) => setState(() => _findDate = d),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _replyController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Result / Reply',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _resolution,
                    decoration: const InputDecoration(
                      labelText: 'Accept / Return',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ACCEPT', child: Text('ACCEPT')),
                      DropdownMenuItem(value: 'RETURN', child: Text('RETURN')),
                    ],
                    onChanged: (v) => setState(() => _resolution = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDatePicker(
              'Completion Date',
              _completionDate,
              (d) => setState(() => _completionDate = d),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _arrestLotController,
              decoration: const InputDecoration(
                labelText: 'Complaint Arrest Lot No',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Complaint Cleared?'),
              subtitle: Text(_isCleared ? 'Yes - Resolved' : 'No - Pending'),
              value: _isCleared,
              onChanged: (v) => setState(() => _isCleared = v),
              activeColor: ColorPalette.success,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? value,
    Function(DateTime) onPicked,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(LucideIcons.calendar),
        ),
        child: Text(
          value != null
              ? DateFormat('dd-MM-yyyy').format(value)
              : 'Select Date',
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _save,
        icon: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(LucideIcons.save),
        label: const Text('Save Resolution'),
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorPalette.success,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
