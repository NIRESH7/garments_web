import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/custom_dropdown_field.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class GodownStockReportScreen extends StatefulWidget {
  const GodownStockReportScreen({super.key});

  @override
  State<GodownStockReportScreen> createState() =>
      _GodownStockReportScreenState();
}

class _GodownStockReportScreenState extends State<GodownStockReportScreen> {
  final _api = MobileApiService();

  String? _selectedLotName;
  String? _selectedDia;

  List<String> _lotNames = ['All'];
  List<String> _dias = ['All'];
  List<dynamic> _reportData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiltersAndData();
  }

  Future<void> _loadFiltersAndData() async {
    try {
      final categories = await _api.getCategories();
      setState(() {
        _lotNames = ['All', ..._getValues(categories, 'Lot Name')];
        _dias = ['All', ..._getValues(categories, 'dia')];
      });
      _fetchReport();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _getValues(List<dynamic> categories, String name) {
    try {
      final match = categories.firstWhere(
        (c) => (c['name'] ?? '').toString().toLowerCase() == name.toLowerCase(),
        orElse: () => null,
      );
      if (match == null) return [];
      final vals = match['values'] as List;
      return vals.map((v) => v['name'].toString()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getGodownStockReport(
        lotName: _selectedLotName == 'All' ? null : _selectedLotName,
        dia: _selectedDia == 'All' ? null : _selectedDia,
      );
      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy HH:mm').format(now);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) => pw.Column(
          children: [
            pw.Text(
              'GODOWN STOCK REPORT',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text(
              'Generated on: $dateStr',
              style: const pw.TextStyle(fontSize: 10),
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
                fontSize: 10,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: [
                'LOT',
                'DIA',
                'STOCK (Kg)',
                'MIN',
                'MAX',
                'NEED WT',
                'NEED ROLL',
                'STATUS',
              ],
              data: _reportData.map((item) {
                return [
                  item['lotName'],
                  item['dia'],
                  '${item['currentWeight'].toStringAsFixed(1)}${item['outsideInput'] != 0 ? ' (+${item['outsideInput']})' : ''}',
                  '${item['minWeight']}',
                  '${item['maxWeight']}',
                  '${item['needWeight'].toStringAsFixed(1)}',
                  '${(item['needWeight'] / 20).toStringAsFixed(1)}',
                  item['status'],
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );
    return pdf;
  }

  Future<void> _shareReport() async {
    if (_reportData.isEmpty) return;
    final pdf = await _generatePDF();
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'Godown_Stock_Report_${DateFormat('ddMMyy').format(DateTime.now())}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Godown Stock (Min/Max)'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.printer, size: 20),
            onPressed: () async => Printing.layoutPdf(
              onLayout: (format) async => (await _generatePDF()).save(),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.share2, size: 20),
            onPressed: _shareReport,
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: _fetchReport,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          _buildSummaryHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildReportTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    int lowCount = _reportData.where((d) => d['status'] == 'LOW STOCK').length;
    int highCount = _reportData
        .where((d) => d['status'] == 'HIGH STOCK')
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _SummaryBox(label: 'LOW', count: lowCount, color: Colors.red),
          const SizedBox(width: 8),
          _SummaryBox(label: 'HIGH', count: highCount, color: Colors.orange),
          const SizedBox(width: 8),
          _SummaryBox(
            label: 'NORMAL',
            count: _reportData.length - lowCount - highCount,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: CustomDropdownField(
                label: 'Lot Name',
                value: _selectedLotName ?? 'All',
                items: _lotNames,
                onChanged: (v) {
                  setState(() => _selectedLotName = v);
                  _fetchReport();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomDropdownField(
                label: 'DIA',
                value: _selectedDia ?? 'All',
                items: _dias,
                onChanged: (v) {
                  setState(() => _selectedDia = v);
                  _fetchReport();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTable() {
    if (_reportData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.package2, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No stock movements captured yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            horizontalMargin: 12,
            columnSpacing: 20,
            columns: const [
              DataColumn(
                label: Text(
                  'LOT/DIA',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'STOCK',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'MIN',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'MAX',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'NEED WT',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'NEED ROLL',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'STATUS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: _reportData.map((item) {
              final status = item['status'];
              Color statusColor = Colors.green;
              if (status == 'LOW STOCK') statusColor = Colors.red;
              if (status == 'HIGH STOCK') statusColor = Colors.orange;

              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item['lotName'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'DIA ${item['dia']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${item['currentWeight'].toStringAsFixed(1)}kg',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (item['outsideInput'] != 0)
                          Text(
                            'Adj: ${item['outsideInput']}kg',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                            ),
                          ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      '${item['minWeight']}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${item['maxWeight']}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${item['needWeight'].toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ColorPalette.primary,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${(item['needWeight'] / 20).toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryBox({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
