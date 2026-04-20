import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../utils/print_utils.dart';
import '../core/constants/api_constants.dart';
import 'package:http/http.dart' as http;
import '../utils/pdf_font_helper.dart';

class QualityAuditPrintService {
  static final QualityAuditPrintService _instance =
      QualityAuditPrintService._internal();
  factory QualityAuditPrintService() => _instance;
  QualityAuditPrintService._internal();

  Future<void> printQualityAudit(List<dynamic> reports) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy HH:mm').format(now);
    final font = await PdfFontHelper.regular;
    final boldFont = await PdfFontHelper.bold;

    // Fetch images helper - PDFs need actual bytes for images
    Future<pw.MemoryImage?> _getMemoryImage(String? path) async {
      if (path == null || path.isEmpty) return null;
      try {
        final url = ApiConstants.getImageUrl(path);
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          return pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        print('Error fetching image for PDF: $e');
      }
      return null;
    }

    for (var item in reports) {
      final isCleared = item['isComplaintCleared'] ?? false;

      // Fetch signatures and images
      final inchargeSig = await _getMemoryImage(item['lotInchargeSignature']);
      final authSig = await _getMemoryImage(item['authorizedSignature']);
      final mdSig = await _getMemoryImage(item['mdSignature']);

      final qualityImg = await _getMemoryImage(item['qualityImage']);
      final complaintImg = await _getMemoryImage(item['complaintImage']);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                PrintUtils.buildCompanyHeader(boldFont, font),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'QUALITY & COMPLAINT AUDIT',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red900,
                      ),
                    ),
                    pw.Text(
                      'Date: $dateStr',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                  ],
                ),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 10),

                // Lot Details
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: isCleared ? PdfColors.green50 : PdfColors.red50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(
                      color: isCleared ? PdfColors.green200 : PdfColors.red200,
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'LOT: ${item['lotNo']} - ${item['lotName']}',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          pw.Text(
                            'Party: ${item['fromParty']}',
                            style: pw.TextStyle(font: boldFont, fontSize: 14),
                          ),
                        ],
                      ),
                      pw.Text(
                        isCleared ? 'CLEARED' : 'PENDING',
                        style: pw.TextStyle(
                          color: isCleared ? PdfColors.green : PdfColors.red,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 15),

                // Complaint Section
                pw.Text(
                  'Complaint Details:',
                  style: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold, fontSize: 13),
                ),
                pw.Text(
                  item['complaintText'] ?? 'None',
                  style: pw.TextStyle(font: boldFont, fontSize: 13, color: PdfColors.red),
                ),
                pw.SizedBox(height: 10),

                // Resolution if any
                if (item['complaintResolution'] != null) ...[
                  pw.Text(
                    'Resolution & Reply:',
                    style: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold, fontSize: 13),
                  ),
                  pw.Text(item['complaintReply'] ?? 'No reply recorded.', style: pw.TextStyle(font: font)),
                  pw.Text('Action: ${item['complaintResolution']}', style: pw.TextStyle(font: font)),
                  pw.SizedBox(height: 10),
                ],

                // Images Row
                pw.Row(
                  children: [
                    if (qualityImg != null)
                      pw.Container(
                        width: 150,
                        height: 150,
                        margin: const pw.EdgeInsets.only(right: 12),
                        child: pw.Column(
                          children: [
                            pw.Image(qualityImg, fit: pw.BoxFit.cover),
                            pw.Text(
                              'Quality Image',
                              style: pw.TextStyle(font: font, fontSize: 8),
                            ),
                          ],
                        ),
                      ),
                    if (complaintImg != null)
                      pw.Container(
                        width: 150,
                        height: 150,
                        child: pw.Column(
                          children: [
                            pw.Image(complaintImg, fit: pw.BoxFit.cover),
                            pw.Text(
                              'Complaint Image',
                              style: pw.TextStyle(font: font, fontSize: 8),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                pw.SizedBox(height: 30),

                // Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildSigBox('Lot Incharge', inchargeSig, boldFont, font),
                    _buildSigBox('Authorized', authSig, boldFont, font),
                    _buildSigBox('MD', mdSig, boldFont, font),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Quality_Audit_Report_${DateFormat('ddMMyy').format(now)}',
    );
  }

  pw.Widget _buildSigBox(String label, pw.MemoryImage? sig, pw.Font boldFont, pw.Font font) {
    return pw.Column(
      children: [
        pw.Container(
          width: 80,
          height: 40,
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
          ),
          child: sig != null ? pw.Image(sig, fit: pw.BoxFit.contain) : null,
        ),
        pw.SizedBox(height: 5),
        pw.Text(label, style: pw.TextStyle(font: boldFont, fontSize: 10)),
      ],
    );
  }
}
