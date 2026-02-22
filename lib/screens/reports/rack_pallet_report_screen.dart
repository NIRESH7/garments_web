import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/color_palette.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/custom_dropdown_field.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../utils/print_utils.dart';

class RackPalletReportScreen extends StatefulWidget {
  const RackPalletReportScreen({super.key});

  @override
  State<RackPalletReportScreen> createState() => _RackPalletReportScreenState();
}

class _RackPalletReportScreenState extends State<RackPalletReportScreen> {
  final _api = MobileApiService();

  String? _selectedLotName;
  String? _selectedRack;
  String? _selectedPallet;

  List<String> _lotNames = ['All'];
  List<String> _racks = ['All'];
  List<String> _pallets = ['All'];
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
        // Racks and Pallets might not be in categories, we might need to extract them from data
        // For now let's just initialize with 'All'
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
      final data = await _api.getRackPalletStockReport(
        lotName: _selectedLotName == 'All' ? null : _selectedLotName,
        rackName: _selectedRack == 'All' ? null : _selectedRack,
        palletNo: _selectedPallet == 'All' ? null : _selectedPallet,
      );
      
      setState(() {
        _reportData = data;
        
        // Dynamically update filters based on current data if not explicitly set
        if (_racks.length <= 1) {
          final uniqueRacks = data.map((e) => e['rackName'].toString()).toSet().toList();
          uniqueRacks.sort();
          _racks = ['All', ...uniqueRacks.where((r) => r != 'N/A' && r != 'null')];
        }
        
        if (_pallets.length <= 1) {
          final uniquePallets = data.map((e) => e['palletNo'].toString()).toSet().toList();
          uniquePallets.sort();
          _pallets = ['All', ...uniquePallets.where((p) => p != 'N/A' && p != 'null')];
        }

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
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) => pw.Column(
          children: [
            PrintUtils.buildCompanyHeader(pw.Font.helveticaBold(), pw.Font.helvetica()),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'RACK & PALLET STOCK REPORT',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  'Generated on: $dateStr',
                  style: const pw.TextStyle(fontSize: 10),
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
              headers: [
                'RACK',
                'PALLET',
                'LOT NAME',
                'LOT NO',
                'DIA',
                'COLOUR',
                'WEIGHT',
                'SET NO',
                'INWARD DATE',
              ],
              data: _reportData.map((item) {
                return [
                  item['rackName'],
                  item['palletNo'],
                  item['lotName'],
                  item['lotNo'],
                  item['dia'],
                  item['colour'],
                  '${item['weight'].toStringAsFixed(2)}',
                  item['setNo'],
                  item['inwardDate'] != null 
                      ? DateFormat('dd-MM-yy').format(DateTime.parse(item['inwardDate']))
                      : 'N/A',
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
      filename: 'Rack_Pallet_Report_${DateFormat('ddMMyy').format(DateTime.now())}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Rack & Pallet Wise Report'),
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
          _buildSummaryLabel(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildReportTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLabel() {
    double totalWeight = _reportData.fold(0.0, (sum, item) => sum + (item['weight'] ?? 0));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        'Showing ${_reportData.length} items | Total Weight: ${totalWeight.toStringAsFixed(2)} kg',
        style: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
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
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomDropdownField(
                    label: 'Rack',
                    value: _selectedRack ?? 'All',
                    items: _racks,
                    onChanged: (v) {
                      setState(() => _selectedRack = v);
                      _fetchReport();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomDropdownField(
                    label: 'Pallet',
                    value: _selectedPallet ?? 'All',
                    items: _pallets,
                    onChanged: (v) {
                      setState(() => _selectedPallet = v);
                      _fetchReport();
                    },
                  ),
                ),
              ],
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
              'No stock items found',
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
              DataColumn(label: Text('RACK', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('PALLET', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('LOT NAME', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('LOT NO', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('COLOUR', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('WT(kg)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('SET NO', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _reportData.map((item) {
              return DataRow(
                cells: [
                  DataCell(Text(item['rackName'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(item['palletNo'] ?? 'N/A')),
                  DataCell(Text(item['lotName'] ?? 'N/A')),
                  DataCell(Text(item['lotNo'] ?? 'N/A')),
                  DataCell(Text(item['colour'] ?? 'N/A')),
                  DataCell(Text('${(item['weight'] ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: ColorPalette.primary))),
                  DataCell(Text(item['setNo'] ?? 'N/A')),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
