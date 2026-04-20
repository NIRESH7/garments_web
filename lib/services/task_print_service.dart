import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../utils/print_utils.dart';

class TaskPrintService {
  static pw.MemoryImage? _cachedLogo;

  Future<pw.MemoryImage?> _loadLogo() async {
    if (_cachedLogo != null) return _cachedLogo;
    try {
      final logoData = await rootBundle.load('assets/images/app_logo.png');
      _cachedLogo = pw.MemoryImage(logoData.buffer.asUint8List());
      return _cachedLogo;
    } catch (e) {
      print('Error loading app logo for task: $e');
      return null;
    }
  }

  Future<void> printTaskDetails(dynamic task) async {
    final pdf = pw.Document();
    // Use Unicode-capable fonts so Tamil instructions render correctly in print/PDF.
    final font = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final tamilFont = await PdfGoogleFonts.notoSansTamilRegular();
    final tamilBoldFont = await PdfGoogleFonts.notoSansTamilBold();
    final logoImage = await _loadLogo();

    final instructionText =
        (task['description'] ?? 'No instructions provided.').toString();
    final bool instructionHasTamil = _containsTamil(instructionText);
    final pw.TextStyle instructionStyle = pw.TextStyle(
      font: instructionHasTamil ? tamilBoldFont : boldFont,
      fontSize: 13,
      fontFallback: [tamilBoldFont, tamilFont],
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              PrintUtils.buildCompanyHeader(boldFont, font, logo: logoImage),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  'TASK ASSIGNMENT SLIP',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 18,
                    decoration: pw.TextDecoration.underline,
                    fontFallback: [tamilBoldFont, tamilFont],
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              _buildInfoRow(
                'Task Title',
                task['title'] ?? 'N/A',
                boldFont,
                font,
                fallbacks: [tamilFont],
              ),
              _buildInfoRow(
                'Created on',
                _formatDate(task['createdAt']),
                boldFont,
                font,
                fallbacks: [tamilFont],
              ),
              _buildInfoRow(
                'Priority',
                task['priority'] ?? 'Medium',
                boldFont,
                font,
                fallbacks: [tamilFont],
              ),
              _buildInfoRow(
                'Assigned To',
                task['assignedTo'] ?? 'All',
                boldFont,
                font,
                fallbacks: [tamilFont],
              ),
              _buildInfoRow(
                'Status',
                task['status'] ?? 'To Do',
                boldFont,
                font,
                fallbacks: [tamilFont],
              ),

              pw.SizedBox(height: 15),
              pw.Text(
                'Instruction:',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 12,
                  fontFallback: [tamilBoldFont, tamilFont],
                ),
              ),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Text(
                  instructionText,
                  style: instructionStyle,
                ),
              ),

              if (task['replies'] != null &&
                  (task['replies'] as List).isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Progress History:',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 12,
                    fontFallback: [tamilBoldFont, tamilFont],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  headers: ['Date', 'Worker', 'Status', 'Message'],
                  headerStyle: pw.TextStyle(
                    font: boldFont,
                    fontSize: 13,
                    fontFallback: [tamilBoldFont, tamilFont],
                  ),
                  cellStyle: pw.TextStyle(
                    font: boldFont,
                    fontSize: 12,
                    fontFallback: [tamilBoldFont, tamilFont],
                  ),
                  data: (task['replies'] as List)
                      .map(
                        (r) => [
                          _formatDate(r['submittedAt']),
                          r['workerName'] ?? 'N/A',
                          r['status'] ?? 'N/A',
                          r['replyText'] ?? '',
                        ],
                      )
                      .toList(),
                ),
              ],

              pw.Spacer(),
              pw.Divider(thickness: 0.5, color: PdfColors.grey),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Software Copy - IDEAL innerwear',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      color: PdfColors.grey700,
                      fontFallback: [tamilFont],
                    ),
                  ),
                  pw.Text(
                    'Date: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      color: PdfColors.grey700,
                      fontFallback: [tamilFont],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Task_${task['title']?.toString().replaceAll(' ', '_') ?? 'Details'}',
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr.toString());
      return DateFormat('dd-MM-yyyy hh:mm a').format(dt);
    } catch (e) {
      return dateStr.toString();
    }
  }

  bool _containsTamil(String input) {
    return RegExp(r'[\u0B80-\u0BFF]').hasMatch(input);
  }

  pw.Widget _buildInfoRow(
    String label,
    String value,
    pw.Font bold,
    pw.Font normal,
    {List<pw.Font> fallbacks = const []}
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                font: bold,
                fontSize: 11,
                fontFallback: fallbacks,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                font: normal,
                fontSize: 11,
                fontFallback: fallbacks,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
