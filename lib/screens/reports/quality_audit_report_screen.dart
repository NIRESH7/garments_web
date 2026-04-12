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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Quality & Complaint Audit',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        actions: [
          _buildActionButton(
            icon: LucideIcons.printer,
            onPressed: () {
              if (_reports.isNotEmpty) {
                QualityAuditPrintService().printQualityAudit(_reports);
              }
            },
          ),
          _buildActionButton(
            icon: LucideIcons.filter,
            onPressed: _showFilterDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _reports.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    return _buildAuditCard(_reports[index]);
                  },
                ),
    );
  }

  Widget _buildActionButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: const Color(0xFF475569)),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.clipboardCheck, size: 48, color: Colors.blueGrey.shade300),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Audit Records Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your filters or check back later.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              setState(() {
                _lotFilter = null;
                _clearedFilter = null;
              });
              _fetchReport();
            },
            child: const Text('Reset All Filters', style: TextStyle(color: Color(0xFF475569))),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditCard(Map<String, dynamic> item) {
    bool isCleared = item['isComplaintCleared'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'LOT: ${item['lotNo']}',
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item['lotName'] ?? 'Unnamed Lot',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(LucideIcons.factory, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${item['fromParty']}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(isCleared),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Complaint Detail
                Row(
                  children: [
                    const Icon(LucideIcons.alertTriangle, size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    const Text(
                      'Complaint Observation',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFEE2E2)),
                  ),
                  child: Text(
                    (item['complaintText'] != null &&
                            item['complaintText'].toString().isNotEmpty)
                        ? item['complaintText']
                        : 'No issues reported.',
                    style: TextStyle(
                      color: const Color(0xFF991B1B),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),

                // Pictures Section
                const Text(
                  'Audit Visuals',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildImageThumbnail('Quality', item['qualityImage'], item['qualityStatus']),
                      _buildImageThumbnail('GSM', item['gsmImage'], item['gsmStatus']),
                      _buildImageThumbnail('Shade', item['shadeImage'], item['shadeStatus']),
                      _buildImageThumbnail('Washing', item['washingImage'], item['washingStatus']),
                      _buildImageThumbnail('Complaint', item['complaintImage'], null),
                    ],
                  ),
                ),

                if (item['complaintResolution'] != null || item['complaintReply'] != null)
                  _buildResolutionDetails(item),

                const SizedBox(height: 24),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 20),

                // Signatures Section
                const Text(
                  'Authorizations',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSigItem('Audit Incharge', item['lotInchargeSignature']),
                    _buildSigItem('Auth. Manager', item['authorizedSignature']),
                    _buildSigItem('MD Approval', item['mdSignature']),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isCleared) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isCleared ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCleared ? LucideIcons.checkCircle : LucideIcons.clock,
            size: 14,
            color: isCleared ? const Color(0xFF166534) : const Color(0xFF991B1B),
          ),
          const SizedBox(width: 6),
          Text(
            isCleared ? 'CLEARED' : 'PENDING',
            style: TextStyle(
              color: isCleared ? const Color(0xFF166534) : const Color(0xFF991B1B),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(String label, String? path, String? status) {
    if (path == null || path.toString().isEmpty) return const SizedBox.shrink();

    final bool isBad = status == 'Not OK';

    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  ApiConstants.getImageUrl(path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (ctx, err, stack) =>
                      const Center(child: Icon(LucideIcons.imageOff, size: 20, color: Color(0xFFCBD5E1))),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          if (status != null)
            Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isBad ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSigItem(String label, String? path) {
    bool hasSig = path != null && path.isNotEmpty;
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 60,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: hasSig
                ? Image.network(
                    ApiConstants.getImageUrl(path),
                    fit: BoxFit.contain,
                  )
                : Center(
                    child: Text(
                      'N/A',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade300,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionDetails(Map<String, dynamic> item) {
    final resolution = item['complaintResolution'] ?? 'Pending';
    final reply = item['complaintReply'] ?? 'No reply recorded.';
    final arrestLot = item['complaintArrestLotNo'];

    String findDateStr = 'N/A';
    if (item['complaintFindDate'] != null) {
      findDateStr = DateFormat('dd MMM yyyy').format(DateTime.parse(item['complaintFindDate']));
    }

    String completionDateStr = 'N/A';
    if (item['complaintCompletionDate'] != null) {
      completionDateStr = DateFormat('dd MMM yyyy').format(DateTime.parse(item['complaintCompletionDate']));
    }

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0F2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.checkCircle2, size: 16, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              const Text(
                'RESOLUTION SUMMARY',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Color(0xFF0284C7),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFFBAE6FD), height: 1),
          ),
          _buildDetailRow('Discovered On', findDateStr),
          _buildDetailRow('Action Taken', resolution),
          _buildDetailRow('Outcome Note', reply),
          if (arrestLot != null && arrestLot.toString().isNotEmpty)
             _buildDetailRow('Linked Lot', arrestLot),
          _buildDetailRow('Resolution Date', completionDateStr),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF475569),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Filter Reports',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Lot Number',
                  hintText: 'e.g. 2526/00142',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                onChanged: (v) => _lotFilter = v,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<bool?>(
                value: _clearedFilter,
                decoration: InputDecoration(
                  labelText: 'Resolution Status',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Show All Records')),
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
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _fetchReport();
              },
              child: const Text('Apply Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
