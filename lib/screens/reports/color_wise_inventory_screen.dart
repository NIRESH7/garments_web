import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import '../../services/mobile_api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../utils/print_utils.dart';

class ColorWiseInventoryScreen extends StatefulWidget {
  final String lotName;
  final String lotNo;
  final String? dia;
  final String? setNo;
  final List<dynamic> initialData;

  const ColorWiseInventoryScreen({
    super.key,
    required this.lotName,
    required this.lotNo,
    this.dia,
    this.setNo,
    required this.initialData,
  });

  @override
  State<ColorWiseInventoryScreen> createState() => _ColorWiseInventoryScreenState();
}

class _ColorWiseInventoryScreenState extends State<ColorWiseInventoryScreen> {
  final _api = MobileApiService();
  bool _isLoading = true;
  bool _isPrinting = false;
  List<dynamic> _data = [];
  Map<String, String> _colourImages = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Filter the initial data or re-fetch if needed
      // For now, use initialData and filter by Dia/Set if provided
      var filtered = widget.initialData;
      if (widget.dia != null && widget.dia != 'ALL DIAS') {
        filtered = filtered.where((item) => item['dia'].toString() == widget.dia).toList();
      }
      if (widget.setNo != null) {
        filtered = filtered.where((item) => item['setNo'].toString() == widget.setNo).toList();
      }

      // Fetch colour images from categories
      final categories = await _api.getCategories();
      final colourCat = categories.firstWhere(
        (c) => (c['name'] ?? '').toString().toLowerCase().contains('colour'),
        orElse: () => null,
      );

      if (colourCat != null && colourCat['values'] != null) {
        for (var v in colourCat['values']) {
          if (v is Map && v['name'] != null && v['photo'] != null) {
            _colourImages[v['name'].toString()] = ApiConstants.getImageUrl(v['photo']);
          }
        }
      }

      setState(() {
        _data = filtered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = 'COLOUR WISE REPORT';
    if (widget.dia != null) title += ' - DIA ${widget.dia}';
    if (widget.setNo != null) title += ' - SET ${widget.setNo}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          IconButton(
            icon: _isPrinting 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.printer, size: 20),
            onPressed: _isPrinting ? null : _handlePrint,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
              ? _buildEmptyState()
              : _buildGridView(),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        mainAxisExtent: 280,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: _data.length,
      itemBuilder: (context, index) {
        final item = _data[index];
        final colour = item['colour']?.toString() ?? 'N/A';
        final imageUrl = _colourImages[colour];
        final weight = ((item['weight'] as num?) ?? 0).toDouble();
        final rack = item['rackName']?.toString() ?? '-';
        final pallet = item['palletNo']?.toString() ?? '-';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Section
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(color: Colors.grey[100]);
                        },
                        errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(colour),
                      )
                    else
                      _buildImagePlaceholder(colour),
                    
                    // Lot/Set Badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'SET ${item['setNo']}',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Details Section
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              colour.toUpperCase(),
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF1E293B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${weight.toStringAsFixed(2)} KG',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(LucideIcons.mapPin, size: 14, color: const Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            'RACK: $rack',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'PALLET: $pallet',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            'DIA ${item['dia']}',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)),
                          ),
                          const Spacer(),
                          Text(
                            widget.lotName,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePlaceholder(String colour) {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.image, size: 32, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 8),
            Text(
              colour.substring(0, 1).toUpperCase(),
              style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.w900, color: const Color(0xFFCBD5E1).withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.package2, size: 64, color: const Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          Text('No data found for this selection', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  Future<void> _handlePrint() async {
    setState(() => _isPrinting = true);
    try {
      await Printing.layoutPdf(onLayout: (format) async => (await _generatePDF()).save());
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();
    final bold = pw.Font.helveticaBold();
    final normal = pw.Font.helvetica();

    // Fetch images for PDF
    Map<String, pw.MemoryImage> pdfImages = {};
    for (var item in _data) {
      final colour = item['colour']?.toString() ?? 'N/A';
      final url = _colourImages[colour];
      if (url != null && url.isNotEmpty && !pdfImages.containsKey(colour)) {
        try {
          final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) {
            pdfImages[colour] = pw.MemoryImage(response.bodyBytes);
          }
        } catch (e) {
          debugPrint('Error loading image for PDF: $e');
        }
      }
    }
    
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => PrintUtils.buildCompanyHeader(bold, normal),
      build: (context) => [
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('COLOUR WISE INVENTORY REPORT', style: pw.TextStyle(font: bold, fontSize: 16, color: PdfColors.blueGrey800)),
                pw.Text('LOT: ${widget.lotName} (${widget.lotNo})', style: pw.TextStyle(font: normal, fontSize: 10)),
                if (widget.dia != null) pw.Text('DIA: ${widget.dia}', style: pw.TextStyle(font: normal, fontSize: 10)),
              ],
            ),
            pw.Text(DateFormat('dd-MM-yyyy').format(DateTime.now()), style: pw.TextStyle(font: normal, fontSize: 10)),
          ],
        ),
        pw.SizedBox(height: 20),
        
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              children: [
                _pdfH('IMAGE', bold),
                _pdfH('COLOUR', bold),
                _pdfH('SET', bold),
                _pdfH('WEIGHT', bold),
                _pdfH('LOCATION', bold),
              ],
            ),
            // Data
            ..._data.map((item) {
              final colour = item['colour']?.toString() ?? 'N/A';
              final img = pdfImages[colour];
              return pw.TableRow(
                children: [
                  pw.Container(
                    width: 40,
                    height: 40,
                    padding: const pw.EdgeInsets.all(2),
                    child: img != null 
                        ? pw.Image(img, fit: pw.BoxFit.cover)
                        : pw.Center(child: pw.Text('-', style: pw.TextStyle(fontSize: 8))),
                  ),
                  _pdfC(colour.toUpperCase(), normal),
                  _pdfC(item['setNo']?.toString() ?? '', normal),
                  _pdfC('${((item['weight'] as num?) ?? 0).toStringAsFixed(2)} KG', bold),
                  _pdfC('R:${item['rackName'] ?? '-'} P:${item['palletNo'] ?? '-'}', normal),
                ],
              );
            }),
          ],
        ),
      ],
    ));

    return pdf;
  }

  pw.Widget _pdfH(String text, pw.Font font) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white)),
  );

  pw.Widget _pdfC(String text, pw.Font font) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 8)),
  );
}
