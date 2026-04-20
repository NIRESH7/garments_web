import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../utils/print_utils.dart';
import '../utils/pdf_font_helper.dart';
import 'package:flutter/services.dart' show rootBundle;

class ReportPrintService {
  // Singleton pattern
  static final ReportPrintService _instance = ReportPrintService._internal();
  factory ReportPrintService() => _instance;
  ReportPrintService._internal();

  static pw.MemoryImage? _cachedLogo;

  Future<pw.MemoryImage?> _loadLogo() async {
    if (_cachedLogo != null) return _cachedLogo;
    try {
      final logoData = await rootBundle.load('assets/images/app_logo.png');
      _cachedLogo = pw.MemoryImage(logoData.buffer.asUint8List());
      return _cachedLogo;
    } catch (e) {
      print('Error loading app logo for report: $e');
      return null;
    }
  }

  Future<Uint8List> generateReportPdf({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    List<String>? footerRow,
    String? subtitle,
    Map<String, pw.MemoryImage>? colorImages,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy HH:mm').format(now);
    final font = await PdfFontHelper.regular;
    final boldFont = await PdfFontHelper.bold;
    final logoImage = await _loadLogo();
    final subtitleStyle = pw.TextStyle(font: font, fontSize: 10);
    final companyTextBase = pw.TextStyle(font: font);
    final companyTextBold = pw.TextStyle(font: boldFont);
    final footerStyle = pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey);

    final tableRows = List<List<String>>.from(rows);
    if (footerRow != null) {
      tableRows.add(footerRow);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) => pw.Column(
          children: [
            PrintUtils.buildCompanyHeader(boldFont, font, logo: logoImage),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      title.toUpperCase(),
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    if (subtitle != null)
                      pw.Text(
                        subtitle,
                        style: subtitleStyle,
                      ),
                  ],
                ),
                pw.Text(
                  'Date: $dateStr',
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (pw.Context context) {
          int colourColIndex = -1;
          for (int i = 0; i < headers.length; i++) {
            if (headers[i].toUpperCase().contains('COLOUR') || headers[i].toUpperCase().contains('COLOR')) {
              colourColIndex = i;
              break;
            }
          }

          return [
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
              children: [
                // Header Row
                pw.TableRow(
                  children: headers.map((h) => pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(h, style: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                  )).toList(),
                ),
                // Data Rows
                ...tableRows.map((row) {
                  final isFooter = footerRow != null && row == tableRows.last;
                  return pw.TableRow(
                    decoration: isFooter ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
                    children: List.generate(row.length, (colIdx) {
                      final val = row[colIdx];
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: (colIdx == colourColIndex && !isFooter)
                            ? PrintUtils.buildColourCell(val, font, image: colorImages?[val.toUpperCase()])
                            : pw.Text(val, style: pw.TextStyle(font: isFooter ? boldFont : font, fontSize: isFooter ? 11 : 10)),
                      );
                    }),
                  );
                }),
              ],
            ),
          ];
        },
        footer: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated by Garments App',
              style: footerStyle,
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: footerStyle,
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }
}
