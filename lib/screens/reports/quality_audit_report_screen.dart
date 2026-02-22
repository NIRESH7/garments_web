import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';
import '../../core/constants/api_constants.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../services/quality_audit_print_service.dart';

class QualityAuditReportScreen extends StatefulWidget {
  const QualityAuditReportScreen({super.key});

  @override
  State<QualityAuditReportScreen> createState() =>
      _QualityAuditReportScreenState();
}

class _QualityAuditReportScreenState extends State<QualityAuditReportScreen> {
  final _api = MobileApiService();
  List<dynamic> _reports = [];
  bool _isLoading = true;
  String? _lotFilter;
  bool? _clearedFilter;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getQualityAuditReport(
        lotNo: _lotFilter,
        isCleared: _clearedFilter,
      );
      setState(() => _reports = res);
    } catch (e) {
      debugPrint('Error fetching report: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quality & Complaint Audit'),
        backgroundColor: Colors.red.shade700,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.printer),
            onPressed: () {
              if (_reports.isNotEmpty) {
                QualityAuditPrintService().printQualityAudit(_reports);
              }
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.filter),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _reports.length,
              itemBuilder: (context, index) {
                return _buildAuditCard(_reports[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.checkCircle2, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No quality issues found or filtered.'),
          TextButton(
            onPressed: () {
              setState(() {
                _lotFilter = null;
                _clearedFilter = null;
              });
              _fetchReport();
            },
            child: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditCard(Map<String, dynamic> item) {
    bool isCleared = item['isComplaintCleared'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCleared ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LOT: ${item['lotNo']} - ${item['lotName']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Party: ${item['fromParty']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCleared ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCleared ? 'CLEARED' : 'PENDING',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Complaint Detail
                const Text(
                  'Complaint Detail:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  (item['complaintText'] != null && item['complaintText'].toString().isNotEmpty)
                      ? item['complaintText']
                      : 'None',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 12),

                // Pictures Grid
                const Text(
                  'Audit Pictures:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildImageThumbnail(
                        'Quality',
                        item['qualityImage'],
                        item['qualityStatus'],
                      ),
                      _buildImageThumbnail(
                        'GSM',
                        item['gsmImage'],
                        item['gsmStatus'],
                      ),
                      _buildImageThumbnail(
                        'Shade',
                        item['shadeImage'],
                        item['shadeStatus'],
                      ),
                      _buildImageThumbnail(
                        'Washing',
                        item['washingImage'],
                        item['washingStatus'],
                      ),
                      _buildImageThumbnail(
                        'Complaint',
                        item['complaintImage'],
                        null,
                      ),
                    ],
                  ),
                ),

                _buildResolutionDetails(item),
                
                const Divider(height: 32),

                // Signatures
                const Text(
                  'Authorized Signatures:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSigItem('Incharge', item['lotInchargeSignature']),
                    _buildSigItem('Auth', item['authorizedSignature']),
                    _buildSigItem('MD', item['mdSignature']),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(String label, String? path, String? status) {
    if (path == null || path.toString().isEmpty) return const SizedBox.shrink();

    final bool isBad = status == 'Not OK';

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                '${ApiConstants.serverUrl}/$path',
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) =>
                    const Center(child: Icon(Icons.broken_image, size: 20)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          if (status != null)
            Text(
              status,
              style: TextStyle(
                fontSize: 9,
                color: isBad ? Colors.red : Colors.green,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSigItem(String label, String? path) {
    bool hasSig = path != null && path.isNotEmpty;
    return Column(
      children: [
        Container(
          width: 70,
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(4),
          ),
          child: hasSig
              ? Image.network(
                  '${ApiConstants.serverUrl}/$path',
                  fit: BoxFit.contain,
                )
              : const Center(
                  child: Text(
                    'N/A',
                    style: TextStyle(fontSize: 8, color: Colors.grey),
                  ),
                ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9)),
      ],
    );
  }

  Widget _buildResolutionDetails(Map<String, dynamic> item) {
    if (item['complaintResolution'] == null && item['complaintReply'] == null) {
      return const SizedBox.shrink();
    }

    final resolution = item['complaintResolution'] ?? 'Pending';
    final reply = item['complaintReply'] ?? 'No reply recorded.';
    final arrestLot = item['complaintArrestLotNo'];
    
    String findDateStr = 'N/A';
    if (item['complaintFindDate'] != null) {
      findDateStr = DateFormat('dd-MM-yyyy').format(DateTime.parse(item['complaintFindDate']));
    }
    
    String completionDateStr = 'N/A';
    if (item['complaintCompletionDate'] != null) {
      completionDateStr = DateFormat('dd-MM-yyyy').format(DateTime.parse(item['complaintCompletionDate']));
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.checkSquare, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'COMPLAINT RESOLUTION',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.blue, height: 16),
          _buildDetailRow('Complaint Find Date:', findDateStr),
          _buildDetailRow('Result / Reply:', reply),
          _buildDetailRow('Accept / Return:', resolution),
          _buildDetailRow('Completion Date:', completionDateStr),
          if (arrestLot != null && arrestLot.toString().isNotEmpty)
            _buildDetailRow('Complaint Arrest Lot No:', arrestLot),
            
          _buildDetailRow('Complaint Cleared?', (item['isComplaintCleared'] == true) ? 'Yes - Resolved' : 'No - Pending'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Audit Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Lot Number'),
                onChanged: (v) => _lotFilter = v,
              ),
              const SizedBox(height: 16),
              DropdownButton<bool?>(
                value: _clearedFilter,
                hint: const Text('Resolution Status'),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: false, child: Text('Pending Only')),
                  DropdownMenuItem(value: true, child: Text('Cleared Only')),
                ],
                onChanged: (v) => setDialogState(() => _clearedFilter = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _fetchReport();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
