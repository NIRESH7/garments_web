import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';

class ShadeCardPrintService {
  Future<void> printShadeCard(List<dynamic> groups) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    // Grouping everything into one large list for grid layout if needed,
    // or keep group headers. User said group by Lot Name & Item.

    for (var group in groups) {
      final String groupName = group['groupName'] ?? 'No Lot';
      final List items = group['items'] ?? [];
      final List colours = group['colours'] ?? [];

      if (colours.isEmpty) continue;

      // Group images logic
      List<pw.Widget> colorWidgets = [];
      for (var color in colours) {
        final String? photoPath = color['photo'];
        pw.MemoryImage? netImage;
        if (photoPath != null) {
          try {
            final String fullImageUrl =
                '${ApiConstants.serverUrl}${photoPath.startsWith('/') ? photoPath : '/$photoPath'}';
            final response = await http.get(Uri.parse(fullImageUrl));
            if (response.statusCode == 200) {
              netImage = pw.MemoryImage(response.bodyBytes);
            }
          } catch (e) {}
        }

        colorWidgets.add(
          pw.Container(
            width: 120,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              children: [
                pw.Container(
                  height: 100,
                  width: 100,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    image: netImage != null
                        ? pw.DecorationImage(
                            image: netImage,
                            fit: pw.BoxFit.cover,
                          )
                        : null,
                  ),
                  child: netImage == null
                      ? pw.Center(child: pw.Text('No Image'))
                      : null,
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  color['name'] ?? 'Unknown',
                  style: pw.TextStyle(font: boldFont, fontSize: 10),
                ),
                pw.Text(
                  'GSM: ${color['gsm'] ?? 'N/A'}',
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
              ],
            ),
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SHADE CARD REPORT',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 18,
                  color: PdfColors.indigo,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Lot Name: $groupName',
                style: pw.TextStyle(font: boldFont, fontSize: 14),
              ),
              pw.Text(
                'Items: ${items.join(', ')}',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey),
              pw.SizedBox(height: 16),
            ],
          ),
          build: (context) => [
            pw.Wrap(spacing: 20, runSpacing: 20, children: colorWidgets),
          ],
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
}
