import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../utils/print_utils.dart';

class TaskPrintService {
  Future<void> printTaskDetails(dynamic task) async {
    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              PrintUtils.buildCompanyHeader(boldFont, font),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  'TASK ASSIGNMENT SLIP',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 18,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              _buildInfoRow(
                'Task Title',
                task['title'] ?? 'N/A',
                boldFont,
                font,
              ),
              _buildInfoRow(
                'Created on',
                _formatDate(task['createdAt']),
                boldFont,
                font,
              ),
              _buildInfoRow(
                'Priority',
                task['priority'] ?? 'Medium',
                boldFont,
                font,
              ),
              _buildInfoRow(
                'Assigned To',
                task['assignedTo'] ?? 'All',
                boldFont,
                font,
              ),
              _buildInfoRow(
                'Status',
                task['status'] ?? 'To Do',
                boldFont,
                font,
              ),

              pw.SizedBox(height: 15),
              pw.Text(
                'Instruction:',
                style: pw.TextStyle(font: boldFont, fontSize: 12),
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
                  task['description'] ?? 'No instructions provided.',
                  style: pw.TextStyle(font: font, fontSize: 11),
                ),
              ),

              if (task['replies'] != null &&
                  (task['replies'] as List).isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Progress History:',
                  style: pw.TextStyle(font: boldFont, fontSize: 12),
                ),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  headers: ['Worker', 'Status', 'Message'],
                  headerStyle: pw.TextStyle(font: boldFont, fontSize: 10),
                  cellStyle: pw.TextStyle(font: font, fontSize: 9),
                  data: (task['replies'] as List)
                      .map(
                        (r) => [
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
                    ),
                  ),
                  pw.Text(
                    'Date: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      color: PdfColors.grey700,
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

  pw.Widget _buildInfoRow(
    String label,
    String value,
    pw.Font bold,
    pw.Font normal,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(font: bold, fontSize: 11),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: normal, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
