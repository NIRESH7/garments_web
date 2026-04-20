import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'inward_data_processor.dart';
import '../core/constants/api_constants.dart';
import '../utils/print_utils.dart';
import '../utils/pdf_font_helper.dart';

class InwardPrintService {
  static pw.MemoryImage? _cachedLogo;

  Future<pw.MemoryImage?> _loadLogo() async {
    if (_cachedLogo != null) return _cachedLogo;
    try {
      final logoData = await rootBundle.load('assets/images/app_logo.png');
      _cachedLogo = pw.MemoryImage(logoData.buffer.asUint8List());
      return _cachedLogo;
    } catch (e) {
      print('Error loading app logo: $e');
      return null;
    }
  }

  Future<Uint8List> generatePdfBytes(Map<String, dynamic> inward) async {
    final pdf = await _buildPdf(inward);
    return pdf.save();
  }

  Future<void> printInwardReport(Map<String, dynamic> inward) async {
    final pdf = await _buildPdf(inward);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Lot_Inward_${inward['lotNo']}',
    );
  }

  Future<pw.MemoryImage?> _loadNetImage(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      String url = ApiConstants.getImageUrl(path);
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return pw.MemoryImage(response.bodyBytes);
      }
    } catch (e) {
      print('Error loading image for PDF: $e');
    }
    return null;
  }

  Future<pw.Document> _buildPdf(Map<String, dynamic> inward) async {
    final pdf = pw.Document();
    final data = InwardDataProcessor.process(inward);
    final dias = data['dias'] as List<String>;
    final rows = data['rows'] as List<Map<String, dynamic>>;
    final totals = data['totals'] as Map<String, dynamic>;

    // Parallel fetch fonts and signatures
    final List<dynamic> results = await Future.wait([
      PdfFontHelper.regular,
      PdfFontHelper.bold,
      _loadNetImage(inward['lotInchargeSignature']?.toString()),
      _loadNetImage(inward['authorizedSignature']?.toString()),
      _loadNetImage(inward['mdSignature']?.toString()),
      _loadLogo(),
    ]);

    final font = results[0] as pw.Font;
    final boldFont = results[1] as pw.Font;
    final inchargeImg = results[2] as pw.MemoryImage?;
    final authImg = results[3] as pw.MemoryImage?;
    final mdImg = results[4] as pw.MemoryImage?;
    final logoImage = results[5] as pw.MemoryImage?;

    // Pre-load colour visual assets
    final Map<String, pw.MemoryImage?> colourImages = {};
    final Map<String, String?> colourHexes = {};
    
    // Collect unique colours from rows
    final List<String> uniqueColours = rows.map((r) => r['colour']?.toString() ?? '').where((c) => c.isNotEmpty).toSet().toList();
    
    // For Lot Inward, we might have colour definitions in inward['storageDetails']
    if (inward['storageDetails'] != null) {
      for (var sd in inward['storageDetails']) {
        for (var row in sd['rows'] ?? []) {
          final cName = row['colour']?.toString();
          if (cName != null && uniqueColours.contains(cName)) {
             if (row['colourImage'] != null) colourHexes[cName] = row['colourImage']; // could be hex or path
          }
        }
      }
    }

    // Try to load images for anything that looks like a path
    final List<Future<void>> imgFutures = [];
    for (var c in uniqueColours) {
      final val = colourHexes[c];
      if (val != null && !val.startsWith('#') && val.length > 7) {
        imgFutures.add(_loadNetImage(val).then((img) => colourImages[c] = img));
      }
    }
    if (imgFutures.isNotEmpty) await Future.wait(imgFutures);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.only(top: 2, left: 20, right: 20, bottom: 20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              PrintUtils.buildCompanyHeader(boldFont, font, logo: logoImage),
              _buildHeader(inward, boldFont, font),
              pw.SizedBox(height: 5),
              _buildTable(dias, rows, totals, font, boldFont, colourImages, colourHexes),
              pw.SizedBox(height: 30),
              // Signatures Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSigBox('Lot Incharge', inchargeImg, boldFont),
                  _buildSigBox('Authorized', authImg, boldFont),
                  _buildSigBox('MD', mdImg, boldFont),
                ],
              ),
              pw.Spacer(),
              _buildFooter(boldFont, font),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildSigBox(String label, pw.MemoryImage? img, pw.Font boldFont) {
    return pw.Column(
      children: [
        pw.Container(
          height: 60,
          width: 100,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: img != null
              ? pw.Image(img, fit: pw.BoxFit.contain)
              : pw.Center(
                  child: pw.Text(
                    'Missing',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 8,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(label, style: pw.TextStyle(font: boldFont, fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildHeader(Map<String, dynamic> inward, pw.Font boldFont, pw.Font font) {
    const double headerFontSize = 8.0;
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'LOT INWARD REPORT',
                  style: pw.TextStyle(font: boldFont, fontSize: 14),
                ),
                pw.Text('Party: ${inward['fromParty']}', style: pw.TextStyle(font: font, fontSize: headerFontSize)),
                pw.Text('Lot Name: ${inward['lotName']}', style: pw.TextStyle(font: font, fontSize: headerFontSize)),
              ],
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(right: 5), // Safe margin from right edge
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Date: ${DateFormat('dd-MM-yyyy').format(DateTime.parse(inward['inwardDate']))}',
                    style: pw.TextStyle(font: font, fontSize: headerFontSize),
                  ),
                  pw.Text('Lot No: ${inward['lotNo']}', style: pw.TextStyle(font: font, fontSize: headerFontSize)),
                  pw.Text('Ref/DC: ${inward['partyDcNo'] ?? 'N/A'}', style: pw.TextStyle(font: font, fontSize: headerFontSize)),
                  pw.Text('Vehicle No: ${inward['vehicleNo'] ?? ""}', style: pw.TextStyle(font: font, fontSize: headerFontSize)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTable(
    List<String> dias,
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> totals,
    pw.Font font,
    pw.Font boldFont,
    Map<String, pw.MemoryImage?> colourImages,
    Map<String, String?> colourHexes,
  ) {
    final headers = [
      'Colour',
      ...dias.map((d) => '$d DIA'),
      'Total Rolls',
      'Total Wt',
    ];

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        for (int i = 0; i < dias.length; i++) i + 1: const pw.FlexColumnWidth(1.5),
        dias.length + 1: const pw.FlexColumnWidth(1.2),
        dias.length + 2: const pw.FlexColumnWidth(1.2),
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: headers.map((h) => pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Center(child: pw.Text(h, style: pw.TextStyle(font: boldFont, fontSize: 11, fontWeight: pw.FontWeight.bold))),
          )).toList(),
        ),
        // Data Rows
        ...rows.map((row) {
          final cName = row['colour']?.toString() ?? '-';
          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: PrintUtils.buildColourCell(
                  cName,
                  font,
                  image: colourImages[cName],
                  hexColor: colourHexes[cName]?.startsWith('#') == true ? colourHexes[cName] : null,
                ),
              ),
              ...dias.map((dia) {
                final cell = row['data'][dia] ?? {'rolls': 0, 'weight': 0.0};
                final txt = (cell['rolls'] == 0 && cell['weight'] == 0) ? '-' : '${cell['rolls']} / ${cell['weight'].toStringAsFixed(2)}';
                return pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Center(child: pw.Text(txt, style: pw.TextStyle(font: font, fontSize: 10))),
                );
              }),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Center(child: pw.Text(row['totalRolls'].toString(), style: pw.TextStyle(font: font, fontSize: 10))),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Center(child: pw.Text(row['totalWeight'].toStringAsFixed(2), style: pw.TextStyle(font: boldFont, fontSize: 10))),
              ),
            ],
          );
        }),
        // Grand Total Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('TOTAL', style: pw.TextStyle(font: boldFont, fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ),
            ...dias.map((dia) {
              final t = totals[dia] ?? {'rolls': 0, 'weight': 0.0};
              final rolls = (t['rolls'] as num?)?.toInt() ?? 0;
              return pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Center(child: pw.Text('$rolls / ${t['weight'].toStringAsFixed(2)}', style: pw.TextStyle(font: boldFont, fontSize: 10))),
              );
            }),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Center(child: pw.Text(totals['grandTotalRolls'].toString(), style: pw.TextStyle(font: boldFont, fontSize: 11))),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Center(child: pw.Text(totals['grandTotalWeight'].toStringAsFixed(2), style: pw.TextStyle(font: boldFont, fontSize: 11))),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Font boldFont, pw.Font font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generated by Garments App',
          style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey),
        ),
        pw.Text(
          'Software Copy - Authorized Signature',
          style: pw.TextStyle(font: boldFont, fontSize: 8),
        ),
      ],
    );
  }
}
