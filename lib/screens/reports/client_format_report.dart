import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../services/mobile_api_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';

class ClientFormatReportScreen extends StatefulWidget {
  const ClientFormatReportScreen({super.key});

  @override
  State<ClientFormatReportScreen> createState() =>
      _ClientFormatReportScreenState();
}

class _ClientFormatReportScreenState extends State<ClientFormatReportScreen> {
  final _apiService = MobileApiService();
  List<dynamic> _data = [];
  bool _isLoading = true;
  String? _selectedParty;
  List<String> _parties = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_fetchParties(), _fetchReport()]);
  }

  Future<void> _fetchParties() async {
    final parties = await _apiService.getParties();
    setState(() {
      _parties = parties.map((e) => e['name'].toString()).toList();
    });
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getClientFormatReport(
        fromParty: _selectedParty,
      );
      setState(() {
        _data = res;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load report')));
      }
    }
  }

  Future<void> _shareReportAs(String format) async {
    if (_data.isEmpty) return;

    final pdf = await _generatePDF();
    final now = DateTime.now();
    final dateStr = DateFormat('ddMMyy').format(now);

    if (format == 'PDF') {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Stock_Status_Report_$dateStr.pdf',
      );
    } else if (format == 'Image') {
      // Rasterize the first page of the PDF to an image for sharing
      await for (var page in Printing.raster(
        await pdf.save(),
        pages: [0],
        dpi: 300,
      )) {
        final imageBytes = await page.toPng();
        await Share.shareXFiles([
          XFile.fromData(
            imageBytes,
            name: 'Report_$dateStr.png',
            mimeType: 'image/png',
          ),
        ], text: 'Stock Status Report - $dateStr');
        break; // Just share the first page for simplicity
      }
    } else if (format == 'WhatsApp') {
      // Generate a structured text table for direct WhatsApp sharing
      final buffer = StringBuffer();
      buffer.writeln("*STOCK STATUS REPORT*");
      buffer.writeln(
        "Generated: ${DateFormat('dd-MM-yyyy HH:mm').format(now)}",
      );
      if (_selectedParty != null) buffer.writeln("Party: $_selectedParty");
      buffer.writeln("---------------------------------");
      buffer.writeln("Lot | Party | Date | Bal WT | Status");
      buffer.writeln("---------------------------------");

      for (var item in _data.take(20)) {
        // Limit items for text visibility
        final date = DateTime.parse(item['inwardDate']);
        final lot = item['lotNo'] ?? '';
        final party = (item['fromParty'] ?? '').toString().characters.take(8);
        final dateStr = DateFormat('dd/MM').format(date);
        final bal = ((item['balanceWeight'] ?? 0) as num).toStringAsFixed(1);
        final status = item['status'] == 'In Stock' ? 'IN' : 'DIS';
        buffer.writeln("$lot | $party | $dateStr | $bal | $status");
      }

      if (_data.length > 20) {
        buffer.writeln("... and ${_data.length - 20} more items.");
      }

      await Share.share(buffer.toString());
    }
  }

  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy HH:mm').format(now);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape, // Landscape for table width
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'STOCK STATUS REPORT',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      'Generated on: $dateStr',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
                if (_selectedParty != null)
                  pw.Text(
                    'PARTY FILTER: $_selectedParty',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (pw.Context context) {
          return [
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              headers: [
                'LOT NO/NAME',
                'PARTY NAME',
                'DATE',
                'VEHICLE',
                'ORIGINAL WT',
                'BAL WT',
                'STATUS',
              ],
              data: _data.map((item) {
                final date = DateTime.parse(item['inwardDate']);
                return [
                  '${item['lotNo']}\n${item['lotName']}',
                  item['fromParty']?.toString() ?? '',
                  DateFormat('dd-MM-yy').format(date),
                  item['vehicleNo']?.toString() ?? 'N/A',
                  '${((item['totalWeight'] ?? 0) as num).toStringAsFixed(3)}',
                  '${((item['balanceWeight'] ?? 0) as num).toStringAsFixed(3)}',
                  item['status']?.toString().toUpperCase() ?? '',
                ];
              }).toList(),
            ),
          ];
        },
        footer: (pw.Context context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      ),
    );
    return pdf;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Stock Status Report',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          _buildShareMenu(),
          IconButton(
            icon: const Icon(LucideIcons.printer, size: 20),
            onPressed: () async => Printing.layoutPdf(
              onLayout: (format) async => (await _generatePDF()).save(),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: _fetchReport,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _data.isEmpty
                ? _buildEmptyState()
                : _buildTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildShareMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(LucideIcons.share2, size: 20),
      onSelected: _shareReportAs,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'PDF',
          child: Row(
            children: [
              Icon(LucideIcons.fileText, size: 18),
              SizedBox(width: 8),
              Text("Share as PDF"),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'Image',
          child: Row(
            children: [
              Icon(LucideIcons.image, size: 18),
              SizedBox(width: 8),
              Text("Share as Image"),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'WhatsApp',
          child: Row(
            children: [
              Icon(Icons.message_outlined, size: 18),
              SizedBox(width: 8),
              Text("Share via WhatsApp"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          dataRowMinHeight: 48,
          dataRowMaxHeight: 64,
          columnSpacing: 24,
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 13,
          ),
          columns: const [
            DataColumn(label: Text('Lot Details')),
            DataColumn(label: Text('Party Name')),
            DataColumn(label: Text('Inward Date')),
            DataColumn(label: Text('Vehicle No')),
            DataColumn(label: Text('Original Wt')),
            DataColumn(label: Text('Balance Wt')),
            DataColumn(label: Text('Status')),
          ],
          rows: _data.map((item) => _buildDataRow(item)).toList(),
        ),
      ),
    );
  }

  DataRow _buildDataRow(dynamic item) {
    final date = DateTime.parse(item['inwardDate']);
    final isStk = item['status'] == 'In Stock';

    return DataRow(
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item['lotNo'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                item['lotName'] ?? '',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ),
        ),
        DataCell(Text(item['fromParty'] ?? '')),
        DataCell(Text(DateFormat('dd MMM yy').format(date))),
        DataCell(Text(item['vehicleNo'] ?? 'N/A')),
        DataCell(
          Text("${((item['totalWeight'] ?? 0) as num).toStringAsFixed(3)}"),
        ),
        DataCell(
          Text(
            "${((item['balanceWeight'] ?? 0) as num).toStringAsFixed(3)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isStk ? Colors.orange.shade800 : Colors.green.shade700,
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isStk ? Colors.blue : Colors.green).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item['status'],
              style: TextStyle(
                color: isStk ? Colors.blue : Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedParty,
                  isExpanded: true,
                  hint: const Text("All Parties"),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text("All Parties"),
                    ),
                    ..._parties.map(
                      (e) => DropdownMenuItem(value: e, child: Text(e)),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedParty = v);
                    _fetchReport();
                  },
                ),
              ),
            ),
          ),
          if (_selectedParty != null)
            IconButton(
              icon: const Icon(
                LucideIcons.xCircle,
                color: Colors.red,
                size: 20,
              ),
              onPressed: () {
                setState(() => _selectedParty = null);
                _fetchReport();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.clipboardList,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "No records available",
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
